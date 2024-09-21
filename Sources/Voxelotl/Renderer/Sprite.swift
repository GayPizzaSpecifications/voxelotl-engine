public struct Sprite {
  public struct Flip: OptionSet {
    public let rawValue: UInt16
    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let none: Self = Self(rawValue: 0)
    public static let horz: Self = Self(rawValue: 1 << 0)
    public static let vert: Self = Self(rawValue: 1 << 1)
    public static let diag: Self = Self(rawValue: 1 << 2)
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

public extension Sprite.Flip {
  var clockwise: Self {
    [Self](arrayLiteral: [ .vert, .diag ], [ .horz, .vert, .diag ], .diag,
      [ .horz, .diag ], .horz, .none, [ .horz, .vert ], .vert)[Int(self.rawValue)]
  }

  var counterClockwise: Self {
    [Self](arrayLiteral: [ .horz, .diag ], .diag, [ .horz, .vert, .diag ],
      [ .vert, .diag ], .vert, [ .horz, .vert ], .none, .horz)[Int(self.rawValue)]
  }
}
