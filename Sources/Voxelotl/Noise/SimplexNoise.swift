import Foundation

public struct SimplexNoise<Scalar: BinaryFloatingPoint & SIMDScalar>: CoherentNoise2D, CoherentNoise3D, CoherentNoise4D, CoherentNoiseRandomInit, CoherentNoiseTableInit {
  private let p: [Int16], pMod12: [Int16]

  private let grad3: [SIMD3<Scalar>] = [
    .init(1, 1, 0), .init(-1,  1, 0), .init(1, -1,  0), .init(-1, -1,  0),
    .init(1, 0, 1), .init(-1,  0, 1), .init(1,  0, -1), .init(-1,  0, -1),
    .init(0, 1, 1), .init( 0, -1, 1), .init(0,  1, -1), .init( 0, -1, -1)
  ]
  private let grad4: [SIMD4<Scalar>] = [
    .init( 0,  1, 1, 1), .init( 0,  1,  1, -1), .init( 0,  1, -1, 1), .init( 0,  1, -1, -1),
    .init( 0, -1, 1, 1), .init( 0, -1,  1, -1), .init( 0, -1, -1, 1), .init( 0, -1, -1, -1),
    .init( 1,  0, 1, 1), .init( 1,  0,  1, -1), .init( 1,  0, -1, 1), .init( 1,  0, -1, -1),
    .init(-1,  0, 1, 1), .init(-1,  0,  1, -1), .init(-1,  0, -1, 1), .init(-1,  0, -1, -1),
    .init( 1,  1, 0, 1), .init( 1,  1,  0, -1), .init( 1, -1,  0, 1), .init( 1, -1,  0, -1),
    .init(-1,  1, 0, 1), .init(-1,  1,  0, -1), .init(-1, -1,  0, 1), .init(-1, -1,  0, -1),
    .init( 1,  1, 1, 0), .init( 1,  1, -1,  0), .init( 1, -1,  1, 0), .init( 1, -1, -1,  0),
    .init(-1,  1, 1, 0), .init(-1,  1, -1,  0), .init(-1, -1,  1, 0), .init(-1, -1, -1,  0)
  ]

  public init(permutation: [Int16]) {
    assert(permutation.count == 0x100)
    self.p = permutation
    self.pMod12 = self.p.map { $0 % 12 }
  }

  public init<Random: RandomProvider>(random: inout Random) {
    self.p = (0..<0x100).map { Int16($0) }.shuffled(using: &random)
    self.pMod12 = self.p.map { $0 % 12 }
  }

  public func get(_ point: SIMD2<Scalar>) -> Scalar {
    // Skew space into rhobuses to find which simplex cell we're in
    let f2 = 0.5 * (Scalar(3).squareRoot() - 1)
    let g2 = (3 - Scalar(3).squareRoot()) / 6
    let skewFactor = point.sum() * f2
    let cellID = SIMD2(floor(point.x + skewFactor), floor(point.y + skewFactor))
    let cellOrigin = cellID - (cellID.sum() * g2)
    let corner0 = point - cellOrigin

    // For the 2d case, the simplex shape is an equilateral triangle
    // Determine which side of the rhombus on to find the simplex
    let cornerOfs1: SIMD2<Int> = corner0.x > corner0.y ? .init(1, 0) : .init(0, 1)
    let corner1 = corner0 - SIMD2<Scalar>(cornerOfs1) + g2
    let corner2 = corner0 - 1 + 2 * g2

    // Compute the hashed gradient indices of the three simplex corners
    let cellHash = SIMD2<Int>(cellID) & 0xFF
    let gradIndex0 = permMod12(cellHash.x + perm(cellHash.y))
    let gradIndex1 = permMod12(cellHash.x + cornerOfs1.x + perm(cellHash.y + cornerOfs1.y))
    let gradIndex2 = permMod12(cellHash.x + 1 + perm(cellHash.y + 1))

    // Calculate the contribution from the three corners
    @inline(__always) func cornerContribution(_ corner: SIMD2<Scalar>, _ gradID: Int) -> Scalar {
      var t = 0.5 - corner.x * corner.x - corner.y * corner.y
      if t < 0 {
        return 0
      } else {
        t *= t
        return t * t * self.grad3[gradID].xy.dot(corner)
      }
    }
    let noise0 = cornerContribution(corner0, gradIndex0)
    let noise1 = cornerContribution(corner1, gradIndex1)
    let noise2 = cornerContribution(corner2, gradIndex2)

    return 70 * (noise0 + noise1 + noise2)
  }

  public func get(_ point: SIMD3<Scalar>) -> Scalar {
    // Skew space into rhombohedrons to find which simplex cell we're in
    let g3 = 1 / Scalar(6), f3 = 1 / Scalar(3)
    let skewFactor = point.sum() * f3
    let cellID = SIMD3(floor(point.x + skewFactor), floor(point.y + skewFactor), floor(point.z + skewFactor))
    let cellOrigin = cellID - (cellID.sum() * g3)
    let corner0 = point - cellOrigin

    // For the 3D case, the simplex shape is a slightly irregular tetrahedron
    // Compute the offsets for the second & third corners of the simplex
    let (corner1ID, corner2ID): (SIMD3<Int>, SIMD3<Int>) = if corner0.x >= corner0.y {
      if corner0.y >= corner0.z {
        (.init(1, 0, 0), .init(1, 1, 0))  // X Y Z
      } else if corner0.x >= corner0.z {
        (.init(1, 0, 0), .init(1, 0, 1))  // X Z Y
      } else {
        (.init(0, 0, 1), .init(1, 0 ,1))  // Z X Y
      }
    } else {
      if corner0.y < corner0.z {
        (.init(0, 0, 1), .init(0, 1, 1))  // Z Y X
      } else if corner0.x < corner0.z {
        (.init(0, 1, 0), .init(0, 1, 1))  // Y Z X
      } else {
        (.init(0, 1, 0), .init(1, 1, 0))  // Y X Z
      }
    }
    let corner1 = corner0 - SIMD3<Scalar>(corner1ID) + g3
    let corner2 = corner0 - SIMD3<Scalar>(corner2ID) + 2 * g3
    let corner3 = corner0 - 1 + 3 * g3

    // Compute the hashed gradient indices of the four simplex corners
    let cellHash = SIMD3<Int>(cellID) & 0xFF
    let gradCorner0 = permMod12(
      cellHash.x + perm(
        cellHash.y + perm(
          cellHash.z)))
    let gradCorner1 = permMod12(
      cellHash.x + corner1ID.x + perm(
        cellHash.y + corner1ID.y + perm(
          cellHash.z + corner1ID.z)))
    let gradCorner2 = permMod12(
      cellHash.x + corner2ID.x + perm(
        cellHash.y + corner2ID.y + perm(
          cellHash.z + corner2ID.z)))
    let gradCorner3 = permMod12(
      cellHash.x + 1 + perm(
        cellHash.y + 1 + perm(
          cellHash.z + 1)))

    // Calculate the contribution from the four corners
    @inline(__always) func cornerContribution(_ corner: SIMD3<Scalar>, _ gradID: Int) -> Scalar {
      var t = 0.6 - corner.x * corner.x - corner.y * corner.y - corner.z * corner.z
      if t < 0 {
        return 0
      } else {
        t *= t
        return t * t * self.grad3[gradID].dot(corner)
      }
    }
    let noise0 = cornerContribution(corner0, gradCorner0)
    let noise1 = cornerContribution(corner1, gradCorner1)
    let noise2 = cornerContribution(corner2, gradCorner2)
    let noise3 = cornerContribution(corner3, gradCorner3)

    return 32 * (noise0 + noise1 + noise2 + noise3)
  }

  public func get(_ point: SIMD4<Scalar>) -> Scalar {
    let g4 = (5 - Scalar(5).squareRoot()) / 20, f4 = (Scalar(5).squareRoot() - 1) / 4
    let skewFactor = point.sum() * f4
    let cellID = SIMD4(floor(point.x + skewFactor), floor(point.y + skewFactor), floor(point.z + skewFactor), floor(point.w + skewFactor))
    let cellOrigin = cellID - (cellID.sum() * g4)
    let corner0 = point - cellOrigin

    // Determine which of the 24 simplices we're in
    // Find the magnitude ordering
    var rank = SIMD4<Int>.zero
    if corner0.x > corner0.y { rank.x += 1 } else { rank.y += 1 }
    if corner0.x > corner0.z { rank.x += 1 } else { rank.z += 1 }
    if corner0.x > corner0.w { rank.x += 1 } else { rank.w += 1 }
    if corner0.y > corner0.z { rank.y += 1 } else { rank.z += 1 }
    if corner0.y > corner0.w { rank.y += 1 } else { rank.w += 1 }
    if corner0.z > corner0.w { rank.z += 1 } else { rank.w += 1 }

    // Compute 4D corners
    let cornerOfs1 = SIMD4<Int>.zero.replacing(with: .one, where: rank .>= 3)
    let cornerOfs2 = SIMD4<Int>.zero.replacing(with: .one, where: rank .>= 2)
    let cornerOfs3 = SIMD4<Int>.zero.replacing(with: .one, where: rank .>= 1)
    let corner1 = corner0 - SIMD4<Scalar>(cornerOfs1) + g4
    let corner2 = corner0 - SIMD4<Scalar>(cornerOfs2) + 2 * g4
    let corner3 = corner0 - SIMD4<Scalar>(cornerOfs3) + 3 * g4
    let corner4 = corner0 - 1 + 4 * g4

    // Compute the hashed gradient indices of the five simplex corners
    let cellHash = SIMD4<Int>(cellID) & 0xFF
    let gradIndex0 = Int(perm(
      cellHash.x + perm(
        cellHash.y + perm(
          cellHash.z + perm(
            cellHash.w))))) & 0x1F
    let gradIndex1 = Int(perm(
      cellHash.x + cornerOfs1.x + perm(
        cellHash.y + cornerOfs1.y + perm(
          cellHash.z + cornerOfs1.z + perm(
            cellHash.w + cornerOfs1.w))))) & 0x1F
    let gradIndex2 = Int(perm(
      cellHash.x + cornerOfs2.x + perm(
        cellHash.y + cornerOfs2.y + perm(
          cellHash.z + cornerOfs2.z + perm(
            cellHash.w + cornerOfs2.w))))) & 0x1F
    let gradIndex3 = Int(perm(
      cellHash.x + cornerOfs3.x + perm(
        cellHash.y + cornerOfs3.y + perm(
          cellHash.z + cornerOfs3.z + perm(
            cellHash.w + cornerOfs3.w))))) & 0x1F
    let gradIndex4 = Int(perm(
      cellHash.x + 1 + perm(
        cellHash.y + 1 + perm(
          cellHash.z + 1 + perm(
            cellHash.w + 1))))) & 0x1F

    // Calculate the contribution from the five corners
    @inline(__always) func cornerContribution(_ corner: SIMD4<Scalar>, _ gradID: Int) -> Scalar {
      var t = corner.indices.reduce(0.6) { accum, i in accum - corner[i] * corner[i] }
      if t < 0 {
        return 0
      } else {
        t *= t
        return t * t * self.grad4[gradID].dot(corner)
      }
    }
    let noise0 = cornerContribution(corner0, gradIndex0)
    let noise1 = cornerContribution(corner1, gradIndex1)
    let noise2 = cornerContribution(corner2, gradIndex2)
    let noise3 = cornerContribution(corner3, gradIndex3)
    let noise4 = cornerContribution(corner4, gradIndex4)

    return 27 * (noise0 + noise1 + noise2 + noise3 + noise4)
  }

  @inline(__always) fileprivate func perm(_ idx: Int) -> Int { Int(self.p[idx & 0xFF]) }
  @inline(__always) fileprivate func permMod12(_ idx: Int) -> Int { Int(self.pMod12[idx & 0xFF]) }
}
