#include "shadertypes.h"
#include <metal_stdlib>


struct FragmentInput {
  float4 position [[position]];
  float4 normal;
  float2 texCoord;
  half4 color;
};

vertex FragmentInput vertexMain(
  uint vertexID [[vertex_id]],
  uint instanceID [[instance_id]],
  device const ShaderVertex* vtx [[buffer(ShaderInputIdxVertices)]],
  device const ShaderInstance* i [[buffer(ShaderInputIdxInstance)]],
  constant ShaderUniforms& u [[buffer(ShaderInputIdxUniforms)]]
) {
  auto position = vtx[vertexID].position;
  auto world = i[instanceID].model * position;
  auto ndc = u.projView * world;

  FragmentInput out;
  out.position = ndc;
  out.color    = half4(i[instanceID].color) / 255.0;
  out.normal   = vtx[vertexID].normal;
  out.texCoord = vtx[vertexID].texCoord;
  return out;
}

fragment half4 fragmentMain(
  FragmentInput in [[stage_in]],
  metal::texture2d<half, metal::access::sample> texture [[texture(0)]]
) {
  constexpr metal::sampler sampler(metal::address::repeat, metal::filter::nearest);
  half4 albedo = texture.sample(sampler, in.texCoord);
  return albedo * in.color;
}
