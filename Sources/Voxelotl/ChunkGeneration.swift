import Foundation
import Spatial

public struct ChunkGeneration {
  private let queue: OperationQueue
  private let localReadyChunks = ConcurrentDictionary<SIMD3<Int>, Chunk>()
  private var chunkGenerationOperations = ConcurrentDictionary<SIMD3<Int>, WeakChunkGenerationOperationHolder>()
  private var generatingChunkSet = Set<SIMD3<Int>>()

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

  public mutating func generate(chunkID: SIMD3<Int>) {
    if generatingChunkSet.insert(chunkID).inserted {
      self.queueGenerateJob(chunkID: chunkID)
    }
  }

  func queueGenerateJob(chunkID: SIMD3<Int>) {
    let operation = ChunkGenerationOperation(chunkID: chunkID)
    operation.world = self.world
    operation.localReadyChunks = self.localReadyChunks
    operation.chunkGenerationOperations = self.chunkGenerationOperations
    self.queue.addOperation(operation)
    let holder = WeakChunkGenerationOperationHolder()
    holder.operation = operation
    self.chunkGenerationOperations[chunkID] = holder
  }

  public mutating func updatePriorityPosition(position: SIMD3<Float>) {
    let centerChunkID = World.makeID(position: position)
    let centerChunkPoint = Point3D(x: Double(centerChunkID.x), y: Double(centerChunkID.y), z: Double(centerChunkID.z))

    self.chunkGenerationOperations.with { operations in
      var remove: [SIMD3<Int>] = []
      for (chunkID, operation) in operations {
        if operation.operation == nil {
          remove.append(chunkID)
          continue
        }
        let chunkPoint = Point3D(x: Double(chunkID.x), y: Double(chunkID.y), z: Double(chunkID.z))
        let distance = abs(chunkPoint.distance(to: centerChunkPoint))
        let priority: Operation.QueuePriority
        if distance < 3 {
          priority = .veryHigh
        } else if distance < 6 {
          priority = .normal
        } else if distance < 10 {
          priority = .low
        } else {
          priority = .veryLow
        }

        if priority == .veryLow {
          operation.operation?.cancel()
          self.generatingChunkSet.remove(chunkID)
        } else {
          operation.operation?.queuePriority = priority
        }
      }
      
      for item in remove {
        operations.removeValue(forKey: item)
      }
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

class WeakChunkGenerationOperationHolder {
  weak var operation: ChunkGenerationOperation?
}

class ChunkGenerationOperation: Operation, @unchecked Sendable {
  let chunkID: SIMD3<Int>

  weak var world: World?
  weak var localReadyChunks: ConcurrentDictionary<SIMD3<Int>, Chunk>?
  weak var chunkGenerationOperations: ConcurrentDictionary<SIMD3<Int>, WeakChunkGenerationOperationHolder>?

  init(chunkID: SIMD3<Int>) {
    self.chunkID = chunkID
  }

  override func main() {
    if isCancelled {
      return
    }
    
    guard let world = self.world else {
      return
    }

    guard let localReadyChunks = self.localReadyChunks else {
      return
    }

    let chunk = world.generateSingleChunkUncommitted(chunkID: self.chunkID)
    localReadyChunks[chunkID] = chunk
    
    guard let chunkGenerationOperations = self.chunkGenerationOperations else {
      return
    }
    chunkGenerationOperations.remove(key: chunkID)
  }
}
