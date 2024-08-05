import Darwin

let app = Application(
  configuration: ApplicationConfiguration(
  width: 1280,
  height: 720,
  title: "Voxelotl Demo",
  flags: [ .resizable, .highDPI ],
  vsyncMode: .off))

exit(app.run())
