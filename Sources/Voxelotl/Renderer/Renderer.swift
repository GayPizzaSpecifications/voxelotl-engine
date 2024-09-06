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
  private var layer: CAMetalLayer
  private var backBufferSize: Size<Int>
  private var _clearColor: Color<Double>
  private var _aspectRatio: Float
  private var queue: MTLCommandQueue
  private var lib: MTLLibrary
  private let passDescription = MTLRenderPassDescriptor()
  private var pso: MTLRenderPipelineState
  private var depthStencilState: MTLDepthStencilState
  private let _defaultStorageMode: MTLResourceOptions

  private var depthTextures: [MTLTexture]
  private var _instances: [MTLBuffer?]

  private var _encoder: MTLRenderCommandEncoder! = nil

  private var defaultTexture: MTLTexture
  private var cubeTexture: MTLTexture? = nil

  private let inFlightSemaphore = DispatchSemaphore(value: numFramesInFlight)
  private var currentFrame = 0

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
    self.layer = metalLayer

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

    layer.device = device
    layer.pixelFormat = colorFormat

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

    self._instances = [MTLBuffer?](repeating: nil, count: numFramesInFlight)

    let stencilDepthDescription = MTLDepthStencilDescriptor()
    stencilDepthDescription.depthCompareFunction = .less  // OpenGL default
    stencilDepthDescription.isDepthWriteEnabled  = true
    guard let depthStencilState = device.makeDepthStencilState(descriptor: stencilDepthDescription) else {
      throw RendererError.initFailure("Failed to create depth stencil state")
    }
    self.depthStencilState = depthStencilState

    // Create shader library & grab functions
    do {
      self.lib = try device.makeDefaultLibrary(bundle: Bundle.main)
    } catch {
      throw RendererError.initFailure("Metal shader compilation failed:\n\(error.localizedDescription)")
    }
    let vertexProgram   = lib.makeFunction(name: "vertexMain")
    let fragmentProgram = lib.makeFunction(name: "fragmentMain")

    // Set up pipeline state
    let pipeDescription = MTLRenderPipelineDescriptor()
    pipeDescription.vertexFunction   = vertexProgram
    pipeDescription.fragmentFunction = fragmentProgram
    pipeDescription.colorAttachments[0].pixelFormat = layer.pixelFormat
    pipeDescription.depthAttachmentPixelFormat = depthFormat
    do {
      self.pso = try device.makeRenderPipelineState(descriptor: pipeDescription)
    } catch {
      throw RendererError.initFailure("Failed to create pipeline state: \(error.localizedDescription)")
    }

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

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, resourcePath path: String,
    _ transitoryOpt: MTLResourceOptions
  ) throws -> MTLTexture {
    do {
      return try loadTexture(device, queue, url: Bundle.main.getResource(path), transitoryOpt)
    } catch ContentError.resourceNotFound(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, url imageUrl: URL,
    _ transitoryOpt: MTLResourceOptions
  ) throws -> MTLTexture {
    do {
      return try loadTexture(device, queue, image2D: try NSImageLoader.open(url: imageUrl), transitoryOpt)
    } catch ImageLoaderError.openFailed(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, image2D image: Image2D,
    _ transitoryOpt: MTLResourceOptions
  ) throws -> MTLTexture {
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

      return newTexture
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
      guard let rt = layer.nextDrawable() else {
        throw RendererError.drawFailure("Failed to get next drawable render target")
      }

      passDescription.colorAttachments[0].clearColor  = MTLClearColor(self._clearColor)
      passDescription.colorAttachments[0].texture = rt.texture
      passDescription.depthAttachment.texture = self.depthTextures[self.currentFrame]

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
      encoder.setRenderPipelineState(pso)
      encoder.setDepthStencilState(depthStencilState)
      encoder.setFragmentTexture(cubeTexture ?? defaultTexture, index: 0)

      self._encoder = encoder
      frameFunc(self)
      self._encoder = nil

      encoder.endEncoding()
      commandBuf.present(rt)
      commandBuf.commit()

      self.currentFrame &+= 1
      if self.currentFrame == numFramesInFlight {
        self.currentFrame = 0
      }
    }
  }

  func draw(model: matrix_float4x4, color: Color<Float>, mesh: RendererMesh, material: Material, environment: Environment, camera: Camera) {
    assert(self._encoder != nil, "draw can't be called outside of a frame being rendered")

    var vertUniforms = VertexShaderUniforms(projView: camera.viewProjection)
    var fragUniforms = FragmentShaderUniforms(
      cameraPosition: camera.position,
      directionalLight: normalize(environment.lightDirection),
      ambientColor:  SIMD4(material.ambient),
      diffuseColor:  SIMD4(material.diffuse),
      specularColor: SIMD4(material.specular),
      specularIntensity: material.gloss)
    var instance = VertexShaderInstance(
      model:       model,
      normalModel: model.inverse.transpose,
      color:       SIMD4(color))

    self._encoder.setCullMode(.init(environment.cullFace))

    self._encoder.setVertexBuffer(mesh._vertBuf, offset: 0, index: VertexShaderInputIdx.vertices.rawValue)
    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(&instance,
      length: MemoryLayout<VertexShaderInstance>.stride,
      index: VertexShaderInputIdx.instance.rawValue)
    self._encoder.setVertexBytes(&vertUniforms,
      length: MemoryLayout<VertexShaderUniforms>.stride,
      index: VertexShaderInputIdx.uniforms.rawValue)
    self._encoder.setFragmentBytes(&fragUniforms,
      length: MemoryLayout<FragmentShaderUniforms>.stride,
      index: FragmentShaderInputIdx.uniforms.rawValue)

    self._encoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: mesh.numIndices,
      indexType: .uint16,
      indexBuffer: mesh._idxBuf,
      indexBufferOffset: 0)
  }

  func createModelBatch() -> ModelBatch {
    return ModelBatch(self)
  }

  func batch(instances: [ModelBatch.Instance], mesh: RendererMesh, material: Material, environment: Environment, camera: Camera) {
    assert(self._encoder != nil, "batch can't be called outside of a frame being rendered")

    var vertUniforms = VertexShaderUniforms(projView: camera.viewProjection)
    var fragUniforms = FragmentShaderUniforms(
      cameraPosition: camera.position,
      directionalLight: normalize(environment.lightDirection),
      ambientColor:  SIMD4(material.ambient),
      diffuseColor:  SIMD4(material.diffuse),
      specularColor: SIMD4(material.specular),
      specularIntensity: material.gloss)

    let numInstances = instances.count
    let instancesBytes = numInstances * MemoryLayout<VertexShaderInstance>.stride

    // (Re)create instance buffer if needed
    if self._instances[self.currentFrame] == nil || instancesBytes > self._instances[self.currentFrame]!.length {
      guard let instanceBuffer = self.device.makeBuffer(
        length: instancesBytes,
        options: self._defaultStorageMode)
      else {
        fatalError("Failed to (re)create instance buffer")
      }
      self._instances[self.currentFrame] = instanceBuffer
    }
    let instanceBuffer = self._instances[self.currentFrame]!

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

    self._encoder.setCullMode(.init(environment.cullFace))

    self._encoder.setVertexBuffer(mesh._vertBuf, offset: 0, index: VertexShaderInputIdx.vertices.rawValue)
    self._encoder.setVertexBuffer(instanceBuffer,
      offset: 0,
      index: VertexShaderInputIdx.instance.rawValue)
    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(&vertUniforms,
      length: MemoryLayout<VertexShaderUniforms>.stride,
      index: VertexShaderInputIdx.uniforms.rawValue)
    self._encoder.setFragmentBytes(&fragUniforms,
      length: MemoryLayout<FragmentShaderUniforms>.stride,
      index: FragmentShaderInputIdx.uniforms.rawValue)

    self._encoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: mesh.numIndices,
      indexType: .uint16,
      indexBuffer: mesh._idxBuf,
      indexBufferOffset: 0,
      instanceCount: numInstances)
  }
}

public struct RendererMesh: Hashable {
  fileprivate let _vertBuf: MTLBuffer, _idxBuf: MTLBuffer
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

extension MTLClearColor {
  init(_ color: Color<Double>) {
    self.init(red: color.r, green: color.g, blue: color.b, alpha: color.a)
  }
}

fileprivate extension MTLCullMode {
  init(_ face: Environment.Face) {
    self = switch face {
    case .none: .none
    case .front: .front
    case .back: .back
    }
  }
}

enum RendererError: Error {
  case initFailure(_ message: String)
  case loadFailure(_ message: String)
  case drawFailure(_ message: String)
}
