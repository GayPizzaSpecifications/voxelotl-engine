import simd

struct AABB {
  private var _bounds: simd_float2x3

  var lower: SIMD3<Float> {
    get { _bounds[0] }
    set(row) { self._bounds[0] = row }
  }
  var upper: SIMD3<Float> {
    get { _bounds[1] }
    set(row) { self._bounds[1] = row }
  }
  var center: SIMD3<Float> {
    get { (self._bounds[0] + self._bounds[1]) / 2 }
  }
  var size: SIMD3<Float> {
    get { self._bounds[1] - self._bounds[0] }
  }

  var left: Float   { self._bounds[0].x }
  var bottom: Float { self._bounds[0].y }
  var far: Float    { self._bounds[0].z }
  var right: Float  { self._bounds[1].x }
  var top: Float    { self._bounds[1].y }
  var near: Float   { self._bounds[1].z }

  private init(bounds: simd_float2x3) {
    self._bounds = bounds
  }

  init(from: SIMD3<Float>, to: SIMD3<Float>) {
    self.init(bounds: .init(from, to))
  }

  static func fromUnitCube(position: SIMD3<Float> = .zero, scale: SIMD3<Float> = .one) -> Self {
    self.init(
      from: position - scale,
      to:   position + scale)
  }

  func touching(_ other: Self) -> Bool{
    let distLower = other._bounds[0] - self._bounds[1]  // x: left, y: bottom, z: far
    let distUpper = self._bounds[0] - other._bounds[1]  // x: right, y: top, z: near

    if distLower.x > 0 || distUpper.x > 0 { return false }
    if distLower.y > 0 || distUpper.y > 0 { return false }
    if distLower.z > 0 || distUpper.z > 0 { return false }

    return true
  }
}

extension AABB {
  static func + (lhs: Self, rhs: SIMD3<Float>) -> Self {
    .init(bounds: lhs._bounds + .init(rhs, rhs))
  }
}
