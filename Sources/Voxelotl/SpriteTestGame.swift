import Foundation
import simd

internal class SpriteTestGame: GameDelegate {
  private var spriteBatch: SpriteBatch!
  private var player = TestPlayer(position: .one * 10)
  private var texture: RendererTexture2D!
  private var wireShark: RendererTexture2D!
  private var level = TestLevel()

  func create(_ renderer: Renderer) {
    self.spriteBatch = renderer.createSpriteBatch()
    renderer.clearColor = .init(hue: 301.2, saturation: 0.357, value: 0.488).linear // .magenta.mix(.white, 0.4).mix(.black, 0.8)
    self.texture = renderer.loadTexture(resourcePath: "test.png")
    self.wireShark = renderer.loadTexture(resourcePath: "wireshark.png")
  }

  func update(_ time: GameTime) {
    let dt = Float(time.delta)

    self.player.velocity.x = 0
    if let pad = GameController.current?.state {
      self.player.velocity.x = pad.leftStick.x.axisDeadzone(0.1, 0.8) * 660
      if pad.pressed(.start) {
        self.player.position = .one * 10
      }
      if pad.pressed(.east) && player.onGround {
        self.player.velocity.y = -1000
      } else if pad.released(.east) && self.player.velocity.y < -550 {
        self.player.velocity.y = -550
      }
    }
    if Keyboard.down(.left) {
      self.player.velocity.x = -660
    } else if Keyboard.down(.right) {
      self.player.velocity.x = 660
    }
    if Keyboard.pressed(.up) && player.onGround {
      self.player.velocity.y = -1000
    } else if Keyboard.released(.up) && self.player.velocity.y < -550 {
      self.player.velocity.y = -550
    }

    if Mouse.down(.left) {
      self.level.set(SIMD2(Mouse.position / TestLevel.cellScale, rounding: .down), true)
    } else if Mouse.down(.right) {
      self.level.set(SIMD2(Mouse.position / TestLevel.cellScale, rounding: .down), false)
    }

    self.player.update(deltaTime: dt, level: self.level)
  }

  func draw(_ renderer: Renderer, _ time: GameTime) {
    self.spriteBatch.begin(blendMode: .premultiplied)

    // Draw background
    self.spriteBatch.draw(self.texture,
      source: .init(
        origin: .init(scalar: fmod(Float(time.total), 32)),
        size:   spriteBatch.viewport.size * 0.01),
      destination: nil,
      color: .init(renderer.clearColor).setAlpha(0.7))

    // Draw level
    let scale: Float = 64
    for y in 0..<TestLevel.levelHeight {
      for x in 0..<TestLevel.levelWidth {
        if self.level.get(.init(x, y)) {
          self.spriteBatch.draw(self.texture, destination: .init(origin: Point(Point(x, y)) * scale, size: .init(scalar: scale)))
        }
      }
    }

    // Draw wireshark
    var shorkFlip: Sprite.Flip = fmod(self.player.rotate, 0.25) < 0.125 ? .none : .horz
    if self.player.velocity.y > 0 {
      shorkFlip = self.player.velocity.x < 0 ? shorkFlip.counterClockwise : shorkFlip.clockwise
    }
    self.spriteBatch.draw(self.wireShark,
      position: self.player.position, scale: 0.2, origin: .init(250, 275 * 2), flip: shorkFlip)

    // Sliding door test
    let doorAngle = max(sin(player.rotate * 2.6) - 0.75, 0) * .pi
    self.spriteBatch.draw(self.texture, source: Rect<Float>(
        origin: .init(4 + cos(player.rotate / 1.2) * 4, 0),
        size:   .init(4 + cos(player.rotate / 1.3) * 4, 16)),
      position: .init(704 + 24, 1152 + 12), scale: .init(24, 12),
      angle: doorAngle, origin: SIMD2<Float>(repeating: 1),
      flip: .none, color: .red.mix(.white, 0.3))

    // Draw mouse cursor
    var mpos = Mouse.position
    if self.spriteBatch.viewport.size != Size<Float>(renderer.frame.size) {
      mpos /= SIMD2(Size<Float>(renderer.frame.size))
      mpos *= SIMD2(self.spriteBatch.viewport.size)
    }
    let inter = 0.5 + sin(Float(time.total) * 10) * 0.5
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

  func resize(_ size: Size<Int>) {
    self.spriteBatch.viewport.size = Size<Float>(size)
  }
}

fileprivate struct TestLevel {
  public static let levelWidth = 40, levelHeight = 23
  public static let cellScale: Float = 64

  private var data: [UInt8]

  init() {
    self.data = .init(repeating: 0, count: Self.levelWidth * Self.levelHeight)
    for i in 0..<Self.levelWidth { self.data[i + (Self.levelHeight - 1) * Self.levelWidth] = 1 }
    for i in 0..<Self.levelWidth { self.data[i + (Self.levelHeight - 2) * Self.levelWidth] = 1 }
    for i in 17...20 { self.data[10 + i * Self.levelWidth] = 1 }
    for i in 17...20 { self.data[14 + i * Self.levelWidth] = 1 }
    for i in 11...13 { self.data[i + 17 * Self.levelWidth] = 1 }
  }

  mutating func set(_ p: SIMD2<Int>, _ to: Bool) {
    if p.x >= 0 && p.y >= 0 && p.x < Self.levelWidth && p.y < Self.levelHeight {
      self.data[p.x + Self.levelWidth * p.y] = to ? 1 : 0
    }
  }

  func get(_ p: Point<Int>) -> Bool {
    if p.x < 0 || p.y < 0 || p.x >= Self.levelWidth || p.y >= Self.levelHeight {
      return false
    }
    return self.data[p.x + Self.levelWidth * p.y] == 1
  }

  func check(_ p: SIMD2<Float>) -> Bool {
    let p = SIMD2<Int>(p / TestLevel.cellScale, rounding: .down)
    return self.get(Point<Int>(p.x, p.y))
  }

  func check(_ rect: Extent<Float>) -> Bool {
    let p = Extent<Int>(floor(rect / Self.cellScale))
    return self.get(p.topLeft) || self.get(p.topRight) || self.get(p.bottomLeft) || self.get(p.bottomRight)
  }
}

fileprivate struct TestPlayer {
  static private let rect = Extent<Float>(left: -30, top: -63, right: 30, bottom: 0)

  var position: SIMD2<Float>
  var velocity: SIMD2<Float> = .zero
  var rotate: Float = 0

  private var _onGround = false
  var onGround: Bool { self._onGround }

  init(position: SIMD2<Float>) {
    self.position = position
  }

  mutating func update(deltaTime dt: Float, level: TestLevel) {
    self.velocity.y += 1500 * dt
    if abs(self.velocity.y) > 3000 {
      self.velocity.y = .init(signOf: self.velocity.y, magnitudeOf: 3000)
    }

    if self.velocity.x != 0 {
      self.position.x += self.velocity.x * dt
      if level.check(Self.rect + self.position) {
        let offset = self.velocity.x < 0 ? Self.rect.left : Self.rect.right
        self.position.x = round((self.position.x + offset) / TestLevel.cellScale) * TestLevel.cellScale - offset
        self.position.x -= .init(signOf: self.velocity.x, magnitudeOf: .ulpOfOne * 12000);
        self.velocity.x = 0
      }
    }
    if self.velocity.y != 0 {
      self.position.y += self.velocity.y * dt
      if level.check(Self.rect + (self.position)) {
        let offset = self.velocity.y < 0 ? Self.rect.top : Self.rect.bottom
        self.position.y = round((self.position.y + offset) / TestLevel.cellScale) * TestLevel.cellScale - offset
        self.position.y -= .init(signOf: self.velocity.y, magnitudeOf: .ulpOfOne * 12000);
        self.velocity.y = 0
      }
    }

    if self.velocity.x != 0 {
      self.rotate += abs(self.velocity.x) / 1000 * dt
    }

    self._onGround = level.check(Self.rect + self.position + .init(0, .ulpOfOne * 24000))
  }
}

fileprivate extension Color {
  func setAlpha(_ newAlpha: T) -> Self {
    return .init(r: r, g: g, b: b, a: newAlpha)
  }
}
