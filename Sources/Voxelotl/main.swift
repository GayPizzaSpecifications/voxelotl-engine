import Foundation

Thread.current.qualityOfService = .userInteractive

let app = Application(
  delegate: Game(),
  configuration: ApplicationConfiguration(
  frame: Size(1280, 720),
  title: "Voxelotl Demo",
  flags: [ .resizable, .highDPI ],
  vsyncMode: .on(interval: 1)))

exit(app.run())
