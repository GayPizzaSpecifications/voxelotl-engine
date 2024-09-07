import Foundation

public struct ChunkGeneration {
  private let queue: OperationQueue
  private let localReadyChunks = ConcurrentDictionary<ChunkID, Chunk>()
  private var generatingChunkSet = Set<ChunkID>()

  weak var world: World?

  init(queue: DispatchQueue) {
    self.queue = OperationQueue()
    self.queue.underlyingQueue = queue
    self.queue.maxConcurrentOperationCount = 8
    self.queue.qualityOfService = .userInitiated
  }

  public mutating func cancelAndClearAll() {
    self.queue.cancelAllOperations()
    self.queue.waitUntilAllOperationsAreFinished()
    self.localReadyChunks.removeAll()
    self.generatingChunkSet.removeAll()
  }

  public mutating func generate(chunkID: ChunkID) {
    if generatingChunkSet.insert(chunkID).inserted {
      self.queueGenerateJob(chunkID: chunkID)
    }
  }

  func queueGenerateJob(chunkID: ChunkID) {
    self.queue.addOperation {
      guard let world = self.world else {
        return
      }
      let chunk = world.generateSingleChunkUncommitted(id: chunkID)
      self.localReadyChunks[chunkID] = chunk
    }
  }

  public mutating func generateAdjacentIfNeeded(position: SIMD3<Float>) {
    guard let world = self.world else {
      return
    }
    let centerChunkID = ChunkID(fromPosition: position)
    let range = -2...2
    for z in range {
      for y in range {
        for x in range {
          let chunkID = centerChunkID &+ ChunkID(x, y, z)
          if world.getChunk(id: chunkID) == nil {
            self.generate(chunkID: chunkID)
          }
        }
      }
    }
  }

  public func waitForActiveOperations() {
    self.queue.waitUntilAllOperationsAreFinished()
  }

  public mutating func acceptReadyChunks() {
    guard let world = self.world else {
      return
    }

    if self.generatingChunkSet.isEmpty {
      return
    }

    for (chunkID, chunk) in self.localReadyChunks.take() {
      world.addChunk(id: chunkID, chunk: chunk)
      self.generatingChunkSet.remove(chunkID)
    }
  }
}
