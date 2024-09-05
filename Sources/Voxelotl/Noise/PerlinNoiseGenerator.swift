import Foundation

public struct ImprovedPerlin<Scalar: BinaryFloatingPoint & SIMDScalar>: CoherentNoise2D, CoherentNoise3D, CoherentNoiseRandomInit, CoherentNoiseTableInit {
  private let p: [Int16]

  public init(permutation: [Int16]) {
    assert(permutation.count == 0x100)
    self.p = permutation
  }

  public init<Random: RandomProvider>(random: inout Random) {
    self.p = (0..<0x100).map { Int16($0) }.shuffled(using: &random)
  }

  public func get(_ point: SIMD2<Scalar>) -> Scalar {
    // Find unit square
    let idx = SIMD2(Int(floor(point.x)), Int(floor(point.y))) & 0xFF
    // Find relative point in square
    let inner = point - SIMD2(floor(point.x), floor(point.y))

    // Compute fade curves for each axis
    let u = inner.x.smootherStep()
    let v = inner.y.smootherStep()

    // Compute hash of the coordinates of the 4 square corners
    let a = idx.y + perm(idx.x), b = idx.y + perm(idx.x + 1)
    let aa = perm(a), ab = perm(a + 1)
    let ba = perm(b), bb = perm(b + 1)

    // Add blended results
    return v.mlerp(
      u.mlerp(
        grad(perm(aa), inner),
        grad(perm(ba), .init(inner.x - 1, inner.y))),
      u.mlerp(
        grad(perm(ab), .init(inner.x, inner.y - 1)),
        grad(perm(bb), inner - .init(repeating: 1))))
  }

  public func get(_ point: SIMD3<Scalar>) -> Scalar {
    // Find unit cube containg point
    let idx = SIMD3(Int(floor(point.x)), Int(floor(point.y)), Int(floor(point.z))) & 0xFF
    // Find relative point in cube
    let inner = point - SIMD3(floor(point.x), floor(point.y), floor(point.z))

    // Compute fade curves for each axis
    let u = inner.x.smootherStep()
    let v = inner.y.smootherStep()
    let w = inner.z.smootherStep()

    // Compute hash of the coordinates of the 8 cube corners
    let a  = idx.y + perm(idx.x)
    let aa = idx.z + perm(a)
    let ab = idx.z + perm(a + 1)
    let b  = idx.y + perm(idx.x + 1)
    let ba = idx.z + perm(b)
    let bb = idx.z + perm(b + 1)

    // Add blended results
    return w.mlerp(v.mlerp(
        u.mlerp(
          grad(perm(aa), inner),
          grad(perm(ba), .init(inner.x - 1, inner.y, inner.z))),
        u.mlerp(
          grad(perm(ab), .init(inner.x, inner.y - 1, inner.z)),
          grad(perm(bb), .init(inner.x - 1, inner.y - 1, inner.z)))),
      v.mlerp(u.mlerp(
          grad(perm(aa + 1), .init(inner.x, inner.y, inner.z - 1)),
          grad(perm(ba + 1), .init(inner.x - 1, inner.y, inner.z - 1))),
        u.mlerp(
          grad(perm(ab + 1), .init(inner.x, inner.y - 1, inner.z - 1)),
          grad(perm(bb + 1), inner - .init(repeating: 1)))))
  }

  @inline(__always) fileprivate func perm(_ x: Int) -> Int { Int(self.p[x & 0xFF]) }

  @inline(__always) fileprivate func grad(_ hash: Int, _ point: SIMD2<Scalar>) -> Scalar { grad(hash, SIMD3(point, 0)) }

  fileprivate func grad(_ hash: Int, _ point: SIMD3<Scalar>) -> Scalar {
    // Convert low 4 bits of hash code into 12 gradient directions
    let low4 = hash & 0xF
    var u = low4 < 8 ? point.x : point.y
    var v = low4 < 4 ? point.y : (low4 == 0b1100 || low4 == 0b1110 ? point.x : point.z)
    u = (low4 & 0x1) == 0 ? u : -u
    v = (low4 & 0x2) == 0 ? v : -v
    return u + v
  }
}
