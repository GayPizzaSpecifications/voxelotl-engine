add_executable(Voxelotl MACOSX_BUNDLE
  # Resources
  Assets.xcassets
  test.png

  # Shaders
  shadertypes.h
  shader.metal

  # Common utility library
  Common/ConcurrentDictionary.swift
  Common/Color.swift
  Common/FPSCalculator.swift

  # Maths library
  Math/FloatExtensions.swift
  Math/IntegerExtensions.swift
  Math/VectorExtensions.swift
  Math/Matrix4x4.swift
  Math/Point.swift
  Math/Size.swift
  Math/Rectangle.swift
  Math/Extent.swift
  Math/AABB.swift

  # Random number generator subsystem
  Random/RandomProvider.swift
  Random/RandomRange.swift
  Random/Arc4Random.swift
  Random/PCG32Random.swift
  Random/Xoroshiro128.swift
  Random/SplitMix64.swift
  Random/RandomCollectionExtensions.swift

  # Coherent noise classes
  Noise/CoherentNoise.swift
  Noise/PerlinNoiseGenerator.swift
  Noise/SimplexNoise.swift
  Noise/LayeredNoise.swift

  # Resource classes
  Resource/NSImageLoader.swift

  # Renderer classes
  Renderer/Material.swift
  Renderer/Environment.swift
  Renderer/Mesh.swift
  Renderer/ModelBatch.swift
  Renderer/ChunkRenderer.swift
  Renderer/Renderer.swift

  # Input wrappers
  Input/Keyboard.swift
  Input/GameController.swift
  Input/Mouse.swift

  # Worldgens
  Generator/WorldGenerator.swift
  Generator/StandardWorldGenerator.swift
  Generator/TerrorTowerGenerator.swift

  # Game logic classes
  Chunk.swift
  ChunkGeneration.swift
  ChunkMeshGeneration.swift
  CubeMeshBuilder.swift
  ChunkMeshBuilder.swift
  ChunkID.swift
  World.swift
  Raycast.swift
  Camera.swift
  Player.swift
  Game.swift

  # Core application classes
  GameDelegate.swift
  Application.swift

  # Entry point
  Program.swift
  main.m
)

set_source_files_properties(
  shader.metal PROPERTIES
  LANGUAGE METAL
  COMPILE_OPTIONS "-I${PROJECT_SOURCE_DIR}"
)

target_include_directories(Voxelotl PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(Voxelotl PRIVATE SDLSwift)
target_compile_definitions(Voxelotl PRIVATE $<$<CONFIG:Debug>:DEBUG>)

if(VOXELOTL_MOBILE_ENABLED)
  set(VOXELOTL_APPICON "AppIconMobile")
  set(VOXELOTL_RPATH "@loader_path/Frameworks")
else()
  set(VOXELOTL_APPICON "AppIcon")
  set(VOXELOTL_RPATH "@loader_path/../Frameworks")
endif()

set_target_properties(Voxelotl PROPERTIES
  XCODE_ATTRIBUTE_ENABLE_HARDENED_RUNTIME YES
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "gay.pizza.voxelotl"
  XCODE_EMBED_FRAMEWORKS "${SDL3}"
  XCODE_EMBED_FRAMEWORKS_REMOVE_HEADERS_ON_COPY YES
  XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY YES
  MACOSX_BUNDLE_BUNDLE_NAME "Voxelotl"
  MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
  MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
  MACOSX_BUNDLE_GUI_IDENTIFIER "gay.pizza.voxelotl"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
  XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "${VOXELOTL_APPICON}"
  BUILD_RPATH "${VOXELOTL_RPATH}"
  XCODE_ATTRIBUTE_SKIP_INSTALL "NO"
  XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
  XCODE_GENERATE_SCHEME ON
  XCODE_SCHEME_ENABLE_GPU_FRAME_CAPTURE_MODE "Metal"
  XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/Voxelotl.entitlements"
  MACOSX_BUNDLE_COPYRIGHT "© 2024 Gay Pizza Specifications")

if(VOXELOTL_MOBILE_ENABLED)
  set_target_properties(Voxelotl PROPERTIES
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "YES"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "YES"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
  )
endif()

set_source_files_properties(Assets.xcassets PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
set_source_files_properties(module.modulemap PROPERTIES MACOSX_PACKAGE_LOCATION Modules)
set_source_files_properties(test.png PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

#TODO: should use TREE mode as documented in https://cmake.org/cmake/help/latest/command/source_group.html
source_group("Resources" FILES Assets.xcassets test.png)
source_group("Source Files" REGULAR_EXPRESSION "\\.(swift|metal|m)$")
source_group("Source Files\\Common" REGULAR_EXPRESSION "Common/")
source_group("Source Files\\Random" REGULAR_EXPRESSION "Random/")
source_group("Source Files\\Noise" REGULAR_EXPRESSION "Noise/")
source_group("Source Files\\Math" REGULAR_EXPRESSION "Math/")
source_group("Source Files\\Input" REGULAR_EXPRESSION "Input/")
source_group("Source Files\\Renderer" REGULAR_EXPRESSION "Renderer/")
source_group("Source Files\\Generator" REGULAR_EXPRESSION "Generator/")
