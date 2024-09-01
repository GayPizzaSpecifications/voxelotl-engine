import Foundation

class WorldGenerator: NSObject {
  var noise: ImprovedPerlin<Float>!, noise2: SimplexNoise<Float>!
  var generating: Set<SIMD3<Int>> = .init()
  let generatingLock: NSLock = .init()
  
  public func reset(seed: UInt64) {
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

  public func isCurrentlyGenerating(id chunkID: SIMD3<Int>) -> Bool {
    self.generatingLock.lock()
    defer {
      self.generatingLock.unlock()
    }
    return self.generating.contains(chunkID)
  }
  
  public func makeChunk(id chunkID: SIMD3<Int>, completion: @escaping (Chunk) -> Void) {
    self.generatingLock.lock()
    print(self.generating)
    if !self.generating.insert(chunkID).inserted {
        self.generatingLock.unlock()
        return
    }
    self.generatingLock.unlock()
    DispatchQueue.global(qos: .userInteractive).async {
      defer {
        self.generatingLock.lock()
        self.generating.remove(chunkID)
        self.generatingLock.unlock()
      }
      
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
      completion(chunk)
    }
  }
}

fileprivate extension RandomProvider where Output == UInt64, Self: RandomSeedable, SeedType == UInt64 {
  static func createState(seed value: UInt64) -> (UInt64, UInt64) {
    var hash = Self(seed: value)
    let state = (hash.next(), hash.next())
    return state
  }
}
