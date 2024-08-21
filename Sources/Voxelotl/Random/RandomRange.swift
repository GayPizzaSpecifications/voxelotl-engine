public extension RandomProvider where Output: BinaryInteger {
  mutating func next(in range: Range<Int>) -> Int {
    range.lowerBound + self.next(in: range.upperBound - range.lowerBound)
  }

  mutating func next(in range: ClosedRange<Int>) -> Int {
    range.lowerBound + self.next(in: range.upperBound - range.lowerBound + 1)
  }

  mutating func next(in bound: Int) -> Int {
    assert(Self.min == 0)
    assert(Self.max >= bound)
    let threshold = Int(Self.max % Output(bound))
    var result: Int
    repeat {
      result = Int(truncatingIfNeeded: self.next())
    } while result < threshold
    return result % bound
  }
}
