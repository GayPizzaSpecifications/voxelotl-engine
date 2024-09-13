public struct Size<T: AdditiveArithmetic & Hashable>: Hashable {
  public var w: T, h: T

  public static var zero: Self { .init(.zero, .zero) }

  public init(_ w: T, _ h: T) {
    self.w = w
    self.h = h
  }

  public init(scalar value: T) {
    self.w = value
    self.h = value
  }

  @inline(__always) public static func == (lhs: Self, rhs: Self) -> Bool { lhs.w == rhs.w && lhs.h == rhs.h }
  @inline(__always) public static func != (lhs: Self, rhs: Self) -> Bool { lhs.w != rhs.w || lhs.h != rhs.h }
}

public extension Size where T: AdditiveArithmetic {
  @inline(__always) static func + (lhs: Self, rhs: Self) -> Self { .init(lhs.w + rhs.w, lhs.h + rhs.h) }
  @inline(__always) static func - (lhs: Self, rhs: Self) -> Self { .init(lhs.w - rhs.w, lhs.h - rhs.h) }

  @inline(__always) static func += (lhs: inout Self, rhs: Self) { lhs.w += rhs.w; lhs.h += rhs.h }
  @inline(__always) static func -= (lhs: inout Self, rhs: Self) { lhs.w -= rhs.w; lhs.h -= rhs.h }
}

public extension Size where T: Numeric {
  @inline(__always) static func * (lhs: Self, rhs: Self) -> Self { .init(lhs.w * rhs.w, lhs.h * rhs.h) }
  @inline(__always) static func * (lhs: Self, rhs: T) -> Self { .init(lhs.w * rhs, lhs.h * rhs) }

  @inline(__always) static func *= (lhs: inout Self, rhs: Self) { lhs.w *= rhs.w; lhs.h *= rhs.h }
  @inline(__always) static func *= (lhs: inout Self, rhs: T) { lhs.w *= rhs; lhs.h *= rhs }
}

extension Size where T: FloatingPoint {
  @inline(__always) static func / (lhs: Self, rhs: Self) -> Self { .init(lhs.w / rhs.w, lhs.h / rhs.h) }
  @inline(__always) static func / (lhs: Self, rhs: T) -> Self { .init(lhs.w / rhs, lhs.h / rhs) }
  @inline(__always) static func / (lhs: T, rhs: Self) -> Self { .init(lhs / rhs.w, lhs / rhs.h) }

  @inline(__always) static func /= (lhs: inout Self, rhs: Self) { lhs.w /= rhs.w; lhs.h /= rhs.h }
  @inline(__always) static func /= (lhs: inout Self, rhs: T) { lhs.w /= rhs; lhs.h /= rhs }
}

extension Size where T: BinaryInteger {
  static var one: Self { .init(T(1), T(1)) }

  init<O: BinaryInteger>(_ other: Size<O>) {
    self.init(T(other.w), T(other.h))
  }
  init<O: BinaryFloatingPoint>(_ other: Size<O>) {
    self.init(T(other.w), T(other.h))
  }
}

extension Size where T: BinaryFloatingPoint {
  init<O: BinaryInteger>(_ other: Size<O>) {
    self.init(T(other.w), T(other.h))
  }
  init<O: BinaryFloatingPoint>(_ other: Size<O>) {
    self.init(T(other.w), T(other.h))
  }
}

extension SIMD2 where Scalar: AdditiveArithmetic {
  init(_ size: Size<Scalar>) {
    self.init(size.w, size.h)
  }
}

extension Size where T: SIMDScalar & Numeric {
  @inline(__always) public static func * (lhs: Self, rhs: SIMD2<T>) -> Self { .init(lhs.w * rhs.x, lhs.h * rhs.y) }
}
