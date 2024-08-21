import Foundation

public class Arc4Random: RandomProvider {
  public typealias Output = UInt32

  public static var min: UInt32 { 0x00000000 }
  public static var max: UInt32 { 0xFFFFFFFF }

  private init() {}
  public static let instance = Arc4Random()

  public func stir() {
    arc4random_stir()
  }

  public func next() -> UInt32 {
    arc4random()
  }

  func next(in bound: UInt32) -> UInt32 {
    return arc4random_uniform(bound)
  }

  func next(in bound: Int) -> Int {
    assert(bound <= UInt32.max, "Maximum raw random provider output is smaller than requested bound")
    return Int(arc4random_uniform(UInt32(bound)))
  }
}

public extension Arc4Random {
  func next(in range: Range<UInt32>) -> UInt32 {
    assert(!range.isEmpty, "Ranged next called with empty range")
    return range.lowerBound + next(in: range.upperBound - range.lowerBound)
  }

  func next(in range: ClosedRange<UInt32>) -> UInt32 {
    if range == 0...UInt32.max {
      next()
    } else {
      next(in: range.upperBound - range.lowerBound + 1)
    }
  }

  func next(in range: Range<Int>) -> Int {
    assert(!range.isEmpty, "Ranged next called with empty range")
    return range.lowerBound + next(in: range.upperBound - range.lowerBound)
  }

  func next(in range: ClosedRange<Int>) -> Int {
    assert(range.upperBound - range.lowerBound < Int.max, "Closed range exceeds Int.max")
    return range.lowerBound + next(in: range.upperBound - range.lowerBound + 1)
  }
}
