import Foundation

public class World {
  public typealias ChunkID = SIMD3<Int>
  @inline(__always) public static func makeID<F: BinaryFloatingPoint>(position: SIMD3<F>) -> ChunkID {
    makeID(position: SIMD3(Int(floor(position.x)), Int(floor(position.y)), Int(floor(position.z))))
  }
  @inline(__always) public static func makeID(position: SIMD3<Int>) -> ChunkID { position &>> Chunk.shift }

  private var _chunks: Dictionary<ChunkID, Chunk>
  private var _chunkDamage: Set<ChunkID>
  private var _generator: WorldGenerator

  public init() {
    self._chunks = [:]
    self._chunkDamage = []
    self._generator = WorldGenerator()
  }

  func getBlock(at position: SIMD3<Int>) -> Block {
    return if let chunk = self._chunks[position &>> Chunk.shift] {
      chunk.getBlock(at: position)
    } else { Block(.air) }
  }

  func setBlock(at position: SIMD3<Int>, type: BlockType) {
    // Find the chunk containing the block position
    let chunkID = position &>> Chunk.shift
    if let idx = self._chunks.index(forKey: chunkID) {
      // Set the block and mark the containing chunk for render update
      self._chunks.values[idx].setBlock(at: position, type: type)
      self._chunkDamage.insert(chunkID)

      // Mark adjacent chunks for render update when placing along the chunk border
      let internalPos = position &- chunkID &<< Chunk.shift
      for (i, ofs) in zip(internalPos.indices, [ SIMD3<Int>.X, .Y, .Z ]) {
        if internalPos[i] == 0 {
          let id = chunkID &- ofs
          if let other = self._chunks[id],
            // optim: Damage adjacent chunk only if block is touching a solid
            case .solid = other.getBlock(internal: (internalPos &- ofs) & Chunk.mask).type
          {
            self._chunkDamage.insert(id)
          }
        } else if internalPos[i] == Chunk.size - 1 {
          let id = chunkID &+ ofs
          if let other = self._chunks[id],
            // optim: Damage adjacent chunk only if block is touching a solid
            case .solid = other.getBlock(internal: (internalPos &+ ofs) & Chunk.mask).type
          {
            self._chunkDamage.insert(id)
          }
        }
      }
    }
  }

  func getChunk(id chunkID: ChunkID) -> Chunk? {
    self._chunks[chunkID]
  }

  public func forEachChunk(_ body: @escaping (_ id: SIMD3<Int>, _ chunk: Chunk) throws -> Void) rethrows {
    for i in self._chunks {
      try body(i.key, i.value)
    }
  }

  func generate(width: Int, height: Int, depth: Int, seed: UInt64) {
    self._generator.reset(seed: seed)
    let orig = SIMD3(width, height, depth) / 2

    let localChunks = ConcurrentDictionary<ChunkID, Chunk>()
    let queue = OperationQueue()
    queue.qualityOfService = .userInitiated
    for z in 0..<depth {
      for y in 0..<height {
        for x in 0..<width {
          let chunkID = SIMD3(x, y, z) &- orig
          queue.addOperation {
            let chunk = self._generator.makeChunk(id: chunkID)
            localChunks[chunkID] = chunk
          }
        }
      }
    }
    queue.waitUntilAllOperationsAreFinished()
    for (chunkID, chunk) in localChunks {
      self._chunks[chunkID] = chunk
      self._chunkDamage.insert(chunkID)
    }
  }

  func generate(chunkID: ChunkID) {
    self._chunks[chunkID] = self._generator.makeChunk(id: chunkID)
    self._chunkDamage.insert(chunkID)
    for i: ChunkID in [ .X, .Y, .Z ] {
      for otherID in [ chunkID &- i, chunkID &+ i ] {
        if self._chunks.keys.contains(otherID) {
          self._chunkDamage.insert(otherID)
        }
      }
    }
  }

  func handleRenderDamagedChunks(_ body: (_ id: ChunkID, _ chunk: Chunk) -> Void) {
    for id in self._chunkDamage {
      body(id, self._chunks[id]!)
    }
    self._chunkDamage.removeAll(keepingCapacity: true)
  }
}
