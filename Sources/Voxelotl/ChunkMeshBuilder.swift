struct ChunkMeshBuilder {
  public static func build(world: World, chunk: Chunk) -> Mesh<VertexPositionNormalColorTexcoord, UInt16> {
    var vertices = [VertexPositionNormalColorTexcoord]()
    var indices = [UInt16]()
    chunk.forEach { block, position in
      if case .solid(let color) = block.type {
        for side in [ Side.left, .right, .down, .up, .back, .front ] {
          let globalPos = chunk.origin &+ position
          if case .air = world.getBlock(at: globalPos.offset(by: side)).type {
            //FIXME: use 32 bit indices for really big chunks
            let orig = UInt16(truncatingIfNeeded: vertices.count)
            vertices.append(contentsOf: cubeVertices[side]!.map {
              .init(
                position: SIMD3(position) + $0.position,
                normal: $0.normal,
                color: SIMD4(color),
                texCoord: $0.texCoord)
            })
            indices.append(contentsOf: sideIndices.map { orig + $0 })
          }
        }
      }
    }

    return .init(vertices: vertices, indices: indices)
  }
}

fileprivate let cubeVertices: [Side: [VertexPositionNormalTexcoord]] = [
  .back: [
    .init(position: .init(0, 0, 1), normal: .back, texCoord: .init(0, 0)),
    .init(position: .init(1, 0, 1), normal: .back, texCoord: .init(1, 0)),
    .init(position: .init(0, 1, 1), normal: .back, texCoord: .init(0, 1)),
    .init(position: .init(1, 1, 1), normal: .back, texCoord: .init(1, 1))
  ], .right: [
    .init(position: .init(1, 0, 1), normal: .right, texCoord: .init(0, 0)),
    .init(position: .init(1, 0, 0), normal: .right, texCoord: .init(1, 0)),
    .init(position: .init(1, 1, 1), normal: .right, texCoord: .init(0, 1)),
    .init(position: .init(1, 1, 0), normal: .right, texCoord: .init(1, 1))
  ], .front: [
    .init(position: .init(1, 0, 0), normal: .forward, texCoord: .init(0, 0)),
    .init(position: .init(0, 0, 0), normal: .forward, texCoord: .init(1, 0)),
    .init(position: .init(1, 1, 0), normal: .forward, texCoord: .init(0, 1)),
    .init(position: .init(0, 1, 0), normal: .forward, texCoord: .init(1, 1))
  ], .left: [
    .init(position: .init(0, 0, 0), normal: .left, texCoord: .init(0, 0)),
    .init(position: .init(0, 0, 1), normal: .left, texCoord: .init(1, 0)),
    .init(position: .init(0, 1, 0), normal: .left, texCoord: .init(0, 1)),
    .init(position: .init(0, 1, 1), normal: .left, texCoord: .init(1, 1))
  ], .down: [
    .init(position: .init(0, 0, 0), normal: .down, texCoord: .init(0, 0)),
    .init(position: .init(1, 0, 0), normal: .down, texCoord: .init(1, 0)),
    .init(position: .init(0, 0, 1), normal: .down, texCoord: .init(0, 1)),
    .init(position: .init(1, 0, 1), normal: .down, texCoord: .init(1, 1))
  ], .up: [
    .init(position: .init(0, 1, 1), normal: .up, texCoord: .init(0, 0)),
    .init(position: .init(1, 1, 1), normal: .up, texCoord: .init(1, 0)),
    .init(position: .init(0, 1, 0), normal: .up, texCoord: .init(0, 1)),
    .init(position: .init(1, 1, 0), normal: .up, texCoord: .init(1, 1))
  ]
]

fileprivate let sideIndices: [UInt16] = [ 0,  1,  2,  2,  1,  3 ]

fileprivate enum Side {
  case left, right
  case down, up
  case back, front
}

fileprivate extension SIMD3 where Scalar: SignedInteger & FixedWidthInteger {
  func offset(by side: Side) -> Self {
    let ofs: Self = switch side {
    case .right: .right
    case .left:  .left
    case .up:    .up
    case .down:  .down
    case .back:  .back
    case .front: .forward
    }
    return self &+ ofs
  }
}
