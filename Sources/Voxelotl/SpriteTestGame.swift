import Foundation
import simd

internal class SpriteTestGame: GameDelegate {
  private var spriteBatch: SpriteBatch!
  private var player = TestPlayer(position: .one * 10)
  private var texture: RendererTexture2D!
  private var wireShark: RendererTexture2D!

  private static let levelWidth = 40, levelHeight = 23
  private var level: [UInt8]

  init() {
    self.level = .init(repeating: 0, count: Self.levelWidth * Self.levelHeight)
    for i in 0..<Self.levelWidth { self.level[i + (Self.levelHeight - 1) * Self.levelWidth] = 1 }
    for i in 0..<Self.levelWidth { self.level[i + (Self.levelHeight - 2) * Self.levelWidth] = 1 }
    for i in 17...20 { self.level[10 + (i) * Self.levelWidth] = 1 }
    for i in 17...20 { self.level[14 + (i) * Self.levelWidth] = 1 }
    for i in 11...13 { self.level[i + (17) * Self.levelWidth] = 1 }
  }

  func create(_ renderer: Renderer) {
    self.spriteBatch = renderer.createSpriteBatch()
    // Uncomment to squeesh
    //self.spriteBatch.viewport = .init(renderer.frame)
    renderer.clearColor = .init(hue: 301.2, saturation: 0.357, value: 0.488).linear // .magenta.mix(.white, 0.4).mix(.black, 0.8)
    self.texture = renderer.loadTexture(resourcePath: "test.png")
    self.wireShark = renderer.loadTexture(resourcePath: "wireshark.png")
  }

  func update(_ time: GameTime) {
    if let pad = GameController.current?.state {
      self.player.position += pad.leftStick.radialDeadzone(min: 0.1, max: 1) * 1000 * Float(time.delta)
    }
    self.player.rotate += Float(time.delta)
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    self.spriteBatch.begin(blendMode: .premultiplied)

    // Draw background
    self.spriteBatch.draw(self.texture,
      source: .init(
        origin: .init(scalar: fmod(player.rotate, 32)),
        size:   (spriteBatch.viewport?.size ?? Size<Float>(renderer.frame.size)) * 0.01),
      destination: nil,
      color: .init(renderer.clearColor).setAlpha(0.7))

    // Draw level
    let scale: Float = 64
    for y in 0..<Self.levelHeight {
      for x in 0..<Self.levelWidth {
        if level[x + Self.levelWidth * y] == 1 {
          self.spriteBatch.draw(self.texture, destination: .init(origin: Point(Point(x, y)) * scale, size: .init(scalar: scale)))
        }
      }
    }

    // Draw wireshark (controllable)
    self.spriteBatch.draw(self.wireShark,
      position: player.position,
      scale: .init(sin(player.rotate * 5), cos(player.rotate * 3)),
      angle: player.rotate, origin: .init(250, 275))

    // Sliding door test
    self.spriteBatch.draw(self.texture, source: .init(
        origin: .init(4 + cos(player.rotate / 1.2) * 4, 0),
        size:   .init(4 + cos(player.rotate / 1.3) * 4, 16)),
      transform: .init(
        .init( 24,    0, 0),
        .init(  0,   12, 0),
        .init(704, 1152, 1)), color: .red.mix(.white, 0.3))

    // Draw mouse cursor
    var mpos = Mouse.position
    if self.spriteBatch.viewport != nil {
      mpos /= SIMD2(Size<Float>(renderer.frame.size))
      mpos *= SIMD2(self.spriteBatch.viewport!.size)
    }
    let inter = 0.5 + sin(player.rotate * 10) * 0.5
    let color = Color<Float>.green.mix(.white, 0.3)
    let mesh = Mesh<VertexPosition2DTexcoordColor, UInt16>.init(vertices: [
      .init(position: mpos, texCoord: .zero, color: .one),
      .init(position: mpos + .init(50, 0) + .init(-50,  50) * inter, texCoord: .zero, color: SIMD4(color)),
      .init(position: mpos + .init(0, 50) + .init( 50, -50) * inter, texCoord: .zero, color: SIMD4(color)),
      .init(position: mpos + .init(80, 80), texCoord: .zero, color: .zero)
    ], indices: [ 0, 1, 2,  1, 2, 3 ])
    if Mouse.down(.left) {
      self.spriteBatch.draw(self.texture, mesh: mesh)
    } else {
      self.spriteBatch.draw(self.texture, vertices: mesh.vertices[..<3])
    }
    self.spriteBatch.end()
  }
}

fileprivate struct TestPlayer {
  var position: SIMD2<Float>
  var rotate: Float = 0
}

fileprivate extension Color {
  func setAlpha(_ newAlpha: T) -> Self {
    return .init(r: r, g: g, b: b, a: newAlpha)
  }
}
