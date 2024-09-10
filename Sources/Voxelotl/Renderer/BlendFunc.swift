internal enum BlendFunc: Hashable {
  case off
  case on(src: BlendFuncSourceFactor = .one, dst: BlendFuncDestinationFactor = .zero, equation: BlendFuncEquation = .add)
  case separate(
    srcColor: BlendFuncSourceFactor,      srcAlpha: BlendFuncSourceFactor,
    dstColor: BlendFuncDestinationFactor, dstAlpha: BlendFuncDestinationFactor,
    equColor: BlendFuncEquation,          equAlpha: BlendFuncEquation)
}

enum BlendFuncSourceFactor: Hashable {
  case zero, one
  case srcColor, oneMinusSrcColor
  case dstColor, oneMinusDstColor
  case srcAlpha, oneMinusSrcAlpha
  case dstAlpha, oneMinusDstAlpha
  /*
  case constantColor, oneMinusConstantColor
  case constantAlpha, oneMinusConstantAlpha
  */
  case srcAlphaSaturate
  case src1Color, oneMinusSrc1Color
  case src1Alpha, oneMinusSrc1Alpha
}

enum BlendFuncDestinationFactor: Hashable {
  case zero, one
  case srcColor, oneMinusSrcColor
  case dstColor, oneMinusDstColor
  case srcAlpha, oneMinusSrcAlpha
  case dstAlpha, oneMinusDstAlpha
  /*
  case constantColor, oneMinusConstantColor
  case constantAlpha, oneMinusConstantAlpha
  */
}

enum BlendFuncEquation: Hashable {
  case add
  case subtract, reverseSubtract
  case min, max
}
