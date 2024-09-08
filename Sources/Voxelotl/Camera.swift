import simd

public final class Camera {
  private struct Dirty: OptionSet {
    let rawValue: UInt8

    static let projection = Self(rawValue: 1 << 0)
    static let view       = Self(rawValue: 1 << 1)
    static let viewProj   = Self(rawValue: 1 << 2)
  }

  private var _position = SIMD3<Float>.zero
  private var _rotation = simd_quatf.identity
  private var _fieldOfView: Float
  private var _aspectRatio: Float
  private var _zNearFar: ClosedRange<Float>
  private var _viewport: Rect<Float>

  private var _dirty: Dirty
  private var _projection = matrix_identity_float4x4
  private var _view = matrix_identity_float4x4
  private var _viewProjection = matrix_identity_float4x4
  private var _invViewProjection = matrix_identity_float4x4

  public var position: SIMD3<Float> {
    get { self._position }
    set(position) {
      if self._position != position {
        self._position = position
        self._dirty.insert(.view)
      }
    }
  }

  public var rotation: simd_quatf {
    get { self._rotation }
    set(rotation) {
      if self._rotation != rotation {
        self._rotation = rotation
        self._dirty.insert(.view)
      }
    }
  }

  public var fieldOfView: Float {
    get { self._fieldOfView.degrees }
    set(fov) {
      let fovRad = fov.radians
      self._fieldOfView = fovRad
      self._dirty.insert(.projection)
    }
  }

  public var aspectRatio: Float {
    get { self._aspectRatio }
    set(aspect) {
      if self._aspectRatio != aspect {
        self._aspectRatio = aspect
        self._dirty.insert(.projection)
      }
    }
  }

  public var viewport: Rect<Float> {
    get { self._viewport }
    set {
      self._viewport = newValue
      self.aspectRatio = Float(newValue.w) / Float(newValue.h)
    }
  }
  public var size: Size<Int> {
    get { Size<Int>(self._viewport.size) }
    set {
      self._viewport.size = Size<Float>(newValue)
      self.aspectRatio = Float(newValue.w) / Float(newValue.h)
    }
  }

  public var range: ClosedRange<Float> {
    get { self._zNearFar }
    set(range) {
      self._zNearFar = range
      self._dirty.insert(.projection)
    }
  }

  public var projection: matrix_float4x4 {
    if self._dirty.contains(.projection) {
      self._projection = .perspective(
        verticalFov: self._fieldOfView,
        aspect: self._aspectRatio,
        near: self._zNearFar.lowerBound,
        far: self._zNearFar.upperBound)
      self._dirty.remove(.projection)
      self._dirty.insert(.viewProj)
    }
    return self._projection
  }
  public var view: matrix_float4x4 {
    if self._dirty.contains(.view) {
      self._view = matrix_float4x4(rotation) * .translate(-position)
      self._dirty.remove(.view)
      self._dirty.insert(.viewProj)
    }
    return self._view
  }
  public var viewProjection: matrix_float4x4 {
    if !self._dirty.isEmpty {
      self._viewProjection = self.projection * self.view
      self._invViewProjection = self._viewProjection.inverse
      self._dirty.remove(.viewProj)
    }
    return self._viewProjection
  }
  public var invViewProjection: matrix_float4x4 {
    if !self._dirty.isEmpty {
      self._viewProjection = self.projection * self.view
      self._invViewProjection = self._viewProjection.inverse
      self._dirty.remove(.viewProj)
    }
    return self._invViewProjection
  }

  init(fov: Float, size: Size<Int>, range: ClosedRange<Float>) {
    self._fieldOfView = fov.radians
    self._aspectRatio = Float(size.w) / Float(size.h)
    self._zNearFar = range
    self._viewport = .init(origin: .zero, size: Size<Float>(size))
    self._dirty = [ .projection, .view, .viewProj ]
  }

  //TODO: maybe make this a struct instead?
  convenience init(_ copy: Camera) {
    self.init(fov: copy._fieldOfView, size: copy.size, range: copy._zNearFar)
    self._position = copy._position
    self._rotation = copy._rotation
    self._aspectRatio = copy._aspectRatio
    self._viewport = copy._viewport
    self._dirty = copy._dirty
    self._projection = copy._projection
    self._view = copy._view
    self._viewProjection = copy._viewProjection
    self._invViewProjection = copy._invViewProjection
  }

  public func screenRay(_ screen: SIMD2<Float>) -> SIMD3<Float> {
#if true
    simd_normalize(self.unproject(screen: SIMD3(screen, 1)) - self.unproject(screen: SIMD3(screen, 0)))
#else
    let inverse = self.projection.inverse
    var viewportCoord = screen - SIMD2(self._viewport.origin)
    viewportCoord = (viewportCoord * 2) / SIMD2(self.viewport.size) - 1
    return simd_normalize(self._rotation * inverse.project(SIMD3(viewportCoord.x, -viewportCoord.y, 1)))
#endif
  }

  public func unproject(screen2D: SIMD2<Float>) -> SIMD3<Float> {
    self.unproject(screen: SIMD3(screen2D, self._zNearFar.lowerBound))
  }

  public func unproject(screen: SIMD3<Float>) -> SIMD3<Float> {
    let inverse = self.invViewProjection

    var viewportCoord = screen.xy - SIMD2(self._viewport.origin)
    viewportCoord = (viewportCoord * 2) / SIMD2(self._viewport.size) - 1

#if true
    return inverse.project(SIMD3(viewportCoord.x, -viewportCoord.y, screen.z))
#else
    let projected = inverse * SIMD4(viewportCoord.x, -viewportCoord.y, screen.z, 1)
    return projected.xyz * (1 / projected.w)
#endif
  }

  public func project(world position: SIMD3<Float>) -> SIMD2<Float> {
    let viewport = self.viewProjection * SIMD4(position, 1)
    if viewport.w == 0 {
      // World point is exactly on focus point, screenpoint is undefined
      return .zero
    }

    return (viewport.xy + 1) * 0.5 * SIMD2(self._viewport.size)
  }
}
