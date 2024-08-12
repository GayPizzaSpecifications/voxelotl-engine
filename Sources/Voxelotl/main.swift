import Darwin

var rect = Rect(origin: .init(0, 0), size: .init(32, 32))
rect.origin += Point(10, 10)

let app = Application(
  delegate: Game(),
  configuration: ApplicationConfiguration(
  width: 1280,
  height: 720,
  title: "Voxelotl Demo",
  flags: [ .resizable, .highDPI ],
  vsyncMode: .on(interval: 1)))

exit(app.run())
