import Metal

public struct RendererDynamicMesh<VertexType: Vertex, IndexType: UnsignedInteger> {
  private weak var _renderer: Renderer!
  internal let _vertBufs: [MTLBuffer], _idxBufs: [MTLBuffer]
  private var _numVertices: Int = 0, _numIndices: Int = 0

  public let vertexCapacity: Int, indexCapacity: Int
  public var vertexCount: Int { self._numVertices }
  public var indexCount: Int { self._numIndices }

  init(renderer: Renderer, _ vertBufs: [MTLBuffer], _ idxBufs: [MTLBuffer]) {
    self._renderer = renderer
    self._vertBufs = vertBufs
    self._idxBufs = idxBufs
    self.vertexCapacity = self._vertBufs.map { $0.length }.min()! / MemoryLayout<VertexType>.stride
    self.indexCapacity = self._idxBufs.map { $0.length }.min()! / MemoryLayout<IndexType>.stride
  }

  public mutating func clear() {
    self._numVertices = 0
    self._numIndices = 0
  }


  public mutating func insert(vertices: [VertexType]) {
    self.insert(vertices: vertices[...])
  }

  public mutating func insert(vertices: ArraySlice<VertexType>) {
    assert(self._numVertices + vertices.count < self.vertexCapacity)

    let vertexBuffer: MTLBuffer = self._vertBufs[self._renderer.currentFrame]
    vertexBuffer.contents().withMemoryRebound(to: VertexType.self, capacity: self.vertexCapacity) { vertexData in
      for i in 0..<vertices.count {
        vertexData[self._numVertices + i] = vertices[i]
      }
    }

#if os(macOS)
    if self._renderer.isManagedStorage {
      let stride = MemoryLayout<VertexType>.stride
      vertexBuffer.didModifyRange(stride * self._numVertices..<stride * vertices.count)
    }
#endif

    self._numVertices += vertices.count
  }

  public mutating func insert(indices: [IndexType], baseVertex: Int = 0) {
    assert(self._numIndices + indices.count < self.indexCapacity)

    let indexBuffer: MTLBuffer = self._idxBufs[self._renderer.currentFrame]
    let base = IndexType(baseVertex)
    indexBuffer.contents().withMemoryRebound(to: IndexType.self, capacity: self.indexCapacity) { indexData in
      for i in 0..<indices.count {
        indexData[self._numIndices + i] = base + indices[i]
      }
    }

#if os(macOS)
    if self._renderer.isManagedStorage {
      let stride = MemoryLayout<VertexType>.stride
      indexBuffer.didModifyRange(stride * self._numIndices..<stride * indices.count)
    }
#endif

    self._numIndices += indices.count
  }
}
