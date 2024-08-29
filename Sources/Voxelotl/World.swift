import Foundation

public class World {
  private var _chunks: Dictionary<SIMD3<Int>, Chunk>

  public init() {
    self._chunks = [:]
  }

  func getBlock(at position: SIMD3<Int>) -> Block {
    return if let chunk = self._chunks[position &>> Chunk.shift] {
      chunk.getBlock(at: position)
    } else { Block(.air) }
  }

  func setBlock(at position: SIMD3<Int>, type: BlockType) {
    self._chunks[position &>> Chunk.shift]?.setBlock(at: position, type: type)
  }

  func generate(width: Int, height: Int, depth: Int, random: inout any RandomProvider) {
    let noise = ImprovedPerlin<Float>(random: &random)
    let noise2 = SimplexNoise<Float>(random: &random)

    for x in 0..<width {
      for y in 0..<height {
        for z in 0..<depth {
          let chunkID = SIMD3(x, y, z) &- SIMD3(width, height, depth) / 2
          let chunkOrigin = chunkID &<< Chunk.shift
          var chunk = Chunk(position: chunkOrigin)
          chunk.fill(allBy: { position in
            let fpos = SIMD3<Float>(position)
            return if fpos.y / Float(Chunk.size)
                + noise.get(fpos * 0.05) * 1.1
                + noise.get(fpos * 0.10) * 0.5
                + noise.get(fpos * 0.30) * 0.23 < 0.6 {
              .solid(.init(
                hue:        Float16(180 + noise2.get(fpos * 0.05) * 180),
                saturation: Float16(0.5 + noise2.get(SIMD4(fpos * 0.05, 4)) * 0.5),
                value:      Float16(0.5 + noise2.get(SIMD4(fpos * 0.05, 9)) * 0.5).lerp(0.5, 1)).linear)
            } else {
              .air
            }
          })
          self._chunks[chunkID] = chunk
        }
      }
    }
  }

  var instances: [Instance] {
    self._chunks.values.flatMap { chunk in
      chunk.compactMap { block, position in
        if case let .solid(color) = block.type {
          Instance(
            position: SIMD3<Float>(position) + 0.5,
            scale:    .init(repeating: 0.5),
            color:    color)
        } else { nil }
      }
    }
  }
}
