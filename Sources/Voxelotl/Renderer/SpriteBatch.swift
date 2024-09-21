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

  public var viewport: Rect<Float>

  internal init(_ renderer: Renderer, _ viewport: Rect<Float>) {
    self._renderer = renderer
    self._mesh = renderer.createDynamicMesh(vertexCapacity: 4096, indexCapacity: 4096)!
    self.viewport = viewport
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
    self.drawQuad(texture, .positions(position, Size<Float>(texture.size)))
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
    let texCoord = Quad.texcoords(flip)
    let color = color.linear
    if angle != 0 {
      let bias = origin / SIMD2(size)
      self.drawQuad(texture, .positions(position, size * scale, angle, bias), texCoord, color: color)
    } else {
      self.drawQuad(texture, .positions(position - origin * scale, size * scale), texCoord, color: color)
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
    let texCoord = Quad.texcoords(flip)
    let color = color.linear
    if angle != 0 {
      let bias = SIMD2(origin) / SIMD2(size)
      self.drawQuad(texture, .positions(position, size * scale, angle, bias), texCoord, color: color)
    } else {
      self.drawQuad(texture, .positions(position - origin * scale, size * scale), texCoord, color: color)
    }
  }

  public mutating func draw(_ texture: RendererTexture2D, destination: Rect<Float>?) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(destination ?? self.viewport))
  }

  public mutating func draw(_ texture: RendererTexture2D, destination: Rect<Float>?,
    angle: Float = 0.0, center: Point<Float>? = .zero, flip: Sprite.Flip = .none, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let dst = destination ?? self.viewport
    if dst.size.w.isZero || dst.size.h.isZero { return }
    let texCoord = Quad.texcoords(flip)
    let color = color.linear
    if angle != 0 {
      let origin = SIMD2(center ?? Point(dst.size * 0.5))
      let bias = origin / SIMD2(dst.size)
      self.drawQuad(texture, .positions(SIMD2(dst.origin) + origin, dst.size, angle, bias), texCoord, color: color)
    } else {
      self.drawQuad(texture, .positions(dst), texCoord, color: color)
    }
  }

  public mutating func draw(_ texture: RendererTexture2D, transform: simd_float3x3) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(transform, Size<Float>(texture.size)))
  }

  public mutating func draw(_ texture: RendererTexture2D, transform: simd_float3x3,
    flip: Sprite.Flip = .none, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture,
      .positions(transform, Size<Float>(texture.size)),
      .texcoords(flip), color: color.linear)
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(position, source.size), .texcoords(texture.size, source))
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>,
    scale: SIMD2<Float>, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture,
      .positions(position, source.size * scale),
      .texcoords(texture.size, source), color: color.linear)
  }
  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, position: SIMD2<Float>,
    scale: Float = 1.0, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture,
      .positions(position, source.size * scale),
      .texcoords(texture.size, source), color: color.linear)
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>,
    position: SIMD2<Float>, scale: SIMD2<Float>,
    angle: Float = 0.0, origin: SIMD2<Float> = .zero,
    flip: Sprite.Flip = .none, color: Color<Float> = .white
    //depth: Int = 0)
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    if source.size.w.isZero || source.size.h.isZero { return }
    let texCoord = Quad.texcoords(texture.size, source, flip)
    let color = color.linear
    if angle != 0 {
      let bias = origin / SIMD2(source.size)
      self.drawQuad(texture, .positions(position, source.size * scale, angle, bias), texCoord, color: color)
    } else {
      self.drawQuad(texture, .positions(position - SIMD2(origin) * scale, source.size * scale), texCoord, color: color)
    }
  }
  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>,
    position: SIMD2<Float>, scale: Float = 1.0,
    angle: Float = 0.0, origin: SIMD2<Float> = .zero,
    flip: Sprite.Flip = .none, color: Color<Float> = .white
    //depth: Int = 0)
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    if source.size.w.isZero || source.size.h.isZero { return }
    let texCoord = Quad.texcoords(texture.size, source, flip)
    let color = color.linear
    if angle != 0 {
      let bias = origin / SIMD2(source.size)
      self.drawQuad(texture, .positions(position, source.size * scale, angle, bias), texCoord, color: color)
    } else {
      self.drawQuad(texture, .positions(position - SIMD2(origin) * scale, source.size * scale), texCoord, color: color)
    }
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, destination: Rect<Float>?) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(destination ?? self.viewport), .texcoords(texture.size, source))
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, destination: Rect<Float>?,
    color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(destination ?? self.viewport),
      .texcoords(texture.size, source), color: color.linear)
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, destination: Rect<Float>?,
    angle: Float = 0.0, center: Point<Float>? = .zero, flip: Sprite.Flip = .none, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    let dst = destination ?? self.viewport
    if dst.size.w.isZero || dst.size.h.isZero { return }
    let texCoord = Quad.texcoords(texture.size, source, flip)
    let color = color.linear
    if angle != 0 {
      let origin = SIMD2(center ?? Point(dst.size * 0.5))
      let bias = origin / SIMD2(dst.size)
      self.drawQuad(texture, .positions(SIMD2(dst.origin) + origin, dst.size, angle, bias), texCoord, color: color)
    } else {
      self.drawQuad(texture, .positions(dst), texCoord, color: color)
    }
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, transform: simd_float3x3) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(transform, source.size), .texcoords(texture.size, source))
  }

  public mutating func draw(_ texture: RendererTexture2D, source: Rect<Float>, transform: simd_float3x3,
    flip: Sprite.Flip = .none, color: Color<Float> = .white
  ) {
    assert(self._active != .inactive, "call to SpriteBatch.draw without calling begin")
    self.drawQuad(texture, .positions(transform, source.size), .texcoords(texture.size, source), color: color.linear)
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
      self._renderer.setupBatch(blendMode: self._blendMode, frame: self.viewport)
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

  fileprivate struct Quad {
    let v00: SIMD2<Float>, v01: SIMD2<Float>
    let v10: SIMD2<Float>, v11: SIMD2<Float>
  }

  private mutating func drawQuad(_ texture: RendererTexture2D,
    _ p: Quad, _ t: Quad = .texcoordsDefault, color: Color<Float> = .white
  ) {
    let color = SIMD4(color)
    let base = self._mesh.vertexCount
    self._mesh.insert(vertices: zip([ p.v00, p.v01, p.v10, p.v11 ], [ t.v00, t.v01, t.v10, t.v11 ])
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

fileprivate extension SpriteBatch.Quad {
  static func positions(_ position: SIMD2<Float>, _ size: Size<Float>) -> Self {
    .init(
      v00: position,
      v01: .init(position.x + size.w, position.y),
      v10: .init(position.x,          position.y + size.h),
      v11: .init(position.x + size.w, position.y + size.h))
  }

  static func positions(_ position: SIMD2<Float>, _ size: Size<Float>,
    _ angle: Float, _ offset: SIMD2<Float>
  ) -> Self {
    let (tc, ts) = (cos(angle), sin(angle))
    let rotate = matrix_float2x2(
      .init( tc, ts),
      .init(-ts, tc))
    let right = SIMD2<Float>(size.w, 0) * rotate
    let down  = SIMD2<Float>(0, size.h) * rotate
    return .init (
      v00: position - right *       offset.x - down *      offset.y,
      v01: position + right * (1 - offset.x) - down *      offset.y,
      v10: position - right *       offset.x + down * (1 - offset.y),
      v11: position + right * (1 - offset.x) + down * (1 - offset.y))
  }

  static func positions(_ rect: Rect<Float>) -> Self {
    .init(
      v00: SIMD2(rect.left,  rect.up),   v01: SIMD2(rect.right, rect.up),
      v10: SIMD2(rect.left,  rect.down), v11: SIMD2(rect.right, rect.down))
  }

  static func positions(_ transform: simd_float3x3, _ size: Size<Float>) -> Self {
    let w = size.w, h = size.h
    return .init(
      v00: (transform * .init(0, 0, 1)).xy,
      v01: (transform * .init(w, 0, 1)).xy,
      v10: (transform * .init(0, h, 1)).xy,
      v11: (transform * .init(w, h, 1)).xy)
  }

  static let texcoordsDefault = Self(
    v00: SIMD2<Float>(0, 1), v01: SIMD2<Float>(1, 1),
    v10: SIMD2<Float>(0, 0), v11: SIMD2<Float>(1, 0))

  static func texcoords(_ flip: Sprite.Flip) -> Self {
    let flipX = flip.contains(.horz), flipY = flip.contains(.vert), flipD = flip.contains(.diag)
    return .init(
      v00: .init(flipX ? 1 : 0, flipY ? 0 : 1),
      v01: flipD ? .init(flipX ? 1 : 0, flipY ? 1 : 0) : .init(flipX ? 0 : 1, flipY ? 0 : 1),
      v10: flipD ? .init(flipX ? 0 : 1, flipY ? 0 : 1) : .init(flipX ? 1 : 0, flipY ? 1 : 0),
      v11: .init(flipX ? 0 : 1, flipY ? 1 : 0))
  }

  static func texcoords(_ texSize: Size<Int>, _ source: Rect<Float>) -> Self {
    let invSize = 1 / Size<Float>(texSize)
    let st = Extent(source) * invSize
    return .init(
      v00: SIMD2(st.left,  st.top),    v01: SIMD2(st.right, st.top),
      v10: SIMD2(st.left,  st.bottom), v11: SIMD2(st.right, st.bottom))
  }

  static func texcoords(_ texSize: Size<Int>, _ source: Rect<Float>, _ flip: Sprite.Flip) -> Self {
    let flipX = flip.contains(.horz), flipY = flip.contains(.vert), flipD = flip.contains(.diag)
    let invSize = 1 / Size<Float>(texSize)
    let st = Extent(source) * invSize
    return .init(
      v00: .init(flipX ? st.right : st.left, flipY ? st.bottom : st.top),
      v01: flipD
        ?  .init(flipX ? st.right : st.left, flipY ? st.top : st.bottom)
        :  .init(flipX ? st.left : st.right, flipY ? st.bottom : st.top),
      v10: flipD
        ?  .init(flipX ? st.left : st.right, flipY ? st.bottom : st.top)
        :  .init(flipX ? st.right : st.left, flipY ? st.top : st.bottom),
      v11: .init(flipX ? st.left : st.right, flipY ? st.top : st.bottom))
  }
}
