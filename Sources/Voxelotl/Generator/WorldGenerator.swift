public protocol WorldGenerator {
  mutating func reset(seed: UInt64)
  func makeChunk(id: ChunkID) -> Chunk
}

internal extension RandomProvider where Output == UInt64, Self: RandomSeedable, SeedType == UInt64 {
  static func createState(seed value: UInt64) -> (UInt64, UInt64) {
    var hash = Self(seed: value)
    let state = (hash.next(), hash.next())
    return state
  }
}
