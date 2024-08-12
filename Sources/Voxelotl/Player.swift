import simd

struct Player {
  private var _position = SIMD3<Float>.zero
  private var _rotation = SIMD2<Float>.zero

  public var position: SIMD3<Float> { self._position }
  public var rotation: SIMD2<Float> { self._rotation }

  mutating func update(deltaTime: Float) {
    if let pad = GameController.current?.state {
      let turning = pad.rightStick.radialDeadzone(min: 0.1, max: 1)
      _rotation += turning * deltaTime * 3.0
      if _rotation.x < 0.0 {
        _rotation.x += .pi * 2
      } else if _rotation.x > .pi * 2 {
        _rotation.x -= .pi * 2
      }
      _rotation.y = _rotation.y.clamp(-.pi * 0.5, .pi * 0.5)

      let movement = pad.leftStick.cardinalDeadzone(min: 0.1, max: 1)

      let rotc = cos(_rotation.x), rots = sin(_rotation.x)
      _position += .init(
        movement.x * rotc - movement.y * rots,
        0,
        movement.y * rotc + movement.x * rots
      ) * deltaTime * 3.0

      if pad.pressed(.back) {
        _position = .zero
        _rotation = .zero
      }
    }
  }
}
