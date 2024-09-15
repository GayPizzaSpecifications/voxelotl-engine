import Foundation
import SDL3
import QuartzCore.CAMetalLayer

#if canImport(GameController)
import GameController
#endif

public class Application {
  private let cfg: ApplicationConfiguration
  private var del: GameDelegate!

  private var window: OpaquePointer? = nil
  private var view: SDL_MetalView? = nil
  private var renderer: Renderer? = nil
  private var lastCounter: UInt64 = 0
  private var time: Duration = .zero

#if os(iOS)
  private var onScreenVirtualController: GCVirtualController? = nil
  private var onScreenVirtualControllerShown: Bool = false
#endif

  public init(delegate: GameDelegate, configuration: ApplicationConfiguration) {
    self.cfg = configuration
    self.del = delegate
  }

  private func initialize() -> ApplicationExecutionState {
#if os(iOS)
    if cfg.flags.contains(.onScreenVirtualController) {
      onScreenVirtualController = initializeOnScreenVirtualController()
      self.showVirtualGameController(true)
    }
#endif

    guard SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD) else {
      printErr("SDL_Init() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    // Create SDL window
    var windowFlags = SDL_WindowFlags(SDL_WINDOW_METAL)
    if cfg.flags.contains(.resizable) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_RESIZABLE)
    }
    if cfg.flags.contains(.highDPI) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_HIGH_PIXEL_DENSITY)
    }
    if cfg.flags.contains(.borderless) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_BORDERLESS)
    }
    if cfg.flags.contains(.fullscreen) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_FULLSCREEN)
    }
    window = SDL_CreateWindow(cfg.title, cfg.frame.w, cfg.frame.h, windowFlags)
    guard window != nil else {
      printErr("SDL_CreateWindow() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    // Get window metrics
    var backBuffer = Size<Int32>.zero, windowSize = Size<Int32>.zero
    guard SDL_GetWindowSizeInPixels(window, &backBuffer.w, &backBuffer.h) else {
      printErr("SDL_GetWindowSizeInPixels() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }
    guard SDL_GetWindowSize(window, &windowSize.w, &windowSize.h) else {
      printErr("SDL_GetWindowSize() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }
    Mouse.instance.setDPI(scale: SIMD2(Size<Float>(backBuffer) / Size<Float>(windowSize)))

    // Create Metal renderer
    view = SDL_Metal_CreateView(window)
    do {
      let layer = unsafeBitCast(SDL_Metal_GetLayer(view), to: CAMetalLayer.self)
#if os(macOS)
      layer.displaySyncEnabled = cfg.vsyncMode == .off ? false : true
#endif
      self.renderer = try Renderer(layer: layer, size: Size<Int>(backBuffer))
    } catch RendererError.initFailure(let message) {
      printErr("Renderer init error: \(message)")
      return .exitFailure
    } catch {
      printErr("Renderer init error: unexpected error")
    }

    self.del.create(renderer!)

    lastCounter = SDL_GetPerformanceCounter()
    return .running
  }

#if os(iOS)
  private func initializeOnScreenVirtualController() -> GCVirtualController {
    let configuration = GCVirtualController.Configuration()
    configuration.elements = [
      GCInputLeftThumbstick,
      GCInputRightThumbstick,
      GCInputLeftTrigger,
      GCInputRightTrigger,
      GCInputButtonA,
      GCInputButtonB,
    ]
    let controller = GCVirtualController(configuration: configuration)
    return controller
  }
#endif

  private func deinitialize() {
    self.del = nil
    self.renderer = nil
    SDL_Metal_DestroyView(view)
    SDL_DestroyWindow(window)
    SDL_Quit()
  }

  private func beginHandleEvents() {
    Keyboard.instance.newFrame()
    GameController.instance.newFrame()
    Mouse.instance.newFrame(window!)
  }

  private func handleEvent(_ event: SDL_Event) -> ApplicationExecutionState {
    switch SDL_EventType(event.type) {
    case SDL_EVENT_QUIT:
      return .exitSuccess

    case SDL_EVENT_KEY_DOWN:
      switch event.key.key {
      case SDLK_ESCAPE:
        return .exitSuccess
      default:
        Keyboard.instance.keyDownEvent(scan: event.key.scancode, repeat: event.key.repeat != 0)
      }
      return .running

    case SDL_EVENT_KEY_UP:
      Keyboard.instance.keyUpEvent(scan: event.key.scancode)
      return .running

    case SDL_EVENT_GAMEPAD_ADDED:
      if SDL_IsGamepad(event.gdevice.which) {
        GameController.instance.connectedEvent(id: event.gdevice.which)
      }
      return .running
    case SDL_EVENT_GAMEPAD_REMOVED:
      GameController.instance.removedEvent(id: event.gdevice.which)
      return .running
    case SDL_EVENT_GAMEPAD_AXIS_MOTION:
      GameController.instance.axisEvent(id: event.gaxis.which,
        axis: SDL_GamepadAxis(Int32(event.gaxis.axis)), value: event.gaxis.value)
      return .running
    case SDL_EVENT_GAMEPAD_BUTTON_DOWN, SDL_EVENT_GAMEPAD_BUTTON_UP:
      GameController.instance.buttonEvent(id: event.gbutton.which,
        btn: SDL_GamepadButton(Int32(event.gbutton.button)), state: event.gbutton.state)
      return .running

    case SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
      Mouse.instance.buttonEvent(
        btn: UInt32(event.button.button),
        state: event.button.state)
      return .running
    case SDL_EVENT_MOUSE_MOTION:
      Mouse.instance.motionEvent(
        absolute: SIMD2(event.motion.x, event.motion.y),
        relative: SIMD2(event.motion.xrel, event.motion.yrel))
      return .running

    case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
      let backBufferSize = Size(Int(event.window.data1), Int(event.window.data2))
      self.renderer!.resize(size: backBufferSize)
      self.del.resize(backBufferSize)
      return .running

    default:
      return .running
    }
  }

  private func showVirtualGameController(_ shown: Bool) {
#if os(iOS)
    guard let onScreenVirtualController = self.onScreenVirtualController else {
      return
    }

    if shown {
      if !onScreenVirtualControllerShown {
        let semaphore = DispatchSemaphore(value: 1)
        DispatchQueue.global().async {
          Task.detached {
            try? await onScreenVirtualController.connect()
            semaphore.signal()
          }
        }
        semaphore.wait()
        onScreenVirtualControllerShown = true
      }
    } else {
      if onScreenVirtualControllerShown {
        onScreenVirtualController.disconnect()
        onScreenVirtualControllerShown = false
      }
    }
#endif
  }

  private func update() -> ApplicationExecutionState {
    let deltaTime = getDeltaTime()
    time += deltaTime
    let gameTime = GameTime(total: time, delta: deltaTime)

    del.update(gameTime)

    do {
      try renderer!.newFrame {
        del.draw($0, gameTime)
      }
    } catch RendererError.drawFailure(let message) {
      printErr("Renderer draw error: \(message)")
      return .exitFailure
    } catch {
      printErr("Renderer draw error: unexpected error")
      return .exitFailure
    }

    return .running
  }

  private func getDeltaTime() -> Duration {
    let counter = SDL_GetPerformanceCounter()
    defer {
      lastCounter = counter
    }
    let difference = Double(counter &- lastCounter)
    let divisor = Double(SDL_GetPerformanceFrequency())
    return Duration.seconds(difference / divisor)
  }

  func run() -> Int32 {
    var res = initialize()

    quit: while res == .running {
      beginHandleEvents()
      var event = SDL_Event()
      while SDL_PollEvent(&event) {
        res = handleEvent(event)
        if res != .running {
          break quit
        }
      }
      res = update()
    }

    return res == .exitSuccess ? 0 : 1
  }
}

public struct ApplicationConfiguration {
  public struct Flags: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    static let resizable = Flags(rawValue: 1 << 0)
    static let highDPI = Flags(rawValue: 1 << 1)
    static let borderless = Flags(rawValue: 1 << 2)
    static let fullscreen = Flags(rawValue: 1 << 3)
    static let onScreenVirtualController = Flags(rawValue: 1 << 4)
  }

  public enum VSyncMode: Equatable {
    case off
    case on(interval: UInt)
    case adaptive
  }

  let frame: Size<Int32>
  let title: String
  let flags: Flags
  let vsyncMode: VSyncMode

  public init(frame: Size<Int32>, title: String, flags: Flags, vsyncMode: VSyncMode) {
    self.frame = frame
    self.title = title
    self.flags = flags
    self.vsyncMode = vsyncMode
  }
}

fileprivate enum ApplicationExecutionState {
  case exitFailure
  case exitSuccess
  case running
}

func printErr(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  var stderr = FileHandle.standardError
  print(items, separator: separator, terminator: terminator, to: &stderr)
}

extension FileHandle: TextOutputStream {
  public func write(_ string: String) {
    self.write(Data(string.utf8))
  }
}
