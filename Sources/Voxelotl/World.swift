import Foundation

public class World {
  private var _chunks: Dictionary<ChunkID, Chunk>
  private var _chunkDamage: Set<ChunkID>
  private var _generator: any WorldGenerator
  private var _chunkGeneration: ChunkGeneration

  public init(generator: any WorldGenerator) {
    self._chunks = [:]
    self._chunkDamage = []
    self._generator = generator
    self._chunkGeneration = ChunkGeneration(queue: .global(qos: .userInitiated))
    self._chunkGeneration.world = self
  }

  func getBlock(at position: SIMD3<Int>) -> Block {
    if let chunk = self._chunks[ChunkID(fromPosition: position)] {
      chunk.getBlock(at: position)
    } else { Block(.air) }
  }

  func setBlock(at position: SIMD3<Int>, type: BlockType) {
    // Find the chunk containing the block position
    let chunkID = ChunkID(fromPosition: position)
    if let idx = self._chunks.index(forKey: chunkID) {
      // Set the block and mark the containing chunk for render update
      self._chunks.values[idx].setBlock(at: position, type: type)
      self._chunkDamage.insert(chunkID)

      // Mark adjacent chunks for render update when placing along the chunk border
      let internalPos = position &- chunkID.getPosition()
      for (i, ofs) in zip(internalPos.indices, [ SIMD3<Int>.X, .Y, .Z ]) {
        if internalPos[i] == 0 {
          let id = chunkID &- ChunkID(id: ofs)
          if let other = self._chunks[id],
            // optim: Damage adjacent chunk only if block is touching a solid
            case .solid = other.getBlock(internal: (internalPos &- ofs) & Chunk.mask).type
          {
            self._chunkDamage.insert(id)
          }
        } else if internalPos[i] == Chunk.size - 1 {
          let id = chunkID &+ ChunkID(id: ofs)
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

  public func forEachChunk(_ body: @escaping (_ id: ChunkID, _ chunk: Chunk) throws -> Void) rethrows {
    for i in self._chunks {
      try body(i.key, i.value)
    }
  }

  func removeAllChunks() {
    self._chunkGeneration.cancelAndClearAll()
    self._chunks.removeAll()
  }

  func generate(width: Int, height: Int, depth: Int, seed: UInt64) {
    self._generator.reset(seed: seed)
    let orig = SIMD3(width, height, depth) / 2

    for z in 0..<depth {
      for y in 0..<height {
        for x in 0..<width {
          let chunkID = ChunkID(id: SIMD3(x, y, z) &- orig)
          self._chunkGeneration.generate(chunkID: chunkID)
        }
      }
    }
  }

  func generateSingleChunkUncommitted(id chunkID: ChunkID) -> Chunk {
    self._generator.makeChunk(id: chunkID)
  }

  public func generateAdjacentChunksIfNeeded(position: SIMD3<Float>) {
    self._chunkGeneration.generateAdjacentIfNeeded(position: position)
  }

  public func addChunk(id chunkID: ChunkID, chunk: Chunk) {
    self._chunks[chunkID] = chunk
    self._chunkDamage.insert(chunkID)
    for i in ChunkID.axes {
      for otherID in [ chunkID &- i, chunkID &+ i ] {
        if self._chunks.keys.contains(otherID) {
          self._chunkDamage.insert(otherID)
        }
      }
    }
  }

  public func update() {
    self._chunkGeneration.acceptReadyChunks()
  }

  public func waitForActiveOperations() {
    self._chunkGeneration.waitForActiveOperations()
  }

  func handleRenderDamagedChunks(_ body: (_ id: ChunkID, _ chunk: Chunk) -> Void) {
    for id in self._chunkDamage {
      body(id, self._chunks[id]!)
    }
    self._chunkDamage.removeAll(keepingCapacity: true)
  }
}
