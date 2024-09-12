import Metal

public struct RendererMesh: Hashable {
  internal let _vertBuf: MTLBuffer, _idxBuf: MTLBuffer
  public let numIndices: Int

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._vertBuf.gpuAddress == rhs._vertBuf.gpuAddress && lhs._vertBuf.length == rhs._vertBuf.length &&
    lhs._vertBuf.gpuAddress == rhs._vertBuf.gpuAddress && lhs._vertBuf.length == rhs._vertBuf.length &&
    lhs.numIndices == rhs.numIndices
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self._vertBuf.hash)
    hasher.combine(self._idxBuf.hash)
    hasher.combine(self.numIndices)
  }
}
