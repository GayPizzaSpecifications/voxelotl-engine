#include "shadertypes.h"
#include <metal_stdlib>


struct FragmentInput {
  float4 position [[position]];
  float2 texCoord;
  half4  color;
};

vertex FragmentInput vertex2DMain(uint vertexID [[vertex_id]],
  device const Vertex2D* vtx [[buffer(VertexShaderInputIdxVertices)]],
  constant Shader2DUniforms& u [[buffer(VertexShaderInputIdxUniforms)]]
) {
  FragmentInput out;
  out.position = u.projection * float4(vtx[vertexID].position, 0.0, 1.0);
  out.texCoord = vtx[vertexID].texCoord;
  out.color    = half4(vtx[vertexID].color);
  return out;
}

fragment half4 fragment2DMain(FragmentInput in [[stage_in]],
  metal::texture2d<half, metal::access::sample> texture [[texture(0)]]
) {
  constexpr metal::sampler sampler(metal::address::repeat, metal::filter::linear);
  half4 texel = texture.sample(sampler, in.texCoord);
  return texel * in.color;
}
