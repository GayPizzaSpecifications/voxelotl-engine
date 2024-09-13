import simd

public typealias Affine2D = simd_float2x2

public struct SpriteBatch {
  public typealias VertexType = VertexPosition2DTexcoordColor
  public typealias IndexType = UInt16

  private weak var _renderer: Renderer!
  private var _active = ActiveState.inactive
  private var _blendMode = BlendMode.none

  private var _mesh: RendererDynamicMesh<VertexType, IndexType>
  private var _instances = [SpriteInstance]()

  public var viewport: Rect<Float>? = nil

  internal init(_ renderer: Renderer) {
    self._renderer = renderer
    self._mesh = renderer.createDynamicMesh(vertexCapacity: 4096, indexCapacity: 4096)!
  }

  //MARK: - Public API

  //TODO: Sort
  //FIXME: currently will misbehave if begin is called more than once per frame
  public mutating func begin(blendMode: BlendMode = .normal) {
    assert(self._active == .inactive, "call to SpriteBatch.begin without first calling end")
    self._blendMode = blendMode
    self._active = .begin
    self._mesh.clear()
  }

  public mutating func end() {
    assert(self._active != .inactive, "call to SpriteBatch.end without first calling begin")
    if !self._instances.isEmpty {
      self.flush()
    }
    self._active = .inactive
  }

  public mutating func draw(_ sprite: Sprite) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    fatalError("TODO")
  }

  public mutating func draw(_ texture: RendererTexture2D, position: SIMD2<Float>) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, position: position, size: Size<Float>(texture.size))
  }

  public mutating func draw(_ texture: RendererTexture2D, position: SIMD2<Float>,
    scale: SIMD2<Float>,
    angle: Float = 0.0, origin: SIMD2<Float> = .zero,
    flip: Sprite.Flip = .none,
    color: Color<Float> = .white
    //depth: Int = 0
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let size = Size<Float>(texture.size)
    let color = color.linear
    if angle != 0 {
      let bias = SIMD2(origin) / SIMD2(size)
      self.drawQuad(texture, position: position, angle: angle, size: size * scale, offset: bias, color: color)
    } else {
      self.drawQuad(texture, position: position - origin, size: size * scale, color: color)
    }
  }

  public mutating func draw(_ texture: RendererTexture2D, position: SIMD2<Float>,
    scale: Float = 1.0,
    angle: Float = 0.0, origin: SIMD2<Float> = .zero,
    flip: Sprite.Flip = .none,
    color: Color<Float> = .white
    //depth: Int = 0
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let size = Size<Float>(texture.size)
    let color = color.linear
    if angle != 0 {
      let bias = SIMD2(origin) / SIMD2(size)
      self.drawQuad(texture, position: position, angle: angle, size: size * Size(scalar: scale), offset: bias, color: color)
    } else {
      self.drawQuad(texture, position: position - origin, size: size * scale, color: color)
    }
  }

  public mutating func draw(_ texture: RendererTexture2D, destination: Rect<Float>?) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let rect = destination ?? self.viewport ?? Rect<Float>(self._renderer.frame)
    self.drawQuad(texture,
      p00: SIMD2(rect.left,  rect.up),   p10: SIMD2(rect.right, rect.up),
      p01: SIMD2(rect.left,  rect.down), p11: SIMD2(rect.right, rect.down))
  }

  public mutating func draw(_ texture: RendererTexture2D, transform: simd_float3x3) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let w = Float(texture.size.w), h = Float(texture.size.h)
    self.drawQuad(texture,
      p00: (transform * .init(0, 0, 1)).xy,
      p10: (transform * .init(w, 0, 1)).xy,
      p01: (transform * .init(0, h, 1)).xy,
      p11: (transform * .init(w, h, 1)).xy)
  }

  public mutating func draw(_ texture: RendererTexture2D, transform: simd_float3x3,
    flip: Sprite.Flip = .none,
    color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let w = Float(texture.size.w), h = Float(texture.size.h)
    self.drawQuad(texture,
      p00: (transform * .init(0, 0, 1)).xy,
      p10: (transform * .init(w, 0, 1)).xy,
      p01: (transform * .init(0, h, 1)).xy,
      p11: (transform * .init(w, h, 1)).xy,
      flip: flip, color: color.linear)
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let size = source.size
    self.drawQuad(texture, source,
      p00: .init(position.x, position.y),
      p10: .init(position.x + size.w, position.y),
      p01: .init(position.x, position.y + size.h),
      p11: position + SIMD2(size))
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>,
    scale: SIMD2<Float>, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let size = source.size * scale
    self.drawQuad(texture, source,
      p00: .init(position.x, position.y),
      p10: .init(position.x + size.w, position.y),
      p01: .init(position.x, position.y + size.h),
      p11: position + SIMD2(size),
      color: color.linear)
  }
  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>,
    scale: Float = 1.0, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let size = source.size * scale
    self.drawQuad(texture, source,
      p00: .init(position.x, position.y),
      p10: .init(position.x + size.w, position.y),
      p01: .init(position.x, position.y + size.h),
      p11: position + SIMD2(size),
      color: color.linear)
  }

  //TODO: Everything
  //public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>, scale: SIMD2<Float>, angle: Float = 0.0, origin: Point<Int> = .zero, flip: Sprite.Flip = .none, color: Color<Float> = .white, depth: Int = 0) {
  //public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>, scale: Float = 1.0, angle: Float = 0.0, origin: Point<Int> = .zero, flip: Sprite.Flip = .none, color: Color<Float> = .white, depth: Int = 0) {

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, destination: Rect<Float>?) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let dst = destination ?? self.viewport ?? Rect<Float>(self._renderer.frame)
    self.drawQuad(texture, source,
      p00: SIMD2(dst.left,  dst.up),   p10: SIMD2(dst.right, dst.up),
      p01: SIMD2(dst.left,  dst.down), p11: SIMD2(dst.right, dst.down))
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, destination: Rect<Float>?,
    color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let dst = destination ?? self.viewport ?? Rect<Float>(self._renderer.frame)
    self.drawQuad(texture, source,
      p00: SIMD2(dst.left,  dst.up),   p10: SIMD2(dst.right, dst.up),
      p01: SIMD2(dst.left,  dst.down), p11: SIMD2(dst.right, dst.down),
      color: color.linear)
  }

  //TODO: Destination with rotation

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, transform: simd_float3x3) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let w = source.size.w, h = source.size.h
    self.drawQuad(texture, source,
      p00: (transform * .init(0, 0, 1)).xy,
      p10: (transform * .init(w, 0, 1)).xy,
      p01: (transform * .init(0, h, 1)).xy,
      p11: (transform * .init(w, h, 1)).xy)
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, transform: simd_float3x3,
    flip: Sprite.Flip = .none, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let w = source.size.w, h = source.size.h
    self.drawQuad(texture, source,
      p00: (transform * .init(0, 0, 1)).xy,
      p10: (transform * .init(w, 0, 1)).xy,
      p01: (transform * .init(0, h, 1)).xy,
      p11: (transform * .init(w, h, 1)).xy,
      color: color.linear)
  }

  public mutating func draw(_ texture: RendererTexture2D, vertices: [VertexType]) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let base = self._mesh.vertexCount
    self._mesh.insert(vertices: vertices)
    self._mesh.insert(indices: (0..<vertices.count).map(IndexType.init), baseVertex: base)
    self._instances.append(.init(texture: texture, size: UInt16(vertices.count)))
  }

  public mutating func draw(_ texture: RendererTexture2D, vertices: ArraySlice<VertexType>) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let base = self._mesh.vertexCount
    self._mesh.insert(vertices: vertices)
    self._mesh.insert(indices: (0..<vertices.count).map(IndexType.init), baseVertex: base)
    self._instances.append(.init(texture: texture, size: UInt16(vertices.count)))
  }

  public mutating func draw(_ texture: RendererTexture2D, mesh: Mesh<VertexType, IndexType>) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let base = self._mesh.vertexCount
    self._mesh.insert(vertices: mesh.vertices)
    self._mesh.insert(indices: mesh.indices, baseVertex: base)
    self._instances.append(.init(texture: texture, size: UInt16(mesh.indices.count)))
  }

  //MARK: - Private implementation

  private mutating func flush() {
    assert(self._instances.count > 0)

    if self._active == .begin {
      self._renderer.setupBatch(blendMode: self._blendMode, frame: self.viewport ?? .init(self._renderer.frame))
      self._active = .active
    }

    var base = 0, offset = 0
    var prevTexture: RendererTexture2D! = nil
    for instance in self._instances {
      if prevTexture != nil && prevTexture != instance.texture {
        self._renderer.submit(mesh: self._mesh, texture: prevTexture, offset: base, count: offset - base)
        base = offset
      }
      offset += Int(instance.size)
      prevTexture = instance.texture
    }
    self._renderer.submit(mesh: self._mesh, texture: prevTexture, offset: base, count: offset - base)

    self._instances.removeAll(keepingCapacity: true)
  }

  private mutating func drawQuad(_ texture: RendererTexture2D,
    position: SIMD2<Float>, size: Size<Float>, color: Color<Float> = .white
  ) {
    self.drawQuad(texture,
      p00: position,
      p10: .init(position.x + size.w, position.y),
      p01: .init(position.x, position.y + size.h),
      p11: .init(position.x + size.w, position.y + size.h), color: color)
  }

  private mutating func drawQuad(_ texture: RendererTexture2D,
    position: SIMD2<Float>, angle: Float, size: Size<Float>, offset bias: SIMD2<Float>, color: Color<Float> = .white
  ) {
    let (tc, ts) = (cos(angle), sin(angle))
    let rotate = matrix_float2x2(
      .init( tc, ts),
      .init(-ts, tc))
    let right = SIMD2<Float>(size.w, 0) * rotate
    let down  = SIMD2<Float>(0, size.h) * rotate
    self.drawQuad(texture,
      p00: position - right *       bias.x - down *      bias.y,
      p10: position + right * (1 - bias.x) - down *      bias.y,
      p01: position - right *       bias.x + down * (1 - bias.y),
      p11: position + right * (1 - bias.x) + down * (1 - bias.y), color: color)
  }

  private mutating func drawQuad(_ texture: RendererTexture2D,
    p00: SIMD2<Float>, p10: SIMD2<Float>, p01: SIMD2<Float>, p11: SIMD2<Float>,
    flip: Sprite.Flip, color: Color<Float> = .white
  ) {
    let flipX = flip.contains(.x), flipY = flip.contains(.y)
    self.drawQuad(texture, p00: p00, p10: p10, p01: p01, p11: p11,
      t00: .init(flipX ? 1 : 0, flipY ? 0 : 1),
      t10: .init(flipX ? 0 : 1, flipY ? 0 : 1),
      t01: .init(flipX ? 1 : 0, flipY ? 1 : 0),
      t11: .init(flipX ? 0 : 1, flipY ? 1 : 0),
      color: color)
  }

  private mutating func drawQuad(_ texture: RendererTexture2D, _ source: Rect<Float>,
    p00: SIMD2<Float>, p10: SIMD2<Float>, p01: SIMD2<Float>, p11: SIMD2<Float>,
    color: Color<Float> = .white
  ) {
    let invSize = 1 / Size<Float>(texture.size)
    let st = Extent(source) * invSize
    self.drawQuad(texture, p00: p00, p10: p10, p01: p01, p11: p11,
      t00: SIMD2(st.left,  st.top),    t10: SIMD2(st.right, st.top),
      t01: SIMD2(st.left,  st.bottom), t11: SIMD2(st.right, st.bottom), color: color)
  }

  private mutating func drawQuad(_ texture: RendererTexture2D,
    p00: SIMD2<Float>, p10: SIMD2<Float>, p01: SIMD2<Float>, p11: SIMD2<Float>,
    t00: SIMD2<Float> = SIMD2(0, 1), t10: SIMD2<Float> = SIMD2(1, 1),
    t01: SIMD2<Float> = SIMD2(0, 0), t11: SIMD2<Float> = SIMD2(1, 0),
    color: Color<Float> = .white
  ) {
    let color = SIMD4(color)
    let base = self._mesh.vertexCount
    self._mesh.insert(vertices: zip([ p00, p01, p10, p11 ], [ t00, t01, t10, t11 ])
      .map { .init(position: $0, texCoord: $1, color: color) })
    self._mesh.insert(indices: [ 0, 1, 2,  2, 1, 3 ], baseVertex: base)
    self._instances.append(.init(texture: texture, size: 6))
  }

  internal struct SpriteInstance {
    let texture: RendererTexture2D
    let size: IndexType
  }

  internal enum ActiveState {
    case inactive, begin, active
  }
}
