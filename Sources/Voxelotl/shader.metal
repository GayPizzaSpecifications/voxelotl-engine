#include "shadertypes.h"

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
