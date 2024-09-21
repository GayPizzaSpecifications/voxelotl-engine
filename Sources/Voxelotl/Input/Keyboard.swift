import SDL3

public class Keyboard {
  public enum Keys {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case leftBracket
    case right, left, up, down
    case space, tab
    case enter
  }

  public static func down(_ key: Keys) -> Bool {
     keyState(key) & Self._DOWN == Self._DOWN
  }

  public static func pressed(_ key: Keys, repeat rep: Bool = false) -> Bool {
    var state = keyState(key)
    if rep {
      state &= ~Self._REPEAT
    }
    return state == Self._PRESS
  }

  public static func released(_ key: Keys) -> Bool {
    keyState(key) == Self._RELEASE
  }

  //MARK: - Private

  private static let _instance = Keyboard()
  public static var instance: Keyboard { _instance }

  @inline(__always) private static func keyState(_ key: Keys) -> UInt8 {
    self._instance._state[Int(key.sdlScancode.rawValue)]
  }

  private static let _UP = UInt8(0b000), _DOWN = UInt8(0b010), _IMPULSE = UInt8(0b001)
  private static let _REPEAT = UInt8(0b100)
  private static let _PRESS: UInt8 = _DOWN | _IMPULSE
  private static let _RELEASE: UInt8 = _UP | _IMPULSE

  private var _state = [UInt8](repeating: _UP, count: Int(SDL_NUM_SCANCODES.rawValue))

  internal func keyDownEvent(scan: SDL_Scancode, repeat rep: Bool) {
    var newState = Self._PRESS
    if rep {
      newState |= Self._REPEAT
    }
    self._state[Int(scan.rawValue)] = newState
  }

  internal func keyUpEvent(scan: SDL_Scancode) {
    self._state[Int(scan.rawValue)] = Self._RELEASE
  }

  internal func newFrame() {
    self._state = self._state.map({ $0 & ~(Self._IMPULSE | Self._REPEAT) })
  }
}

internal extension Keyboard.Keys {
  var sdlKeycode: SDL_Keycode {
    switch self {
    case .a:     SDLK_A
    case .b:     SDLK_B
    case .c:     SDLK_C
    case .d:     SDLK_D
    case .e:     SDLK_E
    case .f:     SDLK_F
    case .g:     SDLK_G
    case .h:     SDLK_H
    case .i:     SDLK_I
    case .j:     SDLK_J
    case .k:     SDLK_K
    case .l:     SDLK_L
    case .m:     SDLK_M
    case .n:     SDLK_N
    case .o:     SDLK_O
    case .p:     SDLK_P
    case .q:     SDLK_Q
    case .r:     SDLK_R
    case .s:     SDLK_S
    case .t:     SDLK_T
    case .u:     SDLK_U
    case .v:     SDLK_V
    case .w:     SDLK_W
    case .x:     SDLK_X
    case .y:     SDLK_Y
    case .z:     SDLK_Z
    case .leftBracket: SDLK_LEFTBRACKET
    case .left:  SDLK_LEFT
    case .right: SDLK_RIGHT
    case .up:    SDLK_UP
    case .down:  SDLK_DOWN
    case .space: SDLK_SPACE
    case .tab:   SDLK_TAB
    case .enter: SDLK_RETURN
    }
  }

  var sdlScancode: SDL_Scancode {
    switch self {
    case .a:     SDL_SCANCODE_A
    case .b:     SDL_SCANCODE_B
    case .c:     SDL_SCANCODE_C
    case .d:     SDL_SCANCODE_D
    case .e:     SDL_SCANCODE_E
    case .f:     SDL_SCANCODE_F
    case .g:     SDL_SCANCODE_G
    case .h:     SDL_SCANCODE_H
    case .i:     SDL_SCANCODE_I
    case .j:     SDL_SCANCODE_J
    case .k:     SDL_SCANCODE_K
    case .l:     SDL_SCANCODE_L
    case .m:     SDL_SCANCODE_M
    case .n:     SDL_SCANCODE_N
    case .o:     SDL_SCANCODE_O
    case .p:     SDL_SCANCODE_P
    case .q:     SDL_SCANCODE_Q
    case .r:     SDL_SCANCODE_R
    case .s:     SDL_SCANCODE_S
    case .t:     SDL_SCANCODE_T
    case .u:     SDL_SCANCODE_U
    case .v:     SDL_SCANCODE_V
    case .w:     SDL_SCANCODE_W
    case .x:     SDL_SCANCODE_X
    case .y:     SDL_SCANCODE_Y
    case .z:     SDL_SCANCODE_Z
    case .leftBracket: SDL_SCANCODE_LEFTBRACKET
    case .left:  SDL_SCANCODE_LEFT
    case .right: SDL_SCANCODE_RIGHT
    case .up:    SDL_SCANCODE_UP
    case .down:  SDL_SCANCODE_DOWN
    case .space: SDL_SCANCODE_SPACE
    case .tab:   SDL_SCANCODE_TAB
    case .enter: SDL_SCANCODE_RETURN
    }
  }
}

fileprivate extension SDL_Keycode {
  init(scancode: SDL_Scancode) {
    self.init(scancode.rawValue | UInt32(SDLK_SCANCODE_MASK))
  }
}
