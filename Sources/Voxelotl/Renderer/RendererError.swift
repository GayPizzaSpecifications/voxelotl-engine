enum RendererError: Error {
  case initFailure(_ message: String)
  case loadFailure(_ message: String)
  case drawFailure(_ message: String)
}
