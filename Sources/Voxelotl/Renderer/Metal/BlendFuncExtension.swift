import Metal

internal extension BlendFunc {
  func setBlend(colorAttachment: inout MTLRenderPipelineColorAttachmentDescriptor) {
    switch self {
    case .off:
      colorAttachment.isBlendingEnabled = false
    case .on(let srcFactor, let dstFactor, let equation):
      colorAttachment.isBlendingEnabled = true
      colorAttachment.rgbBlendOperation = .init(equation)
      colorAttachment.alphaBlendOperation = .init(equation)
      colorAttachment.sourceRGBBlendFactor = .init(srcFactor)
      colorAttachment.sourceAlphaBlendFactor = .init(srcFactor)
      colorAttachment.destinationRGBBlendFactor = .init(dstFactor)
      colorAttachment.destinationAlphaBlendFactor = .init(dstFactor)
    case .separate(let srcColor, let srcAlpha, let dstColor, let dstAlpha, let equColor, let equAlpha):
      colorAttachment.isBlendingEnabled = true
      colorAttachment.rgbBlendOperation = .init(equColor)
      colorAttachment.alphaBlendOperation = .init(equAlpha)
      colorAttachment.sourceRGBBlendFactor = .init(srcColor)
      colorAttachment.sourceAlphaBlendFactor = .init(srcAlpha)
      colorAttachment.destinationRGBBlendFactor = .init(dstColor)
      colorAttachment.destinationAlphaBlendFactor = .init(dstAlpha)
    }
  }
}

internal extension MTLBlendOperation {
  init(_ equation: BlendFuncEquation) {
    self = switch equation {
    case .add:             .add
    case .subtract:        .subtract
    case .reverseSubtract: .reverseSubtract
    case .min:             .min
    case .max:             .max
    }
  }
}

internal extension MTLBlendFactor {
  init(_ source: BlendFuncSourceFactor) {
    self = switch source {
    case .zero:                  .zero
    case .one:                   .one
    case .srcColor:              .sourceColor
    case .oneMinusSrcColor:      .oneMinusSourceColor
    case .srcAlpha:              .sourceAlpha
    case .oneMinusSrcAlpha:      .oneMinusSourceAlpha
    case .dstColor:              .destinationColor
    case .oneMinusDstColor:      .oneMinusDestinationColor
    case .dstAlpha:              .destinationAlpha
    case .oneMinusDstAlpha:      .oneMinusDestinationAlpha
    case .srcAlphaSaturate:      .sourceAlphaSaturated
    /*
    case .constantColor:         .blendColor
    case .oneMinusConstantColor: .oneMinusBlendColor
    case .constantAlpha:         .blendAlpha
    case .oneMinusConstantAlpha: .oneMinusBlendAlpha
    */
    case .src1Color:             .source1Color
    case .oneMinusSrc1Color:     .oneMinusSource1Color
    case .src1Alpha:             .source1Alpha
    case .oneMinusSrc1Alpha:     .oneMinusSource1Alpha
    }
  }

  init(_ destination: BlendFuncDestinationFactor) {
    self = switch destination {
    case .zero:                  .zero
    case .one:                   .one
    case .srcColor:              .sourceColor
    case .oneMinusSrcColor:      .oneMinusSourceColor
    case .srcAlpha:              .sourceAlpha
    case .oneMinusSrcAlpha:      .oneMinusSourceAlpha
    case .dstColor:              .destinationColor
    case .oneMinusDstColor:      .oneMinusDestinationColor
    case .dstAlpha:              .destinationAlpha
    case .oneMinusDstAlpha:      .oneMinusDestinationAlpha
    /*
    case .constantColor:         .blendColor
    case .oneMinusConstantColor: .oneMinusBlendColor
    case .constantAlpha:         .blendAlpha
    case .oneMinusConstantAlpha: .oneMinusBlendAlpha
    */
    }
  }
}
