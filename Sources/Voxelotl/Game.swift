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
#if true
    let newSeed = UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32
    printErr(newSeed)
    var random = Xoroshiro128PlusPlus(seed: newSeed)
#else
    var random = PCG32Random(
      seed: UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32,
      sequence: UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32)
#endif
    self.chunk.fill(allBy: {
      if (random.next() & 0x1) == 0x1 {
        .solid(.init(rgb888: UInt32(random.next(in: 0..<0xFFFFFF+1))).linear)
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

    if let pad = GameController.current?.state {
      // Delete block underneath player
      if pad.pressed(.south) {
        self.chunk.setBlock(at: SIMD3(player.position + .down * 0.2), type: .air)
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
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let instances = chunk.compactMap { block, position in
      if case let .solid(color) = block.type {
        Instance(
          position: SIMD3<Float>(position) + 0.5,
          scale:    .init(repeating: 0.5),
          color:    color)
      } else { nil }
    }
    if !instances.isEmpty {
      renderer.batch(instances: instances, camera: self.camera)
    }
  }

  func resize(_ size: Size<Int>) {
    self.camera.setSize(size)
  }
}
