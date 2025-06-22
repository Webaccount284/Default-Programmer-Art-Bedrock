#include "ShaderConstants.fxh"

struct VS_Input {
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD_0;
	float2 uv1 : TEXCOORD_1;
	#ifdef INSTANCEDSTEREO
		uint instanceID : SV_InstanceID;
	#endif
};


struct PS_Input {
	float4 position : SV_Position;

	#ifndef BYPASS_PIXEL_SHADER
		lpfloat4 color : COLOR;
		snorm float2 colorLookupUV : TEXCOORD_0_FB_MSAA;
		float4 encodedPlane : PLANE_INFO;
		float3 eyePositionInWorld : EYE_POS;
		float3 surfacePositionInWorld : SURFACE_POS;

		#ifdef FOG
			float4 fogColor : FOG_COLOR;
		#endif
	#endif

	#ifdef INSTANCEDSTEREO
		uint instanceID : SV_InstanceID;
	#endif
};

static const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

void main(in VS_Input VSInput, out PS_Input PSInput) {
	///// Vertex Transformation
	float3 worldPos = (VSInput.position.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;

	#ifdef INSTANCEDSTEREO
		int i = VSInput.instanceID;

		PSInput.position = mul(WORLDVIEW_STEREO[i], float4(worldPos, 1 ));
		PSInput.position = mul(PROJ_STEREO[i], PSInput.position);

		PSInput.instanceID = i;
	#else
		PSInput.position = mul(WORLDVIEW, float4( worldPos, 1 ));
		PSInput.position = mul(PROJ, PSInput.position);
	#endif

	#ifndef BYPASS_PIXEL_SHADER
		///// End Portal Data
		PSInput.color = float4(1,1,1,1);
		PSInput.colorLookupUV = VSInput.uv0;
		PSInput.encodedPlane = VSInput.color; // See BlockTessellator::tessellateEndPortalInWorld(...)
		PSInput.eyePositionInWorld = VIEW_POS;
		PSInput.surfacePositionInWorld = worldPos + VIEW_POS;

		///// Fog
		#ifdef FOG
			#ifdef FANCY
				float3 relPos = -worldPos;
				float cameraDepth = length(relPos);
			#else
				float cameraDepth = PSInput.position.z;
			#endif
			float len = cameraDepth / RENDER_DISTANCE;
			#ifdef ALLOW_FADE
				len += CURRENT_COLOR.r;
			#endif
			PSInput.fogColor.rgb = FOG_COLOR.rgb;
			PSInput.fogColor.a = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
		#endif
	#endif
}
