import Foundation

public struct ChunkMeshGeneration {
  private let queue: OperationQueue
  private let localReadyMeshes = ConcurrentDictionary<SIMD3<Int>, RendererMesh?>()

  weak var game: Game?
  weak var renderer: Renderer?

  init(queue: DispatchQueue) {
    self.queue = OperationQueue()
    self.queue.underlyingQueue = queue
    self.queue.maxConcurrentOperationCount = 8
    self.queue.qualityOfService = .userInitiated
  }

  public mutating func generate(chunkID: SIMD3<Int>, chunk: Chunk) {
    self.queueGenerateJob(chunkID: chunkID, chunk: chunk)
  }

  func queueGenerateJob(chunkID: SIMD3<Int>, chunk: Chunk) {
    self.queue.addOperation {
      guard let game = self.game else {
        return
      }

      guard let renderer = self.renderer else {
        return
      }

      let mesh = ChunkMeshBuilder.build(world: game.world, chunk: chunk)
      self.localReadyMeshes[chunkID] = renderer.createMesh(mesh)
    }
  }

  public mutating func acceptReadyMeshes() {
    guard let game = self.game else {
      return
    }

    queue.waitUntilAllOperationsAreFinished()

    for (chunkID, mesh) in self.localReadyMeshes.take() {
      game.renderChunks.updateValue(mesh, forKey: chunkID)
    }
  }
}
