import simd

public struct AABB {
  private var _bounds: simd_float2x3

  public var lower: SIMD3<Float> {
    get { _bounds[0] }
    set(row) { self._bounds[0] = row }
  }
  public var upper: SIMD3<Float> {
    get { _bounds[1] }
    set(row) { self._bounds[1] = row }
  }
  public var center: SIMD3<Float> {
    get { (self._bounds[0] + self._bounds[1]) / 2 }
  }
  public var size: SIMD3<Float> {
    get { self._bounds[1] - self._bounds[0] }
  }

  public var left: Float   { self._bounds[0].x }
  public var bottom: Float { self._bounds[0].y }
  public var far: Float    { self._bounds[0].z }
  public var right: Float  { self._bounds[1].x }
  public var top: Float    { self._bounds[1].y }
  public var near: Float   { self._bounds[1].z }

  private init(bounds: simd_float2x3) {
    self._bounds = bounds
  }

  public init(from: SIMD3<Float>, to: SIMD3<Float>) {
    self.init(bounds: .init(from, to))
  }

  public static func fromUnitCube(position: SIMD3<Float> = .zero, scale: SIMD3<Float> = .one) -> Self {
    self.init(
      from: position - scale,
      to:   position + scale)
  }

  public func touching(_ other: Self) -> Bool{
    let distLower = other._bounds[0] - self._bounds[1]  // x: left, y: bottom, z: far
    let distUpper = self._bounds[0] - other._bounds[1]  // x: right, y: top, z: near

    if distLower.x > 0 || distUpper.x > 0 { return false }
    if distLower.y > 0 || distUpper.y > 0 { return false }
    if distLower.z > 0 || distUpper.z > 0 { return false }

    return true
  }
}

public extension AABB {
  public static func + (lhs: Self, rhs: SIMD3<Float>) -> Self {
    .init(bounds: lhs._bounds + .init(rhs, rhs))
  }
}
