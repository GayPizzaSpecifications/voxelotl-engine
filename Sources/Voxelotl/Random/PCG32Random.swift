public struct PCG32Random: RandomProvider, RandomSeedable, RandomStateAccess {
  public typealias Output = UInt32
  public typealias SeedType = (UInt64, UInt64)
  public typealias StateType = (UInt64, UInt64)

  public static var min: UInt32 { .min }
  public static var max: UInt32 { .max }

  private var _state: UInt64, _inc: UInt64

  public var state: (UInt64, UInt64) {
    get { (self._state, self._inc) }
    set {
      self._state = newValue.0
      self._inc   = newValue.1
    }
  }

  init() {
    self._state = 0x853C49E6748FEA9B
    self._inc   = 0xDA3E39CB94B95BDB
  }

  public init(state: (UInt64, UInt64)) {
    self._state = state.0
    self._inc   = state.1
  }

  public init(seed: (UInt64, UInt64)) {
    self.init()
    self.seed(state: seed.0, sequence: seed.1)
  }

  public mutating func seed(_ seed: (UInt64, UInt64)) {
    self.seed(state: seed.0, sequence: seed.1)
  }

  public mutating func seed(state: UInt64, sequence: UInt64) {
    self._state = 0
    self._inc   = sequence << 1 | 0x1
    _ = next()
    self._state &+= state
    _ = next()
  }

  public mutating func next() -> UInt32 {
    let prevState = self._state

    // LCG component
    self._state &*= 6364136223846793005
    self._state &+= self._inc

    // Permutation (XorShift + RotRight)
    let xorShifted = UInt32(truncatingIfNeeded: (prevState &>> 18 ^ prevState) &>> 27)
    let rot59 = UInt32(truncatingIfNeeded: prevState &>> 59)
    return xorShifted &>> rot59 | xorShifted &<< UInt32(bitPattern: -Int32(bitPattern: rot59) & 0x1F)
  }
}
