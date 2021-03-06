Shader "Hidden/Edge Detect Normals" {
Properties {
	_MainTex ("Base (RGB)", Rect) = "white" {}
	_NormalPower ("Normal power", Range(0.0, 10.0)) = 1.0
	_DepthPower ("Depth power", Range(0.0, 10.0)) = 1.0
}

SubShader {
	Pass {
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#pragma fragmentoption ARB_precision_hint_fastest 
#include "UnityCG.cginc"

uniform sampler2D _MainTex;
uniform float _NormalPower;
uniform float _DepthPower;
sampler2D _CameraDepthNormalsTexture;
uniform float4 _MainTex_TexelSize;

struct v2f {
	float4 pos : POSITION;
	float2 uv[4] : TEXCOORD0;
};

v2f vert( appdata_img v )
{
	v2f o;
	o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
	float2 uv = MultiplyUV( UNITY_MATRIX_TEXTURE0, v.texcoord );
	o.uv[0] = uv;
	
	// On D3D when AA is used, the main texture & scene depth texture
	// will come out in different vertical orientations.
	// So flip sampling of depth texture when that is the case (main texture
	// texel size will have negative Y).
	#if SHADER_API_D3D9
	if (_MainTex_TexelSize.y < 0)
		uv.y = 1-uv.y;
	#endif
	
	o.uv[1] = uv;
	// offsets for two additional samples
	o.uv[2] = uv + float2(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * 1.0;
	o.uv[3] = uv + float2(+_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * 1.0;
	return o;
}

inline half CheckSame (half2 centerNormal, float centerDepth, half4 sample)
{
	// difference in normals
	// do not bother decoding normals - there's no need here
	half2 diff = pow(abs(centerNormal - sample.xy), _NormalPower); /// <<<
	half isSameNormal = saturate(1.0 - 5.0 * (diff.x + diff.y)); /// <<<
	// difference in depth
	float sampleDepth = DecodeFloatRG (sample.zw);
	float zdiff = pow(abs(centerDepth - sampleDepth), _DepthPower); /// <<<
	// scale the required threshold by the distance
	half isSameDepth = saturate((centerDepth - 10.0 * zdiff) / centerDepth);
	// return:
	// 1 - if normals and depth are similar enough
	// 0 - otherwise
	return isSameNormal * isSameDepth;
}

half4 frag (v2f i) : COLOR
{
	half4 original = tex2D(_MainTex, i.uv[0]);
	
	half4 center = tex2D (_CameraDepthNormalsTexture, i.uv[1]);
	half4 sample1 = tex2D (_CameraDepthNormalsTexture, i.uv[2]);
	half4 sample2 = tex2D (_CameraDepthNormalsTexture, i.uv[3]);
	
	// encoded normal
	half2 centerNormal = center.xy;
	// decoded depth
	float centerDepth = DecodeFloatRG (center.zw);
	
	//original *= float4(1,1,1,1);
	original *= CheckSame(centerNormal, centerDepth, sample1);
	original *= CheckSame(centerNormal, centerDepth, sample2);
		
	return original;
}
ENDCG
		}
	}
	Fallback off
}