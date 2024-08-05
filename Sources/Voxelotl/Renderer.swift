import Foundation
import Metal
import QuartzCore.CAMetalLayer
import simd
import ShaderTypes

class Renderer {
  fileprivate static let vertices = [
    ShaderVertex(position: SIMD4<Float>(-0.5, -0.5, 0.0, 1.0), color: SIMD4<Float>(1.0, 0.0, 0.0, 1.0)),
    ShaderVertex(position: SIMD4<Float>( 0.0,  0.5, 0.0, 1.0), color: SIMD4<Float>(0.0, 1.0, 0.0, 1.0)),
    ShaderVertex(position: SIMD4<Float>( 0.5, -0.5, 0.0, 1.0), color: SIMD4<Float>(0.0, 0.0, 1.0, 1.0))
  ]

  private var device: MTLDevice
  private var layer: CAMetalLayer
  private var viewport = MTLViewport()
  private var queue: MTLCommandQueue
  private var lib: MTLLibrary
  private let passDescription = MTLRenderPassDescriptor()
  private var pso: MTLRenderPipelineState

  private var vtxBuffer: MTLBuffer! = nil

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

    // Create vertex buffers
    guard let vtxBuffer = device.makeBuffer(
      bytes: Self.vertices,
      length: Self.vertices.count * MemoryLayout<ShaderVertex>.stride,
      options: .storageModeManaged)
    else {
      throw RendererError.initFailure("Failed to create vertex buffer")
    }
    self.vtxBuffer = vtxBuffer
  }

  deinit {
    
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

    encoder.setVertexBuffer(vtxBuffer, offset: 0, index: ShaderInputIdx.vertices.rawValue)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    encoder.endEncoding()
    commandBuf.present(rt)
    commandBuf.commit()
  }
}

enum RendererError: Error {
  case initFailure(_ message: String)
  case drawFailure(_ message: String)
}
