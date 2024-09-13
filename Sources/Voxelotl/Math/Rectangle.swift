public struct Rect<T: AdditiveArithmetic & Hashable>: Hashable {
  public var x: T, y: T, w: T, h: T

  public var origin: Point<T> {
    get { .init(self.x, self.y) }
    set(point) { self.x = point.x; self.y = point.y }
  }
  public var size: Size<T> {
    get { .init(self.w, self.h) }
    set(size) { self.w = size.w; self.h = size.h }
  }

  public static var zero: Self { .init(origin: .zero, size: .zero) }

  init(x: T, y: T, width: T, height: T) {
    self.x = x
    self.y = y
    self.w = width
    self.h = height
  }

  public init(origin: Point<T>, size: Size<T>) {
    self.x = origin.x
    self.y = origin.y
    self.w = size.w
    self.h = size.h
  }

  @inline(__always) public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.x == rhs.x && lhs.y == rhs.y && lhs.w == rhs.w && lhs.h == rhs.h
  }
}

public extension Rect where T: AdditiveArithmetic {
  var left: T { x }
  var right: T { x + w }
  var up: T { y }
  var down: T { y + h }
}

public extension Rect where T: BinaryInteger {
  init<O: BinaryInteger>(_ other: Rect<O>) {
    self.init(origin: Point<T>(other.origin), size: Size<T>(other.size))
  }
  init<O: BinaryFloatingPoint>(_ other: Rect<O>) {
    self.init(origin: Point<T>(other.origin), size: Size<T>(other.size))
  }
}

public extension Rect where T: BinaryFloatingPoint {
  init<O: BinaryInteger>(_ other: Rect<O>) {
    self.init(origin: Point<T>(other.origin), size: Size<T>(other.size))
  }
  init<O: BinaryFloatingPoint>(_ other: Rect<O>) {
    self.init(origin: Point<T>(other.origin), size: Size<T>(other.size))
  }
}
