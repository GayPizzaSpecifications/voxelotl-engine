import Foundation

public struct Color<T: SIMDScalar>: Hashable {
  private var _values: SIMD4<T>

  internal var values: SIMD4<T> { self._values }

  public init(r newR: T, g newG: T, b newB: T, a newA: T) {
    self._values = .init(newR, newG, newB, newA)
  }

  @inline(__always) public var r: T { get { self._values.x } set(newR) { self._values.x = newR } }
  @inline(__always) public var g: T { get { self._values.y } set(newG) { self._values.y = newG } }
  @inline(__always) public var b: T { get { self._values.z } set(newB) { self._values.z = newB } }
  @inline(__always) public var a: T { get { self._values.w } set(newA) { self._values.w = newA } }
}

// Sadly doesn't seem to be a better way to do this generically at the moment
public extension Color where T: AdditiveArithmetic {
  @inline(__always) static var zero: T { T.zero }
}
public extension Color where T: FixedWidthInteger {
  static var black: Self   { .init(r: zero, g: zero, b: zero, a: one) }
  static var white: Self   { .init(r:  one, g:  one, b:  one, a: one) }
  static var red: Self     { .init(r:  one, g: zero, b: zero, a: one) }
  static var green: Self   { .init(r: zero, g:  one, b: zero, a: one) }
  static var blue: Self    { .init(r: zero, g: zero, b:  one, a: one) }
  static var yellow: Self  { .init(r:  one, g:  one, b: zero, a: one) }
  static var magenta: Self { .init(r:  one, g: zero, b:  one, a: one) }
  static var cyan: Self    { .init(r: zero, g:  one, b:  one, a: one) }
}
public extension Color where T: BinaryFloatingPoint {
  static var black: Self   { .init(r: zero, g: zero, b: zero, a: one) }
  static var white: Self   { .init(r:  one, g:  one, b:  one, a: one) }
  static var red: Self     { .init(r:  one, g: zero, b: zero, a: one) }
  static var green: Self   { .init(r: zero, g:  one, b: zero, a: one) }
  static var blue: Self    { .init(r: zero, g: zero, b:  one, a: one) }
  static var yellow: Self  { .init(r:  one, g:  one, b: zero, a: one) }
  static var magenta: Self { .init(r:  one, g: zero, b:  one, a: one) }
  static var cyan: Self    { .init(r: zero, g:  one, b:  one, a: one) }
}

public extension Color where T: FixedWidthInteger {
  @inline(__always) static var one: T { T.max }

  init(r newR: T, g newG: T, b newB: T) {
    self.init(r: newR, g: newG, b: newB, a: Self.one)
  }
}

public extension Color where T: UnsignedInteger & FixedWidthInteger {
  init<U: BinaryFloatingPoint>(_ other: Color<U>) {
    self.init(
      r: T((other.r * U(T.max)).clamp(0, U(T.max))),
      g: T((other.g * U(T.max)).clamp(0, U(T.max))),
      b: T((other.b * U(T.max)).clamp(0, U(T.max))),
      a: T((other.a * U(T.max)).clamp(0, U(T.max))))
  }
}

public extension Color where T == UInt8 {
  init(rgba8888 c: UInt32) {
    self.init(
    r: UInt8((c & 0xFF000000) >> 24),
    g: UInt8((c & 0x00FF0000) >> 16),
    b: UInt8((c & 0x0000FF00) >>  8),
    a: UInt8((c & 0x000000FF) >>  0))
  }

  init(rgb888 c: UInt32) {
    self.init(
      r: UInt8((c & 0xFF0000) >> 16),
      g: UInt8((c & 0x00FF00) >>  8),
      b: UInt8((c & 0x0000FF) >>  0))
  }

  func mix(_ other: Self, _ n: Float) -> Self {
    Self(Color<Float>(self).mix(Color<Float>(other), n.saturated))
  }

  var linear: Self { Self(Color<Float>(self).linear) }
  var sRGB: Self { Self(Color<Float>(self).sRGB) }
}

public extension Color where T: BinaryFloatingPoint {
  @inline(__always) static var one: T { T(1) }

  init(r newR: T, g newG: T, b newB: T) {
    self.init(r: newR, g: newG, b: newB, a: Self.one)
  }

  init<U: BinaryFloatingPoint>(_ other: Color<U>) {
    self._values = SIMD4<T>(other._values)
  }

  init<U: BinaryInteger>(_ other: Color<U>) {
    let mul = 1 / T(0xFF)
    self.init(
      r: T(other.r) * mul,
      g: T(other.g) * mul,
      b: T(other.b) * mul,
      a: T(other.a) * mul)
  }

  init(rgba8888 c: UInt32) {
    self.init(Color<UInt8>(rgba8888: c))
  }

  init(rgb888 c: UInt32) {
    self.init(Color<UInt8>(rgb888: c))
  }

  func mix(_ other: Self, _ n: T) -> Self{
    let x = n.saturated
    return .init(
      r: x.lerp(r, other.r),
      g: x.lerp(g, other.g),
      b: x.lerp(b, other.b),
      a: x.lerp(a, other.a))
  }

  var linear: Self {
    Self(
      r: linearFromSRGB(r),
      g: linearFromSRGB(g),
      b: linearFromSRGB(b),
      a: a)
  }

  var sRGB: Self {
    Self(
      r: sRGBFromLinear(r),
      g: sRGBFromLinear(g),
      b: sRGBFromLinear(b),
      a: a)
  }

  @inline(__always) fileprivate func linearFromSRGB(_ x: T) -> T {
    if x < 0.04045 {
      x / 12.92
    } else {
      T(pow((Double(x) + 0.055) / 1.055, 2.4))
    }
  }

  @inline(__always) fileprivate func sRGBFromLinear(_ x: T) -> T {
    if x.isNaN || x <= 0 {
      0
    } else if x >= 1 {
      1
    } else if x < 0.0031308 {
      x * 12.92
    } else {
      T(1.055 * pow(Double(abs(x)), 1 / 2.4) - 0.055)
    }
  }
}

public extension SIMD4 {
  init(_ other: Color<Scalar>) {
    self = other.values
  }
}

public extension Color where T: FloatingPoint {
  init(hue: T, saturation: T, value: T) {
    if saturation == 0 {
      self.init(r: value, g: value, b: value, a: 1)
    } else {
      let hue = hue.floorMod(360)

      let rescale: T = 1 / 60
      let interp = (hue - floor(hue * rescale) * 60) * rescale
      let invInterp = (1 - interp)

      let base = 1 - saturation

      let dark = base * value
      let rise = value * interp + dark * invInterp
      let fall = dark * interp + value * invInterp

      if hue < 60 {
        self.init(r: value, g: rise, b: dark, a: 1)
      } else if hue < 120 {
        self.init(r: fall, g: value, b: dark, a: 1)
      } else if hue < 180 {
        self.init(r: dark, g: value, b: rise, a: 1)
      } else if hue < 240 {
        self.init(r: dark, g: fall, b: value, a: 1)
      } else if hue < 300 {
        self.init(r: rise, g: dark, b: value, a: 1)
      } else {
        self.init(r: value, g: dark, b: fall, a: 1)
      }
    }
  }
}
