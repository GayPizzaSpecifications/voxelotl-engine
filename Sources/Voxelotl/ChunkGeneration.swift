import Foundation

public struct ChunkGeneration {
  private let queue: OperationQueue
  private let localReadyChunks = ConcurrentDictionary<SIMD3<Int>, Chunk>()
  private var generatingChunkSet = Set<SIMD3<Int>>()

  weak var world: World?

  init(queue: DispatchQueue) {
    self.queue = OperationQueue()
    self.queue.underlyingQueue = queue
    self.queue.maxConcurrentOperationCount = 8
    self.queue.qualityOfService = .userInitiated
  }

  public mutating func generate(chunkID: SIMD3<Int>) {
    if !generatingChunkSet.insert(chunkID).inserted {
      return
    }

    self.queueGenerateJob(chunkID: chunkID)
  }

  func queueGenerateJob(chunkID: SIMD3<Int>) {
    self.queue.addOperation {
      guard let world = self.world else {
        return
      }
      let chunk = world.generateSingleChunkUncommitted(chunkID: chunkID)
      self.localReadyChunks[chunkID] = chunk
    }
  }

  public mutating func generateAdjacentIfNeeded(position: SIMD3<Float>) {
    guard let world = self.world else {
      return
    }
    let centerChunkID = World.makeID(position: position)
    let range = -2...2
    for z in range {
      for y in range {
        for x in range {
          let chunkID = centerChunkID &+ SIMD3(x, y, z)
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
      world.addChunk(chunkID: chunkID, chunk: chunk)
      self.generatingChunkSet.remove(chunkID)
    }
  }
}
