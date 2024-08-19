public struct Chunk {
  public static let chunkSize: Int = 16
  
  public let position: SIMD3<Int>
  private var blocks: [Block]
  
  init(position: SIMD3<Int>, blocks: [Block]) {
    self.position = position
    self.blocks = blocks
  }
  
  init(position: SIMD3<Int>) {
    self.position = position
    self.blocks = Array(
      repeating: BlockType.air,
      count: Chunk.chunkSize * Chunk.chunkSize * Chunk.chunkSize
    ).map { type in Block(type) }
  }

  func getBlockInternally(at position: SIMD3<Int>) -> Block {
    blocks[position.x + position.y * Chunk.chunkSize + position.z * Chunk.chunkSize * Chunk.chunkSize]
  }
  
  mutating func setBlockInternally(at position: SIMD3<Int>, type: BlockType) {
    if position.x >= Chunk.chunkSize || position.y >= Chunk.chunkSize || position.z >= Chunk.chunkSize {
      return
    }
    
    if position.x < 0 || position.y < 0 || position.z < 0 {
      return
    }
    
    blocks[position.x + position.y * Chunk.chunkSize + position.z * Chunk.chunkSize * Chunk.chunkSize].type = type
  }
  
  mutating func fill(allBy calculation: () -> BlockType) {
    blocks.indices.forEach { i in
      blocks[i].type = calculation()
    }
  }
  
  func forEach(block perform: (SIMD3<Int>, Block) -> Void) {
    for x in 0..<Chunk.chunkSize {
      for y in 0..<Chunk.chunkSize {
        for z in 0..<Chunk.chunkSize {
          perform(SIMD3(x, y, z), blocks[x + y * Chunk.chunkSize + z * Chunk.chunkSize * Chunk.chunkSize])
        }
      }
    }
  }
}

public enum BlockType: Equatable {
  case air
  case solid(Color<Float16>)
}

public struct Block {
  public var type: BlockType
  
  
  public init(_ type: BlockType) {
    self.type = type
  }
}
