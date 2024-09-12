import Metal

internal struct PipelineOptions: Hashable {
  let colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat
  let shader: Shader
  let blendFunc: BlendFunc
}

internal extension PipelineOptions {
  func createPipeline(_ device: MTLDevice) throws -> MTLRenderPipelineState {
    let pipeDescription = MTLRenderPipelineDescriptor()
    pipeDescription.vertexFunction   = self.shader.vertexProgram
    pipeDescription.fragmentFunction = self.shader.fragmentProgram
    pipeDescription.colorAttachments[0].pixelFormat = self.colorFormat
    self.blendFunc.setBlend(colorAttachment: &pipeDescription.colorAttachments[0])
    pipeDescription.depthAttachmentPixelFormat = self.depthFormat
    do {
      return try device.makeRenderPipelineState(descriptor: pipeDescription)
    } catch {
      throw RendererError.initFailure("Failed to create pipeline state: \(error.localizedDescription)")
    }
  }
}
