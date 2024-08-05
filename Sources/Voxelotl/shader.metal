#ifndef SHADERTYPES_H
#define SHADERTYPES_H

#ifdef __METAL_VERSION__
# define NS_ENUM(TYPE, NAME) enum NAME : TYPE NAME; enum NAME : TYPE
# define NSInteger metal::int32_t
#else
# import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, ShaderInputIdx) {
  ShaderInputIdxVertices = 0
};

typedef struct {
  vector_float4 position;
  vector_float4 color;
} ShaderVertex;

#endif//SHADERTYPES_H

#include <metal_stdlib>

using namespace metal;

struct FragmentInput {
  float4 position [[position]];
  float4 color;
};

vertex FragmentInput vertexMain(
  uint vertexID [[vertex_id]],
  device const ShaderVertex* vtx [[buffer(ShaderInputIdxVertices)]]
) {
  FragmentInput out;
  out.position = vtx[vertexID].position;
  out.color    = vtx[vertexID].color;
  return out;
}

fragment float4 fragmentMain(FragmentInput in [[stage_in]]) {
  return in.color;
}
