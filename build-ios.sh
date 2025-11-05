#!/bin/bash
set -e

echo "🔧 Building Voxelotl Engine for iOS..."

# Initialize submodules if needed
if [ ! -d "External/SDLSwift/.git" ]; then
    echo "📦 Initializing git submodules..."
    git submodule update --init --recursive
fi

# Generate Xcode project for iOS
echo "🏗️  Generating Xcode project for iOS..."
cmake -B build-ios -G Xcode \
    -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ios.toolchain.cmake \
    -DPLATFORM=OS64 \
    -DVOXELOTL_MOBILE_ENABLED=ON

echo "✅ Project generation complete!"
echo "📍 Xcode project: build-ios/voxelotl.xcodeproj"
echo ""
echo "To build and deploy to iOS device:"
echo "  1. open build-ios/voxelotl.xcodeproj"
echo "  2. Select your device/simulator"
echo "  3. Build and run from Xcode (Cmd+R)"
echo ""
echo "Note: iOS builds require code signing configured in Xcode"
