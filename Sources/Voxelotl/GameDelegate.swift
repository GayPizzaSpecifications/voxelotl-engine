public protocol GameDelegate {
  func create(_ renderer: Renderer)
  func fixedUpdate(_ time: GameTime)
  func update(_ time: GameTime)
  func draw(_ renderer: Renderer, _ time: GameTime)
  func resize(_ size: Size<Int>)
}

public extension GameDelegate {
  func fixedUpdate(_ time: GameTime) {}
  func update(_ time: GameTime) {}
  func resize(_ size: Size<Int>) {}
}

public struct GameTime {
  let total: Duration
  let delta: Duration
}

extension Duration {
  var asFloat: Double {
    Double(components.seconds) + Double(components.attoseconds) * 1e-18
  }
}
