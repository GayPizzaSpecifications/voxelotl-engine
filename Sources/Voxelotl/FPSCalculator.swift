import Foundation

public struct FPSCalculator {
  private var _accumulator = 0.0
  private var _framesCount = 0

  public mutating func frame(deltaTime: Double, result: (_ fps: Int) -> Void) {
    _framesCount += 1
    _accumulator += deltaTime

    if (_accumulator >= 1.0) {
      result(_framesCount)

      _framesCount = 0
      _accumulator = fmod(_accumulator, 1.0)
    }
  }
}
