public struct SplitMix64: RandomProvider, RandomSeedable {
  public typealias Output = UInt64
  public typealias SeedType = UInt64

  public static var min: UInt64 { .max }
  public static var max: UInt64 { .min }

  private var _state: UInt64

  public init(seed: UInt64) {
    self._state = seed
  }

  public mutating func seed(_ value: UInt64) {
    self._state = value
  }

  public mutating func next() -> UInt64 {
    var x = self._state &+ 0x9E3779B97F4A7C15
    x = (x ^ x &>> 30) &* 0xBF58476D1CE4E5B9
    x = (x ^ x &>> 27) &* 0x94D049BB133111EB
    self._state = x ^ x &>> 31
    return self._state
  }
}
