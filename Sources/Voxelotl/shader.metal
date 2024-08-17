#include "shadertypes.h"
#include <metal_stdlib>


struct FragmentInput {
  float4 position [[position]];
  float3 normal;
  float2 texCoord;
  half4 color;
};

vertex FragmentInput vertexMain(
  uint vertexID [[vertex_id]],
  uint instanceID [[instance_id]],
  device const ShaderVertex* vtx [[buffer(VertexShaderInputIdxVertices)]],
  device const VertexShaderInstance* i [[buffer(VertexShaderInputIdxInstance)]],
  constant VertexShaderUniforms& u [[buffer(VertexShaderInputIdxUniforms)]]
) {
  auto position = vtx[vertexID].position;
  auto world = i[instanceID].model * position;
  auto ndc = u.projView * world;

  FragmentInput out;
  out.position = ndc;
  out.color    = half4(i[instanceID].color) / 255.0;
  out.normal   = (i[instanceID].normalModel * vtx[vertexID].normal).xyz;
  out.texCoord = vtx[vertexID].texCoord;
  return out;
}

fragment half4 fragmentMain(
  FragmentInput in [[stage_in]],
  metal::texture2d<half, metal::access::sample> texture [[texture(0)]],
  constant FragmentShaderUniforms& u [[buffer(FragmentShaderInputIdxUniforms)]]
) {
  constexpr metal::sampler sampler(metal::address::repeat, metal::filter::nearest);
  auto normal = metal::normalize(in.normal);

  float lambert = metal::dot(normal, -u.directionalLight);
  float diffuse = metal::max(0.0, lambert);

  half4 albedo = texture.sample(sampler, in.texCoord);
  albedo *= in.color;

  return albedo * diffuse;
}
