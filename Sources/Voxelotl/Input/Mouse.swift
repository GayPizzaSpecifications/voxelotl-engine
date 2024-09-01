import SDL3

public class Mouse {
  public struct Buttons: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    static let left    = Self(rawValue: UInt32(SDL_BUTTON_LEFT).buttonMask)
    static let middle  = Self(rawValue: UInt32(SDL_BUTTON_MIDDLE).buttonMask)
    static let right   = Self(rawValue: UInt32(SDL_BUTTON_RIGHT).buttonMask)
    static let button4 = Self(rawValue: UInt32(SDL_BUTTON_X1).buttonMask)
    static let button5 = Self(rawValue: UInt32(SDL_BUTTON_X2).buttonMask)
  }

  public static var capture: Bool {
    get { self._instance.getCapture() }
    set { self._instance.setCapture(newValue) }
  }

  public static var position: SIMD2<Float> { self._instance.getAbsolute() }
  public static var relative: SIMD2<Float> { self._instance.getDelta() }

  public static func down(_ btn: Buttons) -> Bool {
    btn.isSubset(of: self._instance._btns)
  }
  public static func pressed(_ btn: Buttons) -> Bool {
    btn.isSubset(of: self._instance._btns.intersection(self._instance._btnImpulse))
  }
  public static func released(_ btn: Buttons) -> Bool {
    btn.isSubset(of: self._instance._btnImpulse.subtracting(self._instance._btns))
  }

  //MARK: - Private

  private static let _instance = Mouse()
  public static var instance: Mouse { self._instance }

  private var _window: OpaquePointer!
  private var _captured: Bool = false
  private var _dpiScale: SIMD2<Float> = .one
  private var _abs: SIMD2<Float> = .zero, _delta: SIMD2<Float> = .zero
  private var _btns: Buttons = [], _btnImpulse: Buttons = []

  private func getCapture() -> Bool { self._captured }
  private func setCapture(_ toggle: Bool) {
    if SDL_SetWindowRelativeMouseMode(self._window, toggle) && SDL_SetWindowMouseGrab(self._window, toggle) {
      self._captured = toggle
    }
  }

  internal func setDPI(scale: SIMD2<Float>) { self._dpiScale = scale }

  private func getAbsolute() -> SIMD2<Float> { self._abs * self._dpiScale }
  private func getDelta() -> SIMD2<Float> { self._delta }

  internal func buttonEvent(btn: UInt32, state: UInt8) {
    if state == SDL_PRESSED {
      self._btns.formUnion(.init(rawValue: btn.buttonMask))
    } else {
      self._btns.subtract(.init(rawValue: btn.buttonMask))
    }
    self._btnImpulse.formUnion(.init(rawValue: btn.buttonMask))
  }

  internal func motionEvent(absolute: SIMD2<Float>, relative: SIMD2<Float>) {
    self._abs = absolute
    self._delta += relative
  }

  internal func newFrame(_ window: OpaquePointer) {
    self._window = window

    let grabbedFlag = SDL_WindowFlags(SDL_WINDOW_MOUSE_GRABBED)
    self._captured = (SDL_GetWindowFlags(window) & grabbedFlag) == grabbedFlag

    self._delta = .zero
    self._btnImpulse = []
  }
}

fileprivate extension UInt32 {
  var buttonMask: UInt32 { 1 &<< (self &- 1) }
}
