import simd

struct Instance {
  var position: SIMD3<Float> = .zero
  var scale: SIMD3<Float>    = .one
  var rotation: simd_quatf   = .identity
  var color: SIMD4<Float>    = .one
}

class Game: GameDelegate {

  private var fpsCalculator = FPSCalculator()
  var camera = Camera(fov: 60, size: .one, range: 0.03...25)
  var player = Player()
  var projection: matrix_float4x4 = .identity

  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    let deltaTime = Float(time.delta.asFloat)
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    player.update(deltaTime: deltaTime)
    camera.position = player.position
    camera.rotation =
      simd_quatf(angle: player.rotation.y, axis: .init(1, 0, 0)) *
      simd_quatf(angle: player.rotation.x, axis: .init(0, 1, 0))
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let totalTime = Float(time.total.asFloat)

    let instances: [Instance] = [
      Instance(
        position: .init(0, sin(totalTime * 1.5) * 0.5, -2),
        scale: .init(repeating: 0.25),
        rotation: .init(angle: totalTime * 3.0, axis: .init(0, 1, 0)),
        color: .init(0.5, 0.5, 1, 1)),
      Instance(position: .init(0, -1, 0), scale: .init(10, 0.1, 10)),
      Instance(position: .init(-2.5, 0, -3), color: .init(1, 0.5, 0.75, 1)),
      Instance(position: .init(-2.5, -0.5, -5), color: .init(0.75, 1, 1, 1))
    ]
    renderer.batch(instances: instances, camera: self.camera)
  }

  func resize(_ size: Size<Int>) {
    self.camera.setSize(size)
  }
}
