import simd

public func raycast(
  world: World,
  origin rayPosition: SIMD3<Float>,
  direction: SIMD3<Float>,
  maxDistance: Float
) -> Optional<RaycastHit> {
  let directionLen = simd_length(direction)
  let deltaDistance = SIMD3(direction.indices.map {
    direction[$0] != 0.0 ? abs(directionLen / direction[$0]) : Float.greatestFiniteMagnitude
  })

  var mapPosition = SIMD3<Int>(floor(rayPosition))
  var sideDistance: SIMD3<Float> = .zero
  var step: SIMD3<Int> = .zero
  for i in 0..<3 {
    if direction[i] < 0 {
      step[i] = -1
      sideDistance[i] = (rayPosition[i] - Float(mapPosition[i])) * deltaDistance[i]
    } else {
      step[i] = 1
      sideDistance[i] = (Float(mapPosition[i]) + 1 - rayPosition[i]) * deltaDistance[i]
    }
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
    let distance: Float = if side.isX {
      abs(Float(mapPosition.x) - rayPosition.x + Float(1 - step.x) * 0.5) * deltaDistance.x
    } else if side.isVertical {
      abs(Float(mapPosition.y) - rayPosition.y + Float(1 - step.y) * 0.5) * deltaDistance.y
    } else {
      abs(Float(mapPosition.z) - rayPosition.z + Float(1 - step.z) * 0.5) * deltaDistance.z
    }

    // Bail out if we've exeeded the max raycast distance
    if distance > maxDistance {
      return nil
    }

    // Return a result if we hit something solid
    if world.getBlock(at: mapPosition).type != .air {
      return .init(
        position: rayPosition + direction / directionLen * distance,
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
