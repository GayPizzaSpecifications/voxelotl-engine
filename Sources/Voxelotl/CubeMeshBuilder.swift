public struct CubeMeshBuilder {
  public static func build(bound: AABB) -> Mesh<VertexPositionNormalTexcoord, UInt16> {
    let cubeVertices: [VertexPositionNormalTexcoord] = [
      .init(position: .init( bound.left, bound.bottom, bound.near), normal: .back,    texCoord: .init(0, 0)),
      .init(position: .init(bound.right, bound.bottom, bound.near), normal: .back,    texCoord: .init(1, 0)),
      .init(position: .init( bound.left,    bound.top, bound.near), normal: .back,    texCoord: .init(0, 1)),
      .init(position: .init(bound.right,    bound.top, bound.near), normal: .back,    texCoord: .init(1, 1)),
      .init(position: .init(bound.right, bound.bottom, bound.near), normal: .right,   texCoord: .init(0, 0)),
      .init(position: .init(bound.right, bound.bottom,  bound.far), normal: .right,   texCoord: .init(1, 0)),
      .init(position: .init(bound.right,    bound.top, bound.near), normal: .right,   texCoord: .init(0, 1)),
      .init(position: .init(bound.right,    bound.top,  bound.far), normal: .right,   texCoord: .init(1, 1)),
      .init(position: .init(bound.right, bound.bottom,  bound.far), normal: .forward, texCoord: .init(0, 0)),
      .init(position: .init( bound.left, bound.bottom,  bound.far), normal: .forward, texCoord: .init(1, 0)),
      .init(position: .init(bound.right,    bound.top,  bound.far), normal: .forward, texCoord: .init(0, 1)),
      .init(position: .init( bound.left,    bound.top,  bound.far), normal: .forward, texCoord: .init(1, 1)),
      .init(position: .init( bound.left, bound.bottom,  bound.far), normal: .left,    texCoord: .init(0, 0)),
      .init(position: .init( bound.left, bound.bottom, bound.near), normal: .left,    texCoord: .init(1, 0)),
      .init(position: .init( bound.left,    bound.top,  bound.far), normal: .left,    texCoord: .init(0, 1)),
      .init(position: .init( bound.left,    bound.top, bound.near), normal: .left,    texCoord: .init(1, 1)),
      .init(position: .init( bound.left, bound.bottom,  bound.far), normal: .down,    texCoord: .init(0, 0)),
      .init(position: .init(bound.right, bound.bottom,  bound.far), normal: .down,    texCoord: .init(1, 0)),
      .init(position: .init( bound.left, bound.bottom, bound.near), normal: .down,    texCoord: .init(0, 1)),
      .init(position: .init(bound.right, bound.bottom, bound.near), normal: .down,    texCoord: .init(1, 1)),
      .init(position: .init( bound.left,    bound.top, bound.near), normal: .up,      texCoord: .init(0, 0)),
      .init(position: .init(bound.right,    bound.top, bound.near), normal: .up,      texCoord: .init(1, 0)),
      .init(position: .init( bound.left,    bound.top,  bound.far), normal: .up,      texCoord: .init(0, 1)),
      .init(position: .init(bound.right,    bound.top,  bound.far), normal: .up,      texCoord: .init(1, 1))
    ]
    return .init(vertices: cubeVertices, indices: cubeIndices)
  }
}

fileprivate let cubeIndices: [UInt16] = [
   0,  1,  2,  2,  1,  3,
   4,  5,  6,  6,  5,  7,
   8,  9, 10, 10,  9, 11,
  12, 13, 14, 14, 13, 15,
  16, 17, 18, 18, 17, 19,
  20, 21, 22, 22, 21, 23
]
