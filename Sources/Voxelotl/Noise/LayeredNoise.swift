public struct LayeredNoise<Generator: CoherentNoise> {
  public typealias Scalar = Generator.Scalar

  public let octaves: Int
  public let frequency: Scalar
  public let amplitude: Scalar

  private let _generators: [Generator]
  private let _amplitudeAdjusted: Scalar
}

public extension LayeredNoise where Generator: CoherentNoiseRandomInit {
  init<Random: RandomProvider>(random: inout Random, octaves: Int, frequency: Scalar, amplitude: Scalar = 1) {
    self.octaves   = octaves
    self.frequency = frequency
    self.amplitude = amplitude
    self._generators = (0..<octaves).map { _ in Generator(random: &random) }
    self._amplitudeAdjusted = amplitude / 2
  }
}

public extension LayeredNoise where Generator: CoherentNoiseTableInit {
  init(permutation table: [UInt8], octaves: Int, frequency: Scalar, amplitude: Scalar = 1) {
    self.octaves   = octaves
    self.frequency = frequency
    self.amplitude = amplitude
    self._generators = Array(repeating: Generator(permutation: table), count: octaves)
    self._amplitudeAdjusted = amplitude / 2
  }
}

public extension LayeredNoise where Generator: CoherentNoise2D {
  func get(_ point: SIMD2<Scalar>) -> Scalar {
    zip(self._generators[1...], 1..<self.octaves).map { layer, term in
      let mul = Scalar(1 + term)
      return layer.get(point * self.frequency * mul) / mul
    }.reduce(self._generators[0].get(point * self.frequency)) {
      $0 + $1 } * self._amplitudeAdjusted
  }
}

public extension LayeredNoise where Generator: CoherentNoise3D {
  func get(_ point: SIMD3<Scalar>) -> Scalar {
    zip(self._generators[1...], 1..<self.octaves).map { layer, term in
      let mul = Scalar(1 + term)
      return layer.get(point * self.frequency * mul) / mul
    }.reduce(self._generators[0].get(point * self.frequency)) {
      $0 + $1 } * self._amplitudeAdjusted
  }
}

public extension LayeredNoise where Generator: CoherentNoise4D {
  func get(_ point: SIMD4<Scalar>) -> Scalar {
    zip(self._generators[1...], 1..<self.octaves).map { layer, term in
      let mul = Scalar(1 + term)
      return layer.get(point * self.frequency * mul) / mul
    }.reduce(self._generators[0].get(point * self.frequency)) {
      $0 + $1 } * self._amplitudeAdjusted
  }
}

//MARK: - Experimental

public struct LayeredNoiseAlt<Generator: CoherentNoise> {
  public typealias Scalar = Generator.Scalar

  public let octaves: Int
  public let frequency: Scalar
  public let amplitude: Scalar

  private let _generator: Generator
  private let _amplitudeAdjusted: Scalar

}

public extension LayeredNoiseAlt where Generator: CoherentNoiseRandomInit {
  init<Random: RandomProvider>(random: inout Random, octaves: Int, frequency: Scalar, amplitude: Scalar = 1) {
    self.octaves   = octaves
    self.frequency = frequency
    self.amplitude = amplitude
    self._generator = Generator(random: &random)
    self._amplitudeAdjusted = amplitude / 2
  }
}

public extension LayeredNoiseAlt where Generator: CoherentNoise3D & CoherentNoise2D {
  func get(_ point: SIMD2<Scalar>) -> Scalar {
    let layerOffset: Int = 1
    return (1..<self.octaves).map { term in
      let mul = Scalar(1 + term)
      let point3D = SIMD3(point * frequency * mul, Scalar(term * layerOffset))
      return self._generator.get(point3D) / mul
    }.reduce(self._generator.get(point * frequency)) {
      $0 + $1 } * self._amplitudeAdjusted
  }
}

public extension LayeredNoiseAlt where Generator: CoherentNoise4D & CoherentNoise3D {
  func get(_ point: SIMD3<Scalar>) -> Scalar {
    let layerOffset: Int = 1
    return (1..<self.octaves).map { term in
      let mul = Scalar(1 + term)
      let point4D = SIMD4(point * frequency * mul, Scalar(term * layerOffset))
      return self._generator.get(point4D) / mul
    }.reduce(self._generator.get(point * frequency)) {
      $0 + $1 } * self._amplitudeAdjusted
  }
}
