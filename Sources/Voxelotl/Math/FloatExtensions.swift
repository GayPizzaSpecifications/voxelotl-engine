public extension FloatingPoint {
  @inline(__always) var degrees: Self { self * (180 / Self.pi) }
  @inline(__always) var radians: Self { self * (Self.pi / 180) }

  @inline(__always) func lerp(_ a: Self, _ b: Self) -> Self { b * self + a * (1 - self) }
  @inline(__always) func mlerp(_ a: Self, _ b: Self) -> Self { a + self * (b - a) }

  @inline(__always) func clamp(_ a: Self, _ b: Self) -> Self { min(max(self, a), b) }
  @inline(__always) var saturated: Self { self.clamp(0, 1) }

  @inline(__always) func smoothStep() -> Self { self * self * (3 - 2 * self) }
  @inline(__always) func smootherStep() -> Self { self * self * self * (self * (self * 6 - 15) + 10) }

  @inline(__always) func euclidianMod(_ divisor: Self) -> Self { self.floorMod(abs(divisor)) }
  @inline(__always) func floorMod(_ divisor: Self) -> Self {
    //fmod(fmod(self, divisor) + divisor, divisor)
    (self.truncateMod(divisor) + divisor).truncateMod(divisor)
  }
  @inline(__always) func truncateMod(_ divisor: Self) -> Self {
    self.truncatingRemainder(dividingBy: divisor)
  }
}
