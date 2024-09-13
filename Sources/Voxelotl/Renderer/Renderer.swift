import Foundation
import Metal
import QuartzCore.CAMetalLayer
import simd
import ShaderTypes

fileprivate let numFramesInFlight: Int = 3
fileprivate let colorFormat: MTLPixelFormat = .bgra8Unorm_srgb
fileprivate let depthFormat: MTLPixelFormat = .depth32Float

public class Renderer {
  private var device: MTLDevice
  private var _layer: CAMetalLayer
  private var backBufferSize: Size<Int>
  private var _clearColor: Color<Double>
  private var _aspectRatio: Float
  private var queue: MTLCommandQueue
  private var lib: MTLLibrary
  private var _defaultShader: Shader, _shader2D: Shader
  private let passDescription = MTLRenderPassDescriptor()
  private var _psos: [PipelineOptions: MTLRenderPipelineState]
  private var _depthStencilEnabled: MTLDepthStencilState, _depthStencilDisabled: MTLDepthStencilState
  private let _defaultStorageMode: MTLResourceOptions

  private var depthTextures: [MTLTexture]
  //private var _instances: [MTLBuffer?]
  private var _cameraPos: SIMD3<Float> = .zero, _directionalDir: SIMD3<Float> = .zero

  private var _encoder: MTLRenderCommandEncoder! = nil

  private var defaultTexture: RendererTexture2D
  private var cubeTexture: RendererTexture2D? = nil

  private let inFlightSemaphore = DispatchSemaphore(value: numFramesInFlight)
  private var _currentFrame = 0

  internal var currentFrame: Int { self._currentFrame }
  internal var isManagedStorage: Bool { self._defaultStorageMode == .storageModeManaged }

  var frame: Rect<Int> { .init(origin: .zero, size: self.backBufferSize) }
  var aspectRatio: Float { self._aspectRatio }
  var clearColor: Color<Double> {
    get { self._clearColor }
    set { self._clearColor = newValue }
  }

  fileprivate static func createMetalDevice() -> MTLDevice? {
#if os(macOS)
    MTLCopyAllDevices().reduce(nil, { best, dev in
      if best == nil { dev }
      else if !best!.isLowPower || dev.isLowPower { best }
      else if best!.supportsRaytracing || !dev.supportsRaytracing { best }
      else { dev }
    })
#else
    MTLCreateSystemDefaultDevice()
#endif
  }

  internal init(layer metalLayer: CAMetalLayer, size: Size<Int>) throws {
    self._layer = metalLayer

    // Select best Metal device
    guard let device = Self.createMetalDevice() else {
      throw RendererError.initFailure("Failed to create Metal device")
    }
    self.device = device
#if os(macOS)
    self._defaultStorageMode = if #available(macOS 100.100, iOS 12.0, *) {
      .storageModeShared
    } else if #available(macOS 10.15, iOS 13.0, *) {
      self.device.hasUnifiedMemory ? .storageModeShared : .storageModeManaged
    } else {
      // https://developer.apple.com/documentation/metal/gpu_devices_and_work_submission/multi-gpu_systems/finding_multiple_gpus_on_an_intel-based_mac#3030770
      (self.device.isLowPower && !self.device.isRemovable) ? .storageModeShared : .storageModeManaged
    }
#else
    self._defaultStorageMode = .storageModeShared
#endif

    self._layer.device = device
    self._layer.pixelFormat = colorFormat

    // Setup command queue
    guard let queue = device.makeCommandQueue() else {
      throw RendererError.initFailure("Failed to create command queue")
    }
    self.queue = queue

    self.backBufferSize = size
    self._aspectRatio = Float(self.backBufferSize.w) / Float(self.backBufferSize.w)
    self._clearColor = .black

    passDescription.colorAttachments[0].loadAction  = .clear
    passDescription.colorAttachments[0].storeAction = .store
    passDescription.depthAttachment.loadAction  = .clear
    passDescription.depthAttachment.storeAction = .dontCare
    passDescription.depthAttachment.clearDepth  = 1.0

    self.depthTextures = try (0..<numFramesInFlight).map { _ in
      guard let depthStencilTexture = Self.createDepthTexture(device, size, format: depthFormat) else {
        throw RendererError.initFailure("Failed to create depth buffer")
      }
      return depthStencilTexture
    }

    let stencilDepthDescription = MTLDepthStencilDescriptor()
    stencilDepthDescription.depthCompareFunction = .less  // OpenGL default
    stencilDepthDescription.isDepthWriteEnabled  = true
    guard let depthStencilEnabled = device.makeDepthStencilState(descriptor: stencilDepthDescription),
      let depthStencilDisabled = device.makeDepthStencilState(descriptor: MTLDepthStencilDescriptor())
    else {
      throw RendererError.initFailure("Failed to create depth stencil state")
    }
    self._depthStencilEnabled = depthStencilEnabled
    self._depthStencilDisabled = depthStencilDisabled

    // Create shader library & grab functions
    do {
      self.lib = try device.makeDefaultLibrary(bundle: Bundle.main)
    } catch {
      throw RendererError.initFailure("Metal shader compilation failed:\n\(error.localizedDescription)")
    }
    self._defaultShader = .init(
      vertexProgram:   lib.makeFunction(name: "vertexMain"),
      fragmentProgram: lib.makeFunction(name: "fragmentMain"))
    self._shader2D = .init(
      vertexProgram:   lib.makeFunction(name: "vertex2DMain"),
      fragmentProgram: lib.makeFunction(name: "fragment2DMain"))

    // Set up initial pipeline state
    self._psos = try [ .init(colorFormat: self._layer.pixelFormat, depthFormat: depthFormat, shader: self._defaultShader, blendFunc: .off) ]
      .map { [$0: try $0.createPipeline(device)] }[0]

    // Create a default texture
    do {
      self.defaultTexture = try Self.loadTexture(device, queue, image2D: Image2D(Data([
          0xFF, 0x00, 0xFF, 0xFF,  0x00, 0x00, 0x00, 0xFF,
          0x00, 0x00, 0x00, 0xFF,  0xFF, 0x00, 0xFF, 0xFF
        ]), format: .abgr8888, width: 2, height: 2, stride: 2 * 4), self._defaultStorageMode)
    } catch {
      throw RendererError.initFailure("Failed to create default texture")
    }

    // Load texture from a file in the bundle
    do {
      self.cubeTexture = try Self.loadTexture(device, queue, resourcePath: "test.png", self._defaultStorageMode)
    } catch RendererError.loadFailure(let message) {
      printErr("Failed to load texture image: \(message)")
    } catch {
      printErr("Failed to load texture image: unknown error")
    }
  }

  deinit {
    
  }

  fileprivate func usePipeline(options pipeOpts: PipelineOptions) throws {
    if let exists = self._psos[pipeOpts] {
      self._encoder.setRenderPipelineState(exists)
    } else {
      let new = try pipeOpts.createPipeline(self.device)
      self._encoder.setRenderPipelineState(new)
      self._psos[pipeOpts] = new
    }
  }

  func createMesh(_ mesh: Mesh<VertexPositionNormalColorTexcoord, UInt16>) -> RendererMesh? {
    if mesh.vertices.isEmpty || mesh.indices.isEmpty { return nil }

    let vertices = mesh.vertices.map {
      ShaderVertex(position: $0.position, normal: $0.normal, color: $0.color, texCoord: $0.texCoord)
    }
    return self.createMesh(vertices, mesh.indices)
  }

  func createMesh(_ mesh: Mesh<VertexPositionNormalTexcoord, UInt16>) -> RendererMesh? {
    if mesh.vertices.isEmpty || mesh.indices.isEmpty { return nil }

    let color = Color<Float>.white
    let vertices = mesh.vertices.map {
      ShaderVertex(position: $0.position, normal: $0.normal, color: SIMD4(color), texCoord: $0.texCoord)
    }
    return self.createMesh(vertices, mesh.indices)
  }

  private func createMesh(_ vertices: [ShaderVertex], _ indices: [UInt16]) -> RendererMesh? {
    autoreleasepool {
      let vtxSize = vertices.count * MemoryLayout<ShaderVertex>.stride
      guard let vtxSource = self.device.makeBuffer(bytes: vertices, length: vtxSize, options: self._defaultStorageMode) else {
        printErr("Failed to create vertex buffer source")
        return nil
      }

      let numIndices = indices.count
      let idxSize = numIndices * MemoryLayout<UInt16>.stride
      guard let idxSource = self.device.makeBuffer(bytes: indices, length: idxSize, options: self._defaultStorageMode) else {
        printErr("Failed to create index buffer source")
        return nil
      }

      guard let vtxDestination = self.device.makeBuffer(length: vtxSize, options: .storageModePrivate) else {
        printErr("Failed to create vertex buffer destination")
        return nil
      }
      guard let idxDestination = self.device.makeBuffer(length: idxSize, options: .storageModePrivate) else {
        printErr("Failed to create index buffer destination")
        return nil
      }

      guard let cmdBuffer = queue.makeCommandBuffer(),
        let blitEncoder = cmdBuffer.makeBlitCommandEncoder()
      else {
        printErr("Failed to create blit command encoder")
        return nil
      }

      blitEncoder.copy(from: vtxSource, sourceOffset: 0, to: vtxDestination, destinationOffset: 0, size: vtxSize)
      blitEncoder.copy(from: idxSource, sourceOffset: 0, to: idxDestination, destinationOffset: 0, size: idxSize)
      blitEncoder.endEncoding()

      cmdBuffer.addCompletedHandler { _ in
        //FIXME: look into if this needs to be synchronised
        //printErr("Mesh data was added?")
      }
      cmdBuffer.commit()

      return .init(_vertBuf: vtxDestination, _idxBuf: idxDestination, numIndices: numIndices)
    }
  }

  internal func createDynamicMesh<VertexType: Vertex, IndexType: UnsignedInteger>(
    vertexCapacity: Int, indexCapacity: Int
  ) -> RendererDynamicMesh<VertexType, IndexType>? {
    let vertexBuffers: [MTLBuffer], indexBuffers: [MTLBuffer]
    do {
      let byteCapacity = MemoryLayout<VertexType>.stride * vertexCapacity
      vertexBuffers = try Self.createDynamicBuffer(self.device, capacity: byteCapacity, self._defaultStorageMode)
    } catch {
      printErr("Failed to create vertex buffer")
      return nil
    }
    do {
      let byteCapacity = MemoryLayout<IndexType>.stride * indexCapacity
      indexBuffers =  try Self.createDynamicBuffer(self.device, capacity: byteCapacity, self._defaultStorageMode)
    } catch {
      printErr("Failed to create index buffer")
      return nil
    }
    return .init(renderer: self, vertexBuffers, indexBuffers)
  }

  private static func createDynamicBuffer(_ device: MTLDevice, capacity: Int, _ transitoryOpt: MTLResourceOptions
  ) throws -> [MTLBuffer] {
    try autoreleasepool {
      try (0..<numFramesInFlight).map { _ in
        guard let buffer = device.makeBuffer(length: capacity, options: transitoryOpt) else {
          throw RendererError.initFailure("Failed to create buffer")
        }
        return buffer
      }
    }
  }

  public func loadTexture(resourcePath path: String) -> RendererTexture2D? {
    do {
      return try Self.loadTexture(self.device, self.queue, resourcePath: path, self._defaultStorageMode)
    } catch {
      printErr(error)
      return nil
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, resourcePath path: String,
    _ transitoryOpt: MTLResourceOptions
  ) throws -> RendererTexture2D {
    do {
      return try loadTexture(device, queue, url: Bundle.main.getResource(path), transitoryOpt)
    } catch ContentError.resourceNotFound(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, url imageUrl: URL,
    _ transitoryOpt: MTLResourceOptions
  ) throws -> RendererTexture2D {
    do {
      return try loadTexture(device, queue, image2D: try NSImageLoader.open(url: imageUrl), transitoryOpt)
    } catch ImageLoaderError.openFailed(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, image2D image: Image2D,
    _ transitoryOpt: MTLResourceOptions
  ) throws -> RendererTexture2D {
    try autoreleasepool {
      let texDesc = MTLTextureDescriptor()
      texDesc.width  = image.width
      texDesc.height = image.height
      texDesc.pixelFormat = .rgba8Unorm_srgb
      texDesc.textureType = .type2D
      texDesc.storageMode = .private
      texDesc.usage = .shaderRead
      guard let newTexture = device.makeTexture(descriptor: texDesc) else {
        throw RendererError.loadFailure("Failed to create texture descriptor")
      }

      guard let texData = image.data.withUnsafeBytes({ bytes in
        device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: transitoryOpt)
      }) else {
        throw RendererError.loadFailure("Failed to create shared texture data buffer")
      }

      guard let cmdBuffer = queue.makeCommandBuffer(),
        let blitEncoder = cmdBuffer.makeBlitCommandEncoder()
      else {
        throw RendererError.loadFailure("Failed to create blit command encoder")
      }

      blitEncoder.copy(
        from: texData,
        sourceOffset: 0,
        sourceBytesPerRow: image.stride,
        sourceBytesPerImage: image.stride * image.height,
        sourceSize: .init(width: image.width, height: image.height, depth: 1),

        to: newTexture,
        destinationSlice: 0,
        destinationLevel: 0,
        destinationOrigin: .init(x: 0, y: 0, z: 0))
      blitEncoder.endEncoding()

      cmdBuffer.addCompletedHandler { _ in
        //FIXME: look into if this needs to be synchronised
        //printErr("Texture was added?")
      }
      cmdBuffer.commit()

      return .init(metalTexture: newTexture, size: .init(image.width, image.height))
    }
  }

  private static func createDepthTexture(_ device: MTLDevice, _ size: Size<Int>, format: MTLPixelFormat
  ) -> MTLTexture? {
    autoreleasepool {
      let texDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: format,
        width:       size.w,
        height:      size.h,
        mipmapped:   false)
      texDescriptor.depth       = 1
      texDescriptor.sampleCount = 1
      texDescriptor.usage       = [ .renderTarget, .shaderRead ]
#if !NDEBUG
      texDescriptor.storageMode = .private
#else
      texDescriptor.storageMode = .memoryless
#endif

      guard let depthStencilTexture = device.makeTexture(descriptor: texDescriptor) else { return nil }
      depthStencilTexture.label = "Depth buffer"

      return depthStencilTexture
    }
  }

  static func makeViewport(rect: Rect<Int>, znear: Double = 0.0, zfar: Double = 1.0) -> MTLViewport {
    MTLViewport(
      originX: Double(rect.x),
      originY: Double(rect.y),
      width:   Double(rect.w),
      height:  Double(rect.h),
      znear: znear, zfar: zfar)
  }

  func resize(size: Size<Int>) {
    if self.backBufferSize.w != size.w || self.backBufferSize.h != size.h {
      self.depthTextures = (0..<numFramesInFlight).map { _ in
        Self.createDepthTexture(device, size, format: depthFormat)!
      }
    }

    self.backBufferSize = size
    self._aspectRatio = Float(self.backBufferSize.w) / Float(self.backBufferSize.h)
  }

  func newFrame(_ frameFunc: (Renderer) -> Void) throws {
    try autoreleasepool {
      guard let rt = self._layer.nextDrawable() else {
        throw RendererError.drawFailure("Failed to get next drawable render target")
      }

      passDescription.colorAttachments[0].clearColor = MTLClearColor(self._clearColor)
      passDescription.colorAttachments[0].texture = rt.texture
      passDescription.depthAttachment.texture = self.depthTextures[self._currentFrame]

      // Lock the semaphore here if too many frames are "in flight"
      _ = inFlightSemaphore.wait(timeout: .distantFuture)

      guard let commandBuf: MTLCommandBuffer = queue.makeCommandBuffer() else {
        throw RendererError.drawFailure("Failed to make command buffer from queue")
      }
      commandBuf.addCompletedHandler { _ in
        self.inFlightSemaphore.signal()
      }

      guard let encoder = commandBuf.makeRenderCommandEncoder(descriptor: passDescription) else {
        throw RendererError.drawFailure("Failed to make render encoder from command buffer")
      }

      encoder.setFrontFacing(.counterClockwise)  // OpenGL default
      encoder.setViewport(Self.makeViewport(rect: self.frame))
      encoder.setFragmentTexture(cubeTexture?._textureBuffer ?? defaultTexture._textureBuffer, index: 0)

      self._encoder = encoder
      frameFunc(self)
      self._encoder = nil

      encoder.endEncoding()
      commandBuf.present(rt)
      commandBuf.commit()

      self._currentFrame &+= 1
      if self._currentFrame == numFramesInFlight {
        self._currentFrame = 0
      }
    }
  }

  func createModelBatch() -> ModelBatch {
    return ModelBatch(self)
  }

  func createSpriteBatch() -> SpriteBatch {
    return SpriteBatch(self)
  }

  internal func setupBatch(environment: Environment, camera: Camera) {
    assert(self._encoder != nil, "setupBatch can't be called outside of a frame being rendered")

    do {
      try self.usePipeline(options: PipelineOptions(
        colorFormat: self._layer.pixelFormat, depthFormat: depthFormat,
        shader: self._defaultShader, blendFunc: .off))
    } catch {
      printErr(error)
    }

    var vertUniforms = VertexShaderUniforms(projView: camera.viewProjection)

    self._cameraPos = camera.position
    self._directionalDir = simd_normalize(environment.lightDirection)

    self._encoder.setDepthStencilState(self._depthStencilEnabled)
    self._encoder.setCullMode(.init(environment.cullFace))

    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(&vertUniforms,
      length: MemoryLayout<VertexShaderUniforms>.stride,
      index: VertexShaderInputIdx.uniforms.rawValue)
  }

  internal func setupBatch(blendMode: BlendMode, frame: Rect<Float>) {
    assert(self._encoder != nil, "setupBatch can't be called outside of a frame being rendered")

    do {
      try self.usePipeline(options: PipelineOptions(
        colorFormat: self._layer.pixelFormat, depthFormat: depthFormat,
        shader: self._shader2D, blendFunc: blendMode.function))
    } catch {
      printErr(error)
    }

    self._encoder.setDepthStencilState(self._depthStencilDisabled)
    self._encoder.setCullMode(.none)

    var uniforms = Shader2DUniforms(projection: .orthographic(
      left: frame.left, right: frame.right,
      bottom: frame.down, top: frame.up,
      near: 1, far: -1))

    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(&uniforms,
      length: MemoryLayout<Shader2DUniforms>.stride,
      index: VertexShaderInputIdx.uniforms.rawValue)
  }

  internal func submit(
    mesh: RendererDynamicMesh<SpriteBatch.VertexType, SpriteBatch.IndexType>,
    texture: RendererTexture2D?,
    offset: Int, count: Int
  ) {
    assert(self._encoder != nil, "submit can't be called outside of a frame being rendered")

    self._encoder.setFragmentTexture(texture?._textureBuffer ?? defaultTexture._textureBuffer, index: 0)
    self._encoder.setVertexBuffer(mesh._vertBufs[self._currentFrame],
      offset: 0,
      index: VertexShaderInputIdx.vertices.rawValue)
    self._encoder.drawIndexedPrimitives(
      type:              .triangle,
      indexCount:        count,
      indexType:         .uint16,  // Careful!
      indexBuffer:       mesh._idxBufs[self._currentFrame],
      indexBufferOffset: MemoryLayout<SpriteBatch.IndexType>.stride * offset)
  }

  internal func submit(mesh: RendererMesh, instance: ModelBatch.Instance, material: Material) {
    assert(self._encoder != nil, "submit can't be called outside of a frame being rendered")
    var instanceData = VertexShaderInstance(
      model: instance.world,
      normalModel: instance.world.inverse.transpose,
      color: SIMD4(instance.color))
    var fragUniforms = FragmentShaderUniforms(
      cameraPosition: self._cameraPos,
      directionalLight: self._directionalDir,
      ambientColor:  SIMD4(material.ambient),
      diffuseColor:  SIMD4(material.diffuse),
      specularColor: SIMD4(material.specular),
      specularIntensity: material.gloss)

    self._encoder.setVertexBuffer(mesh._vertBuf, offset: 0, index: VertexShaderInputIdx.vertices.rawValue)
    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(&instanceData,
      length: MemoryLayout<VertexShaderInstance>.stride,
      index: VertexShaderInputIdx.instance.rawValue)
    self._encoder.setFragmentBytes(&fragUniforms,
      length: MemoryLayout<FragmentShaderUniforms>.stride,
      index: FragmentShaderInputIdx.uniforms.rawValue)

    self._encoder.drawIndexedPrimitives(
      type:              .triangle,
      indexCount:        mesh.numIndices,
      indexType:         .uint16,
      indexBuffer:       mesh._idxBuf,
      indexBufferOffset: 0)
  }

  internal func submitBatch(mesh: RendererMesh, instances: [ModelBatch.Instance], material: Material) {
    assert(self._encoder != nil, "submitBatch can't be called outside of a frame being rendered")
    let numInstances = instances.count
    assert(numInstances > 0, "submitBatch called with zero instances")

    /*
    let instancesBytes = numInstances * MemoryLayout<VertexShaderInstance>.stride

    // (Re)create instance buffer if needed
    if self._instances[self._currentFrame] == nil || instancesBytes > self._instances[self._currentFrame]!.length {
      guard let instanceBuffer = self.device.makeBuffer(
        length: instancesBytes,
        options: self._defaultStorageMode)
      else {
        fatalError("Failed to (re)create instance buffer")
      }
      self._instances[self._currentFrame] = instanceBuffer
    }
    let instanceBuffer = self._instances[self._currentFrame]!

    // Convert & upload instance data to the GPU
    //FIXME: currently will misbehave if batch is called more than once
    instanceBuffer.contents().withMemoryRebound(to: VertexShaderInstance.self, capacity: numInstances) { data in
      for i in 0..<numInstances {
        let instance = instances[i]
        data[i] = VertexShaderInstance(
          model: instance.world,
          normalModel: instance.world.inverse.transpose,
          color: SIMD4(instance.color))
      }
    }
#if os(macOS)
    if self._defaultStorageMode == .storageModeManaged {
      instanceBuffer.didModifyRange(0..<instancesBytes)
    }
#endif

    self._encoder.setVertexBuffer(instanceBuffer,
      offset: 0,
      index: VertexShaderInputIdx.instance.rawValue)
    */
    let instanceData = instances.map { instance in
      VertexShaderInstance(
        model: instance.world,
        normalModel: instance.world.inverse.transpose,
        color: SIMD4(instance.color))
    }
    var fragUniforms = FragmentShaderUniforms(
      cameraPosition: self._cameraPos,
      directionalLight: self._directionalDir,
      ambientColor:  SIMD4(material.ambient),
      diffuseColor:  SIMD4(material.diffuse),
      specularColor: SIMD4(material.specular),
      specularIntensity: material.gloss)

    self._encoder.setVertexBuffer(mesh._vertBuf, offset: 0, index: VertexShaderInputIdx.vertices.rawValue)
    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(instanceData,
      length: numInstances * MemoryLayout<VertexShaderInstance>.stride,
      index: VertexShaderInputIdx.instance.rawValue)
    self._encoder.setFragmentBytes(&fragUniforms,
      length: MemoryLayout<FragmentShaderUniforms>.stride,
      index: FragmentShaderInputIdx.uniforms.rawValue)

    self._encoder.drawIndexedPrimitives(
      type:              .triangle,
      indexCount:        mesh.numIndices,
      indexType:         .uint16,
      indexBuffer:       mesh._idxBuf,
      indexBufferOffset: 0,
      instanceCount:     numInstances)
  }
}
