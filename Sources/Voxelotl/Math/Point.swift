public struct Point<T: AdditiveArithmetic & Hashable>: Hashable {
  public var x: T, y: T

  public static var zero: Self { .init(.zero, .zero) }

  public init(_ x: T, _ y: T) {
    self.x = x
    self.y = y
  }

  public init(scalar value: T) {
    self.x = value
    self.y = value
  }

  @inline(__always) public static func == (lhs: Self, rhs: Self) -> Bool { lhs.x == rhs.x && lhs.y == rhs.y }
  @inline(__always) public static func != (lhs: Self, rhs: Self) -> Bool { lhs.x != rhs.x || lhs.y != rhs.y }
}

extension Point where T: BinaryInteger {
  init<O: BinaryInteger>(_ other: Point<O>) {
    self.init(T(other.x), T(other.y))
  }
  init<O: BinaryFloatingPoint>(_ other: Point<O>) {
    self.init(T(other.x), T(other.y))
  }
}

public extension Point where T: AdditiveArithmetic {
  @inline(__always) static func + (lhs: Self, rhs: Self) -> Self { Self(lhs.x + rhs.x, lhs.y + rhs.y) }
  @inline(__always) static func - (lhs: Self, rhs: Self) -> Self { Self(lhs.x - rhs.x, lhs.y - rhs.y) }

  @inline(__always) static func += (lhs: inout Self, rhs: Self) { lhs.x += rhs.x; lhs.y += rhs.y }
  @inline(__always) static func -= (lhs: inout Self, rhs: Self) { lhs.x -= rhs.x; lhs.y -= rhs.y }
}

public extension Point where T: Numeric {
  @inline(__always) static func * (lhs: Self, rhs: Self) -> Self { .init(lhs.x * rhs.x, lhs.y * rhs.y) }
  @inline(__always) static func * (lhs: Self, rhs: T) -> Self { .init(lhs.x * rhs, lhs.y * rhs) }

  @inline(__always) static func *= (lhs: inout Self, rhs: Self) { lhs.x *= rhs.x; lhs.y *= rhs.y }
  @inline(__always) static func *= (lhs: inout Self, rhs: T) { lhs.x *= rhs; lhs.y *= rhs }
}

extension Point where T: FloatingPoint {
  @inline(__always) static func / (lhs: Self, rhs: Self) -> Self { .init(lhs.x / rhs.x, lhs.y / rhs.y) }
  @inline(__always) static func / (lhs: Self, rhs: Size<T>) -> Self { .init(lhs.x / rhs.w, lhs.y / rhs.h) }
  @inline(__always) static func / (lhs: Self, rhs: T) -> Self { .init(lhs.x / rhs, lhs.y / rhs) }

  @inline(__always) static func /= (lhs: inout Self, rhs: Self) { lhs.x /= rhs.x; lhs.y /= rhs.y }
  @inline(__always) static func /= (lhs: inout Self, rhs: Size<T>) { lhs.x /= rhs.w; lhs.y /= rhs.h }
  @inline(__always) static func /= (lhs: inout Self, rhs: T) { lhs.x /= rhs; lhs.y /= rhs }
}

extension Point where T: BinaryFloatingPoint {
  init<O: BinaryInteger>(_ other: Point<O>) {
    self.init(T(other.x), T(other.y))
  }
  init<O: BinaryFloatingPoint>(_ other: Point<O>) {
    self.init(T(other.x), T(other.y))
  }
}

public extension SIMD2 where Scalar: AdditiveArithmetic {
  init(_ point: Point<Scalar>) {
    self.init(point.x, point.y)
  }
}
