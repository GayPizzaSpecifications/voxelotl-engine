import simd

struct Player {
  static let height: Float = 1.8
  static let radius: Float = 0.22
  static let bounds = AABB(
    from: .init(-Self.radius, 0, -Self.radius),
    to: .init(Self.radius, Self.height, Self.radius))

  static let eyeLevel: Float = 1.4
  static let epsilon = Float.ulpOfOne * 10

  static let accelerationCoeff: Float = 75
  static let airAccelCoeff: Float = 3
  static let gravityCoeff: Float = 20
  static let frictionCoeff: Float = 22
  static let jumpVelocity: Float = 7
  static let maxVelocity: Float = 160

  private var _position = SIMD3<Float>.zero
  private var _velocity = SIMD3<Float>.zero
  private var _rotation = SIMD2<Float>.zero

  private var _onGround: Bool = false

  public var position: SIMD3<Float> { get { self._position } set { self._position = newValue } }
  public var velocity: SIMD3<Float> { get { self._velocity } set { self._velocity = newValue } }
  public var rotation: SIMD2<Float> { get { self._rotation } set { self._rotation = newValue } }

  public var eyePosition: SIMD3<Float> { self._position + .up * Self.eyeLevel }
  public var eyeRotation: simd_quatf {
    .init(angle: self._rotation.y, axis: .right) *
    .init(angle: self._rotation.x, axis: .up)
  }

  mutating func update(deltaTime: Float, boxes: [Box]) {
    if let pad = GameController.current?.state {
      // Turning input
      let turning = pad.rightStick.radialDeadzone(min: 0.1, max: 1)
      _rotation += turning * deltaTime * 3.0
      if self._rotation.x < 0.0 {
        self._rotation.x += .pi * 2
      } else if _rotation.x > .pi * 2 {
        self._rotation.x -= .pi * 2
      }
      self._rotation.y = self._rotation.y.clamp(-.pi * 0.5, .pi * 0.5)

      // Jumping
      if self._onGround {
        if pad.pressed(.east) {
          self._velocity.y = Self.jumpVelocity
          self._onGround = false
        }
      }

      // Movement (slower in air than on ground)
      let movement = pad.leftStick.cardinalDeadzone(min: 0.1, max: 1)
      let rotc = cos(self._rotation.x), rots = sin(self._rotation.x)
      let coeff = self._onGround ? Self.accelerationCoeff : Self.airAccelCoeff
      self._velocity.x += (movement.x * rotc - movement.y * rots) * coeff * deltaTime
      self._velocity.z += (movement.y * rotc + movement.x * rots) * coeff * deltaTime

      // Flying and unflying
      self._velocity.y += (pad.rightTrigger - pad.leftTrigger) * 36 * deltaTime
    }

    // Apply gravity
    self._velocity.y -= Self.gravityCoeff * deltaTime

    // Move & handle collision
    let checkCollision = { (position: SIMD3<Float>) -> Optional<AABB> in
      for box in boxes {
        let bounds = Self.bounds + position
        if bounds.touching(box.geometry) {
          return box.geometry
        }
      }
      return nil
    }
    self._position.x += self._velocity.x * deltaTime
    if let aabb = checkCollision(self._position) {
      if self._velocity.x < 0 {
        self._position.x = aabb.right + Self.radius + Self.epsilon
      } else {
        self._position.x = aabb.left - Self.radius - Self.epsilon
      }
      self._velocity.x = 0
    }
    self._position.z += self._velocity.z * deltaTime
    if let aabb = checkCollision(self._position) {
      if self._velocity.z < 0 {
        self._position.z = aabb.near + Self.radius + Self.epsilon
      } else {
        self._position.z = aabb.far - Self.radius - Self.epsilon
      }
      self._velocity.z = 0
    }
    self._position.y += self._velocity.y * deltaTime
    if let aabb = checkCollision(self._velocity.y > 0 ? self._position + .down * Self.epsilon : self.position) {
      if self._velocity.y < 0 {
        self._position.y = aabb.top + Self.epsilon
        self._onGround = true
      } else {
        self._position.y = aabb.bottom - Self.height - Self.epsilon
        self._onGround = false
      }
      self._velocity.y = 0
    } else {
      self._onGround = false
    }

    // Ground friction
    if self._onGround {
      self._velocity.x /= 1.0 + Self.frictionCoeff * deltaTime
      self._velocity.z /= 1.0 + Self.frictionCoeff * deltaTime
    }

    // Limit maximum velocity
    let velocityLen = simd_length(self._velocity)
    if velocityLen > Self.maxVelocity {
      self._velocity = self._velocity / velocityLen * Self.maxVelocity
    }
  }
}
