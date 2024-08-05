import Foundation
import SDL3
import QuartzCore.CAMetalLayer

public class Application {
  private let cfg: ApplicationConfiguration

  private var window: OpaquePointer? = nil
  private var view: SDL_MetalView? = nil
  private var renderer: Renderer? = nil
  private var lastCounter: UInt64 = 0

  private var stderr = FileHandle.standardError

  public init(configuration: ApplicationConfiguration) {
    self.cfg = configuration
  }

  private func initialize() -> ApplicationExecutionState {
    guard SDL_Init(SDL_INIT_VIDEO) >= 0 else {
      print("SDL_Init() error: \(String(cString: SDL_GetError()))", to: &stderr)
      return .exitFailure
    }

    // Create SDL window
    var windowFlags = SDL_WindowFlags(0)
    if (cfg.flags.contains(.resizable)) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_RESIZABLE)
    }
    if (cfg.flags.contains(.highDPI)) {
      windowFlags |= SDL_WindowFlags(SDL_WINDOW_HIGH_PIXEL_DENSITY)
    }
    window = SDL_CreateWindow(cfg.title, cfg.width, cfg.height, windowFlags)
    guard window != nil else {
      print("SDL_CreateWindow() error: \(String(cString: SDL_GetError()))", to: &stderr)
      return .exitFailure
    }

    // Create Metal renderer
    view = SDL_Metal_CreateView(window)
    do {
      let layer = unsafeBitCast(SDL_Metal_GetLayer(view), to: CAMetalLayer.self)
      self.renderer = try Renderer(layer: layer)
    } catch RendererError.initFailure(let message) {
      print("Renderer init error: \(message)", to: &stderr)
      return .exitFailure
    } catch {
      print("Renderer init error: unexpected error", to: &stderr)
    }

    // Get window metrics
    var backBufferWidth: Int32 = 0, backBufferHeight: Int32 = 0
    guard SDL_GetWindowSizeInPixels(window, &backBufferWidth, &backBufferHeight) >= 0 else {
      print("SDL_GetWindowSizeInPixels() error: \(String(cString: SDL_GetError()))", to: &stderr)
      return .exitFailure
    }
    renderer!.resize(size: SIMD2<Int>(Int(backBufferWidth), Int(backBufferHeight)))

    lastCounter = SDL_GetPerformanceCounter()
    return .running
  }

  private func deinitialize() {
    renderer = nil
    SDL_Metal_DestroyView(view)
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

    case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
      let backBufferSize = SIMD2(Int(event.window.data1), Int(event.window.data2))
      renderer!.resize(size: backBufferSize)
      return .running

    default:
      return .running
    }
  }

  private func update(_ deltaTime: Double) -> ApplicationExecutionState {
    do {
      try renderer!.paint()
    } catch RendererError.drawFailure(let message) {
      print("Renderer draw error: \(message)", to: &stderr)
    } catch {
      print("Renderer draw error: unexpected error", to: &stderr)
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

extension FileHandle: TextOutputStream {
  public func write(_ string: String) {
    self.write(Data(string.utf8))
  }
}
