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
}

struct Rect<T: AdditiveArithmetic>: Equatable {
  var x: T, y: T, w: T, h: T

  var origin: Point<T> {
    get { .init(self.x, self.y) }
    set(point) { self.x = point.x; self.y = point.y }
  }
  var size: Size<T> {
    get { .init(self.w, self.h) }
    set(size) { self.w = size.w; self.h = size.h }
  }

  static var zero: Self { .init(origin: .zero, size: .zero) }

  init(x: T, y: T, width: T, height: T) {
    self.x = x
    self.y = y
    self.w = width
    self.h = height
  }

  init(origin: Point<T>, size: Size<T>) {
    self.x = origin.x
    self.y = origin.y
    self.w = size.w
    self.h = size.h
  }

  @inline(__always) static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.x == rhs.x && lhs.y == rhs.y && lhs.w == rhs.w && lhs.h == rhs.h
  }
}

extension Rect where T: AdditiveArithmetic {
  var left: T { x }
  var right: T { x + w }
  var up: T { y }
  var down: T { y + h }
}

struct Extent<T: AdditiveArithmetic>: Equatable {
  var top: T, bottom: T, left: T, right: T

  @inline(__always) static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.left == rhs.left && lhs.right == rhs.right && lhs.top == rhs.top && lhs.bottom == rhs.bottom
  }
}

extension Extent where T: Comparable {
  var size: Size<T> { .init(
    right > left ? right - left : left - right,
    bottom > top ? bottom - top : top - bottom) }
}
