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

class Renderer {
  private var device: MTLDevice
  private var layer: CAMetalLayer
  private var viewport = MTLViewport()
  private var queue: MTLCommandQueue
  private var lib: MTLLibrary
  private let passDescription = MTLRenderPassDescriptor()
  private var pso: MTLRenderPipelineState

  private var vtxBuffer: MTLBuffer, idxBuffer: MTLBuffer
  private var defaultTexture: MTLTexture
  private var cubeTexture: MTLTexture? = nil

  fileprivate static func createMetalDevice() -> MTLDevice? {
    MTLCopyAllDevices().reduce(nil, { best, dev in
      if best == nil { dev }
      else if !best!.isLowPower || dev.isLowPower { best }
      else if best!.supportsRaytracing || !dev.supportsRaytracing { best }
      else { dev }
    })
  }

  init(layer metalLayer: CAMetalLayer) throws {
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
    passDescription.colorAttachments[0].loadAction  = MTLLoadAction.clear
    passDescription.colorAttachments[0].storeAction = MTLStoreAction.store
    passDescription.colorAttachments[0].clearColor  = MTLClearColorMake(0.1, 0.1, 0.1, 1.0)

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

    do {
      self.defaultTexture = try Self.loadTexture(device, image2D: Image2D(Data([
          0xFF, 0x00, 0xFF, 0xFF,  0x00, 0x00, 0x00, 0xFF,
          0x00, 0x00, 0x00, 0xFF,  0xFF, 0x00, 0xFF, 0xFF
        ]), format: .abgr8888, width: 2, height: 2, stride: 2 * 4))
    } catch {
      throw RendererError.initFailure("Failed to create default texture")
    }

    do {
      self.cubeTexture = try Self.loadTexture(device, resourcePath: "test.png")
    } catch RendererError.loadFailure(let message) {
      print("Failed to load texture image: \(message)")
    } catch {
      print("Failed to load texture image: unknown error")
    }
  }

  deinit {
    
  }

  static func loadTexture(_ device: MTLDevice, resourcePath path: String) throws -> MTLTexture {
    do {
      return try loadTexture(device, url: Bundle.main.getResource(path))
    } catch ContentError.resourceNotFound(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, url imageUrl: URL) throws -> MTLTexture {
    do {
      return try loadTexture(device, image2D: try NSImageLoader.open(url: imageUrl))
    } catch ImageLoaderError.openFailed(let message) {
      throw RendererError.loadFailure(message)
    }
  }

  static func loadTexture(_ device: MTLDevice, image2D image: Image2D) throws -> MTLTexture {
    let texDesc = MTLTextureDescriptor()
    texDesc.width  = image.width
    texDesc.height = image.height
    texDesc.pixelFormat = .rgba8Unorm_srgb
    texDesc.textureType = .type2D
    texDesc.storageMode = .managed
    texDesc.usage = .shaderRead
    guard let newTexture = device.makeTexture(descriptor: texDesc) else {
      throw RendererError.loadFailure("Failed to create texture descriptor")
    }
    image.data.withUnsafeBytes { bytes in
      newTexture.replace(
        region: .init(
          origin: .init(x: 0, y: 0, z: 0),
          size: .init(width: image.width, height: image.height, depth: 1)),
        mipmapLevel: 0,
        withBytes: bytes.baseAddress!,
        bytesPerRow: image.stride)
    }
    return newTexture
  }

  func resize(size: SIMD2<Int>) {
    self.viewport = MTLViewport(
      originX: 0.0,
      originY: 0.0,
      width:  Double(size.x),
      height: Double(size.y),
      znear: 1.0,
      zfar: -1.0)
  }

  func paint() throws {
    guard let rt = layer.nextDrawable() else {
      throw RendererError.drawFailure("Failed to get next drawable render target")
    }

    passDescription.colorAttachments[0].texture = rt.texture

    guard let commandBuf: MTLCommandBuffer = queue.makeCommandBuffer() else {
      throw RendererError.drawFailure("Failed to make command buffer from queue")
    }
    guard let encoder = commandBuf.makeRenderCommandEncoder(descriptor: passDescription) else {
      throw RendererError.drawFailure("Failed to make render encoder from command buffer")
    }

    encoder.setViewport(viewport)
    encoder.setCullMode(MTLCullMode.none)
    encoder.setRenderPipelineState(pso)

    encoder.setFragmentTexture(cubeTexture ?? defaultTexture, index: 0)
    encoder.setVertexBuffer(vtxBuffer,
      offset: 0,
      index: ShaderInputIdx.vertices.rawValue)
    encoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: cubeIndices.count,
      indexType: .uint16,
      indexBuffer: idxBuffer,
      indexBufferOffset: 0)

    encoder.endEncoding()
    commandBuf.present(rt)
    commandBuf.commit()
  }
}

enum RendererError: Error {
  case initFailure(_ message: String)
  case loadFailure(_ message: String)
  case drawFailure(_ message: String)
}
