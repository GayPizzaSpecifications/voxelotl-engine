struct Point<T: AdditiveArithmetic>: Equatable {
  var x: T, y: T

  static var zero: Self { .init(.zero, .zero) }

  init(_ x: T, _ y: T) {
    self.x = x
    self.y = y
  }

  @inline(__always) static func == (lhs: Self, rhs: Self) -> Bool { lhs.x == rhs.x && lhs.y == rhs.y }
  @inline(__always) static func != (lhs: Self, rhs: Self) -> Bool { lhs.x != rhs.x || lhs.y != rhs.y }
}

extension Point where T: AdditiveArithmetic {
  @inline(__always) static func + (lhs: Self, rhs: Self) -> Self { Self(lhs.x + rhs.x, lhs.y + rhs.y) }
  @inline(__always) static func - (lhs: Self, rhs: Self) -> Self { Self(lhs.x - rhs.x, lhs.y - rhs.y) }

  @inline(__always) static func += (lhs: inout Self, rhs: Self) { lhs.x += rhs.x; lhs.y += rhs.y }
  @inline(__always) static func -= (lhs: inout Self, rhs: Self) { lhs.x -= rhs.x; lhs.y -= rhs.y }
}

extension SIMD2 where Scalar: AdditiveArithmetic {
  init(_ point: Point<Scalar>) {
    self.init(point.x, point.y)
  }
}
