#ifndef SHADERTYPES_H
#define SHADERTYPES_H

#ifdef __METAL_VERSION__
# define NS_ENUM(TYPE, NAME) enum NAME : TYPE NAME; enum NAME : TYPE
# define NSInteger metal::int32_t
#else
# import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef simd_float4 color_float4;

typedef NS_ENUM(NSInteger, VertexShaderInputIdx) {
  VertexShaderInputIdxVertices = 0,
  VertexShaderInputIdxInstance = 1,
  VertexShaderInputIdxUniforms = 2
};

typedef struct {
  vector_float3 position;
  vector_float3 normal;
  color_float4   color;
  vector_float2 texCoord;
} ShaderVertex;

typedef struct {
  matrix_float4x4 model;
  matrix_float4x4 normalModel;
  color_float4     color;
} VertexShaderInstance;

typedef struct {
  matrix_float4x4 projView;
} VertexShaderUniforms;

typedef NS_ENUM(NSInteger, FragmentShaderInputIdx) {
  FragmentShaderInputIdxUniforms = 0
};

typedef struct {
  vector_float3 cameraPosition, directionalLight;
  color_float4 ambientColor, diffuseColor, specularColor;
  float specularIntensity;
} FragmentShaderUniforms;

#endif//SHADERTYPES_H
