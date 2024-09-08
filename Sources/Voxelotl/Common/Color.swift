import Foundation

public struct Color<T: SIMDScalar>: Hashable {
  private var _r: T, _g: T, _b: T, _a: T

  public init(r newR: T, g newG: T, b newB: T, a newA: T) {
    self._r = newR
    self._g = newG
    self._b = newB
    self._a = newA
  }

  @inline(__always) public var r: T { get { self._r } set(newR) { self._r = newR } }
  @inline(__always) public var g: T { get { self._g } set(newG) { self._g = newG } }
  @inline(__always) public var b: T { get { self._b } set(newB) { self._b = newB } }
  @inline(__always) public var a: T { get { self._a } set(newA) { self._a = newA } }
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
      r: T((other._r * U(T.max)).clamp(0, U(T.max))),
      g: T((other._g * U(T.max)).clamp(0, U(T.max))),
      b: T((other._b * U(T.max)).clamp(0, U(T.max))),
      a: T((other._a * U(T.max)).clamp(0, U(T.max))))
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
    self._r = T(other._r)
    self._g = T(other._g)
    self._b = T(other._b)
    self._a = T(other._a)
  }

  init<U: BinaryInteger>(_ other: Color<U>) {
    let mul = 1 / T(0xFF)
    self.init(
      r: T(other._r) * mul,
      g: T(other._g) * mul,
      b: T(other._b) * mul,
      a: T(other._a) * mul)
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
      r: x.lerp(self._r, other._r),
      g: x.lerp(self._g, other._g),
      b: x.lerp(self._b, other._b),
      a: x.lerp(self._a, other._a))
  }

  var linear: Self {
    Self(
      r: linearFromSRGB(self._r),
      g: linearFromSRGB(self._g),
      b: linearFromSRGB(self._b),
      a: self._a)
  }

  var sRGB: Self {
    Self(
      r: sRGBFromLinear(self._r),
      g: sRGBFromLinear(self._g),
      b: sRGBFromLinear(self._b),
      a: self._a)
  }

  @inline(__always) fileprivate func linearFromSRGB(_ x: T) -> T {
    if x < 0.04045 {
      x / 12.92
    } else {
      T(Darwin.pow((Double(x) + 0.055) / 1.055, 2.4))
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
      T(1.055 * Darwin.pow(Double(abs(x)), 1 / 2.4) - 0.055)
    }
  }
}

fileprivate extension Color {
  @inline(__always) var values: SIMD4<T> {
    .init(self._r, self._g, self._b, self._a)
  }
}
public extension SIMD4 {
  init(_ color: Color<Scalar>) {
    self = color.values
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

public extension Color where T == Float {
  func pow(_ exponent: T) -> Self {
    Self(r: powf(r, exponent), g: powf(g, exponent), b: powf(b, exponent), a: a)
  }
}
public extension Color where T == Double {
  func pow(_ exponent: T) -> Self {
    Self(r: Darwin.pow(r, exponent), g: Darwin.pow(g, exponent), b: Darwin.pow(b, exponent), a: a)
  }
}
