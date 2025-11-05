#!/bin/bash
set -e

echo "🔧 Building Voxelotl Engine for macOS..."

# Initialize submodules if needed
if [ ! -d "External/SDLSwift/.git" ]; then
    echo "📦 Initializing git submodules..."
    git submodule update --init --recursive
fi

# Generate Xcode project
echo "🏗️  Generating Xcode project..."
cmake -B build -G Xcode

# Build the project
echo "🔨 Building Debug configuration..."
cmake --build build --config Debug

echo "✅ Build complete!"
echo "📍 App bundle: build/Debug/Voxelotl.app"
echo ""
echo "To run the app:"
echo "  open build/Debug/Voxelotl.app"
echo ""
echo "To open in Xcode:"
echo "  open build/voxelotl.xcodeproj"
