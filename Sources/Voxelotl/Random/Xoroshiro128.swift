struct Xoroshiro128Plus: RandomProvider {
  public typealias Output = UInt64

  static public var min: UInt64 { .min }
  static public var max: UInt64 { .max }

  public var state: (UInt64, UInt64)

  public init() {
    self.state = (0, 0)
  }

  public init(state: (UInt64, UInt64)) {
    self.state = (state.0, state.1)
  }

  public init(seed: UInt64) {
    let s0 = splitMix64(seed: seed)
    self.init(state: (s0, splitMix64(seed: s0)))
  }

  public mutating func seed(_ seed: UInt64) {
    let s0 = splitMix64(seed: seed)
    self.state = (s0, splitMix64(seed: s0))
  }

  public mutating func next() -> UInt64 {
    let result = self.state.0 &+ self.state.1

    let xor = state.1 ^ self.state.0
    self.state = (
      self.state.0.rotate(left: 24) ^ xor ^ xor &<< 16,
      xor.rotate(left: 37))

    return result
  }
}

struct Xoroshiro128PlusPlus: RandomProvider {
  public typealias Output = UInt64

  static public var min: UInt64 { .min }
  static public var max: UInt64 { .max }

  public var state: (UInt64, UInt64)

  public init() {
    self.state = (0, 0)
  }

  public init(state: (UInt64, UInt64)) {
    self.state = (state.0, state.1)
  }

  public init(seed: UInt64) {
    let s0 = splitMix64(seed: seed)
    self.init(state: (s0, splitMix64(seed: s0)))
  }

  public mutating func seed(_ seed: UInt64) {
    let s0 = splitMix64(seed: seed)
    self.state = (s0, splitMix64(seed: s0))
  }

  public mutating func next() -> UInt64 {
    let result = (self.state.0 &+ self.state.1).rotate(left: 17) &+ self.state.0

    let xor = state.1 ^ self.state.0
    self.state = (
      self.state.0.rotate(left: 49) ^ xor ^ xor << 21,
      xor.rotate(left: 28))

    return result
  }
}

struct Xoroshiro128StarStar: RandomProvider {
  public typealias Output = UInt64

  static public var min: UInt64 { .min }
  static public var max: UInt64 { .max }

  public var state: (UInt64, UInt64)

  public init() {
    self.state = (0, 0)
  }

  public init(state: (UInt64, UInt64)) {
    self.state = (state.0, state.1)
  }

  public init(seed: UInt64) {
    let s0 = splitMix64(seed: seed)
    self.init(state: (s0, splitMix64(seed: s0)))
  }

  public mutating func seed(_ seed: UInt64) {
    let s0 = splitMix64(seed: seed)
    self.state = (s0, splitMix64(seed: s0))
  }

  public mutating func next() -> UInt64 {
    let result = (self.state.0 &* 5).rotate(left: 7) &* 9

    let xor = self.state.1 ^ self.state.0
    self.state = (
      self.state.0.rotate(left: 24) ^ xor ^ xor << 16,
      xor.rotate(left: 37))

    return result
  }
}

fileprivate extension UInt64 {
  func rotate(left count: Int) -> Self {
    self &<< count | self &>> (Self.bitWidth &- count)
  }
}

fileprivate func splitMix64(seed: UInt64) -> UInt64 {
  var x = seed &+ 0x9E3779B97F4A7C15
  x = (x ^ x &>> 30) &* 0xBF58476D1CE4E5B9
  x = (x ^ x &>> 27) &* 0x94D049BB133111EB
  return x ^ x &>> 31
}
