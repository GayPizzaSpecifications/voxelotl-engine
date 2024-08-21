public protocol RandomProvider {
  associatedtype Output: FixedWidthInteger

  static var min: Output { get }
  static var max: Output { get }

  mutating func next() -> Output
}
