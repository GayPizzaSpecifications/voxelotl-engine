
public struct LayeredNoise<Generator: CoherentNoise> {
  public typealias Scalar = Generator.Scalar

  public let octaves: Int
  public let frequency: Scalar
  public let amplitude: Scalar

  private let _generators: [Generator]

  init(octaves: Int, frequency: Scalar, amplitude: Scalar) {
    self.octaves   = octaves
    self.frequency = frequency
    self.amplitude = amplitude
    self._generators = Array(repeating: .init(), count: octaves)
  }
}

public extension LayeredNoise where Generator: CoherentNoiseRandomInit {
  init<Random: RandomProvider>(random: inout Random, octaves: Int, frequency: Scalar, amplitude: Scalar) {
    self.octaves   = octaves
    self.frequency = frequency
    self.amplitude = amplitude
    self._generators = Array(repeating: Generator(random: &random), count: octaves)
  }
}

public extension LayeredNoise where Generator: CoherentNoise2D {
  func get(_ point: SIMD2<Scalar>) -> Scalar {
    zip(self._generators, 0..<self.octaves).map { layer, term in
      let mul = Scalar(1 + term)
      return layer.get(point * frequency * mul) / mul
    }.reduce(0) { $0 + $1 } * amplitude
  }
}

public extension LayeredNoise where Generator: CoherentNoise3D {
  func get(_ point: SIMD3<Scalar>) -> Scalar {
    zip(self._generators, 0..<self.octaves).map { layer, term in
      let mul = Scalar(1 + term)
      return layer.get(point * frequency * mul) / mul
    }.reduce(0) { $0 + $1 } * amplitude
  }
}

public extension LayeredNoise where Generator: CoherentNoise4D {
  func get(_ point: SIMD4<Scalar>) -> Scalar {
    zip(self._generators, 0..<self.octaves).map { layer, term in
      let mul = Scalar(1 + term)
      return layer.get(point * frequency * mul) / mul
    }.reduce(0) { $0 + $1 } * amplitude
  }
}
