public struct Extent<T: AdditiveArithmetic & Hashable>: Hashable {
  public var left: T, top: T, right: T, bottom: T

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
