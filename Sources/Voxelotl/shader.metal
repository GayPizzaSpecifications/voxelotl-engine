#include "shadertypes.h"

#include <metal_stdlib>

using namespace metal;

struct FragmentInput {
  float4 position [[position]];
  float4 normal;
  float2 texCoord;
};

vertex FragmentInput vertexMain(
  uint vertexID [[vertex_id]],
  device const ShaderVertex* vtx [[buffer(ShaderInputIdxVertices)]]
) {
  FragmentInput out;
  out.position = vtx[vertexID].position * float4(0.5, 0.5, 0.5, 1.0);
  out.normal   = vtx[vertexID].normal;
  out.texCoord = vtx[vertexID].texCoord;
  return out;
}

fragment half4 fragmentMain(
  FragmentInput in [[stage_in]],
  texture2d<half, access::sample> tex [[texture(0)]]
) {
  constexpr sampler s(address::repeat, filter::nearest);
  half4 albedo = tex.sample(s, in.texCoord);

  return half4(albedo.rgb, 1.0);
}
