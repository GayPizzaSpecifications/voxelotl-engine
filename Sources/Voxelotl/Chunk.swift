public struct Chunk {
  public static let chunkSize: Int = 16
  public static let blockCount = chunkSize * chunkSize * chunkSize

  private static let yStride = chunkSize
  private static let zStride = chunkSize * chunkSize
  
  public let position: SIMD3<Int>
  private var blocks: [Block]
  
  init(position: SIMD3<Int>, blocks: [Block]) {
    assert(blocks.count == Self.blockCount)
    self.position = position
    self.blocks = blocks
  }
  
  init(position: SIMD3<Int>) {
    self.position = position
    self.blocks = Array(
      repeating: BlockType.air,
      count: Self.blockCount
    ).map { type in Block(type) }
  }

  func getBlock(at position: SIMD3<Int>) -> Block {
    if position.x < 0 || position.y < 0 || position.z < 0 {
      Block(.air)
    } else if position.x >= Self.chunkSize || position.y >= Self.chunkSize || position.z >= Self.chunkSize {
      Block(.air)
    } else {
      blocks[position.x + position.y * Self.yStride + position.z * Self.zStride]
    }
  }
  
  mutating func setBlock(at position: SIMD3<Int>, type: BlockType) {
    if position.x < 0 || position.y < 0 || position.z < 0 {
      return
    }
    if position.x >= Self.chunkSize || position.y >= Self.chunkSize || position.z >= Self.chunkSize {
      return
    }
    
    blocks[position.x + position.y * Self.yStride + position.z * Self.zStride].type = type
  }
  
  mutating func fill(allBy calculation: () -> BlockType) {
    blocks.indices.forEach { i in
      blocks[i].type = calculation()
    }
  }
  
  func forEach(block perform: (Block, SIMD3<Int>) -> Void) {
    for x in 0..<Self.chunkSize {
      for y in 0..<Self.chunkSize {
        for z in 0..<Self.chunkSize {
          let idx = x + y * Self.yStride + z * Self.zStride
          let position = SIMD3(x, y, z)
          perform(blocks[idx], position)
        }
      }
    }
  }

  public func map<T>(block transform: (Block, SIMD3<Int>) throws -> T) rethrows -> [T] {
    assert(self.blocks.count == Self.blockCount)

    var out = [T]()
    out.reserveCapacity(Self.blockCount)

    var position = SIMD3<Int>()
    for i in self.blocks.indices {
      out.append(try transform(blocks[i], position))
      position.x += 1
      if position.x == Self.chunkSize {
        position.x = 0
        position.y += 1
        if position.y == Self.chunkSize {
          position.y = 0
          position.z += 1
        }
      }
    }

    return out
  }

  public func compactMap<T>(block transform: (Block, SIMD3<Int>) throws -> T?) rethrows -> [T] {
    assert(self.blocks.count == Self.blockCount)

    var out = [T]()
    out.reserveCapacity(Self.blockCount >> 1)

    var position = SIMD3<Int>()
    for i in self.blocks.indices {
      if let element = try transform(blocks[i], position) {
        out.append(element)
      }
      position.x += 1
      if position.x == Self.chunkSize {
        position.x = 0
        position.y += 1
        if position.y == Self.chunkSize {
          position.y = 0
          position.z += 1
        }
      }
    }

    return out
  }
}

public enum BlockType: Equatable {
  case air
  case solid(_ color: Color<UInt8>)
}

public struct Block {
  public var type: BlockType

  public init(_ type: BlockType) {
    self.type = type
  }
}
