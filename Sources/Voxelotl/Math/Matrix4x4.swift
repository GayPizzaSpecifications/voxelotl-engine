import simd

public extension simd_float4x4 {
  typealias T = Float

  @inline(__always) static var identity: Self { matrix_identity_float4x4 }

  @inline(__always) static func translate(_ v: SIMD3<T>) -> Self {
    Self(
      .init(  1,   0,   0, 0),
      .init(  0,   1,   0, 0),
      .init(  0,   0,   1, 0),
      .init(v.x, v.y, v.z, 1))
  }

  @inline(__always) static func scale(_ v: SIMD3<T>) -> Self { Self(diagonal: .init(v.x, v.y, v.z, 1)) }
  @inline(__always) static func scale(_ s: T) -> Self { Self(diagonal: .init(s, s, s, 1)) }

  static func rotate(x theta: T) -> Self {
    let c = cos(theta), s = sin(theta)
    return Self(
      .init(1,  0, 0, 0),
      .init(0,  c, s, 0),
      .init(0, -s, c, 0),
      .init(0,  0, 0, 1))
  }

  static func rotate(y theta: T) -> Self {
    let c = cos(theta), s = sin(theta)
    return Self(
      .init(c, 0, -s, 0),
      .init(0, 1,  0, 0),
      .init(s, 0,  c, 0),
      .init(0, 0,  0, 1))
  }

  static func rotate(z theta: T) -> Self {
    let c = cos(theta), s = sin(theta)
    return Self(
      .init(c, -s, 0, 0),
      .init(s,  c, 0, 0),
      .init(0,  0, 1, 0),
      .init(0,  0, 0, 1))
  }

  @inline(__always) static func rotate(yawPitch yp: SIMD2<T>) -> Self { rotate(yaw: yp.x, pitch: yp.y) }

  static func rotate(yaw ytheta: T, pitch xtheta: T) -> Self {
    let xc = cos(xtheta), xs = sin(xtheta)
    let yc = cos(ytheta), ys = sin(ytheta)

    return .init(
      .init(yc, ys *  xs, -ys * xc, 0),
      .init( 0,       xc,       xs, 0),
      .init(ys, yc * -xs,  yc * xc, 0),
      .init( 0,        0,        0, 1))
  }

  static func orthographic(left: T, right: T, bottom: T, top: T, near: T, far: T) -> Self {
    let
      invWidth  = 1 / (right - left),
      invHeight = 1 / (top - bottom),
      invDepth  = 1 / (far - near)
    let
      tx = -(right + left) * invWidth,
      ty = -(top + bottom) * invHeight,
      tz = -near * invDepth
    let x = 2 * invWidth, y = 2 * invHeight, z = invDepth

    return .init(
      .init( x,  0,  0, 0),
      .init( 0,  y,  0, 0),
      .init( 0,  0,  z, 0),
      .init(tx, ty, tz, 1))
  }

  static func perspective(verticalFov fovY: T, aspect: T, near zNear: T, far zFar: T) -> Self {
    let tanHalfFovY = tan(fovY * T(0.5))
    let invClipRange = 1 / (zNear - zFar)

    let y = 1 / tanHalfFovY
    let x = y / aspect
    let z = zFar * invClipRange
    let w = zNear * z
    return .init(
      .init(x, 0, 0,  0),
      .init(0, y, 0,  0),
      .init(0, 0, z, -1),
      .init(0, 0, w,  0))
  }
}

extension simd_quatf {
  static var identity: Self { .init(real: 1, imag: .zero) }
}
