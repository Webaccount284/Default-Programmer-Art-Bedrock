#include "ShaderConstants.fxh"

struct GeometryShaderInput
{
	float4			pos				: SV_POSITION;
	#ifndef BYPASS_PIXEL_SHADER
		lpfloat4 color : COLOR;
		snorm float2 colorLookupUV : TEXCOORD_0_FB_MSAA;
		float4 encodedPlane : PLANE_INFO;
		float3 eyePositionInWorld : EYE_POS;
		float3 surfacePositionInWorld : SURFACE_POS;
		#ifdef FOG
			float4				fogColor		: FOG_COLOR;
		#endif
	#endif
	#ifdef INSTANCEDSTEREO
		uint				instanceID		: SV_InstanceID;
	#endif
};

// Per-pixel color data passed through the pixel shader.
struct GeometryShaderOutput
{
	float4				pos				: SV_POSITION;
	#ifndef BYPASS_PIXEL_SHADER
		lpfloat4 color : COLOR;
		snorm float2 colorLookupUV : TEXCOORD_0_FB_MSAA;
		float4 encodedPlane : PLANE_INFO;
		float3 eyePositionInWorld : EYE_POS;
		float3 surfacePositionInWorld : SURFACE_POS;
		#ifdef FOG
			float4				fogColor		: FOG_COLOR;
		#endif
	#endif
	#ifdef INSTANCEDSTEREO
		uint				renTarget_id : SV_RenderTargetArrayIndex;
	#endif
};

bool inBounds(float3 worldPos)
{
	bool inBounds = true;
	if (worldPos.x < CHUNK_CLIP_MIN.x ||
		worldPos.x > CHUNK_CLIP_MAX.x ||
		worldPos.z < CHUNK_CLIP_MIN.y ||
		worldPos.z > CHUNK_CLIP_MAX.y)
	{
		inBounds = false;
	}

	return inBounds;
}

// passes through the triangles, except changint the viewport id to match the instance
[maxvertexcount(3)]
void main(triangle GeometryShaderInput input[3], inout TriangleStream<GeometryShaderOutput> outStream)
{
	GeometryShaderOutput output = (GeometryShaderOutput)0;

	#ifdef INSTANCEDSTEREO
		int i = input[0].instanceID;
	#endif
	{
		for (int j = 0; j < 3; j++)
		{
			output.pos = input[j].pos;
			#ifndef BYPASS_PIXEL_SHADER
				output.color = input[j].color;
				output.colorLookupUV = input[j].colorLookupUV;
				output.encodedPlane = input[j].encodedPlane;
				output.eyePositionInWorld = input[j].eyePositionInWorld;
				output.surfacePositionInWorld = input[j].surfacePositionInWorld;
				#ifdef FOG
					output.fogColor = input[j].fogColor;
				#endif
			#endif

			#ifdef INSTANCEDSTEREO
				output.renTarget_id = i;
			#endif
			outStream.Append(output);
		}
	}
}