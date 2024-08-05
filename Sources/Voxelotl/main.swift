import Darwin

let app = Application(
  configuration: ApplicationConfiguration(
  width: 1280,
  height: 720,
  title: "Voxelotl Demo",
  flags: .resizable,
  vsyncMode: .on(interval: 1)))

exit(app.run())
