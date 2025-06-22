#include "ShaderConstants.fxh"
#include "Util.fxh"

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

struct PS_Output {
	float4 color : SV_Target;
};

static const float MAX_LAYER_DEPTH = 32.0;

void main( in PS_Input PSInput, out PS_Output PSOutput ) {
	#ifdef BYPASS_PIXEL_SHADER
		PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
	#else
		///// Decode Input Values
		// Decode parallax plane data
		// Using round() because normals should all be in the standard basis
		const float4 planeData = (PSInput.encodedPlane - float4(0.5, 0.5, 0.5, 0.0)) * float4(2.0, 2.0, 2.0, MAX_LAYER_DEPTH);
		const float3 planeNormal = planeData.rgb;
		const float planeDistance = planeData.a;
		// Calculate view direction from the surface position and the eye position
		const float3 viewDirection = PSInput.surfacePositionInWorld - PSInput.eyePositionInWorld;
		
		///// Ray-cast for parallax-offset UV
		// Perform ray-plane intersection to find the position on the parallax plane
		float t = dot(viewDirection - (planeNormal * planeDistance), planeNormal) / dot(viewDirection, planeNormal);
		float3 parallaxSurfacePosition = PSInput.eyePositionInWorld + t * viewDirection;

		///// Ridiculous UV-remapping
		const float3 absNormal = abs(planeNormal);
		// Since all normals are orthonormal on <x,y,z>, mask out the correct uv result
		float2 raycastUV = parallaxSurfacePosition.yz * absNormal[0];
		raycastUV += parallaxSurfacePosition.xz * absNormal[1];
		raycastUV += parallaxSurfacePosition.xy * absNormal[2];
		// Scale the UVs to Minecraft pixel size
		raycastUV = raycastUV / 16.0;

		///// Color Lookup
		float4 colorSample = TEXTURE_1.Sample(TextureSampler1, PSInput.colorLookupUV);

		///// UV Scrolling
		// Scroll direction based on a value unique to the layer (derived from color)
		const float colorSeed = colorSample.g - colorSample.b;
		const float2 scrollDirection = normalize(float2(colorSeed - colorSample.r, colorSeed));
		float2 resultUV = mul(float2x2(float2(scrollDirection.x, scrollDirection.y), float2(-scrollDirection.y, scrollDirection.x)), raycastUV);
		// Offset rotation based on a value unique to the layer (still derived from color)
		resultUV += scrollDirection * colorSeed * 128.0;
		resultUV.y += TIME / 256.0;

		///// Color assembly
		float4 textureSample = TEXTURE_0.Sample(TextureSampler0, resultUV);
		const float3 brightness = textureSample.rgb * (1.0 - PSInput.encodedPlane.w);
		colorSample.rgb *= brightness;

		// Look for hard-coded value to clear the portal first
		#ifdef FOG
			if(planeDistance > MAX_LAYER_DEPTH - 1.0) {
				PSOutput.color = float4(PSInput.fogColor.rgb * PSInput.fogColor.a, 0.0f);
			}
			else {
				PSOutput.color = float4(colorSample.rgb * (1.0 - PSInput.fogColor.a), 1.0f);
			}
		#else
			if(planeDistance > MAX_LAYER_DEPTH - 1.0) {
				PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
			}
			else {
				PSOutput.color = float4(colorSample.rgb, 1);
			}
		#endif
	#endif
}
