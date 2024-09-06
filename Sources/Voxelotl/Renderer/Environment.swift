//TODO: Sort, Blend
public struct Environment {
  public var cullFace: Face
  public var lightDirection: SIMD3<Float>

  public enum Face { case none, front, back }
}
