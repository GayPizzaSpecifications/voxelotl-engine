import AppKit

struct NSImageLoader {
  private static let flipVertically = true

  static func open(url: URL) throws -> Image2D {
    try autoreleasepool {
      // Open as a CoreGraphics image
      guard let nsImage = NSImage(contentsOf: url),
        let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
      else {
        throw ImageLoaderError.openFailed("Failed to open image \"\(url.absoluteString)\"")
      }

      // Convert 8-bit ARGB (sRGB) w/ pre-multiplied alpha
      let alphaInfo = cgImage.alphaInfo == .none
        ? CGImageAlphaInfo.noneSkipLast
        : CGImageAlphaInfo.premultipliedLast
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: nil,
          width: cgImage.width,
          height: cgImage.height,
          bitsPerComponent: 8,
          bytesPerRow: cgImage.width * 4,
          space: colorSpace,
          bitmapInfo: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
      else {
        throw ImageLoaderError.openFailed("Couldn't create graphics context")
      }

      let dstRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
      if flipVertically {
        // Flip the image vertically
        let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cgImage.height))
        context.concatenate(flipVertical)
        context.draw(cgImage, in: dstRect)
      } else {
        context.draw(cgImage, in: dstRect)
      }

      // Convert the context to a raw Data block and return as an Image2D
      guard let data = context.data else {
        throw ImageLoaderError.openFailed("Context data is null")
      }
      return Image2D(
        Data(bytes: data, count: context.bytesPerRow * context.height),
        format: .argb8888,
        width: context.width,
        height: context.height,
        stride: context.bytesPerRow)
    }
  }
}

struct Image2D {
  let data: Data
  let format: Format
  let width: Int, height: Int, stride: Int

  public enum Format {
    case argb8888, abgr8888
    case rgb888, bgr888
    //case l8, l16, a8, al88
    case s3tc_bc1, s3tc_bc2_premul
    case s3tc_bc2, s3tc_bc3_premul
    case s3tc_bc3, rgtc_bc4, rgtc_bc5_3dc
  }
}

extension Image2D {
  init(_ data: Data, format: Format, width: Int, height: Int, stride: Int) {
    self.data = data
    self.format = format
    self.width = width
    self.height = height
    self.stride = stride
  }
}

enum ImageLoaderError: Error {
  case openFailed(_ message: String)
}


extension Bundle {
  func getResource(_ path: String) throws -> URL {
    guard let extIndex = path.lastIndex(of: ".") else {
      throw ContentError.resourceNotFound("Malformed resource path \"\(path)\"")
    }
    let name = String(path[..<extIndex]), ext = String(path[extIndex...])
    guard let resourceUrl: URL = Bundle.main.url(
      forResource: name,
      withExtension: ext)
    else {
      throw ContentError.resourceNotFound("Resource \"\(path)\" doesn't exist")
    }
    return resourceUrl
  }
}

public enum ContentError: Error {
  case resourceNotFound(_ message: String)
}
