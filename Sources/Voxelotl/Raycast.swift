import simd

public func raycast(
  world: World,
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
  var side: RaycastSide
  while true {
    if sideDistance.x < sideDistance.y {
      if sideDistance.x < sideDistance.z {
        sideDistance.x += deltaDistance.x
        mapPosition.x += step.x
        side = step.x > 0 ? .left : .right
      } else {
        sideDistance.z += deltaDistance.z
        mapPosition.z += step.z
        side = step.z > 0 ? .front : .back
      }
    } else {
      if sideDistance.y < sideDistance.z {
        sideDistance.y += deltaDistance.y
        mapPosition.y += step.y
        side = step.y > 0 ? .down : .up
      } else {
        sideDistance.z += deltaDistance.z
        mapPosition.z += step.z
        side = step.z > 0 ? .front : .back
      }
    }

    // Compute distance
    var distance: Float = if side.isX {
      abs(Float(mapPosition.x) - rayPosition.x + Float(1 - step.x) / 2) / direction.x
    } else if side.isVertical {
      abs(Float(mapPosition.y) - rayPosition.y + Float(1 - step.y) / 2) / direction.y
    } else {
      abs(Float(mapPosition.z) - rayPosition.z + Float(1 - step.z) / 2) / direction.z
    }
    distance = abs(distance)

    // Bail out if we've exeeded the max raycast distance
    if distance > maxDistance {
      return nil
    }

    // return a result if we hit something solid
    if world.getBlock(at: mapPosition).type != .air {
      return .init(
        position: rayPosition + direction * distance,
        distance: distance,
        map: mapPosition,
        side: side)
    }
  }
}

public struct RaycastHit {
  let position: SIMD3<Float>
  let distance: Float
  let map: SIMD3<Int>
  let side: RaycastSide
}

public enum RaycastSide {
  case left, right
  case down, up
  case back, front
}

public extension SIMD3 where Scalar == Int {
  func offset(by side: RaycastSide) -> Self {
    let ofs: Self = switch side {
    case .right: .init( 1,  0,  0)
    case .left:  .init(-1,  0,  0)
    case .up:    .init( 0,  1,  0)
    case .down:  .init( 0, -1,  0)
    case .back:  .init( 0,  0,  1)
    case .front: .init( 0,  0, -1)
    }
    return self &+ ofs
  }
}

public extension RaycastSide {
  func normal<T: FloatingPoint>() -> SIMD3<T> {
    switch self {
    case .left:  .left
    case .right: .right
    case .down:  .down
    case .up:    .up
    case .back:  .back
    case .front: .forward
    }
  }

  @inline(__always) var isX: Bool { self == .left || self == .right }
  @inline(__always) var isZ: Bool { self == .back || self == .front }
  @inline(__always) var isHorizontal: Bool { self.isX || self.isZ }
  @inline(__always) var isVertical: Bool { self == .up || self == .down }
}
