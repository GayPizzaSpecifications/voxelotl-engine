import simd

struct Instance {
  let position: SIMD3<Float>
  let scale: SIMD3<Float>
  let rotation: simd_quatf
  let color: Color<Float16>

  init(
    position: SIMD3<Float> = .zero,
    scale: SIMD3<Float> = .one,
    rotation: simd_quatf = .identity,
    color: Color<Float16> = .white
  ) {
    self.position = position
    self.scale = scale
    self.rotation = rotation
    self.color = color
  }
}

class Game: GameDelegate {
  private var fpsCalculator = FPSCalculator()
  var camera = Camera(fov: 60, size: .one, range: 0.06...900)
  var player = Player()
  var projection: matrix_float4x4 = .identity
  var chunk = Chunk(position: .zero)

  var rayhitPos = SIMD3<Float>.zero

  init() {
    self.resetPlayer()
    self.generateWorld()
  }

  private func resetPlayer() {
    self.player.position = .init(repeating: 0.5) + .init(0, Float(Chunk.chunkSize), 0)
    self.player.velocity = .zero
    self.player.rotation = .init(.pi, 0)
  }

  private func generateWorld() {
    var random: any RandomProvider
#if true
    let newSeed = UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32
    printErr(newSeed)
    random = Xoroshiro128PlusPlus(seed: newSeed)
#else
    random = PCG32Random(state: (
        UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32,
        UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32))
#endif
    let noise = ImprovedPerlin<Float>(random: &random)
    self.chunk.fill(allBy: { position in
      let fpos = SIMD3<Float>(position)
      return if fpos.y / Float(Chunk.chunkSize)
          + noise.get(fpos * 0.07) * 0.7
          + noise.get(fpos * 0.321 + 100) * 0.3 < 0.6 {
        .solid(.init(
          r: Float16(noise.get(fpos * 0.1)),
          g: Float16(noise.get(fpos * 0.1 + 10)),
          b: Float16(noise.get(fpos * 0.1 + 100))).mix(.white, 0.4).linear)
      } else {
        .air
      }
    })
  }

  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    let deltaTime = min(Float(time.delta.asFloat), 1.0 / 15)

    var destroy = false
    if let pad = GameController.current?.state {
      if pad.pressed(.south) {
        destroy = true
      }

      // Player reset
      if pad.pressed(.back) {
        self.resetPlayer()
      }

      // Regenerate
      if pad.pressed(.start) {
        self.generateWorld()
      }
    }

    if Keyboard.pressed(.r) {
      self.resetPlayer()
    }
    if Keyboard.pressed(.g) {
      self.generateWorld()
    }

    self.player.update(deltaTime: deltaTime, chunk: chunk)
    self.camera.position = player.eyePosition
    self.camera.rotation = player.eyeRotation

    if let hit = raycast(
      chunk: chunk,
      origin: player.eyePosition,
      direction: .forward * simd_matrix3x3(player.eyeRotation),
      maxDistance: 3.333
    ) {
      self.rayhitPos = hit.position
      if destroy {
        self.chunk.setBlock(at: hit.map, type: .air)
      }
    }
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let totalTime = Float(time.total.asFloat)

    var instances = chunk.compactMap { block, position in
      if case let .solid(color) = block.type {
        Instance(
          position: SIMD3<Float>(chunk.position &+ position) + 0.5,
          scale:    .init(repeating: 0.5),
          color:    color)
      } else { nil }
    }
    instances.append(
      Instance(
        position: rayhitPos,
        scale:    .init(repeating: 0.0725 * 0.5),
        rotation:
          .init(angle: totalTime * 3.0, axis: .init(0, 1, 0)) *
          .init(angle: totalTime * 1.5, axis: .init(1, 0, 0)) *
          .init(angle: totalTime * 0.7, axis: .init(0, 0, 1)),
        color:    .init(r: 0.5, g: 0.5, b: 1).linear))
    if !instances.isEmpty {
      renderer.batch(instances: instances, camera: self.camera)
    }
  }

  func resize(_ size: Size<Int>) {
    self.camera.setSize(size)
  }
}
