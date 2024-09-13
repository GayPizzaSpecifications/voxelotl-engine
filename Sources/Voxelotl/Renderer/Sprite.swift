public struct Sprite {
  public struct Flip: OptionSet {
    public let rawValue: UInt16
    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let none: Self = Self(rawValue: 0)
    public static let x: Self    = Self(rawValue: 1 << 0)
    public static let y: Self    = Self(rawValue: 1 << 1)
  }

  var texture: RendererTexture2D
  var position: SIMD2<Float>
  var scale: SIMD2<Float>
  var origin: SIMD2<Float>
  var shear: SIMD2<Float> = .zero
  var angle: Float
  var depth: Int
  var flip: Flip
  var color: Color<Float>
}
