import simd

public final class Camera {
  private struct Dirty: OptionSet {
    let rawValue: UInt8

    static let projection = Self(rawValue: 1 << 0)
    static let view       = Self(rawValue: 1 << 1)
    static let viewProj   = Self(rawValue: 1 << 2)
  }

  private var _position: SIMD3<Float>
  private var _rotation: simd_quatf
  private var _fieldOfView: Float
  private var _aspectRatio: Float
  private var _zNearFar: ClosedRange<Float>

  private var _dirty: Dirty
  private var _projection: matrix_float4x4
  private var _view: matrix_float4x4
  private var _viewProjection: matrix_float4x4

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

  public func setSize(_ size: Size<Int>) {
    self.aspectRatio = Float(size.w) / Float(size.h)
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
      self._dirty.remove(.viewProj)
    }
    return self._viewProjection
  }

  init(fov: Float, size: Size<Int>, range: ClosedRange<Float>) {
    self._position = .zero
    self._rotation = .identity
    self._fieldOfView = fov.radians
    self._aspectRatio = Float(size.w) / Float(size.h)
    self._zNearFar = range
    self._dirty = [ .projection, .view, .viewProj ]
    self._projection = .init()
    self._view = .init()
    self._viewProjection = .init()
  }
}
