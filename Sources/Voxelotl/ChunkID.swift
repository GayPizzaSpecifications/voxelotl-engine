import simd

public struct ChunkID: Hashable {
  private let _id: SIMD3<Int>

  init(id: SIMD3<Int>) {
    self._id = id
  }
}

public extension ChunkID {
  @inline(__always) init(_ x: Int, _ y: Int, _ z: Int) { self._id = SIMD3(x, y, z) }

  @inline(__always) init<F: BinaryFloatingPoint>(fromPosition position: SIMD3<F>) {
    self.init(fromPosition: SIMD3(Int(floor(position.x)), Int(floor(position.y)), Int(floor(position.z))))
  }
  @inline(__always) init(fromPosition position: SIMD3<Int>) { self._id = position &>> Chunk.shift }

  @inline(__always) func getPosition() -> SIMD3<Int> { self._id &<< Chunk.shift }
  @inline(__always) func getPosition(offset: SIMD3<Int>) -> SIMD3<Int> { self._id &<< Chunk.shift &+ offset }
  @inline(__always) func getFloatPosition() -> SIMD3<Float> { SIMD3<Float>(self._id) * Float(Chunk.size) }
  @inline(__always) func getFloatPosition(offset: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(self._id) * Float(Chunk.size) + offset
  }

  @inline(__always) static func &+ (lhs: Self, rhs: Self) -> Self { .init(id: lhs._id &+ rhs._id) }
  @inline(__always) static func &- (lhs: Self, rhs: Self) -> Self { .init(id: lhs._id &- rhs._id) }
}

public extension ChunkID {
  @inlinable func distance(_ other: Self) -> Float {
    simd_distance(SIMD3<Float>(SIMD3(self)), SIMD3<Float>(SIMD3(other)))
  }
}

public extension ChunkID {
  static var axes: [Self] {
    [ .X, .Y, .Z ].map { (j: SIMD3<Int>) -> Self in .init(id: j) }
  }
}

fileprivate extension ChunkID {
  @inline(__always) var id: SIMD3<Int> { self._id }
}

public extension SIMD3 where Scalar == Int {
  init(_ chunkID: ChunkID) { self = chunkID.id }
}
