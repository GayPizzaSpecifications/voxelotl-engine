import SDL3

public class GameController {
  public struct Pad {
    public enum Axes {
      case leftStickX, leftStickY
      case rightStickX, rightStickY
      case leftTrigger, rightTrigger

      internal var sdlEnum: SDL_GamepadAxis {
        switch self {
        case .leftStickX:   SDL_GAMEPAD_AXIS_LEFTX
        case .leftStickY:   SDL_GAMEPAD_AXIS_LEFTY
        case .rightStickX:  SDL_GAMEPAD_AXIS_RIGHTX
        case .rightStickY:  SDL_GAMEPAD_AXIS_RIGHTY
        case .leftTrigger:  SDL_GAMEPAD_AXIS_LEFT_TRIGGER
        case .rightTrigger: SDL_GAMEPAD_AXIS_RIGHT_TRIGGER
        }
      }
    }

    public struct Buttons: OptionSet {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }

      static let east        = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_EAST.rawValue)
      static let south       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_SOUTH.rawValue)
      static let north       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_NORTH.rawValue)
      static let west        = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_WEST.rawValue)
      static let back        = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_BACK.rawValue)
      static let start       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_START.rawValue)
      static let guide       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_GUIDE.rawValue)
      static let leftStick   = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_LEFT_STICK.rawValue)
      static let rightStick  = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_RIGHT_STICK.rawValue)
      static let leftBumper  = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_LEFT_SHOULDER.rawValue)
      static let rightBumper = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER.rawValue)
      static let dpadLeft    = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_DPAD_LEFT.rawValue)
      static let dpadRight   = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_DPAD_RIGHT.rawValue)
      static let dpadUp      = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_DPAD_UP.rawValue)
      static let dpadDown    = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_DPAD_DOWN.rawValue)
      static let misc1       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_MISC1.rawValue)
      static let misc2       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_MISC2.rawValue)
      static let misc3       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_MISC3.rawValue)
      static let misc4       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_MISC4.rawValue)
      static let misc5       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_MISC5.rawValue)
      static let misc6       = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_MISC6.rawValue)
      static let paddle1     = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1.rawValue)
      static let paddle2     = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_LEFT_PADDLE1.rawValue)
      static let paddle3     = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2.rawValue)
      static let paddle4     = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_LEFT_PADDLE2.rawValue)
      static let touchPad    = Self(rawValue: 1 << SDL_GAMEPAD_BUTTON_TOUCHPAD.rawValue)
    }

    public struct State {
      private let _axes: [Int16]
      private let _btns: Buttons, _btnImpulse: Buttons

      internal init(axes: [Int16], btns: Buttons, btnImpulse: Buttons) {
        self._axes = axes
        self._btns = btns
        self._btnImpulse = btnImpulse
      }

      public func axis(_ axis: Axes) -> Float {
        let raw = rawAxis(axis)
        let rescale = raw < 0 ? 1 / Float(-Int(Int16.min)) : 1 / Float(Int16.max)
        return Float(raw) * rescale
      }
      @inline(__always) func rawAxis(_ axis: Axes) -> Int16 {
        _axes[Int(axis.sdlEnum.rawValue)]
      }

      public func down(_ btn: Buttons) -> Bool {
        btn.isSubset(of: _btns)
      }
      public func pressed(_ btn: Buttons) -> Bool {
        btn.isSubset(of: _btns.intersection(_btnImpulse))
      }
      public func released(_ btn: Buttons) -> Bool {
        btn.isSubset(of: _btnImpulse.subtracting(_btns))
      }
    }

    public var name: String { String(cString: SDL_GetGamepadName(_sdlPad)) }
    public var state: State {
      .init(
        axes: self._axes,
        btns: self._btnCur,
        btnImpulse: self._btnCur.symmetricDifference(self._btnPrv))
    }

    //MARK: - Private

    private var _joyInstance: SDL_JoystickID, _sdlPad: OpaquePointer
    private var _axes = [Int16](repeating: 0, count: Int(SDL_GAMEPAD_AXIS_MAX.rawValue))
    private var _btnCur: Buttons = [], _btnPrv: Buttons = []

    internal var instanceID: SDL_JoystickID { _joyInstance }

    private init(instance: SDL_JoystickID, pad: OpaquePointer) {
      self._joyInstance = instance
      self._sdlPad = pad
    }

    internal static func open(joystickID: SDL_JoystickID) -> Self? {
      return if let sdlPad = SDL_OpenGamepad(joystickID) {
        .init(instance: joystickID, pad: sdlPad)
      } else { nil }
    }

    internal func close() {
      SDL_CloseGamepad(self._sdlPad)
    }

    internal mutating func buttonEvent(_ btn: SDL_GamepadButton, _ down: Bool) {
      if down {
        self._btnCur.formUnion(.init(rawValue: 1 << btn.rawValue))
      } else {
        self._btnCur.subtract(.init(rawValue: 1 << btn.rawValue))
      }
    }

    internal mutating func axisEvent(_ axis: SDL_GamepadAxis, _ value: Int16) {
      self._axes[Int(axis.rawValue)] = value
    }

    internal mutating func newTick() {
      self._btnPrv = self._btnCur
    }
  }

  public static func getPad(id: Int32) -> Pad? {
    _instance._pads[SDL_JoystickID(id)] ?? nil
  }

  @inline(__always) public static var current: Pad? {
    getPad(id: Int32(_instance._firstID))
  }

  //MARK: - Private

  private static let _instance = GameController()
  public static var instance: GameController { _instance }

  private var _pads = Dictionary<SDL_JoystickID, Pad>()
  private var _firstID: SDL_JoystickID = 0

  internal func connectedEvent(id: SDL_JoystickID) {
    if _pads.keys.contains(id) {
      return
    }
    if let pad = Pad.open(joystickID: id) {
      printErr("Using gamepad #\(pad.instanceID), \"\(pad.name)\"")
      if self._firstID == 0 {
        self._firstID = id
      }
      self._pads[id] = pad
    }
  }

  internal func removedEvent(id: SDL_JoystickID) {
    if let pad = self._pads.removeValue(forKey: id) {
      pad.close()
    }
    if id == _firstID {
      _firstID = _pads.keys.first ?? 0
    }
  }

  internal func buttonEvent(id: SDL_JoystickID, btn: SDL_GamepadButton, state: UInt8) {
    _pads[id]?.buttonEvent(btn, state == SDL_PRESSED)
  }

  internal func axisEvent(id: SDL_JoystickID, axis: SDL_GamepadAxis, value: Int16) {
    _pads[id]?.axisEvent(axis, value)
  }

  internal func newFrame() {
    for idx in _pads.values.indices {
      _pads.values[idx].newTick()
    }
  }
}


//MARK: - Stick convenience functions

public extension GameController.Pad.State {
  var leftStick: SIMD2<Float> {
    .init(axis(.leftStickX), axis(.leftStickY))
  }
  var rightStick: SIMD2<Float> {
    .init(axis(.rightStickX), axis(.rightStickY))
  }
  var leftTrigger: Float { axis(.leftTrigger) }
  var rightTrigger: Float { axis(.rightTrigger) }
}

public extension FloatingPoint {
  @inline(__always) internal func axisDeadzone(_ min: Self, _ max: Self) -> Self {
    let x = abs(self)
    return if x <= min { 0 } else if x >= max {
      .init(signOf: self, magnitudeOf: 1)
    } else {
      .init(signOf: self, magnitudeOf: x - min) / (max - min)
    }
  }
}

public extension SIMD2 where Scalar: FloatingPoint {
  func cardinalDeadzone(min: Scalar, max: Scalar) -> Self {
    .init(self.x.axisDeadzone(min, max), self.y.axisDeadzone(min, max))
  }

  func radialDeadzone(min: Scalar, max: Scalar) -> Self {
    let magnitude = (x * x + y * y).squareRoot()
    if magnitude == .zero || magnitude < min {
      return .zero
    } else if magnitude > max {
      return self / magnitude
    } else {
      let rescale = (magnitude - min) / (max - min)
      return self / magnitude * rescale
    }
  }
}
