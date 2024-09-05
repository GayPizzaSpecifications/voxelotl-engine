struct StandardWorldGenerator: WorldGenerator {
  private var heightNoise: LayeredNoiseAlt<SimplexNoise<Float>>!
  private var terrainNoise: LayeredNoise<ImprovedPerlin<Float>>!
  private var colorNoise: LayeredNoiseAlt<SimplexNoise<Float>>!

  public mutating func reset(seed: UInt64) {
    var random = PCG32Random(seed: SplitMix64.createState(seed: seed))

    self.heightNoise  = .init(random: &random, octaves: 200, frequency: 0.0002,    amplitude:  2.000)
    self.terrainNoise = .init(random: &random, octaves:  10, frequency: 0.01,      amplitude:  0.437)
    self.colorNoise   = .init(random: &random, octaves: 150, frequency: 0.0006667, amplitude: 17.000)
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
          let value = height + self.terrainNoise.get(fpos * SIMD3(1, 2, 1))
          let block: BlockType = if value < 0 {
            .solid(.init(
              hue: Float(180 + self.colorNoise.get(fpos) * 180),
              saturation: 0.47, value: 0.9).linear)
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
