public struct DarwinRandom: RandomProvider {
  public typealias Output = Int

  public static var min: Int { 0x00000000 }
  public static var max: Int { 0x7FFFFFFF }

  private var state: Int

  init() {
    self.state = 0
  }

  public init(seed: Int) {
    self.state = seed
  }

  mutating public func seed(with seed: Int) {
    self.state = seed
  }

  mutating public func next() -> Int {
    if self.state == 0 {
      self.state = 123459876
    }
    let hi = self.state / 127773
    let lo = self.state - hi * 127773
    self.state = 16807 * lo - 2836 * hi
    if self.state < 0 {
      self.state += Self.max
    }
    return self.state % (Self.max + 1)
  }
}
