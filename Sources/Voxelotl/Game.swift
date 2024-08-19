import simd
import Foundation

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

class Game: GameDelegate {
  private var fpsCalculator = FPSCalculator()
  var camera = Camera(fov: 60, size: .one, range: 0.06...900)
  var player = Player()
  var projection: matrix_float4x4 = .identity
  
  var boxes: [Box] = []
  var chunk = Chunk(position: .zero)


  init() {
    player.position = SIMD3(0.5, Float(Chunk.chunkSize) + 0.5, 0.5)
    let options: [BlockType] = [
      .air,
      .solid(.blue),
      .air,
      .solid(.red),
      .air,
      .solid(.green),
      .air,
      .solid(.white),
      .air,
      .solid(.cyan),
      .air,
      .solid(.yellow),
      .air,
      .solid(.magenta),
      .air,
    ]
    chunk
      .fill(allBy: { options[Int(arc4random_uniform(UInt32(options.count)))] })
  }
  
  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    let deltaTime = min(Float(time.delta.asFloat), 1.0 / 15)

    if let pad = GameController.current?.state {
      if pad.pressed(.south) {
        chunk
          .setBlockInternally(at: SIMD3(player.position - SIMD3(0, 2, 0)), type: .air)
      }
    }
    boxes = []
    chunk.forEach { position, block in
      if block.type == .air {
        return
      }
      
      if case let .solid(color) = block.type {
        boxes
          .append(
            Box(
              geometry:
                  .fromUnitCube(position: SIMD3<Float>(position) + 0.5, scale: .init(repeating: 0.5)),
              color: color
            )
          )
      }
    }
    
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
        position: .init(0, sin(totalTime * 1.5 * cubeSpeedMul) * 0.5, 0) * 2,
        scale:    .init(repeating: 0.5),
        rotation: .init(angle: totalTime * 3.0 * cubeSpeedMul, axis: .init(0, 1, 0)),
        color:    .init(r: 0.5, g: 0.5, b: 1).linear))
    renderer.batch(instances: instances, camera: self.camera)
  }

  func resize(_ size: Size<Int>) {
    self.camera.setSize(size)
  }
}
