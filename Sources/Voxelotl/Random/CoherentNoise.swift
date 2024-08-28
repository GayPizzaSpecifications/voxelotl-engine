public protocol CoherentNoise2D {
  associatedtype Scalar: FloatingPoint & SIMDScalar

  func get(_ point: SIMD2<Scalar>) -> Scalar
}

public protocol CoherentNoise3D {
  associatedtype Scalar: FloatingPoint & SIMDScalar

  func get(_ point: SIMD3<Scalar>) -> Scalar
}

public protocol CoherentNoise4D {
  associatedtype Scalar: FloatingPoint & SIMDScalar

  func get(_ point: SIMD4<Scalar>) -> Scalar
}
