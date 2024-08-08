import simd

struct Camera {
  private var position = SIMD3<Float>.zero
  private var rotation = SIMD2<Float>.zero

  var view: matrix_float4x4 {
    .rotate(yawPitch: rotation) * .translate(-position)
  }

  mutating func update(deltaTime: Float) {
    if let pad = GameController.current?.state {
      let turning = pad.rightStick.radialDeadzone(min: 0.1, max: 1)
      rotation += turning * deltaTime
      if rotation.x < 0.0 {
        rotation.x += .pi * 2
      } else if rotation.x > .pi * 2 {
        rotation.x -= .pi * 2
      }
      rotation.y = rotation.y.clamp(-.pi * 0.5, .pi * 0.5)

      let movement = pad.leftStick.cardinalDeadzone(min: 0.1, max: 1)

      let rotc = cos(rotation.x), rots = sin(rotation.x)
      position += .init(
        movement.x * rotc - movement.y * rots,
        0,
        movement.y * rotc + movement.x * rots
      ) * deltaTime

      if pad.pressed(.back) {
        position = .zero
        rotation = .zero
      }
    }
  }
}
