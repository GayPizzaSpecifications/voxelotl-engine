struct StandardWorldGenerator: WorldGenerator {
  private var heightNoise: LayeredNoiseAlt<SimplexNoise<Float>>!
  private var terrainNoise: LayeredNoise<SimplexNoise<Float>>!
  private var colorNoise: LayeredNoise<ImprovedPerlin<Float>>!

  public mutating func reset(seed: UInt64) {
    var random: any RandomProvider
    let initialState = SplitMix64.createState(seed: seed)
#if true
    random = Xoroshiro128PlusPlus(state: initialState)
#else
    random = PCG32Random(seed: initialState)
#endif

    self.heightNoise = .init(random: &random, octaves: 200, frequency: 0.0002, amplitude: 2)
    self.terrainNoise = .init(random: &random, octaves: 10, frequency: 0.01, amplitude: 0.337)
    self.colorNoise = .init(random: &random, octaves: 150, frequency: 0.00366, amplitude: 2)
  }

  public func makeChunk(id chunkID: SIMD3<Int>) -> Chunk {
    let chunkOrigin = chunkID &<< Chunk.shift
    var chunk = Chunk(position: chunkOrigin)
    for z in 0..<Chunk.size {
      for x in 0..<Chunk.size {
        let height = self.heightNoise.get(SIMD2<Float>(chunkOrigin.xz &+ SIMD2<Int>(x, z)))
        for y in 0..<Chunk.size {
          let ipos = SIMD3(x, y, z)
          let fpos = SIMD3<Float>(chunkOrigin &+ ipos)
          let height = fpos.y / 64.0 + height
          let value = height + self.terrainNoise.get(fpos)
          let block: BlockType = if value < 0 {
            .solid(.init(
              hue: Float(180 + self.colorNoise.get(fpos) * 180),
              saturation: 0.7, value: 0.9).linear)
          } else {
            .air
          }
          chunk.setBlock(internal: ipos, type: block)
        }
      }
    }
    return chunk
  }
}
