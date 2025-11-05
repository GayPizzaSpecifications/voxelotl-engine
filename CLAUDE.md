# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Voxelotl Engine is a voxel rendering engine written in Swift for Apple platforms (macOS and iOS). It uses Metal for rendering and SDL3 (via SDLSwift wrapper) for windowing and input handling.

## Build System

The project uses CMake with Xcode generator support.

### Building for macOS

```bash
# Initialize and update submodules first
git submodule update --init --recursive

# Generate Xcode project
cmake -B build -G Xcode

# Build from command line
cmake --build build --config Debug

# Or open in Xcode
open build/voxelotl.xcodeproj
```

### Building for iOS

```bash
# Use the iOS toolchain
cmake -B build-ios -G Xcode -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ios.toolchain.cmake -DPLATFORM=OS64 -DVOXELOTL_MOBILE_ENABLED=ON

# Build
cmake --build build-ios --config Debug
```

### Build Configurations

- Debug builds generate smaller worlds (2x2x2 chunks) for faster iteration
- Release builds generate larger worlds (5x3x5 chunks)
- The `DEBUG` preprocessor flag controls this behavior

## Architecture Overview

### Core Application Flow

**Application.swift** → **Game.swift** → **World** → **Chunk** rendering

1. `Application` manages the SDL window, input handling, and render loop
2. `GameDelegate` protocol defines lifecycle hooks (create, update, draw, resize)
3. `Game` implements `GameDelegate` and contains game logic and world management
4. `Renderer` wraps Metal rendering with shader pipeline management

### Voxel World System

The world is divided into **Chunks** (16×16×16 blocks):

- **ChunkID**: Identifies chunk position in world space
- **Chunk**: Contains 4096 blocks in a flat array with XYZ stride access
- **World**: Dictionary-based chunk storage with damage tracking for mesh regeneration
- **ChunkGeneration**: Asynchronous chunk generation on background queues
- **ChunkMeshGeneration**: Asynchronous mesh building for modified chunks

Chunks are generated using `WorldGenerator` implementations:
- `StandardWorldGenerator`: Terrain with Perlin/Simplex noise
- `TerrorTowerGenerator`: Alternative generation pattern

### Rendering Pipeline

Metal-based rendering with custom shader pipeline (`shader.metal`):

1. **Renderer**: Main Metal renderer with command queue and PSO management
2. **ChunkRenderer**: Specialized renderer for voxel chunks with batching
3. **ModelBatch**: General-purpose 3D model renderer for entities
4. **Shader**: Wrapper for vertex/fragment shader functions
5. **Material**: Ambient/diffuse/specular lighting properties

Key rendering features:
- Multi-frame in-flight rendering (3 frames)
- Depth buffering with 32-bit float precision
- sRGB color space (bgra8Unorm_srgb)
- Adaptive GPU selection on macOS (prefers high-power discrete GPUs)

### Supporting Subsystems

**Math** (`Math/`): Custom linear algebra with SIMD types
- Vector/matrix operations, AABB, rectangles, extents
- Matrix4x4 for projection and transforms

**Noise** (`Noise/`): Procedural generation
- Perlin and Simplex noise generators
- Layered noise composition

**Random** (`Random/`): Multiple PRNG implementations
- PCG32, Xoroshiro128, SplitMix64, Arc4Random

**Input** (`Input/`): Abstracted input handling
- `Keyboard`, `Mouse`, `GameController` singletons
- iOS virtual controller support via GameController framework

## Common Operations

### Adding a new block type

Block types are defined in the codebase (search for `BlockType` enum). To add a new type, you'll need to:
1. Add enum case to `BlockType`
2. Update mesh generation in `ChunkMeshBuilder.swift`
3. Update generator logic if needed

### Modifying chunk size

Chunk dimensions are controlled by constants in `Chunk.swift`:
```swift
public static let shift = 4  // 16 = 1 << 4
public static let size: Int = 1 << shift
```

Changing `shift` will affect memory layout and performance significantly.

### Working with the renderer

The renderer uses a frame-based API:
```swift
renderer.newFrame { encoder in
  // Draw calls here
}
```

All rendering must occur within the `newFrame` closure. The renderer manages command buffer submission and presentation.

## Platform-Specific Code

The codebase uses platform checks:
- `#if os(macOS)` for macOS-specific code (discrete GPU selection, window properties)
- `#if os(iOS)` for iOS-specific code (virtual controller, unified memory)
- `#if canImport(GameController)` for controller support

Mobile builds use different:
- Entitlements files (`MobileVoxelotl.entitlements` vs `Voxelotl.entitlements`)
- App icons (`AppIconMobile` vs `AppIcon`)
- RPATH settings for framework loading

## External Dependencies

**SDLSwift** (submodule at `External/SDLSwift`):
- Wraps SDL3 for Swift
- Provides window creation, event handling, and Metal view integration
- Must be initialized via `git submodule update --init --recursive`

## Code Organization

```
Sources/Voxelotl/
├── Application.swift, Game.swift     # Core application and game loop
├── Chunk.swift, World.swift          # Voxel data structures
├── ChunkGeneration.swift             # Async chunk generation
├── ChunkMeshGeneration.swift         # Async mesh building
├── Common/                           # Utilities (Color, FPS counter, concurrent dict)
├── Math/                             # Linear algebra library
├── Noise/                            # Procedural noise generators
├── Random/                           # PRNG implementations
├── Renderer/                         # Metal rendering abstractions
│   └── Metal/                        # Metal-specific extensions
├── Input/                            # Input handling abstractions
├── Generator/                        # World generation implementations
├── shader.metal, shadertypes.h       # Metal shaders
└── Assets.xcassets                   # App icons and resources
```

## Important Notes

- All voxel modifications trigger damage tracking to regenerate affected chunk meshes
- Chunk mesh generation happens asynchronously on `DispatchQueue.global(qos: .userInitiated)`
- The renderer uses a triple-buffering strategy (3 frames in flight) with semaphore-based synchronization
- Block coordinates use SIMD3<Int>, world positions use SIMD3<Float>
- The coordinate system places chunk boundaries at multiples of 16
