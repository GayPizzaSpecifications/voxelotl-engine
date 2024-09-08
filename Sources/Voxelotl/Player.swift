import simd

struct Player {
  static let height: Float = 1.8
  static let radius: Float = 0.22
  static let bounds = AABB(
    from: .init(-Self.radius, 0, -Self.radius),
    to: .init(Self.radius, Self.height, Self.radius))

  static let eyeLevel: Float = 1.4
  static let epsilon = Float.ulpOfOne * 4000
  static let stepHeight: Float = 0.05

  static let accelerationCoeff: Float = 86.6
  static let airAccelCoeff: Float = 3
  static let gravityCoeff: Float = 20
  static let frictionCoeff: Float = 0.7375
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

  private mutating func tryMove(_ deltaTime: Float, _ world: World, newPosition: SIMD3<Float>) {
    //let oldPosition = self._position

    func checkCollision(_ world: World, _ position: SIMD3<Float>) -> Optional<AABB> {
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
        let blockPos = SIMD3(floor(corner.x), floor(corner.y), floor(corner.z))
        if case BlockType.solid = world.getBlock(at: SIMD3<Int>(blockPos)).type {
          let blockGeometry = AABB(from: blockPos, to: blockPos + 1)
          if bounds.touching(blockGeometry) {
            return blockGeometry
          }
        }
      }
      return nil
    }

    func checkCollisionRaycast(_ world: World, _ position: SIMD3<Float>, top: Bool) -> Optional<RaycastHit> {
      let dir: SIMD3<Float> = !top ? .down : .up
      let hHeight = Self.height * 0.5
      var org = self._position + .up * hHeight
      let max: Float = hHeight + Self.epsilon * 4

      org.x -= Self.radius
      org.z -= Self.radius
      if let hit1 = raycast(world: world, origin: org, direction: dir, maxDistance: max) { return hit1 }
      org.x += Self.radius + Self.radius
      if let hit2 = raycast(world: world, origin: org, direction: dir, maxDistance: max) { return hit2 }
      org.x -= Self.radius + Self.radius
      org.z += Self.radius + Self.radius
      if let hit3 = raycast(world: world, origin: org, direction: dir, maxDistance: max) { return hit3 }
      org.x += Self.radius + Self.radius
      if let hit4 = raycast(world: world, origin: org, direction: dir, maxDistance: max) { return hit4 }
      return nil
    }

    var testPos: SIMD3<Float>
#if false
    self._position.y = newPosition.y
    if self._velocity.y <= 0, let hit = checkCollisionRaycast(world, self._position, top: false)
    {
      self._position.y = hit.position.y
      self._velocity.y = 0.0
      self._onGround = true
    } else {
      self._onGround = false
    }
    if self._velocity.y >= 0, let hit = checkCollisionRaycast(world, self._position, top: true)
    {
      self._position.y = hit.position.y - Self.height
      self._velocity.y = 0.0
    }
#else
    self._position.y = newPosition.y
    testPos = self._position
    if self._velocity.y > 0 { testPos.y -= Self.epsilon }
    if let aabb = checkCollision(world, testPos) {
      if self._velocity.y <= 0 {
        self._position.y = aabb.top + Self.epsilon
        self._onGround = true
      } else {
        self._position.y = aabb.bottom - Self.height - Self.epsilon
        self._onGround = false
      }
      self._velocity.y = 0
    } else if checkCollisionRaycast(world, testPos, top: false) == nil {
      self._onGround = false
    }
#endif

    self._position.x = newPosition.x
    testPos = self._position
    //testPos.y += self._onGround ? Self.epsilon + Self.stepHeight : -Self.epsilon
    if let aabb = checkCollision(world, testPos) {
      if self._velocity.x < 0 {
        self._position.x = aabb.right + Self.radius + Self.epsilon
      } else {
        self._position.x = aabb.left - Self.radius - Self.epsilon
      }
      self._velocity.x = 0
    }

    self._position.z = newPosition.z
    testPos = self._position
    //testPos.y += self._onGround ? Self.epsilon + Self.stepHeight : -Self.epsilon
    if let aabb = checkCollision(world, testPos) {
      if self._velocity.z < 0 {
        self._position.z = aabb.near + Self.radius + Self.epsilon
      } else {
        self._position.z = aabb.far - Self.radius - Self.epsilon
      }
      self._velocity.z = 0
    }
  }

  private mutating func moveGround(_ deltaTime: Float, _ world: World, moveDir accelDir: SIMD2<Float>) {
    // Calculate coefficients
    let reference: Float = 60.0
    let invReference = 1 / reference
    let dtReference = deltaTime * reference
    let friction = Self.frictionCoeff
    let fricPowRef = pow(friction, dtReference)
    let fricMin1 = friction - 1
    let fricPowRefMin1 = fricPowRef - 1

    // Integration steps
    func integratePosition(_  acceleration: SIMD2<Float>, _ position: SIMD2<Float>, _ velocity: SIMD2<Float>
    ) -> SIMD2<Float> {
      var stepMul = acceleration * (friction * fricPowRef - friction * (dtReference + 1) + dtReference)
      stepMul += fricMin1 * velocity * fricPowRefMin1
      let step = (friction * stepMul) / (fricMin1 * fricMin1)
      return position + step * invReference
    }
    func integrateVelocity(_ accleration: SIMD2<Float>, _ velocity: SIMD2<Float>) -> SIMD2<Float> {
      velocity * fricPowRef + accleration * (friction * fricPowRefMin1 / fricMin1)
    }

    // Perform integration
    let acceleration = accelDir * Self.accelerationCoeff * invReference
    var nextPosition = self._position
    nextPosition.xz = integratePosition(acceleration, self._position.xz, self._velocity.xz)
    nextPosition.y += self.velocity.y * deltaTime // Hack
    self._velocity.xz = integrateVelocity(acceleration, self._velocity.xz)

    // Handle collision
    tryMove(deltaTime, world, newPosition: nextPosition)
  }

  private mutating func moveAir(_ deltaTime: Float, _ world: World, moveDir accelDir: SIMD2<Float>) {
    var forceSum: SIMD3<Float> = .zero

    // Apply movement
    let scaled = accelDir * Self.airAccelCoeff
    forceSum += SIMD3(scaled.x, 0, scaled.y)

    // Apply gravity
    forceSum += .down * Self.gravityCoeff

    // Classic semi-implicit euler integration
    self._velocity += forceSum * deltaTime
    let nextPosition = self._position + self._velocity * deltaTime

    // Handle collision
    tryMove(deltaTime, world, newPosition: nextPosition)
  }

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

    if Keyboard.pressed(.leftBracket, repeat: true) {
      self._position *= 2
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
    let willJump: Bool
    if self._onGround && self._shouldJump != .none {
      self._shouldJump = .none
      willJump = true
    } else {
      willJump = false
    }

    // Movement/integration
    // Limit unscaled movement vector to one
    let movementMagnitude = simd_length(movement)
    if movementMagnitude > 1.0 {
      movement /= movementMagnitude
    }
    // Rotate movement vector
    let right = SIMD2(cos(self._rotation.x), sin(self._rotation.x))
    movement = (right * movement.x + SIMD2(-right.y, right.x) * movement.y)
    // Flying and unflying
    self._velocity.y += Float(flying).clamp(-1, 1) * Self.flySpeedCoeff * deltaTime
    // Apply physics
    let iterations = 1
    let iterDT = deltaTime / Float(iterations)
    for _ in 0..<iterations {
      if self._onGround {
        self.moveGround(iterDT, world, moveDir: movement)
      } else {
        self.moveAir(iterDT, world, moveDir: movement)
      }
      // Limit maximum velocity
      let velocityLen = simd_length(self._velocity)
      if velocityLen > Self.maxVelocity {
        self._velocity = self._velocity / velocityLen * Self.maxVelocity
      }
    }

    // Jumping
    if self._onGround && willJump {
      self._velocity.y = Self.jumpVelocity
      self._onGround = false
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
  }
}
