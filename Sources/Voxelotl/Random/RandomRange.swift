public extension RandomProvider where Output: BinaryInteger {
  mutating func next(in range: Range<Int>) -> Int {
    assert(!range.isEmpty, "Ranged next called with empty range")
    return range.lowerBound + self.next(in: range.upperBound - range.lowerBound)
  }

  mutating func next(in range: ClosedRange<Int>) -> Int {
    assert(range.upperBound - range.lowerBound < Int.max, "Closed range exceeds Int.max")
    return range.lowerBound + self.next(in: range.upperBound - range.lowerBound + 1)
  }

  mutating func next(in bound: Int) -> Int {
    assert(Self.min == 0, "Range operations are unsupported on random providers with a non-zero minimum")
    assert(Self.max >= bound, "Maximum raw random provider output is smaller than requested bound")
    let threshold = Int(Self.max % Output(bound))
    var result: Int
    repeat {
      result = Int(truncatingIfNeeded: self.next())
    } while result < threshold
    return result % bound
  }
}

public extension RandomProvider where Output: UnsignedInteger {
  mutating func next(in range: Range<Output>) -> Output {
    assert(!range.isEmpty, "Ranged next called with empty range")
    return range.lowerBound + self.next(in: range.upperBound - range.lowerBound)
  }

  mutating func next(in range: ClosedRange<Output>) -> Output {
    if range == 0...Output.max {
      next()
    } else {
      range.lowerBound + self.next(in: range.upperBound - range.lowerBound + 1)
    }
  }

  mutating func next(in bound: Output) -> Output {
    assert(Self.min == 0, "Range operations are unsupported on random providers with a non-zero minimum")
    assert(Self.max >= bound, "Maximum raw random provider output is smaller than requested bound")
    let threshold = (Self.max &- bound &+ 1) % bound
    var result: Output
    repeat {
      result = self.next()
    } while result < threshold
    return result % bound
  }
}

//MARK: - Experimental

// Uniform bounded random without modulos, WILL produce different results from the standard bounded next
public extension RandomProvider where Output: UnsignedInteger {
  mutating func nextModless(in range: Range<Output>) -> Output {
    assert(!range.isEmpty, "Ranged next called with empty range")
    return range.lowerBound + self.nextModless(in: range.upperBound - range.lowerBound)
  }

  mutating func nextModless(in range: ClosedRange<Output>) -> Output {
    if range == 0...Output.max {
      self.next()
    } else {
      range.lowerBound + self.nextModless(in: range.upperBound - range.lowerBound + 1)
    }
  }

  mutating func nextModless(in bound: Output) -> Output {
    func pow2MaskFrom(range num: Output) -> Output {
      if num & (num - 1) == 0 {
        return num - 1
      }
      var result: Output = 1
      for _ in 0..<Output.bitWidth {
        if result >= num {
          return result - 1
        }
        result <<= 1
      }
      return .max
    }

    let mask = pow2MaskFrom(range: bound)
    var result: Output
    repeat {
      result = next() & mask
    } while result >= bound
    return result
  }
}
