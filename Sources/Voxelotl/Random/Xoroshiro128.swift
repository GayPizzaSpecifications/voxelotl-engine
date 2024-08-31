public struct Xoroshiro128Plus: RandomProvider, RandomStateAccess {
  public typealias Output = UInt64
  public typealias StateType = (UInt64, UInt64)

  public static var min: UInt64 { .min }
  public static var max: UInt64 { .max }

  public var state: (UInt64, UInt64)

  public init() {
    self.state = (0, 0)
  }

  public init(state: (UInt64, UInt64)) {
    self.state = (state.0, state.1)
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

public struct Xoroshiro128PlusPlus: RandomProvider, RandomStateAccess {
  public typealias Output = UInt64
  public typealias StateType = (UInt64, UInt64)

  public static var min: UInt64 { .min }
  public static var max: UInt64 { .max }

  public var state: (UInt64, UInt64)

  public init() {
    self.state = (0, 0)
  }

  public init(state: (UInt64, UInt64)) {
    self.state = (state.0, state.1)
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

public struct Xoroshiro128StarStar: RandomProvider, RandomStateAccess {
  public typealias Output = UInt64
  public typealias StateType = (UInt64, UInt64)

  public static var min: UInt64 { .min }
  public static var max: UInt64 { .max }

  public var state: (UInt64, UInt64)

  public init() {
    self.state = (0, 0)
  }

  public init(state: (UInt64, UInt64)) {
    self.state = (state.0, state.1)
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
  @inline(__always) func rotate(left count: Int) -> Self {
    self &<< count | self &>> (Self.bitWidth &- count)
  }
}
