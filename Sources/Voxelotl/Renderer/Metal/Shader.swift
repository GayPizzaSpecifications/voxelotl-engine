import Metal

internal struct Shader: Hashable {
  let vertexProgram: (any MTLFunction)?, fragmentProgram: (any MTLFunction)?

  static func == (lhs: Shader, rhs: Shader) -> Bool {
    lhs.vertexProgram?.hash == rhs.vertexProgram?.hash && lhs.fragmentProgram?.hash == rhs.fragmentProgram?.hash
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.vertexProgram?.hash ?? 0)
    hasher.combine(self.fragmentProgram?.hash ?? 0)
  }
}
