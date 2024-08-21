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

  public func next(in bound: Int) -> Int {
    assert(bound <= Self.max)
    return Int(arc4random_uniform(UInt32(bound)))
  }

  public func next(in range: Range<Int>) -> Int {
    return range.lowerBound + next(in: range.upperBound - range.lowerBound)
  }
}
