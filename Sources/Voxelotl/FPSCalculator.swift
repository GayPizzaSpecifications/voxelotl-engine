import Foundation

public struct FPSCalculator {
  private var _accumulator = Duration.zero
  private var _framesCount = 0

  public mutating func frame(deltaTime: Duration, result: (_ fps: Int) -> Void) {
    self._framesCount += 1
    self._accumulator += deltaTime

    if self._accumulator >= Duration.seconds(1) {
      result(self._framesCount)

      self._framesCount = 0
      self._accumulator = .init(
        secondsComponent: 0,
        attosecondsComponent: self._accumulator.components.attoseconds)
    }
  }
}
