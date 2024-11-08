cbuffer constants : register(b0) {
	float4x4 transform;
	float4x4 projection;
	float3 light_vector;
}

struct vs_in {
	float3 position : POS;
	float3 normal   : NOR;
	float2 texcoord : TEX;
	float3 color    : COL;
};

struct vs_out {
	float4 position : SV_POSITION;
	float2 texcoord : TEX;
	float4 color    : COL;
};

Texture2D    mytexture : register(t0);
SamplerState mysampler : register(s0);

vs_out vs_main(vs_in input) {
	float light = clamp(dot(normalize(mul(transform, float4(input.normal, 0.0f)).xyz), normalize(-light_vector)), 0.0f, 1.0f) * 0.8f + 0.2f;
	vs_out output;
	output.position = mul(projection, mul(transform, float4(input.position, 1.0f)));
	output.texcoord = input.texcoord;
	output.color    = float4(input.color * light, 1.0f);
	return output;
}

float3 linear_to_srgb(float3 rgb)
{
	rgb = clamp(rgb, 0.0, 1.0);
	float3 lt_threshold = step(0.0031308, rgb);
	return lerp(rgb * 12.92, pow(rgb, 1.0 / 2.4) * 1.055 - 0.055, lt_threshold);
}

float4 ps_main(vs_out input) : SV_TARGET {
	float3 texture_color = mytexture.Sample(mysampler, input.texcoord).rgb;
	float3 output_color = texture_color * input.color.rgb;
	return float4(linear_to_srgb(output_color), 1);
}
