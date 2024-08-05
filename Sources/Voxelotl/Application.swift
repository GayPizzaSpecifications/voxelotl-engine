import Foundation
import SDL3

class Application {
  private var window: OpaquePointer? = nil
  private var lastCounter: UInt64 = 0

  private static let windowWidth: Int32 = 1280
  private static let windowHeight: Int32 = 720

  private func initialize() -> ApplicationExecutionState {
    guard SDL_Init(SDL_INIT_VIDEO) >= 0 else {
      print("SDL_Init() error: \(String(cString: SDL_GetError()))")
      return .exitFailure
    }

    window = SDL_CreateWindow("Voxelotl",
      Self.windowWidth, Self.windowHeight,
      SDL_WindowFlags(SDL_WINDOW_RESIZABLE) | SDL_WindowFlags(SDL_WINDOW_HIGH_PIXEL_DENSITY))
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

fileprivate enum ApplicationExecutionState {
  case exitFailure
  case exitSuccess
  case running
}
