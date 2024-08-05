import Foundation
import SDL3

public class Application {
  private let cfg: ApplicationConfiguration

  private var window: OpaquePointer? = nil
  private var lastCounter: UInt64 = 0

  public init(configuration: ApplicationConfiguration) {
    self.cfg = configuration
  }

  private func initialize() -> ApplicationExecutionState {
    guard SDL_Init(SDL_INIT_VIDEO) >= 0 else {
      print("SDL_Init() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    var windowFlags = SDL_WindowFlags(SDL_WINDOW_HIGH_PIXEL_DENSITY)
    if (cfg.flags.contains(.resizable)) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_RESIZABLE)
    }
    window = SDL_CreateWindow(cfg.title, cfg.width, cfg.height, windowFlags)
    guard window != nil else {
      print("SDL_CreateWindow() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    lastCounter = SDL_GetPerformanceCounter()
    return .running
  }

  private func deinitialize() {
    SDL_DestroyWindow(window)
    SDL_Quit()
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

    default:
      return .running
    }
  }

  private func update(_ deltaTime: Double) -> ApplicationExecutionState {
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
  }

  public enum VSyncMode {
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
