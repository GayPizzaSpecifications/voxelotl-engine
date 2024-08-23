public extension MutableCollection {
  mutating func shuffle<T: RandomProvider>(using provider: inout T) {
    guard self.count > 1 else {
      return
    }
    for (first, remaining) in zip(self.indices, stride(from: 0x100, to: 1, by: -1)) {
      let i = self.index(first, offsetBy: provider.next(in: remaining))
      self.swapAt(first, i)
    }
  }
}

public extension Sequence {
  func shuffled<T: RandomProvider>(using provider: inout T) -> [Self.Element] {
    var copy = Array(self)
    copy.shuffle(using: &provider)
    return copy
  }
}
