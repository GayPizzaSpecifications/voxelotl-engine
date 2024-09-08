import Foundation

public struct ChunkMeshGeneration {
  private let queue: OperationQueue
  private let localReadyMeshes = ConcurrentDictionary<ChunkID, RendererMesh?>()

  private weak var _world: World?
  private weak var _renderer: Renderer?

  init(world: World, renderer: Renderer, queue: DispatchQueue) {
    self._world = world
    self._renderer = renderer
    self.queue = OperationQueue()
    self.queue.underlyingQueue = queue
    self.queue.maxConcurrentOperationCount = 8
    self.queue.qualityOfService = .userInitiated
  }

  public mutating func generate(id chunkID: ChunkID, chunk: Chunk) {
    self.queueGenerateJob(id: chunkID, chunk: chunk)
  }

  func queueGenerateJob(id chunkID: ChunkID, chunk: Chunk) {
    self.queue.addOperation {
      let mesh = ChunkMeshBuilder.build(world: self._world!, chunk: chunk)
      self.localReadyMeshes[chunkID] = self._renderer!.createMesh(mesh)
    }
  }

  public mutating func acceptReadyMeshes(_ chunkRenderer: inout ChunkRenderer) {
    queue.waitUntilAllOperationsAreFinished()
    for (chunkID, mesh) in self.localReadyMeshes.take() {
      if let mesh = mesh {
        chunkRenderer.addChunk(id: chunkID, mesh: mesh)
      } else {
        chunkRenderer.removeChunk(id: chunkID)
      }
    }
  }
}
