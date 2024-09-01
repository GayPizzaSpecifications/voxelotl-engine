public struct Chunk: Hashable {
  public static let shift = 4  // 16
  public static let size: Int = 1 << shift
  public static let mask: Int = size - 1

  public static let blockCount = size * size * size

  private static let yStride = size
  private static let zStride = size * size
  
  public let origin: SIMD3<Int>
  private var blocks: [Block]
  
  init(position: SIMD3<Int>, blocks: [Block]) {
    assert(blocks.count == Self.blockCount)
    self.origin = position
    self.blocks = blocks
  }
  
  init(position: SIMD3<Int>) {
    self.origin = position
    self.blocks = Array(
      repeating: BlockType.air,
      count: Self.blockCount
    ).map { type in Block(type) }
  }

  func getBlock(at position: SIMD3<Int>) -> Block {
    getBlock(internal: position &- self.origin)
  }

  func getBlock(internal position: SIMD3<Int>) -> Block {
    if position.x < 0 || position.y < 0 || position.z < 0 {
      Block(.air)
    } else if position.x >= Self.size || position.y >= Self.size || position.z >= Self.size {
      Block(.air)
    } else {
      blocks[position.x + position.y * Self.yStride + position.z * Self.zStride]
    }
  }

  mutating func setBlock(at position: SIMD3<Int>, type: BlockType) {
    setBlock(internal: position &- self.origin, type: type)
  }

  mutating func setBlock(internal position: SIMD3<Int>, type: BlockType) {
    if position.x < 0 || position.y < 0 || position.z < 0 {
      return
    }
    if position.x >= Self.size || position.y >= Self.size || position.z >= Self.size {
      return
    }
    
    blocks[position.x + position.y * Self.yStride + position.z * Self.zStride].type = type
  }

  mutating func fill(allBy calculation: (_ position: SIMD3<Int>) -> BlockType) {
    for i in 0..<Self.blockCount {
      let x = i & Self.mask
      let y = (i &>> Self.shift) & Self.mask
      let z = (i &>> (Self.shift + Self.shift)) & Self.mask
      blocks[i].type = calculation(self.origin &+ SIMD3(x, y, z))
    }
  }

  public func forEach(_ body: @escaping (Block, SIMD3<Int>) throws -> Void) rethrows {
    for i in 0..<Self.blockCount {
      try body(blocks[i], self.origin &+ SIMD3(
        x: i & Self.mask,
        y: (i &>> Self.shift) & Self.mask,
        z: (i &>> (Self.shift + Self.shift)) & Self.mask))
    }
  }

  public func map<T>(block transform: (Block, SIMD3<Int>) throws -> T) rethrows -> [T] {
    assert(self.blocks.count == Self.blockCount)

    var out = [T]()
    out.reserveCapacity(Self.blockCount)

    var position = SIMD3<Int>()
    for i in self.blocks.indices {
      out.append(try transform(blocks[i], self.origin &+ position))
      position.x += 1
      if position.x == Self.size {
        position.x = 0
        position.y += 1
        if position.y == Self.size {
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
      if let element = try transform(blocks[i], self.origin &+ position) {
        out.append(element)
      }
      position.x += 1
      if position.x == Self.size {
        position.x = 0
        position.y += 1
        if position.y == Self.size {
          position.y = 0
          position.z += 1
        }
      }
    }

    return out
  }
}

public enum BlockType: Hashable {
  case air
  case solid(_ color: Color<Float16>)
}

public struct Block: Hashable {
  public var type: BlockType

  public init(_ type: BlockType) {
    self.type = type
  }
}
