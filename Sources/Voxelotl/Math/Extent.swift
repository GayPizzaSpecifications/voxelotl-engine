import Foundation

public struct Extent<T: AdditiveArithmetic & Hashable>: Hashable {
  public var left: T, top: T, right: T, bottom: T

  public init(left: T, top: T, right: T, bottom: T) {
    self.left   = left
    self.top    = top
    self.right  = right
    self.bottom = bottom
  }

  @inline(__always) public var topLeft: Point<T> { .init(left, top) }
  @inline(__always) public var topRight: Point<T> { .init(right, top) }
  @inline(__always) public var bottomLeft: Point<T> { .init(left, bottom) }
  @inline(__always) public var bottomRight: Point<T> { .init(right, bottom) }

  @inline(__always) public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.left == rhs.left && lhs.right == rhs.right && lhs.top == rhs.top && lhs.bottom == rhs.bottom
  }
}

public extension Extent where T: Comparable {
  var size: Size<T> { .init(
    right > left ? right - left : left - right,
    bottom > top ? bottom - top : top - bottom) }
}

public extension Extent where T: SIMDScalar {
  init(from: SIMD2<T>, to: SIMD2<T>) {
    self.left   = from.x
    self.top    = from.y
    self.right  = to.x
    self.bottom = to.y
  }

  @inline(__always) static func + (lhs: Self, rhs: SIMD2<T>) -> Self {
    .init(
      left:   lhs.left + rhs.x,
      top:    lhs.top + rhs.y,
      right:  lhs.right + rhs.x,
      bottom: lhs.bottom + rhs.y)
  }
}

public extension Extent where T: AdditiveArithmetic {
  init(_ rect: Rect<T>) {
    self.left   = rect.x
    self.top    = rect.y
    self.right  = rect.x + rect.w
    self.bottom = rect.y + rect.h
  }
}

public extension Extent where T: Numeric {
  @inline(__always) static func * (lhs: Self, rhs: Size<T>) -> Self {
    .init(
      left:   lhs.left * rhs.w,
      top:    lhs.top * rhs.w,
      right:  lhs.right * rhs.h,
      bottom: lhs.bottom * rhs.h)
  }
}

public extension Extent where T: BinaryInteger {
  init<O: BinaryInteger>(_ other: Extent<O>) {
    self.left   = T(other.left)
    self.top    = T(other.top)
    self.right  = T(other.right)
    self.bottom = T(other.bottom)
  }
  init<O: BinaryFloatingPoint>(_ other: Extent<O>) {
    self.left   = T(other.left)
    self.top    = T(other.top)
    self.right  = T(other.right)
    self.bottom = T(other.bottom)
  }
}

public extension Extent where T: FloatingPoint {
  init<O: BinaryInteger>(_ other: Extent<O>) {
    self.left   = T(other.left)
    self.top    = T(other.top)
    self.right  = T(other.right)
    self.bottom = T(other.bottom)
  }

  @inline(__always) static func / (lhs: Self, rhs: T) -> Self {
    .init(
      left:   lhs.left / rhs,
      top:    lhs.top / rhs,
      right:  lhs.right / rhs,
      bottom: lhs.bottom / rhs)
  }
}

public extension Extent where T: BinaryFloatingPoint {
  init<O: BinaryFloatingPoint>(_ other: Extent<O>) {
    self.left   = T(other.left)
    self.top    = T(other.top)
    self.right  = T(other.right)
    self.bottom = T(other.bottom)
  }
}

@inlinable public func floor<T: FloatingPoint>(_ extent: Extent<T>) -> Extent<T> {
  .init(
    left:   floor(extent.left),
    top:    floor(extent.top),
    right:  floor(extent.right),
    bottom: floor(extent.bottom))
}
