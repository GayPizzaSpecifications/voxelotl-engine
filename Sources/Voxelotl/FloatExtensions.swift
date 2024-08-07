public extension FloatingPoint {
  @inline(__always) var degrees: Self { self * (180 / Self.pi) }
  @inline(__always) var radians: Self { self * (Self.pi / 180) }

  @inline(__always) func lerp(_ a: Self, _ b: Self) -> Self { b * self + a * (1 - self) }
  @inline(__always) func mlerp(_ a: Self, _ b: Self) -> Self { a + (b - a) * self }
}
