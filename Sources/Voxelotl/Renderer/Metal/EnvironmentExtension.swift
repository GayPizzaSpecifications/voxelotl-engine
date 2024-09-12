import Metal

internal extension MTLCullMode {
  init(_ face: Environment.Face) {
    self = switch face {
    case .none: .none
    case .front: .front
    case .back: .back
    }
  }
}
