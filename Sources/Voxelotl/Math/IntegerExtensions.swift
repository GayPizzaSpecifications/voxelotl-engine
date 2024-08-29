public extension BinaryInteger {
  @inline(__always) func euclidianMod(_ divisor: Self) -> Self {
    self.floorMod(divisor < 0 ? divisor * -1 : divisor)
  }
  @inline(__always) func floorMod(_ divisor: Self) -> Self {
    //(self % divisor + divisor) % divisor
    (self.truncateMod(divisor) + divisor).truncateMod(divisor)
  }
  @inline(__always) func truncateMod(_ divisor: Self) -> Self {
    self.quotientAndRemainder(dividingBy: divisor).remainder
  }
}
