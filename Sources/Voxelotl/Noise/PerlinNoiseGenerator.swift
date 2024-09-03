import Foundation

public struct ImprovedPerlin<Scalar: BinaryFloatingPoint & SIMDScalar>: CoherentNoise2D, CoherentNoise3D, CoherentNoiseRandomInit {
  private let p: [Int16]

  public init() {
    self.init(permutation: defaultPermutation)
  }

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

internal let defaultPermutation: [Int16] = [
  151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
  8, 99,37,240,21,10,23,190, 6,148,247,120,234,75, 0,26,197,62,94,252,219,203,
  117,35, 11,32,57,177,33, 88,237,149,56,87,174,20,125,136,171,168, 68,175,74,
  165,71,134,139,48, 27,166,77,146,158,231,83,111,229,122, 60,211,133,230,220,
  105,92,41,55,46,245,40,244,102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,
  187,208, 89, 18,169,200,196,135,130,116,188,159, 86,164,100,109,198,173,186,
  3,64,52,217,226,250,124,123, 5,202, 38,147,118,126,255,82,85,212,207,206,59,
  227,47,16,58,17,182,189,28,42,223,183,170,213,119,248,152, 2,44,154,163, 70,
  221,153,101,155,167, 43,172,9,129,22,39,253, 19, 98,108,110, 79,113,224,232,
  178,185, 112,104,218,246,97,228,251, 34,242,193,238,210,144, 12,191,179,162,
  241, 81,51,145,235,249,14,239,107,49,192,214, 31,181,199,106,157,184,84,204,
  176,115,121,50,45,127, 4,150,254,138,236,205,93,222,114,67,29,24,72,243,141,
  128,195,78,66,215,61,156,180
]
