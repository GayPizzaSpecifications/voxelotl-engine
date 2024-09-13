import Foundation

@objc public class Program: NSObject {
  @objc public static func run() -> Int32 {
    Thread.current.qualityOfService = .userInteractive

    let app = Application(
      delegate: SpriteTestGame(),
      configuration: ApplicationConfiguration(
      frame: Size(1280, 720),
      title: "Voxelotl Demo",
      flags: [ .resizable, .highDPI ],
      vsyncMode: .on(interval: 1)))

    return app.run()
  }
}
