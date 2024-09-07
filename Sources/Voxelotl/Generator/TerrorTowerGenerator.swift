import simd

struct TerrorTowerGenerator: WorldGenerator {
  var noise1: LayeredNoise<ImprovedPerlin<Float>>!
  var noise2: LayeredNoise<SimplexNoise<Float>>!

  public mutating func reset(seed: UInt64) {
    var random = Xoroshiro128PlusPlus(state: SplitMix64.createState(seed: seed))
    self.noise1 = LayeredNoise(random: &random, octaves: 4, frequency: 0.05, amplitude: 2.2)
    self.noise2 = LayeredNoise(random: &random, octaves: 3, frequency: 0.1)
  }

  public func makeChunk(id chunkID: ChunkID) -> Chunk {
    let chunkOrigin = chunkID.getPosition()
    var chunk = Chunk(position: chunkOrigin)
    chunk.fill(allBy: { position in
      let fpos = SIMD3<Float>(chunkOrigin &+ position)
        let threshold: Float = 0.6
        let gradient = simd_length(fpos.xz) / 14.0
        let value = self.noise1.get(fpos) - 0.25
      return if gradient + value < threshold {
        .solid(.init(
          hue: ((fpos.x * 0.5 + fpos.y) / 30.0) * 360.0,
          saturation: 0.2 + noise2.get(fpos) * 0.2,
          value: 0.75 + noise2.get(SIMD4(fpos, 1) * 0.25)
        ).linear)
      } else {
        .air
      }
    })
    return chunk
  }
}
