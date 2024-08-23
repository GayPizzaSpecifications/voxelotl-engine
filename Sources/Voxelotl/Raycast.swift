import simd

struct RaycastHit {
  let position: SIMD3<Float>
  let distance: Float
  let map: SIMD3<Int>
  let normal: SIMD3<Float>
}

func raycast(
  chunk: Chunk,
  origin rayPosition: SIMD3<Float>,
  direction: SIMD3<Float>,
  maxDistance: Float
) -> Optional<RaycastHit> {
  let deltaDistance = abs(SIMD3(repeating: simd_length(direction)) / direction)

  var mapPosition = SIMD3<Int>(floor(rayPosition))
  var sideDistance: SIMD3<Float> = .zero
  var step: SIMD3<Int> = .zero
  if direction.x < 0 {
    step.x = -1
    sideDistance.x = (rayPosition.x - Float(mapPosition.x)) * deltaDistance.x
  } else {
    step.x = 1
    sideDistance.x = (Float(mapPosition.x) + 1 - rayPosition.x) * deltaDistance.x
  }
  if direction.y < 0 {
    step.y = -1
    sideDistance.y = (rayPosition.y - Float(mapPosition.y)) * deltaDistance.y
  } else {
    step.y = 1
    sideDistance.y = (Float(mapPosition.y) + 1 - rayPosition.y) * deltaDistance.y
  }
  if direction.z < 0 {
    step.z = -1
    sideDistance.z = (rayPosition.z - Float(mapPosition.z)) * deltaDistance.z
  } else {
    step.z = 1
    sideDistance.z = (Float(mapPosition.z) + 1 - rayPosition.z) * deltaDistance.z
  }

  // Run digital differential analysis (3DDDA)
  var side: Int
  while true {
    if sideDistance.x < sideDistance.y {
      if sideDistance.x < sideDistance.z {
        sideDistance.x += deltaDistance.x
        mapPosition.x += step.x
        side = 0b100
      } else {
        sideDistance.z += deltaDistance.z
        mapPosition.z += step.z
        side = 0b001
      }
    } else {
      if sideDistance.y < sideDistance.z {
        sideDistance.y += deltaDistance.y
        mapPosition.y += step.y
        side = 0b010
      } else {
        sideDistance.z += deltaDistance.z
        mapPosition.z += step.z
        side = 0b001
      }
    }

    var distance: Float = if side == 0b100 {
      abs(Float(mapPosition.x) - rayPosition.x + Float(1 - step.x) / 2) / direction.x
    } else if side == 0b010 {
      abs(Float(mapPosition.y) - rayPosition.y + Float(1 - step.y) / 2) / direction.y
    } else {
      abs(Float(mapPosition.z) - rayPosition.z + Float(1 - step.z) / 2) / direction.z
    }
    distance = abs(distance)

    if distance > maxDistance {
      return nil
    }
    if chunk.getBlock(at: mapPosition).type != .air {
      return .init(
        position: rayPosition + direction * distance,
        distance: distance,
        map: mapPosition,
        normal: .zero)
    }
  }
}
