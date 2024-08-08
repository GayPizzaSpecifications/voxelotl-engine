import Foundation
import SDL3
import QuartzCore.CAMetalLayer

public class Application {
  private let cfg: ApplicationConfiguration

  private var window: OpaquePointer? = nil
  private var view: SDL_MetalView? = nil
  private var renderer: Renderer? = nil
  private var lastCounter: UInt64 = 0
  private var fpsCalculator = FPSCalculator()


  public init(configuration: ApplicationConfiguration) {
    self.cfg = configuration
  }

  private func initialize() -> ApplicationExecutionState {
    guard SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD) >= 0 else {
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
    window = SDL_CreateWindow(cfg.title, cfg.width, cfg.height, windowFlags)
    guard window != nil else {
      printErr("SDL_CreateWindow() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    // Get window metrics
    var backBufferWidth: Int32 = 0, backBufferHeight: Int32 = 0
    guard SDL_GetWindowSizeInPixels(window, &backBufferWidth, &backBufferHeight) >= 0 else {
      printErr("SDL_GetWindowSizeInPixels() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    // Create Metal renderer
    view = SDL_Metal_CreateView(window)
    do {
      let layer = unsafeBitCast(SDL_Metal_GetLayer(view), to: CAMetalLayer.self)
      layer.displaySyncEnabled = cfg.vsyncMode == .off ? false : true
      self.renderer = try Renderer(layer: layer, size: SIMD2<Int>(Int(backBufferWidth), Int(backBufferHeight)))
    } catch RendererError.initFailure(let message) {
      printErr("Renderer init error: \(message)")
      return .exitFailure
    } catch {
      printErr("Renderer init error: unexpected error")
    }

    lastCounter = SDL_GetPerformanceCounter()
    return .running
  }

  private func deinitialize() {
    renderer = nil
    SDL_Metal_DestroyView(view)
    SDL_DestroyWindow(window)
    SDL_Quit()
  }

  private func beginHandleEvents() {
    GameController.instance.newFrame()
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
        break
      }
      return .running

    case SDL_EVENT_GAMEPAD_ADDED:
      if SDL_IsGamepad(event.gdevice.which) != SDL_FALSE {
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

    case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
      let backBufferSize = SIMD2(Int(event.window.data1), Int(event.window.data2))
      renderer!.resize(size: backBufferSize)
      return .running

    default:
      return .running
    }
  }

  private func update(_ deltaTime: Double) -> ApplicationExecutionState {
    fpsCalculator.frame(deltaTime: deltaTime) { fps in
      print("FPS: \(fps)")
    }

    do {
      try renderer!.paint()
    } catch RendererError.drawFailure(let message) {
      printErr("Renderer draw error: \(message)")
      return .exitFailure
    } catch {
      printErr("Renderer draw error: unexpected error")
      return .exitFailure
    }

    return .running
  }

  private func getDeltaTime() -> Double {
    let counter = SDL_GetPerformanceCounter()
    let divisor = 1.0 / Double(SDL_GetPerformanceFrequency())
    defer { lastCounter = counter }
    return Double(counter &- lastCounter) * divisor
  }

  func run() -> Int32 {
    var res = initialize()

    quit: while res == .running {
      beginHandleEvents()
      var event = SDL_Event()
      while SDL_PollEvent(&event) > 0 {
        res = handleEvent(event)
        if res != .running {
          break quit
        }
      }

      let deltaTime = getDeltaTime()
      res = update(deltaTime)
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
  }

  public enum VSyncMode: Equatable {
    case off
    case on(interval: UInt)
    case adaptive
  }

  let width: Int32
  let height: Int32
  let title: String
  let flags: Flags
  let vsyncMode: VSyncMode

  public init(width: Int32, height: Int32, title: String, flags: Flags, vsyncMode: VSyncMode) {
    self.width = width
    self.height = height
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
