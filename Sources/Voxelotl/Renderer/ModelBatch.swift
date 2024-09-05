import simd

public struct ModelBatch {
  private let _renderer: Renderer
  private var _active = false
  private var _cam: Camera!
  private var _env: Environment!

  internal init(_ renderer: Renderer) {
    self._renderer = renderer
  }

  //TODO: Sort, Blend
  mutating func begin(camera: Camera, environment: Environment) {
    self._active = true
    self._cam = camera
    self._env = environment
  }

  mutating func end() {
    self._active = false
  }

  mutating func draw(_ model: ModelInstance, position: SIMD3<Float>, color: Color<Float> = .white
  ) {
    self.draw(model, world: .translate(position), color: color)
  }

  mutating func draw(_ model: ModelInstance,
    position: SIMD3<Float>, scale: Float, rotation: simd_quatf,
    color: Color<Float> = .white
  ) {
    self.draw(model, position: position, scale: .init(repeating: scale), rotation: rotation, color: color)
  }

  mutating func draw(_ model: ModelInstance,
    position: SIMD3<Float>, scale: SIMD3<Float>, rotation: simd_quatf,
    color: Color<Float> = .white
  ) {
    let world =
      .translate(position) *
      simd_float4x4(rotation) *
      .scale(scale)
    self.draw(model, world: world, color: color)
  }

  mutating func draw(_ model: ModelInstance, world: simd_float4x4, color: Color<Float> = .white) {
    assert(self._active)
    self._renderer.draw(
      model: world,
      color: color.linear,
      mesh: model.mesh,
      material: model.material,
      environment: self._env,
      camera: self._cam)
  }

  internal struct Instance {
    let model: simd_float4x4
    let color: Color<Float>

    init(model: simd_float4x4, color: Color<Float> = .white) {
      self.model = model
      self.color = color
    }
  }
}

//TODO: delet
public struct ModelInstance {
  let mesh: RendererMesh
  let material: Material
}
