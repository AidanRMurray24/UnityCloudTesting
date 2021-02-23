using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways, ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class CloudMaster : MonoBehaviour
{
    [SerializeField] private Shader cloudFragShader = null;
    [SerializeField] private Transform cloudContainer = null;
    [SerializeField] private ComputeShader computeShader = null;
    private Camera cam = null;
    private List<ComputeBuffer> buffersToDispose = null;
    private RenderTexture rt = null;
    private int kernel = 0;

    [HideInInspector]
    public Material material;

    private void Awake()
    {
        // Get a reference to the camera
        cam = GetComponent<Camera>();
    }

    private void Start() => kernel = computeShader.FindKernel("CSMain");

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // Set up material
        if (material == null || material.shader != cloudFragShader)
        {
            material = new Material(cloudFragShader);
        }

        // Set the container bounds
        material.SetVector("boundsMin", cloudContainer.position - cloudContainer.localScale / 2);
        material.SetVector("boundsMax", cloudContainer.position + cloudContainer.localScale / 2);

        Graphics.Blit(source, destination, material);

        // Compute shader
        buffersToDispose = new List<ComputeBuffer>();
        SetShaderParams(source);
        //Render(destination);
    }


    private void InitRenderTexture()
    {
        if (rt == null || rt.width != cam.pixelWidth || rt.height != cam.pixelHeight)
        {
            // Release render texture if we already have one
            if (rt != null)
                rt.Release();

            // Get a render target for Ray Tracing
            rt = new RenderTexture(cam.pixelWidth, cam.pixelHeight, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            rt.enableRandomWrite = true;
            rt.Create();
        }
    }

    private void SetShaderParams(RenderTexture source)
    {
        computeShader.SetMatrix("invViewMatrix", cam.cameraToWorldMatrix);
        computeShader.SetMatrix("invProjectionMatrix", cam.projectionMatrix.inverse);
        computeShader.SetVector("cameraPos", cam.transform.position);
        computeShader.SetTexture(kernel, "Source", source);

        computeShader.SetVector("containerBoundsMin", cloudContainer.position - cloudContainer.localScale / 2);
        computeShader.SetVector("containerBoundsMax", cloudContainer.position + cloudContainer.localScale / 2);

        computeShader.SetTextureFromGlobal(kernel, "_DepthTexture", "_CameraDepthTexture");
    }

    private void Render(RenderTexture destination)
    {
        // Make sure we have a current render target
        InitRenderTexture();

        // Set the target and dispatch the compute shader
        computeShader.SetTexture(kernel, "Result", rt);
        int threadGroupsX = Mathf.CeilToInt(cam.pixelWidth / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(cam.pixelHeight / 8.0f);
        computeShader.Dispatch(kernel, threadGroupsX, threadGroupsY, 1);

        // Blit the result texture to the screen
        Graphics.Blit(rt, destination);

        foreach (var buffer in buffersToDispose)
        {
            buffer.Dispose();
        }
    }
}
