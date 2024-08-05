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