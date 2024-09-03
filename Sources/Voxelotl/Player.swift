import simd

struct Player {
  static let height: Float = 1.8
  static let radius: Float = 0.22
  static let bounds = AABB(
    from: .init(-Self.radius, 0, -Self.radius),
    to: .init(Self.radius, Self.height, Self.radius))

  static let eyeLevel: Float = 1.4
  static let epsilon = Float.ulpOfOne * 2000

  static let accelerationCoeff: Float = 75
  static let airAccelCoeff: Float = 3
  static let gravityCoeff: Float = 20
  static let frictionCoeff: Float = 22
  static let flySpeedCoeff: Float = 36
  static let jumpVelocity: Float = 7
  static let maxVelocity: Float = 160
  static let blockReach: Float = 3.8

  private var _position = SIMD3<Float>.zero
  private var _velocity = SIMD3<Float>.zero
  private var _rotation = SIMD2<Float>.zero

  private var _onGround: Bool = false
  private var _shouldJump: Optional<Float> = .none
  private var _useMouseDir: Bool = false

  public var rayhitPos: Optional<SIMD3<Float>> = nil
  private var prevLeftTrigger: Float = 0, prevRightTrigger: Float = 0

  public var position: SIMD3<Float> { get { self._position } set { self._position = newValue } }
  public var velocity: SIMD3<Float> { get { self._velocity } set { self._velocity = newValue } }
  public var rotation: SIMD2<Float> { get { self._rotation } set { self._rotation = newValue } }

  public var eyePosition: SIMD3<Float> { self._position + .up * Self.eyeLevel }
  public var eyeRotation: simd_quatf {
    .init(angle: self._rotation.y, axis: .right) *
    .init(angle: self._rotation.x, axis: .up)
  }

  enum JumpInput { case off, press, held }

  mutating func update(deltaTime: Float, world: World, camera: inout Camera) {
    var turning: SIMD2<Float> = .zero
    var movement: SIMD2<Float> = .zero
    var flying: Int = .zero
    var jumpInput: JumpInput = .off
    var destroy = false, place = false

    // Read controller input (if one is plugged in)
    if let pad = GameController.current?.state {
      let turn = pad.rightStick.radialDeadzone(min: 0.1, max: 1)
      if turn != .zero {
        turning += turn
        self._useMouseDir = false
      }
      movement = pad.leftStick.cardinalDeadzone(min: 0.1, max: 1)
      flying += (pad.down(.rightBumper) ? 1 : 0) - (pad.down(.leftBumper) ? 1 : 0)
      if pad.pressed(.east) {
        jumpInput = .press
      } else if jumpInput != .press && pad.down(.east) {
        jumpInput = .held
      }
      if pad.leftTrigger > 0.4 && prevLeftTrigger < 0.4 {
        place = true
      }
      if pad.rightTrigger > 0.4 && prevRightTrigger < 0.4 {
        destroy = true
      }
      prevLeftTrigger = pad.leftTrigger
      prevRightTrigger = pad.rightTrigger
    }

    // Read keyboard input
    if Keyboard.down(.w) { movement.y -= 1 }
    if Keyboard.down(.s) { movement.y += 1 }
    if Keyboard.down(.a) { movement.x -= 1 }
    if Keyboard.down(.d) { movement.x += 1 }
    if Keyboard.down(.q) { flying += 1 }
    if Keyboard.down(.e) { flying -= 1 }
    if Keyboard.pressed(.tab) { Mouse.capture = !Mouse.capture }
    if Keyboard.pressed(.space) {
      jumpInput = .press
    } else if jumpInput != .press && Keyboard.down(.space) {
      jumpInput = .held
    }

    // Read mouse input
    if Mouse.pressed(.left)  { destroy = true }
    if Mouse.pressed(.right) { place   = true }
    if Mouse.capture {
      self._rotation += Mouse.relative / 2048 * Float.pi
      self._useMouseDir = false
    } else if simd_length_squared(Mouse.relative) > Float.ulpOfOne {
      self._useMouseDir = true
    }

    // Turning input
    self._rotation += turning * deltaTime * 3.0
    if self._rotation.x < 0.0 {
      self._rotation.x += .pi * 2
    } else if _rotation.x > .pi * 2 {
      self._rotation.x -= .pi * 2
    }
    self._rotation.y = self._rotation.y.clamp(-.pi * 0.5, .pi * 0.5)

    // Jumping
    if jumpInput == .press {
      self._shouldJump = 0.3
    } else if self._shouldJump != .none {
      if jumpInput == .held {
        self._shouldJump! -= deltaTime
        if self._shouldJump! <= 0.0 {
          self._shouldJump = .none
        }
      } else {
        self._shouldJump = .none
      }
    }
    if self._onGround && self._shouldJump != .none {
      self._velocity.y = Self.jumpVelocity
      self._onGround = false
      self._shouldJump = .none
    }

    // Movement (slower in air than on ground)
    let movementMagnitude = simd_length(movement)
    if movementMagnitude > 1.0 {
      movement /= movementMagnitude
    }
    let right = SIMD2(cos(self._rotation.x), sin(self._rotation.x))
    let forward = SIMD2(-right.y, right.x)
    let coeff = self._onGround ? Self.accelerationCoeff : Self.airAccelCoeff
    self._velocity.xz += (right * movement.x + forward * movement.y) * coeff * deltaTime

    // Flying and unflying
    self._velocity.y += Float(flying).clamp(-1, 1) * Self.flySpeedCoeff * deltaTime

    // Apply gravity
    self._velocity.y -= Self.gravityCoeff * deltaTime

    // Move & handle collision
    let checkCorner = { (world: World, bounds: AABB, corner: SIMD3<Float>) -> Optional<AABB> in
      let blockPos = SIMD3(floor(corner.x), floor(corner.y), floor(corner.z))
      if case BlockType.solid = world.getBlock(at: SIMD3<Int>(blockPos)).type {
        let blockGeometry = AABB(from: blockPos, to: blockPos + 1)
        if bounds.touching(blockGeometry) {
          return blockGeometry
        }
      }
      return nil
    }
    let checkCollision = { (world: World, position: SIMD3<Float>) -> Optional<AABB> in
      let bounds = Self.bounds + position
      let corners: [SIMD3<Float>] = [
        .init(bounds.left,  bounds.bottom,   bounds.far),
        .init(bounds.right, bounds.bottom,   bounds.far),
        .init(bounds.left,  bounds.bottom,   bounds.near),
        .init(bounds.right, bounds.bottom,   bounds.near),
        .init(bounds.left,  bounds.center.y, bounds.far),
        .init(bounds.right, bounds.center.y, bounds.far),
        .init(bounds.left,  bounds.center.y, bounds.near),
        .init(bounds.right, bounds.center.y, bounds.near),
        .init(bounds.left,  bounds.top,      bounds.far),
        .init(bounds.right, bounds.top,      bounds.far),
        .init(bounds.left,  bounds.top,      bounds.near),
        .init(bounds.right, bounds.top,      bounds.near)
      ]
      for corner in corners {
        if let geometry = checkCorner(world, bounds, corner) {
          return geometry
        }
      }
      return nil
    }
    self._position.y += self._velocity.y * deltaTime
    if let aabb = checkCollision(world, self._velocity.y > 0 ? self._position + .down * Self.epsilon : self.position) {
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
    self._position.x += self._velocity.x * deltaTime
    if let aabb = checkCollision(world, self._position) {
      if self._velocity.x < 0 {
        self._position.x = aabb.right + Self.radius + Self.epsilon
      } else {
        self._position.x = aabb.left - Self.radius - Self.epsilon
      }
      self._velocity.x = 0
    }
    self._position.z += self._velocity.z * deltaTime
    if let aabb = checkCollision(world, self._position) {
      if self._velocity.z < 0 {
        self._position.z = aabb.near + Self.radius + Self.epsilon
      } else {
        self._position.z = aabb.far - Self.radius - Self.epsilon
      }
      self._velocity.z = 0
    }

    // Update camera
    camera.position = self.eyePosition
    camera.rotation = self.eyeRotation

    // Block picking
    let dir = !Mouse.capture && self._useMouseDir
      ? camera.screenRay(Mouse.position)
      : self.eyeRotation * .forward
    if let hit = raycast(world: world, origin: self.eyePosition, direction: dir, maxDistance: Self.blockReach) {
      if destroy || place {
        if destroy {
          world.setBlock(at: hit.map, type: .air)
        } else {
          world.setBlock(at: hit.map.offset(by: hit.side), type: .solid(.white))
        }
        if let hit = raycast(world: world, origin: self.eyePosition, direction: dir, maxDistance: Self.blockReach) {
          self.rayhitPos = hit.position
        } else {
          self.rayhitPos = nil
        }
      } else {
        self.rayhitPos = hit.position
      }
    } else {
      self.rayhitPos = nil
    }

    // Ground friction
    if self._onGround {
      self._velocity.xz /= 1.0 + Self.frictionCoeff * deltaTime
    }

    // Limit maximum velocity
    let velocityLen = simd_length(self._velocity)
    if velocityLen > Self.maxVelocity {
      self._velocity = self._velocity / velocityLen * Self.maxVelocity
    }
  }
}
