#include "shadertypes.h"
#include <metal_stdlib>


struct FragmentInput {
  float4 position [[position]];
  float3 world;
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
  auto world = i[instanceID].model * float4(position, 1);

  FragmentInput out;
  out.position = u.projView * world;
  out.world    = world.xyz;
  out.color    = vtx[vertexID].color * i[instanceID].color;
  out.normal   = (i[instanceID].normalModel * float4(vtx[vertexID].normal, 0)).xyz;
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

  // Components for blinn-phong & fresnel
  auto lightVec = -u.directionalLight;
  auto eyeVector = metal::normalize(u.cameraPosition - in.world);
  auto halfDir = metal::normalize(lightVec + eyeVector);

  // Compute diffuse component
  float lambert = metal::dot(normal, lightVec);
  float diffuseAmount = metal::max(0.0, lambert);
  half4 diffuse = u.diffuseColor * diffuseAmount;

  // Compute specular component (blinn-phong)
  float specularAngle = metal::max(0.0, metal::dot(halfDir, normal));
  float specularTerm = metal::pow(specularAngle, u.specularIntensity);
  // smoothstep hack to ensure highlight tapers gracefully at grazing angles
  float specularAmount = specularTerm * metal::smoothstep(0, 2, lambert * u.specularIntensity);
  half4 specular = u.specularColor * specularAmount;

  // Sample texture & vertex color to get albedo
  half4 albedo = texture.sample(sampler, in.texCoord);
  albedo *= in.color;

  return albedo * (u.ambientColor + diffuse) + specular;
}
