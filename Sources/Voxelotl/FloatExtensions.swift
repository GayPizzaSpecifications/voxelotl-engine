public extension FloatingPoint {
  @inline(__always) var degrees: Self { self * (180 / Self.pi) }
  @inline(__always) var radians: Self { self * (Self.pi / 180) }

  @inline(__always) func lerp(_ a: Self, _ b: Self) -> Self { b * self + a * (1 - self) }
  @inline(__always) func mlerp(_ a: Self, _ b: Self) -> Self { a + (b - a) * self }

  @inline(__always) func clamp(_ a: Self, _ b: Self) -> Self { min(max(self, a), b) }
  @inline(__always) var saturated: Self { self.clamp(0, 1) }
}

extension SIMD3 where Scalar: FloatingPoint {
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
