public struct Size<T: AdditiveArithmetic>: Equatable {
  var w: T, h: T

  static var zero: Self { .init(.zero, .zero) }

  init(_ w: T, _ h: T) {
    self.w = w
    self.h = h
  }

  @inline(__always) public static func == (lhs: Self, rhs: Self) -> Bool { lhs.w == rhs.w && lhs.h == rhs.h }
  @inline(__always) public static func != (lhs: Self, rhs: Self) -> Bool { lhs.w != rhs.w || lhs.h != rhs.h }
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

  @inline(__always) public static func / (lhs: Self, rhs: Self) -> Self { .init(lhs.w / rhs.w, lhs.h / rhs.h) }
}

extension SIMD2 where Scalar: AdditiveArithmetic {
  init(_ size: Size<Scalar>) {
    self.init(size.w, size.h)
  }
}
