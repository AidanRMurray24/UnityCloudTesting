Shader "Hidden/CloudFrag"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f 
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewVector : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert(appdata v) 
            {
                v2f output;
                output.pos = UnityObjectToClipPos(v.vertex);
                output.uv = v.uv;
                // Camera space matches OpenGL convention where cam forward is -z. In unity forward is positive z.
                // (https://docs.unity3d.com/ScriptReference/Camera-cameraToWorldMatrix.html)
                float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
                output.viewVector = mul(unity_CameraToWorld, float4(viewVector, 0));
                return output;
            }

            sampler2D _CameraDepthTexture;
            float3 boundsMin;
            float3 boundsMax;

            // Returns (dstToBox, dstInsideBox). If ray misses box, dstInsideBox will be zero
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir) {
                // Adapted from: http://jcgt.org/published/0007/03/04/
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));

                // CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
                // dstA is dst to nearest intersection, dstB dst to far intersection

                // CASE 2: ray intersects box from inside (dstA < 0 < dstB)
                // dstA is the dst to intersection behind the ray, dstB is dst to forward intersection

                // CASE 3: ray misses box (dstA > dstB)

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float LinearEyeDepth2(float z)
            {
                //z = 1 - z;
                float near = 0.1f;
                float far = 1000.f;
                float4 _ZBufferParams = 0;
                _ZBufferParams.x = -1 + far / near;
                _ZBufferParams.y = 1;
                _ZBufferParams.z = _ZBufferParams.x / far;
                _ZBufferParams.w = 1 / far;
                /*_ZBufferParams.x = 1 - far / near;
                _ZBufferParams.y = far / near;
                _ZBufferParams.z = _ZBufferParams.x / far;
                _ZBufferParams.w = _ZBufferParams.y / far;*/

                return 1.0f / (_ZBufferParams.z * z + _ZBufferParams.w);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 col = tex2D(_MainTex, i.uv);

                // Create ray
                float3 rayPos = _WorldSpaceCameraPos;
                float viewLength = length(i.viewVector);
                float3 rayDir = i.viewVector / viewLength;

                // Depth and cloud container intersection info:
                float nonlin_depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                //float depth = LinearEyeDepth(nonlin_depth) * viewLength;
                float depth = LinearEyeDepth2(nonlin_depth) * viewLength;

                float2 rayToContainerInfo = rayBoxDst(boundsMin, boundsMax, rayPos, 1 / rayDir);
                float dstToBox = rayToContainerInfo.x;
                float dstInsideBox = rayToContainerInfo.y;


                // Only shade black if inside the box
                bool rayHitBox = dstInsideBox > 0 && dstToBox < depth;
                if (rayHitBox)
                {
                    col = 0;
                }

                //col = float4(depth, depth, depth, 0);
                //col = float4(i.uv, 0, 0);
                //col = float4(dstToBox, dstToBox, dstToBox,0);

                return col;
            }
            ENDCG
        }
    }
}
