import simd

struct Box {
  var geometry: AABB
  var color: Color<Float16> = .white
}

struct Instance {
  let position: SIMD3<Float>
  let scale: SIMD3<Float>
  let rotation: simd_quatf
  let color: Color<Float16>

  init(
    position: SIMD3<Float> = .zero,
    scale: SIMD3<Float> = .one,
    rotation: simd_quatf = .identity,
    color: Color<Float16> = .white
  ) {
    self.position = position
    self.scale = scale
    self.rotation = rotation
    self.color = color
  }
}

let boxes: [Box] = [
  Box(geometry: .fromUnitCube(
    position: .init( 0,  -1,  0) * 2,
    scale:    .init(10, 0.1, 10) * 2)),
  Box(geometry: .fromUnitCube(
    position: .init(-2.5, 0, -3) * 2,
    scale:    .init(repeating: 2)),
    color:    .init(rgb888: 0xFF80BF).linear),
  Box(geometry: .fromUnitCube(
    position: .init(-2.5, -0.5, -5) * 2,
    scale:    .init(repeating: 2)),
    color:    .init(rgb888: 0xBFFFFF).linear)
]

class Game: GameDelegate {
  private var fpsCalculator = FPSCalculator()
  var camera = Camera(fov: 60, size: .one, range: 0.06...50)
  var player = Player()
  var projection: matrix_float4x4 = .identity

  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    let deltaTime = min(Float(time.delta.asFloat), 1.0 / 15)

    player.update(deltaTime: deltaTime, boxes: boxes)
    camera.position = player.position
    camera.rotation =
      simd_quatf(angle: player.rotation.y, axis: .init(1, 0, 0)) *
      simd_quatf(angle: player.rotation.x, axis: .init(0, 1, 0))
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let totalTime = Float(time.total.asFloat)
    let cubeSpeedMul: Float = 0.1

    var instances: [Instance] = boxes.map {
      Instance(
        position: $0.geometry.center,
        scale:    $0.geometry.size * 0.5,
        color:    $0.color)
    }
    instances.append(
      Instance(
        position: .init(0, sin(totalTime * 1.5 * cubeSpeedMul) * 0.5, -2) * 2,
        scale:    .init(repeating: 0.5),
        rotation: .init(angle: totalTime * 3.0 * cubeSpeedMul, axis: .init(0, 1, 0)),
        color:    .init(r: 0.5, g: 0.5, b: 1).linear))
    renderer.batch(instances: instances, camera: self.camera)
  }

  func resize(_ size: Size<Int>) {
    self.camera.setSize(size)
  }
}
