public protocol RandomProvider {
  associatedtype Output: FixedWidthInteger

  static var min: Output { get }
  static var max: Output { get }

  mutating func next() -> Output
}

public protocol RandomSeedable {
  associatedtype SeedType: FixedWidthInteger

  init(seed: SeedType)
  mutating func seed(_ value: SeedType)
}

public protocol RandomStateAccess {
  associatedtype StateType

  var state: StateType { get set }

  init(state: StateType)
}
