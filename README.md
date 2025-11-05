# Voxelotl Engine

Voxel engine in Swift, designed for Apple Platforms.

## Features

- Metal-based voxel rendering with custom shaders
- Procedural world generation using Perlin/Simplex noise
- Chunk-based world system (16×16×16 blocks per chunk)
- Asynchronous chunk generation and mesh building
- Support for macOS and iOS
- SDL3 for windowing and input handling
- Game controller support (including iOS virtual controller)

## Requirements

- macOS 13.6 or later / iOS (see build instructions)
- Xcode (for building)
- CMake 3.24 or later

## Quick Start

### Building for macOS

The easiest way to build is using the provided script:

```bash
./build-macos.sh
```

This will:
1. Initialize git submodules
2. Generate the Xcode project
3. Build the Debug configuration
4. Output the app at `build/Debug/Voxelotl.app`

To run:
```bash
open build/Debug/Voxelotl.app
```

Or open in Xcode:
```bash
open build/voxelotl.xcodeproj
```

### Building for iOS

```bash
./build-ios.sh
```

Then open `build-ios/voxelotl.xcodeproj` in Xcode to build and deploy to your device/simulator.

Note: iOS builds require code signing to be configured in Xcode.

## Manual Build Instructions

### macOS

```bash
# Initialize submodules
git submodule update --init --recursive

# Generate Xcode project
cmake -B build -G Xcode

# Build
cmake --build build --config Debug

# Run
open build/Debug/Voxelotl.app
```

### iOS

```bash
# Initialize submodules
git submodule update --init --recursive

# Generate Xcode project with iOS toolchain
cmake -B build-ios -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ios.toolchain.cmake \
    -DPLATFORM=OS64 \
    -DVOXELOTL_MOBILE_ENABLED=ON

# Open in Xcode to build and deploy
open build-ios/voxelotl.xcodeproj
```

## Controls

### Keyboard & Mouse (macOS)
- WASD - Move
- Mouse - Look around
- R - Reset player position
- G - Regenerate world
- P - Regenerate current chunk
- ESC - Quit

### Game Controller
- Left stick - Move
- Right stick - Look around
- Back button - Reset player
- Start button - Regenerate world
- Guide button - Regenerate current chunk

## Architecture

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## License

See [LICENSE](LICENSE) file for details.
