#ifndef SHADERTYPES_H
#define SHADERTYPES_H

#ifdef __METAL_VERSION__
# define NS_ENUM(TYPE, NAME) enum NAME : TYPE NAME; enum NAME : TYPE
# define NSInteger metal::int32_t
#else
# import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

// HACK: allow passing SIMD4<Float16> to shader while `simd_half4` is beta
#ifdef __METAL_VERSION__
typedef half4 color_half4;
#else
typedef simd_ushort4 color_half4;
#endif

typedef NS_ENUM(NSInteger, VertexShaderInputIdx) {
  VertexShaderInputIdxVertices = 0,
  VertexShaderInputIdxInstance = 1,
  VertexShaderInputIdxUniforms = 2
};

typedef struct {
  vector_float3 position;
  vector_float3 normal;
  color_half4   color;
  vector_float2 texCoord;
} ShaderVertex;

typedef struct {
  matrix_float4x4 model;
  matrix_float4x4 normalModel;
  color_half4     color;
} VertexShaderInstance;

typedef struct {
  matrix_float4x4 projView;
} VertexShaderUniforms;

typedef NS_ENUM(NSInteger, FragmentShaderInputIdx) {
  FragmentShaderInputIdxUniforms = 0
};

typedef struct {
  vector_float3 cameraPosition, directionalLight;
  color_half4 ambientColor, diffuseColor, specularColor;
  float specularIntensity;
} FragmentShaderUniforms;

#endif//SHADERTYPES_H
