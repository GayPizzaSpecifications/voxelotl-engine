import simd

public struct ModelBatch {
  private let _renderer: Renderer
  private var _active = false
  private var _cam: Camera!
  private var _env: Environment!
  private var _prev: ModelInstance!
  private var _instances: [Instance]

  internal init(_ renderer: Renderer) {
    self._renderer = renderer
    self._instances = Array()
  }

  //TODO: Sort, Blend
  public mutating func begin(camera: Camera, environment: Environment) {
    self._active = true
    self._cam = camera
    self._env = environment
    self._prev = nil
  }

  private mutating func flush() {
    assert(self._instances.count > 0)
    if self._instances.count == 1 {
      let instance = self._instances.first!
      self._renderer.draw(
        model:       instance.world,
        color:       instance.color,
        mesh:        self._prev.mesh,
        material:    self._prev.material,
        environment: self._env,
        camera:      self._cam)
    } else {
      self._renderer.batch(
        instances:   self._instances,
        mesh:        self._prev.mesh,
        material:    self._prev.material,
        environment: self._env,
        camera:      self._cam)
    }
    self._instances.removeAll(keepingCapacity: true)
    self._prev = nil
  }

  public mutating func end() {
    if !self._instances.isEmpty {
      self.flush()
    }
    self._cam    = nil
    self._env    = nil
    self._active = false
  }

  public mutating func draw(_ model: ModelInstance, position: SIMD3<Float>, color: Color<Float> = .white
  ) {
    self.draw(model, world: .translate(position), color: color)
  }

  public mutating func draw(_ model: ModelInstance,
    position: SIMD3<Float>, scale: Float, rotation: simd_quatf,
    color: Color<Float> = .white
  ) {
    self.draw(model, position: position, scale: .init(repeating: scale), rotation: rotation, color: color)
  }

  public mutating func draw(_ model: ModelInstance,
    position: SIMD3<Float>, scale: SIMD3<Float>, rotation: simd_quatf,
    color: Color<Float> = .white
  ) {
    let world =
      .translate(position) *
      simd_float4x4(rotation) *
      .scale(scale)
    self.draw(model, world: world, color: color)
  }

  public mutating func draw(_ model: ModelInstance, world: simd_float4x4, color: Color<Float> = .white) {
    assert(self._active)
    if self._prev == nil {
      self._prev = model
    } else if model != self._prev {
      self.flush()
      self._prev = model
    }

    self._instances.append(.init(
      world: world,
      color: color.linear))
  }

  internal struct Instance {
    let world: simd_float4x4
    let color: Color<Float>

    init(world: simd_float4x4, color: Color<Float> = .white) {
      self.world = world
      self.color = color
    }
  }
}

//TODO: delet
public struct ModelInstance: Hashable {
  let mesh: RendererMesh
  let material: Material
}
