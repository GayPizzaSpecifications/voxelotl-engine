import simd
import Foundation

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
  var chunk = Chunk(position: .zero)

  init() {
    player.position = SIMD3(0.5, Float(Chunk.chunkSize) + 0.5, 0.5)
    player.rotation = .init(.pi, 0)

    let colors: [Color<UInt8>] = [
      .white,
      .red, .blue, .green,
      .magenta, .yellow, .cyan
    ]
    chunk.fill(allBy: {
      if (arc4random() & 0x1) == 0x1 {
        .solid(colors[Int(arc4random_uniform(UInt32(colors.count)))])
      } else {
        .air
      }
    })
  }

  func fixedUpdate(_ time: GameTime) {
    
  }

  func update(_ time: GameTime) {
    fpsCalculator.frame(deltaTime: time.delta) { fps in
      print("FPS: \(fps)")
    }

    let deltaTime = min(Float(time.delta.asFloat), 1.0 / 15)

    if let pad = GameController.current?.state {
      // Delete block underneath player
      if pad.pressed(.south) {
        chunk.setBlock(at: SIMD3(player.position + .down * 0.2), type: .air)
      }
      // Player reset
      if pad.pressed(.back) {
        player.position = .init(repeating: 0.5) + .init(0, Float(Chunk.chunkSize), 0)
        player.velocity = .zero
        player.rotation = .init(.pi, 0)
      }
    }

    player.update(deltaTime: deltaTime, chunk: chunk)
    camera.position = player.eyePosition
    camera.rotation = player.eyeRotation
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    let totalTime = Float(time.total.asFloat)
    let cubeSpeedMul: Float = 0.1

    let instances = chunk.compactMap { block, position in
      if case let .solid(color) = block.type {
        Instance(
          position: SIMD3<Float>(position) + 0.5,
          scale:    .init(repeating: 0.5),
          color:    Color<Float16>(color).linear)
      } else { nil }
    }
    renderer.batch(instances: instances, camera: self.camera)
  }

  func resize(_ size: Size<Int>) {
    self.camera.setSize(size)
  }
}
