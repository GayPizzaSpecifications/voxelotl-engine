struct StandardWorldGenerator: WorldGenerator {
  private var heightNoise: LayeredNoiseAlt<SimplexNoise<Float>>!
  private var terrainNoise: LayeredNoise<ImprovedPerlin<Float>>!
  private var ravineNoise: LayeredNoise<SimplexNoise<Float>>!
  private var ravineMask: LayeredNoise<SimplexNoise<Float>>!
  private var colorNoise: LayeredNoiseAlt<SimplexNoise<Float>>!

  public mutating func reset(seed: UInt64) {
    var random = PCG32Random(seed: SplitMix64.createState(seed: seed))

    self.heightNoise  = .init(random: &random, octaves: 28, frequency: 0.0008,   amplitude: 1.4)
    self.terrainNoise = .init(random: &random, octaves: 10, frequency: 0.01,     amplitude: 0.437)
    self.ravineNoise  = .init(random: &random, octaves: 12, frequency: 0.01)
    self.ravineMask   = .init(random: &random, octaves:  2, frequency: 0.00241,  amplitude: 2)
    self.colorNoise   = .init(random: &random, octaves: 15, frequency: 0.006667, amplitude: 3)
  }

  public func makeChunk(id chunkID: ChunkID) -> Chunk {
    let blockFunc = { (height: Float, position: SIMD3<Float>) -> BlockType in
#if true
      let value = height + self.terrainNoise.get(position * SIMD3(1, 2, 1))
      if value >= 0 {
        return .air
      }
#else
      if height >= 0 {
        return .air
      }
#endif
#if true
      // Carve out ravines
      if self.ravineMask.get(position * SIMD3(1, 0.441, 1)) >= 0.8 &&
        abs(self.ravineNoise.get(position * SIMD3(1, 0.6, 1))) <= 0.1 { return .air }
#endif
      return .solid(.init(
        hue: Float(180 + self.colorNoise.get(position) * 180),
        saturation: 0.47, value: 0.9).linear)
    }

    let chunkOrigin = chunkID.getPosition()
    var chunk = Chunk(position: chunkOrigin)
    for z in 0..<Chunk.size {
      for x in 0..<Chunk.size {
        let fpos2D = SIMD2<Float>(chunkOrigin.xz &+ SIMD2<Int>(x, z))
        let height = self.heightNoise.get(fpos2D)
        for y in 0..<Chunk.size {
          let ipos = SIMD3(x, y, z)
          let fpos = SIMD3<Float>(chunkOrigin &+ ipos)
          chunk.setBlock(internal: ipos, type: blockFunc(fpos.y / 64.0 + height, fpos))
        }
      }
    }
    return chunk
  }
}
