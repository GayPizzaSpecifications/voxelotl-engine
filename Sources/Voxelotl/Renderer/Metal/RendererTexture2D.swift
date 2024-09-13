import Metal

public struct RendererTexture2D: Hashable {
  internal let _textureBuffer: MTLTexture
  public let size: Size<Int>

  internal init(metalTexture: MTLTexture, size: Size<Int>) {
    self._textureBuffer = metalTexture
    self.size = size
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._textureBuffer.gpuResourceID._impl == rhs._textureBuffer.gpuResourceID._impl && lhs.size == rhs.size
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self._textureBuffer.hash)
  }
}

