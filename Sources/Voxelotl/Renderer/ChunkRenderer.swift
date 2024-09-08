import simd

public struct ChunkRenderer {
  private weak var _renderer: Renderer?
  private var _renderChunks = [ChunkID: RendererMesh]()

  public var material: Material

  public init(renderer: Renderer) {
    self._renderer = renderer
    self.material = .init(ambient: .black, diffuse: .white, specular: .white, gloss: 20.0)
  }

  public mutating func draw(environment: Environment, camera globalCamera: Camera) {
    let fChunkSz = Float(Chunk.size), divisor = 1 / fChunkSz
    let origin = SIMD3<Int>(floor(globalCamera.position * divisor), rounding: .down)

    let localCamera = Camera(globalCamera)
    localCamera.position = globalCamera.position - SIMD3<Float>(origin) * fChunkSz

    self._renderer!.setupBatch(environment: environment, camera: localCamera)
    for (chunkID, mesh) in self._renderChunks {
      let drawPos = SIMD3<Float>(SIMD3<Int>(chunkID) &- origin) * fChunkSz
      self._renderer!.submit(
        mesh: mesh,
        instance: .init(world: .translate(drawPos)),
        material: self.material)
    }
  }

  public mutating func addChunk(id chunkID: ChunkID, mesh: RendererMesh) {
    self._renderChunks.updateValue(mesh, forKey: chunkID)
  }

  public mutating func removeChunk(id chunkID: ChunkID) {
    self._renderChunks.removeValue(forKey: chunkID)
  }

  public mutating func removeAll() {
    self._renderChunks.removeAll()
  }
}
