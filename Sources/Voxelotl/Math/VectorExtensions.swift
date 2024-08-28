import simd

public extension SIMD2 where Scalar: Numeric & AdditiveArithmetic {
  @inline(__always) func dot(_ b: Self) -> Scalar { self.x * b.x + self.y * b.y }
}

public extension SIMD3 {
  @inline(__always) var xy: SIMD2<Scalar> {
    get { .init(self.x, self.y) }
    set {
      self.x = newValue.x
      self.y = newValue.y
    }
  }

  @inline(__always) var xz: SIMD2<Scalar> {
    get { .init(self.x, self.z) }
    set {
      self.x = newValue.x
      self.z = newValue.y
    }
  }
}

public extension SIMD3 where Scalar: FloatingPoint {
  @inline(__always) static var X: Self      { Self(1, 0, 0) }
  @inline(__always) static var Y: Self      { Self(0, 1, 0) }
  @inline(__always) static var Z: Self      { Self(0, 0, 1) }

  @inline(__always) static var up: Self      {  Y }
  @inline(__always) static var down: Self    { -Y }
  @inline(__always) static var left: Self    { -X }
  @inline(__always) static var right: Self   {  X }
  @inline(__always) static var forward: Self { -Z }
  @inline(__always) static var back: Self    {  Z }
}

public extension SIMD3 where Scalar: Numeric & AdditiveArithmetic {
  @inline(__always) func dot(_ b: Self) -> Scalar { self.x * b.x + self.y * b.y + self.z * b.z }
}

extension SIMD3 where Scalar == Float {
  static func * (q: simd_quatf, v: Self) -> Self {
#if true
    let q = simd_inverse(q)
#else
    let q = simd_quatf(real: q.real, imag: -q.imag)
#endif

#if true
    var out = q.imag * 2 * simd_dot(q.imag, v)
    out += v * (q.real * q.real - simd_dot(q.imag, q.imag))
    return out + simd_cross(q.imag, v) * 2 * q.real
#else
    let uv = simd_cross(q.imag, v)
    let uuv = simd_cross(q.imag, uv)
    return v + ((uv * q.real) + uuv) * 2
#endif
  }
}

public extension SIMD4 {
  @inline(__always) var xy: SIMD2<Scalar> {
    get { .init(self.x, self.y) }
    set {
      self.x = newValue.x
      self.y = newValue.y
    }
  }

  @inline(__always) var xyz: SIMD3<Scalar> {
    get { .init(self.x, self.y, self.z) }
    set {
      self.x = newValue.x
      self.y = newValue.y
      self.z = newValue.z
    }
  }
}

public extension SIMD4 where Scalar: Numeric & AdditiveArithmetic {
  @inline(__always) func dot(_ b: Self) -> Scalar { self.x * b.x + self.y * b.y + self.z * b.z + self.w * b.w }
}
