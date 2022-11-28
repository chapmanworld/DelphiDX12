unit D3DClass;

{$IFDEF FPC}
{$mode delphiunicode}{$H+}
{$ENDIF}

interface

uses
    Classes, SysUtils, Windows,
    DX12.D3DCommon,
    DX12.D3D11,
    DX12.DXGI,
    DX12.D3DCompiler,
    DX12.D3DX10,
    DirectX.Math;

type

    { TD3DClass }

    TD3DClass = class(TObject)
    private
        m_vsync_enabled: boolean;
        m_videoCardMemory: integer;
        m_videoCardDescription: WideString; // array [0..127] of wchar;
        m_swapChain: IDXGISwapChain;
        m_device: ID3D11Device;
        m_deviceContext: ID3D11DeviceContext;
        m_renderTargetView: ID3D11RenderTargetView;
        m_depthStencilBuffer: ID3D11Texture2D;
        m_depthStencilState: ID3D11DepthStencilState;
        m_depthStencilView: ID3D11DepthStencilView;
        m_rasterState: ID3D11RasterizerState;
        m_projectionMatrix: TXMMATRIX;
        m_worldMatrix: TXMMATRIX;
        m_orthoMatrix: TXMMATRIX;
        m_orthoMatrix2: TD3DMATRIX;
        m_viewport: TD3D11_VIEWPORT;

        m_depthDisabledStencilState: ID3D11DepthStencilState;
        m_alphaEnableBlendingState: ID3D11BlendState;
        m_alphaDisableBlendingState: ID3D11BlendState;
    public
        constructor Create;
        destructor Destroy; override;

        function Initialize(screenWidth, screenHeight: integer; vsync: boolean; hwnd: HWND; fullscreen: boolean;
            screenDepth, screenNear: single): HResult;
        procedure Shutdown();

        procedure BeginScene(red, green, blue, alpha: single);
        procedure EndScene();

        function GetDevice(): ID3D11Device;
        function GetDeviceContext(): ID3D11DeviceContext;

        function GetProjectionMatrix: TXMMATRIX;
        function GetWorldMatrix: TXMMATRIX;
        function GetOrthoMatrix: TXMMATRIX;

        procedure GetVideoCardInfo(var cardName: WideString; var memory: integer);
        procedure TurnZBufferOn();
        procedure TurnZBufferOff();

        procedure TurnOnAlphaBlending();
        procedure TurnOffAlphaBlending();

        function GetDepthStencilView(): ID3D11DepthStencilView;
        procedure SetBackBufferRenderTarget();
        procedure ResetViewport();

    end;

implementation

{ TD3DClass }

constructor TD3DClass.Create;
begin

end;



destructor TD3DClass.Destroy;
begin
    inherited Destroy;
end;



function TD3DClass.Initialize(screenWidth, screenHeight: integer; vsync: boolean; hwnd: HWND; fullscreen: boolean;
    screenDepth, screenNear: single): HResult;
var
    factory: IDXGIFactory;
    adapter: IDXGIAdapter;
    adapterOutput: IDXGIOutput;
    numModes, i, numerator, denominator: UINT;
    stringLength: ULONGLONG;
    displayModeList: array of TDXGI_MODE_DESC;
    adapterDesc: TDXGI_ADAPTER_DESC;
    error: integer;
    swapChainDesc: TDXGI_SWAP_CHAIN_DESC;
    featureLevel: TD3D_FEATURE_LEVEL;
    backBufferPtr: ID3D11Texture2D;
    depthBufferDesc: TD3D11_TEXTURE2D_DESC;
    depthStencilDesc: TD3D11_DEPTH_STENCIL_DESC;
    depthStencilViewDesc: TD3D11_DEPTH_STENCIL_VIEW_DESC;
    rasterDesc: TD3D11_RASTERIZER_DESC;
    fieldOfView, screenAspect: single;
    lFeaturLevel: TD3D_FEATURE_LEVEL;
    depthDisabledStencilDesc: TD3D11_DEPTH_STENCIL_DESC;
    blendStateDescription: TD3D11_BLEND_DESC;

begin

    // Store the vsync setting.
    m_vsync_enabled := vsync;

    // Create a DirectX graphics interface factory.
    Result := CreateDXGIFactory(IID_IDXGIFactory, factory);
    if (FAILED(Result)) then
        Exit;


    // Use the factory to create an adapter for the primary graphics interface (video card).
    Result := factory.EnumAdapters(0, adapter);
    if (FAILED(Result)) then
        Exit;

    // Enumerate the primary adapter output (monitor).
    Result := adapter.EnumOutputs(0, adapterOutput);
    if (FAILED(Result)) then
        Exit;

    // Get the number of modes that fit the DXGI_FORMAT_R8G8B8A8_UNORM display format for the adapter output (monitor).
    Result := adapterOutput.GetDisplayModeList(DXGI_FORMAT_R8G8B8A8_UNORM, DXGI_ENUM_MODES_INTERLACED, numModes, nil);
    if (FAILED(Result)) then
        Exit;

    // Create a list to hold all the possible display modes for this monitor/video card combination.
    SetLength(displayModeList, numModes);

    // Now fill the display mode list structures.
    Result := adapterOutput.GetDisplayModeList(DXGI_FORMAT_R8G8B8A8_UNORM, DXGI_ENUM_MODES_INTERLACED, numModes, @displayModeList[0]);
    if (FAILED(Result)) then
        Exit;

    // Now go through all the display modes and find the one that matches the screen width and height.
    // When a match is found store the numerator and denominator of the refresh rate for that monitor.
    for i := 0 to numModes - 11 do
    begin
        if (displayModeList[i].Width = screenWidth) then
        begin
            if (displayModeList[i].Height = screenHeight) then
            begin
                numerator := displayModeList[i].RefreshRate.Numerator;
                denominator := displayModeList[i].RefreshRate.Denominator;
            end;
        end;
    end;

    // Get the adapter (video card) description.
    Result := adapter.GetDesc(adapterDesc);
    if (FAILED(Result)) then
        Exit;

    // Store the dedicated video card memory in megabytes.
    m_videoCardMemory := trunc((adapterDesc.DedicatedVideoMemory / 1024 / 1024));

    // Convert the name of the video card to a character array and store it.
    // Move(adapterDesc.Description[0],m_videoCardDescription ,128);


    // Release the display mode list.
    SetLength(displayModeList, 0);


    // Release the adapter output.
    adapterOutput := nil;

    // Release the adapter.
    adapter := nil;

    // Release the factory.
    factory := nil;

    // Initialize the swap chain description.
    ZeroMemory(@swapChainDesc, sizeof(swapChainDesc));

    // Set to a single back buffer.
    swapChainDesc.BufferCount := 1;

    // Set the width and height of the back buffer.
    swapChainDesc.BufferDesc.Width := screenWidth;
    swapChainDesc.BufferDesc.Height := screenHeight;

    // Set regular 32-bit surface for the back buffer.
    swapChainDesc.BufferDesc.Format := DXGI_FORMAT_R8G8B8A8_UNORM;

    // Set the refresh rate of the back buffer.
    if (m_vsync_enabled) then
    begin
        swapChainDesc.BufferDesc.RefreshRate.Numerator := numerator;
        swapChainDesc.BufferDesc.RefreshRate.Denominator := denominator;
    end
    else
    begin
        swapChainDesc.BufferDesc.RefreshRate.Numerator := 0;
        swapChainDesc.BufferDesc.RefreshRate.Denominator := 1;
    end;

    // Set the usage of the back buffer.
    swapChainDesc.BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;

    // Set the handle for the window to render to.
    swapChainDesc.OutputWindow := hwnd;

    // Turn multisampling off.
    swapChainDesc.SampleDesc.Count := 1;
    swapChainDesc.SampleDesc.Quality := 0;

    // Set to full screen or windowed mode.
    if (fullscreen) then
    begin
        swapChainDesc.Windowed := False;
    end
    else
    begin
        swapChainDesc.Windowed := True;
    end;

    // Set the scan line ordering and scaling to unspecified.
    swapChainDesc.BufferDesc.ScanlineOrdering := DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
    swapChainDesc.BufferDesc.Scaling := DXGI_MODE_SCALING_UNSPECIFIED;

    // Discard the back buffer contents after presenting.
    swapChainDesc.SwapEffect := DXGI_SWAP_EFFECT_DISCARD;

    // Don't set the advanced flags.
    swapChainDesc.Flags := 0;

    // Set the feature level to DirectX 11.
    featureLevel := D3D_FEATURE_LEVEL_11_0;

    // Create the swap chain, Direct3D device, and Direct3D device context.
    Result := D3D11CreateDeviceAndSwapChain(nil, D3D_DRIVER_TYPE_HARDWARE, 0, 0, @featureLevel, 1, D3D11_SDK_VERSION,
        @swapChainDesc, m_swapChain, m_device, lFeaturLevel, m_deviceContext);
    if (FAILED(Result)) then
        Exit;

    // Get the pointer to the back buffer.
    Result := m_swapChain.GetBuffer(0, IID_ID3D11Texture2D, backBufferPtr);
    if (FAILED(Result)) then
        Exit;

    // Create the render target view with the back buffer pointer.
    Result := m_device.CreateRenderTargetView(backBufferPtr, nil, m_renderTargetView);
    if (FAILED(Result)) then
        Exit;

    // Release pointer to the back buffer as we no longer need it.
    backBufferPtr := nil;

    // Initialize the description of the depth buffer.
    ZeroMemory(@depthBufferDesc, sizeof(depthBufferDesc));

    // Set up the description of the depth buffer.
    depthBufferDesc.Width := screenWidth;
    depthBufferDesc.Height := screenHeight;
    depthBufferDesc.MipLevels := 1;
    depthBufferDesc.ArraySize := 1;
    depthBufferDesc.Format := DXGI_FORMAT_D24_UNORM_S8_UINT;
    depthBufferDesc.SampleDesc.Count := 1;
    depthBufferDesc.SampleDesc.Quality := 0;
    depthBufferDesc.Usage := D3D11_USAGE_DEFAULT;
    depthBufferDesc.BindFlags := Ord(D3D11_BIND_DEPTH_STENCIL);
    depthBufferDesc.CPUAccessFlags := 0;
    depthBufferDesc.MiscFlags := 0;

    // Create the texture for the depth buffer using the filled out description.
    Result := m_device.CreateTexture2D(depthBufferDesc, nil, m_depthStencilBuffer);
    if (FAILED(Result)) then
        Exit;

    // Initialize the description of the stencil state.
    ZeroMemory(@depthStencilDesc, sizeof(depthStencilDesc));

    // Set up the description of the stencil state.
    depthStencilDesc.DepthEnable := True;
    depthStencilDesc.DepthWriteMask := D3D11_DEPTH_WRITE_MASK_ALL;
    depthStencilDesc.DepthFunc := D3D11_COMPARISON_LESS;

    depthStencilDesc.StencilEnable := True;
    depthStencilDesc.StencilReadMask := $FF;
    depthStencilDesc.StencilWriteMask := $FF;

    // Stencil operations if pixel is front-facing.
    depthStencilDesc.FrontFace.StencilFailOp := D3D11_STENCIL_OP_KEEP;
    depthStencilDesc.FrontFace.StencilDepthFailOp := D3D11_STENCIL_OP_INCR;
    depthStencilDesc.FrontFace.StencilPassOp := D3D11_STENCIL_OP_KEEP;
    depthStencilDesc.FrontFace.StencilFunc := D3D11_COMPARISON_ALWAYS;

    // Stencil operations if pixel is back-facing.
    depthStencilDesc.BackFace.StencilFailOp := D3D11_STENCIL_OP_KEEP;
    depthStencilDesc.BackFace.StencilDepthFailOp := D3D11_STENCIL_OP_DECR;
    depthStencilDesc.BackFace.StencilPassOp := D3D11_STENCIL_OP_KEEP;
    depthStencilDesc.BackFace.StencilFunc := D3D11_COMPARISON_ALWAYS;

    // Create the depth stencil state.
    Result := m_device.CreateDepthStencilState(depthStencilDesc, m_depthStencilState);
    if (FAILED(Result)) then
        Exit;

    // Set the depth stencil state.
    m_deviceContext.OMSetDepthStencilState(m_depthStencilState, 1);

    // Initialize the depth stencil view.
    ZeroMemory(@depthStencilViewDesc, sizeof(depthStencilViewDesc));

    // Set up the depth stencil view description.
    depthStencilViewDesc.Format := DXGI_FORMAT_D24_UNORM_S8_UINT;
    depthStencilViewDesc.ViewDimension := D3D11_DSV_DIMENSION_TEXTURE2D;
    depthStencilViewDesc.Texture2D.MipSlice := 0;

    // Create the depth stencil view.
    Result := m_device.CreateDepthStencilView(m_depthStencilBuffer, @depthStencilViewDesc, m_depthStencilView);
    if (FAILED(Result)) then
        Exit;

    // Bind the render target view and depth stencil buffer to the output render pipeline.
    m_deviceContext.OMSetRenderTargets(1, @m_renderTargetView, m_depthStencilView);

    // Setup the raster description which will determine how and what polygons will be drawn.
    rasterDesc.AntialiasedLineEnable := False;
    rasterDesc.CullMode := D3D11_CULL_BACK;
    rasterDesc.DepthBias := 0;
    rasterDesc.DepthBiasClamp := 0.0;
    rasterDesc.DepthClipEnable := True;
    rasterDesc.FillMode := D3D11_FILL_SOLID;
    rasterDesc.FrontCounterClockwise := False;
    rasterDesc.MultisampleEnable := False;
    rasterDesc.ScissorEnable := False;
    rasterDesc.SlopeScaledDepthBias := 0.0;

    // Create the rasterizer state from the description we just filled out.
    Result := m_device.CreateRasterizerState(rasterDesc, m_rasterState);
    if (FAILED(Result)) then
        Exit;

    // Now set the rasterizer state.
    m_deviceContext.RSSetState(m_rasterState);

    // Setup the viewport for rendering.
    m_viewport.Width := screenWidth;
    m_viewport.Height := screenHeight;
    m_viewport.MinDepth := 0.0;
    m_viewport.MaxDepth := 1.0;
    m_viewport.TopLeftX := 0.0;
    m_viewport.TopLeftY := 0.0;

    // Create the viewport.
    m_deviceContext.RSSetViewports(1, @m_viewport);

    // Setup the projection matrix.
    fieldOfView := 3.141592654 / 4.0;
    screenAspect := screenWidth / screenHeight;

    // Create the projection matrix for 3D rendering.
    m_projectionMatrix := XMMatrixPerspectiveFovLH(fieldOfView, screenAspect, screenNear, screenDepth);

    // Initialize the world matrix to the identity matrix.
    m_worldMatrix := XMMatrixIdentity();

    // Create an orthographic projection matrix for 2D rendering.

    D3DXMatrixOrthoLH(@m_orthoMatrix2, screenWidth, screenHeight, screenNear, screenDepth);
    m_orthoMatrix := XMMatrixOrthographicLH(screenWidth, screenHeight, screenNear, screenDepth);

    // Clear the second depth stencil state before setting the parameters.
    ZeroMemory(@depthDisabledStencilDesc, sizeof(depthDisabledStencilDesc));

    // Now create a second depth stencil state which turns off the Z buffer for 2D rendering.  The only difference is
    // that DepthEnable is set to false, all other parameters are the same as the other depth stencil state.
    depthDisabledStencilDesc.DepthEnable := False;
    depthDisabledStencilDesc.DepthWriteMask := D3D11_DEPTH_WRITE_MASK_ALL;
    depthDisabledStencilDesc.DepthFunc := D3D11_COMPARISON_LESS;
    depthDisabledStencilDesc.StencilEnable := True;
    depthDisabledStencilDesc.StencilReadMask := $FF;
    depthDisabledStencilDesc.StencilWriteMask := $FF;
    depthDisabledStencilDesc.FrontFace.StencilFailOp := D3D11_STENCIL_OP_KEEP;
    depthDisabledStencilDesc.FrontFace.StencilDepthFailOp := D3D11_STENCIL_OP_INCR;
    depthDisabledStencilDesc.FrontFace.StencilPassOp := D3D11_STENCIL_OP_KEEP;
    depthDisabledStencilDesc.FrontFace.StencilFunc := D3D11_COMPARISON_ALWAYS;
    depthDisabledStencilDesc.BackFace.StencilFailOp := D3D11_STENCIL_OP_KEEP;
    depthDisabledStencilDesc.BackFace.StencilDepthFailOp := D3D11_STENCIL_OP_DECR;
    depthDisabledStencilDesc.BackFace.StencilPassOp := D3D11_STENCIL_OP_KEEP;
    depthDisabledStencilDesc.BackFace.StencilFunc := D3D11_COMPARISON_ALWAYS;

    // Create the state using the device.
    Result := m_device.CreateDepthStencilState(depthDisabledStencilDesc, m_depthDisabledStencilState);


    // Clear the blend state description.
    ZeroMemory(@blendStateDescription, sizeof(TD3D11_BLEND_DESC));

    // Create an alpha enabled blend state description.
    blendStateDescription.RenderTarget[0].BlendEnable := True;
    blendStateDescription.RenderTarget[0].SrcBlend := D3D11_BLEND_SRC_ALPHA;
    blendStateDescription.RenderTarget[0].DestBlend := D3D11_BLEND_INV_SRC_ALPHA;
    blendStateDescription.RenderTarget[0].BlendOp := D3D11_BLEND_OP_ADD;
    blendStateDescription.RenderTarget[0].SrcBlendAlpha := D3D11_BLEND_ONE;
    blendStateDescription.RenderTarget[0].DestBlendAlpha := D3D11_BLEND_ZERO;
    blendStateDescription.RenderTarget[0].BlendOpAlpha := D3D11_BLEND_OP_ADD;
    blendStateDescription.RenderTarget[0].RenderTargetWriteMask := $0f;

    // Create the blend state using the description.
    Result := m_device.CreateBlendState(blendStateDescription, m_alphaEnableBlendingState);
    if (FAILED(Result)) then Exit;

    // Modify the description to create an alpha disabled blend state description.
    blendStateDescription.RenderTarget[0].BlendEnable := False;

    // Create the blend state using the description.
    Result := m_device.CreateBlendState(blendStateDescription, m_alphaDisableBlendingState);
end;



procedure TD3DClass.Shutdown();
begin
    // Before shutting down set to windowed mode or when you release the swap chain it will throw an exception.
    if (m_swapChain <> nil) then
    begin
        m_swapChain.SetFullscreenState(False, nil);
    end;
    m_alphaEnableBlendingState := nil;
    m_alphaDisableBlendingState := nil;
    m_depthDisabledStencilState := nil;
    m_rasterState := nil;
    m_depthStencilView := nil;
    m_depthStencilState := nil;
    m_depthStencilBuffer := nil;
    m_renderTargetView := nil;
    m_deviceContext := nil;
    m_device := nil;
    m_swapChain := nil;
end;



procedure TD3DClass.BeginScene(red, green, blue, alpha: single);
var
    color: TFloatArray4;
begin

    // Setup the color to clear the buffer to.
    color[0] := red;
    color[1] := green;
    color[2] := blue;
    color[3] := alpha;

    // Clear the back buffer.
    m_deviceContext.ClearRenderTargetView(m_renderTargetView, color);

    // Clear the depth buffer.
    m_deviceContext.ClearDepthStencilView(m_depthStencilView, Ord(D3D11_CLEAR_DEPTH), 1.0, 0);
end;



procedure TD3DClass.EndScene();
begin
    // Present the back buffer to the screen since rendering is complete.
    if (m_vsync_enabled) then
    begin
        // Lock to screen refresh rate.
        m_swapChain.Present(1, 0);
    end
    else
    begin
        // Present as fast as possible.
        m_swapChain.Present(0, 0);
    end;

end;



function TD3DClass.GetDevice(): ID3D11Device;
begin
    Result := m_device;
end;



function TD3DClass.GetDeviceContext(): ID3D11DeviceContext;
begin
    Result := m_deviceContext;
end;



function TD3DClass.GetProjectionMatrix: TXMMATRIX;
begin
    Result := m_projectionMatrix;
end;



function TD3DClass.GetWorldMatrix: TXMMATRIX;
begin
    Result := m_worldMatrix;
end;



function TD3DClass.GetOrthoMatrix: TXMMATRIX;
begin
    Result := m_orthoMatrix;
end;



procedure TD3DClass.GetVideoCardInfo(var cardName: WideString; var memory: integer);
begin
    cardName := m_videoCardDescription;
    memory := m_videoCardMemory;

end;



procedure TD3DClass.TurnZBufferOn();
begin
    m_deviceContext.OMSetDepthStencilState(m_depthStencilState, 1);
end;



procedure TD3DClass.TurnZBufferOff();
begin
    m_deviceContext.OMSetDepthStencilState(m_depthDisabledStencilState, 1);
end;



procedure TD3DClass.TurnOnAlphaBlending();
var
    blendFactor: TFloatArray4;
begin
    // Setup the blend factor.
    blendFactor[0] := 0.0;
    blendFactor[1] := 0.0;
    blendFactor[2] := 0.0;
    blendFactor[3] := 0.0;

    // Turn on the alpha blending.
    m_deviceContext.OMSetBlendState(m_alphaEnableBlendingState, blendFactor, $ffffffff);
end;



procedure TD3DClass.TurnOffAlphaBlending();
var
    blendFactor: TFloatArray4;
begin
    // Setup the blend factor.
    blendFactor[0] := 0.0;
    blendFactor[1] := 0.0;
    blendFactor[2] := 0.0;
    blendFactor[3] := 0.0;

    // Turn on the alpha blending.
    m_deviceContext.OMSetBlendState(m_alphaDisableBlendingState, blendFactor, $ffffffff);
end;



function TD3DClass.GetDepthStencilView(): ID3D11DepthStencilView;
begin
    Result := m_depthStencilView;
end;



procedure TD3DClass.SetBackBufferRenderTarget();
begin
    // Bind the render target view and depth stencil buffer to the output render pipeline.
    m_deviceContext.OMSetRenderTargets(1, @m_renderTargetView, m_depthStencilView);
end;



procedure TD3DClass.ResetViewport();
begin
    // Set the viewport.
    m_deviceContext.RSSetViewports(1, @m_viewport);
end;

end.