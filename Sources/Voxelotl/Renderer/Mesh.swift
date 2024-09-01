public struct Mesh<VertexType: Vertex, IndexType: UnsignedInteger> {
  public let vertices: [VertexType]
  public let indices: [IndexType]
}

public extension Mesh {
  static var empty: Self { .init(vertices: .init(), indices: .init()) }
}

public protocol Vertex: Equatable {}

public struct VertexPositionNormalTexcoord: Vertex {
  var position: SIMD3<Float>
  var normal:   SIMD3<Float>
  var texCoord: SIMD2<Float>
}
