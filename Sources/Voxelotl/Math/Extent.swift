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
