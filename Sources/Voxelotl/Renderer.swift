import Foundation
import Metal
import QuartzCore.CAMetalLayer
import simd
import ShaderTypes

fileprivate let cubeVertices: [ShaderVertex] = [
  .init(position: .init(-1, -1,  1, 1), normal: .init( 0,  0,  1,  0), texCoord: .init(0, 0)),
  .init(position: .init( 1, -1,  1, 1), normal: .init( 0,  0,  1,  0), texCoord: .init(1, 0)),
  .init(position: .init(-1,  1,  1, 1), normal: .init( 0,  0,  1,  0), texCoord: .init(0, 1)),
  .init(position: .init( 1,  1,  1, 1), normal: .init( 0,  0,  1,  0), texCoord: .init(1, 1)),
  .init(position: .init( 1, -1,  1, 1), normal: .init( 1,  0,  0,  0), texCoord: .init(0, 0)),
  .init(position: .init( 1, -1, -1, 1), normal: .init( 1,  0,  0,  0), texCoord: .init(1, 0)),
  .init(position: .init( 1,  1,  1, 1), normal: .init( 1,  0,  0,  0), texCoord: .init(0, 1)),
  .init(position: .init( 1,  1, -1, 1), normal: .init( 1,  0,  0,  0), texCoord: .init(1, 1)),
  .init(position: .init( 1, -1, -1, 1), normal: .init( 0,  0, -1,  0), texCoord: .init(0, 0)),
  .init(position: .init(-1, -1, -1, 1), normal: .init( 0,  0, -1,  0), texCoord: .init(1, 0)),
  .init(position: .init( 1,  1, -1, 1), normal: .init( 0,  0, -1,  0), texCoord: .init(0, 1)),
  .init(position: .init(-1,  1, -1, 1), normal: .init( 0,  0, -1,  0), texCoord: .init(1, 1)),
  .init(position: .init(-1, -1, -1, 1), normal: .init(-1,  0,  0,  0), texCoord: .init(0, 0)),
  .init(position: .init(-1, -1,  1, 1), normal: .init(-1,  0,  0,  0), texCoord: .init(1, 0)),
  .init(position: .init(-1,  1, -1, 1), normal: .init(-1,  0,  0,  0), texCoord: .init(0, 1)),
  .init(position: .init(-1,  1,  1, 1), normal: .init(-1,  0,  0,  0), texCoord: .init(1, 1)),
  .init(position: .init(-1, -1, -1, 1), normal: .init( 0, -1,  0,  0), texCoord: .init(0, 0)),
  .init(position: .init( 1, -1, -1, 1), normal: .init( 0, -1,  0,  0), texCoord: .init(1, 0)),
  .init(position: .init(-1, -1,  1, 1), normal: .init( 0, -1,  0,  0), texCoord: .init(0, 1)),
  .init(position: .init( 1, -1,  1, 1), normal: .init( 0, -1,  0,  0), texCoord: .init(1, 1)),
  .init(position: .init(-1,  1,  1, 1), normal: .init( 0,  1,  0,  0), texCoord: .init(0, 0)),
  .init(position: .init( 1,  1,  1, 1), normal: .init( 0,  1,  0,  0), texCoord: .init(1, 0)),
  .init(position: .init(-1,  1, -1, 1), normal: .init( 0,  1,  0,  0), texCoord: .init(0, 1)),
  .init(position: .init( 1,  1, -1, 1), normal: .init( 0,  1,  0,  0), texCoord: .init(1, 1)),
]

fileprivate let cubeIndices: [UInt16] = [
   0,  1,  2,  2,  1,  3,
   4,  5,  6,  6,  5,  7,
   8,  9, 10, 10,  9, 11,
  12, 13, 14, 14, 13, 15,
  16, 17, 18, 18, 17, 19,
  20, 21, 22, 22, 21, 23
]

fileprivate let numFramesInFlight: Int = 3
fileprivate let depthFormat: MTLPixelFormat = .depth16Unorm

public class Renderer {
  private var device: MTLDevice
  private var layer: CAMetalLayer
  private var backBufferSize: Size<Int>
  private var _aspectRatio: Float
  private var queue: MTLCommandQueue
  private var lib: MTLLibrary
  private let passDescription = MTLRenderPassDescriptor()
  private var pso: MTLRenderPipelineState
  private var depthStencilState: MTLDepthStencilState
  private var depthTextures: [MTLTexture]

  private var _encoder: MTLRenderCommandEncoder! = nil

  private var vtxBuffer: MTLBuffer, idxBuffer: MTLBuffer
  private var defaultTexture: MTLTexture
  private var cubeTexture: MTLTexture? = nil

  private let inFlightSemaphore = DispatchSemaphore(value: numFramesInFlight)
  private var currentFrame = 0

  var frame: Rect<Int> { .init(origin: .zero, size: self.backBufferSize) }
  var aspectRatio: Float { self._aspectRatio }

  fileprivate static func createMetalDevice() -> MTLDevice? {
    MTLCopyAllDevices().reduce(nil, { best, dev in
      if best == nil { dev }
      else if !best!.isLowPower || dev.isLowPower { best }
      else if best!.supportsRaytracing || !dev.supportsRaytracing { best }
      else { dev }
    })
  }

  internal init(layer metalLayer: CAMetalLayer, size: Size<Int>) throws {
    self.layer = metalLayer

    // Select best Metal device
    guard let device = Self.createMetalDevice() else {
      throw RendererError.initFailure("Failed to create Metal device")
    }
    self.device = device

    layer.device = device
    layer.pixelFormat = MTLPixelFormat.bgra8Unorm

    // Setup command queue
    guard let queue = device.makeCommandQueue() else {
      throw RendererError.initFailure("Failed to create command queue")
    }
    self.queue = queue

    self.backBufferSize = size
    self._aspectRatio = Float(self.backBufferSize.w) / Float(self.backBufferSize.w)

    passDescription.colorAttachments[0].loadAction  = .clear
    passDescription.colorAttachments[0].storeAction = .store
    passDescription.colorAttachments[0].clearColor  = MTLClearColorMake(0.1, 0.1, 0.1, 1.0)
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

    // Create cube mesh buffers
    guard let vtxBuffer = device.makeBuffer(
      bytes: cubeVertices,
      length: cubeVertices.count * MemoryLayout<ShaderVertex>.stride,
      options: .storageModeManaged)
    else {
      throw RendererError.initFailure("Failed to create vertex buffer")
    }
    self.vtxBuffer = vtxBuffer
    guard let idxBuffer = device.makeBuffer(
      bytes: cubeIndices,
      length: cubeIndices.count * MemoryLayout<UInt16>.stride,
      options: .storageModeManaged)
    else {
      throw RendererError.initFailure("Failed to create index buffer")
    }
    self.idxBuffer = idxBuffer

    // Create a default texture
    do {
      self.defaultTexture = try Self.loadTexture(device, queue, image2D: Image2D(Data([
          0xFF, 0x00, 0xFF, 0xFF,  0x00, 0x00, 0x00, 0xFF,
          0x00, 0x00, 0x00, 0xFF,  0xFF, 0x00, 0xFF, 0xFF
        ]), format: .abgr8888, width: 2, height: 2, stride: 2 * 4))
    } catch {
      throw RendererError.initFailure("Failed to create default texture")
    }

    // Load texture from a file in the bundle
    do {
      self.cubeTexture = try Self.loadTexture(device, queue, resourcePath: "test.png")
    } catch RendererError.loadFailure(let message) {
      printErr("Failed to load texture image: \(message)")
    } catch {
      printErr("Failed to load texture image: unknown error")
    }
  }

  deinit {
    
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, resourcePath path: String) throws -> MTLTexture {
    do {
      return try loadTexture(device, queue, url: Bundle.main.getResource(path))
    } catch ContentError.resourceNotFound(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, url imageUrl: URL) throws -> MTLTexture {
    do {
      return try loadTexture(device, queue, image2D: try NSImageLoader.open(url: imageUrl))
    } catch ImageLoaderError.openFailed(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, _ queue: MTLCommandQueue, image2D image: Image2D) throws -> MTLTexture {
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
        device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: [ .storageModeShared ])
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
      texDescriptor.depth = 1
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

      encoder.setCullMode(.back)
      encoder.setFrontFacing(.counterClockwise)  // OpenGL default
      encoder.setViewport(Self.makeViewport(rect: self.frame))
      encoder.setRenderPipelineState(pso)
      encoder.setDepthStencilState(depthStencilState)
      encoder.setFragmentTexture(cubeTexture ?? defaultTexture, index: 0)
      encoder.setVertexBuffer(vtxBuffer,
        offset: 0,
        index: ShaderInputIdx.vertices.rawValue)

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

  func batch(instances: [Instance], camera: Camera) {
    assert(self._encoder != nil, "batch can't be called outside of a frame being rendered")
    assert(instances.count < 52)

    var uniforms = ShaderUniforms(projView: camera.viewProjection)
    let instances = instances.map { (instance: Instance) -> ShaderInstance in
      ShaderInstance(
        model:
          .translate(instance.position) *
          matrix_float4x4(instance.rotation) *
          .scale(instance.scale),
        color: .init(
          UInt8(instance.color.x * 0xFF),
          UInt8(instance.color.y * 0xFF),
          UInt8(instance.color.z * 0xFF),
          UInt8(instance.color.w * 0xFF)))
    }

    // Ideal as long as our uniforms total 4 KB or less
    self._encoder.setVertexBytes(instances,
      length: instances.count * MemoryLayout<ShaderInstance>.stride,
      index: ShaderInputIdx.instance.rawValue)
    self._encoder.setVertexBytes(&uniforms,
      length: MemoryLayout<ShaderUniforms>.stride,
      index: ShaderInputIdx.uniforms.rawValue)

    self._encoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: cubeIndices.count,
      indexType: .uint16,
      indexBuffer: idxBuffer,
      indexBufferOffset: 0,
      instanceCount: instances.count)
  }
}

enum RendererError: Error {
  case initFailure(_ message: String)
  case loadFailure(_ message: String)
  case drawFailure(_ message: String)
}
