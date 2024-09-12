import Metal

internal extension MTLClearColor {
  init(_ color: Color<Double>) {
    self.init(red: color.r, green: color.g, blue: color.b, alpha: color.a)
  }
}
