import simd

class Game: GameDelegate {
  private var fpsCalculator = FPSCalculator()
  var camera = Camera(fov: 60, size: .one, range: 0.06...900)
  var player = Player()
  var projection: matrix_float4x4 = .identity
  var world = World(generator: StandardWorldGenerator())
  var cubeMesh: RendererMesh?
  var chunkMeshGeneration: ChunkMeshGeneration!
  var chunkRenderer: ChunkRenderer!
  var modelBatch: ModelBatch!

  func create(_ renderer: Renderer) {
    self.chunkRenderer = ChunkRenderer(renderer: renderer)
    self.chunkRenderer.material = .init(
      ambient:  Color(rgba8888: 0x4F4F4F00).linear,
      diffuse:  Color(rgba8888: 0xDFDFDF00).linear,
      specular: Color(rgba8888: 0x2F2F2F00).linear,
      gloss: 75)

    self.resetPlayer()
    self.generateWorld()
    self.world.waitForActiveOperations()

    self.cubeMesh = renderer.createMesh(CubeMeshBuilder.build(bound: .fromUnitCube(position: .zero, scale: .one)))

    renderer.clearColor = Color<Double>.black.mix(.white, 0.1).linear
    self.chunkMeshGeneration = .init(
      world: world, renderer: renderer,
      queue: .global(qos: .userInitiated))
    self.modelBatch = renderer.createModelBatch()
  }

  private func resetPlayer() {
    self.player.position = .init(repeating: 0.5) + .up * Float(Chunk.size) * 1.6
    self.player.velocity = .zero
    self.player.rotation = .init(.pi, 0)
  }

  private func generateWorld() {
    self.world.removeAllChunks()
    self.chunkRenderer.removeAll()
    let seed = UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32
    printErr(seed)
#if DEBUG
    self.world.generate(width: 2, height: 2, depth: 2, seed: seed)
#else
    self.world.generate(width: 5, height: 3, depth: 5, seed: seed)
#endif
  }

  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    let deltaTime = min(Float(time.delta.asFloat), 1.0 / 15)

    var reset = false, generate = false, regenChunk = false
    if let pad = GameController.current?.state {
      if pad.pressed(.back) { reset = true }
      if pad.pressed(.start) { generate = true }
      if pad.pressed(.guide) { regenChunk = true }
    }
    if Keyboard.pressed(.r) { reset = true }
    if Keyboard.pressed(.g) { generate = true }
    if Keyboard.pressed(.p) { regenChunk = true }

    // Player reset
    if reset {
      self.resetPlayer()
    }
    // Regenerate world
    if generate {
      self.generateWorld()
    }

    self.player.update(deltaTime: deltaTime, world: world, camera: &camera)

    // Regenerate current chunk
    if regenChunk {
      let chunkID = ChunkID(fromPosition: self.player.position)
      let chunk = self.world.generateSingleChunkUncommitted(id: chunkID)
      self.world.addChunk(id: chunkID, chunk: chunk)
    }

    self.world.generateAdjacentChunksIfNeeded(position: self.player.position)
    self.world.update()
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let totalTime = Float(time.total.asFloat)

    let env = Environment(
      cullFace: .back,
      lightDirection: .init(0.75, -1, 0.5))

    // Update chunk meshes if needed
    self.world.handleRenderDamagedChunks { id, chunk in
      self.chunkMeshGeneration.generate(id: id, chunk: chunk)
    }
    self.chunkMeshGeneration.acceptReadyMeshes(&self.chunkRenderer)

    self.chunkRenderer.draw(environment: env, camera: self.camera)

    self.modelBatch.begin(camera: camera, environment: env)
    if let position = player.rayhitPos {
      let rotation: simd_quatf =
        .init(angle: totalTime * 3.0, axis: .Y) *
        .init(angle: totalTime * 1.5, axis: .X) *
        .init(angle: totalTime * 0.7, axis: .Z)
      self.modelBatch.draw(.init(mesh: self.cubeMesh!, material: .init(
          ambient:  .black.mix(.green, 0.65).linear,
          diffuse:  .white.mix(.black, 0.20).linear,
          specular: .magenta.linear,
          gloss:    250)),
        position: position, scale: 0.0725 * 0.5, rotation: rotation,
        color: .init(r: 0.5, g: 0.5, b: 1))
    }

    self.modelBatch.end()
  }

  func resize(_ size: Size<Int>) {
    self.camera.size = size
  }
}
