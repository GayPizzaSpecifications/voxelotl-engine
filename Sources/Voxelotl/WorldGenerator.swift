struct WorldGenerator {
  var noise: ImprovedPerlin<Float>!, noise2: SimplexNoise<Float>!

  public mutating func reset(seed: UInt64) {
    var random: any RandomProvider
#if true
    random = Xoroshiro128PlusPlus(seed: seed)
#else
    //TODO: Fill seed with a hash
    random = PCG32Random(state: (
      UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32,
      UInt64(Arc4Random.instance.next()) | UInt64(Arc4Random.instance.next()) << 32))
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
        let value = fpos.y / Float(Chunk.size)
          + self.noise.get(fpos * 0.05) * 1.1
          + self.noise.get(fpos * 0.10) * 0.5
          + self.noise.get(fpos * 0.30) * 0.23
      return if value < threshold {
        .solid(.init(
          hue:        Float16(180 + self.noise2.get(fpos * 0.05) * 180),
          saturation: Float16(0.5 + self.noise2.get(SIMD4(fpos * 0.05, 4)) * 0.5),
          value:      Float16(0.5 + self.noise2.get(SIMD4(fpos * 0.05, 9)) * 0.5).lerp(0.5, 1)).linear)
      } else {
        .air
      }
    })
    return chunk
  }
}
