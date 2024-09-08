public protocol CoherentNoise {
  associatedtype Scalar: FloatingPoint & SIMDScalar
}

public protocol CoherentNoiseRandomInit: CoherentNoise {
  init<Random: RandomProvider>(random: inout Random)
}

public protocol CoherentNoiseTableInit: CoherentNoise {
  init(permutation: [UInt8])
}

public protocol CoherentNoise2D: CoherentNoise {
  func get(_ point: SIMD2<Scalar>) -> Scalar
}

public protocol CoherentNoise3D: CoherentNoise {
  func get(_ point: SIMD3<Scalar>) -> Scalar
}

public protocol CoherentNoise4D: CoherentNoise {
  func get(_ point: SIMD4<Scalar>) -> Scalar
}
