import Foundation

@objc public class Program: NSObject {
  @objc public static func run() -> Int32 {
    Thread.current.qualityOfService = .userInteractive

    var flags: ApplicationConfiguration.Flags = [ .resizable, .highDPI, .onScreenVirtualController ]
    if enableFullscreenWindow() {
      flags = flags.union(.fullscreen)
    }

    let app = Application(
      delegate: Game(),
      configuration: ApplicationConfiguration(
      frame: Size(1280, 720),
      title: "Voxelotl Demo",
      flags: flags,
      vsyncMode: .on(interval: 1)))

    return app.run()
  }

  static func enableFullscreenWindow() -> Bool {
    return Program.isFrontAndCenterGamingDevice()
  }

  static func isFrontAndCenterGamingDevice() -> Bool {
#if os(iOS)
    return !(ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp)
#elseif os(tvOS)
    return true
#else
    return false
#endif
  }
}
