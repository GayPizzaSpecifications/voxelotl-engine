import Foundation

public class World {
  private var _chunks: Dictionary<SIMD3<Int>, Chunk>
  private var _generator: WorldGenerator

  let _chunkLock: NSLock = .init()
  
  public init() {
    self._chunks = [:]
    self._generator = WorldGenerator()
  }

  func getBlock(at position: SIMD3<Int>) -> Block {
    return if let chunk = self._chunks[position &>> Chunk.shift] {
      chunk.getBlock(at: position)
    } else { Block(.air) }
  }

  func setBlock(at position: SIMD3<Int>, type: BlockType) {
    self._chunks[position &>> Chunk.shift]?.setBlock(at: position, type: type)
  }
  
  func getChunk(id chunkID: SIMD3<Int>) -> Chunk? {
    self._chunkLock.lock()
    let chunk = self._chunks[chunkID]
    self._chunkLock.unlock()
    return chunk
  }

  func generate(width: Int, height: Int, depth: Int, seed: UInt64) {
    self._generator.reset(seed: seed)
    let orig = SIMD3(width, height, depth) / 2
    for z in 0..<depth {
      for y in 0..<height {
        for x in 0..<width {
          let chunkID = SIMD3(x, y, z) &- orig
          self.generate(chunkID: chunkID)
        }
      }
    }
  }

  func generate(chunkID: SIMD3<Int>) {
    if self._generator.isCurrentlyGenerating(id: chunkID) { return }
    self._generator.makeChunk(id: chunkID) { chunk in
      self._chunkLock.lock()
      self._chunks[chunkID] = chunk
      self._chunkLock.unlock()
    }
  }

  var instances: [Instance] {
    self._chunkLock.lock()
    defer {
      self._chunkLock.unlock()
    }
    return self._chunks.values.flatMap { chunk in
      chunk.compactMap { block, position in
        if case let .solid(color) = block.type {
          Instance(
            position: SIMD3<Float>(position) + 0.5,
            scale:    .init(repeating: 0.5),
            color:    color)
        } else { nil }
      }
    }
  }
}
