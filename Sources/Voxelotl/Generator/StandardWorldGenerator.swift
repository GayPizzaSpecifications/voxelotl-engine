struct StandardWorldGenerator: WorldGenerator {
  var noise: ImprovedPerlin<Float>!, noise2: SimplexNoise<Float>!

  public mutating func reset(seed: UInt64) {
    var random: any RandomProvider
    let initialState = SplitMix64.createState(seed: seed)
#if true
    random = Xoroshiro128PlusPlus(state: initialState)
#else
    random = PCG32Random(seed: initialState)
#endif

    self.noise = ImprovedPerlin<Float>(random: &random)
    self.noise2 = SimplexNoise<Float>(random: &random)
  }

  public func makeChunk(id chunkID: SIMD3<Int>) -> Chunk {
    let chunkOrigin = chunkID &<< Chunk.shift
    var chunk = Chunk(position: chunkOrigin)
    chunk.fill(allBy: { position in
      let fpos = SIMD3<Float>(position)
        let threshold: Float = 0.6
        let value = fpos.y / 16.0
          + self.noise.get(fpos * 0.05) * 1.1
          + self.noise.get(fpos * 0.10) * 0.5
          + self.noise.get(fpos * 0.30) * 0.23
      return if value < threshold {
        .solid(.init(
          hue:        Float(180 + self.noise2.get(fpos * 0.05) * 180),
          saturation: Float(0.5 + self.noise2.get(SIMD4(fpos * 0.05, 4)) * 0.5),
          value:      Float(0.5 + self.noise2.get(SIMD4(fpos * 0.05, 9)) * 0.5).lerp(0.5, 1)).linear)
      } else {
        .air
      }
    })
    return chunk
  }
}
