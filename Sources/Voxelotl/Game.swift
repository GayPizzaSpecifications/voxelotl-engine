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
  var world = World()
  var cubeMesh: RendererMesh?

  var renderMode: Bool = false
  var damageChunks = [SIMD3<Int>: Mesh<VertexPositionNormalColorTexcoord, UInt16>]()
  var renderChunks = [SIMD3<Int>: RendererMesh]()

  func create(_ renderer: Renderer) {
    self.resetPlayer()
    self.generateWorld()

    self.cubeMesh = renderer.createMesh(CubeMeshBuilder.build(bound: .fromUnitCube(position: .zero, scale: .one)))

    renderer.clearColor = Color<Double>.black.mix(.white, 0.1).linear
  }

  private func resetPlayer() {
    self.player.position = .init(repeating: 0.5) + .up * Float(Chunk.size)
    self.player.velocity = .zero
    self.player.rotation = .init(.pi, 0)
  }

  private func generateWorld() {
    let seed = UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32
    printErr(seed)
#if DEBUG
    self.world.generate(width: 2, height: 2, depth: 2, seed: seed)
#else
    self.world.generate(width: 5, height: 3, depth: 5, seed: seed)
#endif

    // Build chunk meshes
    self.rebuildChunkMeshes()
  }

  private func rebuildChunkMeshes() {
    self.world.forEachChunk { id, chunk in
      self.damageChunks[id] = ChunkMeshBuilder.build(world: self.world, chunkID: id)
    }
  }

  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    let deltaTime = min(Float(time.delta.asFloat), 1.0 / 15)

    var reset = false, generate = false, toggleRenderMode = false
    if let pad = GameController.current?.state {
      if pad.pressed(.back) { reset = true }
      if pad.pressed(.start) { generate = true }
      if pad.pressed(.guide) { toggleRenderMode = true }
    }
    if Keyboard.pressed(.r) { reset = true }
    if Keyboard.pressed(.g) { generate = true }
    if Keyboard.pressed(.p, repeat: true) { toggleRenderMode = true }
    if Keyboard.pressed(.leftBracket) { self.rebuildChunkMeshes() }

    // Player reset
    if reset {
      self.resetPlayer()
    }
    // Regenerate
    if generate {
      self.generateWorld()
    }
    if toggleRenderMode {
      self.renderMode = !self.renderMode
    }

    self.player.update(deltaTime: deltaTime, world: world, camera: &camera)
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let totalTime = Float(time.total.asFloat)

    let env = Environment(
      cullFace: .back,
      lightDirection: .init(0.75, -1, 0.5))
    let material = Material(
      ambient:  Color(rgba8888: 0x4F4F4F00).linear,
      diffuse:  Color(rgba8888: 0xDFDFDF00).linear,
      specular: Color(rgba8888: 0x2F2F2F00).linear,
      gloss: 75)

    if self.renderMode {
      // Update chunk meshes if needed
      if !self.damageChunks.isEmpty {
        for i in self.damageChunks {
          if let new = renderer.createMesh(i.1) {
            self.renderChunks[i.0] = new
          } else {
            self.renderChunks.removeValue(forKey: i.0)
          }
        }
        self.damageChunks = [:]
      }

      for (id, chunk) in self.renderChunks {
        let drawPos = SIMD3<Float>(id &<< Chunk.shift)
        renderer.draw(
          model: .translate(drawPos),
          color: .white,
          mesh: chunk,
          material: material,
          environment: env,
          camera: self.camera)
      }
    }

    var instances = self.renderMode ? [Instance]() : world.instances
    if let position = player.rayhitPos {
      instances.append(
        Instance(
          position: position,
          scale:    .init(repeating: 0.0725 * 0.5),
          rotation:
            .init(angle: totalTime * 3.0, axis: .init(0, 1, 0)) *
            .init(angle: totalTime * 1.5, axis: .init(1, 0, 0)) *
            .init(angle: totalTime * 0.7, axis: .init(0, 0, 1)),
          color:    .init(r: 0.5, g: 0.5, b: 1).linear))
    }
    if self.cubeMesh != nil && !instances.isEmpty {
      renderer.batch(instances: instances, mesh: self.cubeMesh!, material: material, environment: env, camera: self.camera)
    }
  }

  func resize(_ size: Size<Int>) {
    self.camera.size = size
  }
}
