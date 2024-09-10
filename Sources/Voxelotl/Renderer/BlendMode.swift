public enum BlendMode: Hashable {
  case none
  case normal
  case premultiplied
  case additive
  case screen
  case multiply
  case subtract
}

internal extension BlendMode {
  var function: BlendFunc {
    switch self {
    case .none: .off
    case .normal:        .on(src: .srcAlpha,         dst: .oneMinusSrcAlpha, equation: .add)
    case .premultiplied: .on(src: .one,              dst: .oneMinusSrcAlpha, equation: .add)
    case .additive:      .on(src: .srcAlpha,         dst: .one,              equation: .add)
    case .screen:        .on(src: .one,              dst: .oneMinusSrcColor, equation: .add)
    case .multiply:      .on(src: .dstColor,         dst: .one,              equation: .add)
    case .subtract:      .on(src: .oneMinusSrcAlpha, dst: .one,              equation: .subtract)
    }
  }
}
