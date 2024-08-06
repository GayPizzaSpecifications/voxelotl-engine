public extension FloatingPoint {
  @inline(__always) var degrees: Self { self * (180 / Self.pi) }
  @inline(__always) var radians: Self { self * (Self.pi / 180) }
}
