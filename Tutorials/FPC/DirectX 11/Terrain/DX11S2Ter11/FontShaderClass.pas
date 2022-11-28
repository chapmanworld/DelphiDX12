unit FontShaderClass;

{$IFDEF FPC}
{$mode DelphiUnicode}{$H+}
{$ENDIF}

interface

uses
    Classes, SysUtils,
    Windows,
    DX12.D3D11, DX12.D3DCompiler,
    DX12.D3D10,
    DX12.DXGI,
    DX12.D3DCommon,
    DirectX.Math;

type

    TMatrixBufferType = packed record
        world: TXMMATRIX;
        view: TXMMATRIX;
        projection: TXMMATRIX;
    end;

    TPixelBufferType = packed record
        pixelColor: TXMFLOAT4;
    end;

    { TFontShaderClass }

    TFontShaderClass = class(TObject)
    private
        m_vertexShader: ID3D11VertexShader;
        m_pixelShader: ID3D11PixelShader;
        m_layout: ID3D11InputLayout;
        m_matrixBuffer: ID3D11Buffer;
        m_sampleState: ID3D11SamplerState;
        m_pixelBuffer: ID3D11Buffer;
    private
        function InitializeShader(device: ID3D11Device; hwnd: HWND; vsFilename, psFilename: WideString): HResult;
        procedure ShutdownShader();
        procedure OutputShaderErrorMessage(errorMessage: ID3D10Blob; hwnd: HWND; shaderFilename: WideString);

        function SetShaderParameters(deviceContext: ID3D11DeviceContext; worldMatrix, viewMatrix, projectionMatrix: TXMMATRIX;
            texture: ID3D11ShaderResourceView; pixelColor: TXMFLOAT4): HResult;
        procedure RenderShader(deviceContext: ID3D11DeviceContext; indexCount: integer);
    public
        constructor Create;
        destructor Destroy; override;
        function Initialize(device: ID3D11Device; hwnd: HWND): HResult;
        procedure Shutdown();
        function Render(deviceContext: ID3D11DeviceContext; indexCount: integer; worldMatrix, viewMatrix, projectionMatrix: TXMMATRIX;
            texture: ID3D11ShaderResourceView; pixelColor: TXMFLOAT4): HResult;
    end;




implementation

{ TFontShaderClass }

function TFontShaderClass.InitializeShader(device: ID3D11Device; hwnd: HWND; vsFilename, psFilename: WideString): HResult;
var
    errorMessage: ID3D10Blob;
    vertexShaderBuffer: ID3D10Blob;
    pixelShaderBuffer: ID3D10Blob;
    polygonLayout: array [0..1] of TD3D11_INPUT_ELEMENT_DESC;
    numElements: uint32;
    matrixBufferDesc: TD3D11_BUFFER_DESC;
    samplerDesc: TD3D11_SAMPLER_DESC;
    pixelBufferDesc: TD3D11_BUFFER_DESC;
begin
    // Compile the vertex shader code.
    Result := D3DCompileFromFile(pwidechar(vsFilename), nil, nil, 'FontVertexShader', 'vs_5_0', D3D10_SHADER_ENABLE_STRICTNESS,
        0, vertexShaderBuffer, errorMessage);
    if (FAILED(Result)) then
    begin
        // If the shader failed to compile it should have writen something to the error message.
        if (errorMessage <> nil) then
        begin
            OutputShaderErrorMessage(errorMessage, hwnd, vsFilename);
        end
        // If there was  nothing in the error message then it simply could not find the shader file itself.
        else
        begin
            MessageBoxW(hwnd, pwidechar(vsFilename), 'Missing Shader File', MB_OK);
        end;

        Exit;
    end;


    // Compile the pixel shader code.
    Result := D3DCompileFromFile(pwidechar(psFilename), nil, nil, 'FontPixelShader', 'ps_5_0', D3D10_SHADER_ENABLE_STRICTNESS,
        0, pixelShaderBuffer, errorMessage);
    if (FAILED(Result)) then
    begin
        // If the shader failed to compile it should have writen something to the error message.
        if (errorMessage <> nil) then
        begin
            OutputShaderErrorMessage(errorMessage, hwnd, psFilename);
        end
        // If there was nothing in the error message then it simply could not find the file itself.
        else
        begin
            MessageBoxW(hwnd, pwidechar(psFilename), 'Missing Shader File', MB_OK);
        end;

        Exit;
    end;

    // Create the vertex shader from the buffer.
    Result := device.CreateVertexShader(vertexShaderBuffer.GetBufferPointer(), vertexShaderBuffer.GetBufferSize(), nil, m_vertexShader);
    if (FAILED(Result)) then Exit;

    // Create the pixel shader from the buffer.
    Result := device.CreatePixelShader(pixelShaderBuffer.GetBufferPointer(), pixelShaderBuffer.GetBufferSize(), nil, m_pixelShader);
    if (FAILED(Result)) then Exit;

    // Create the vertex input layout description.
    // This setup needs to match the VertexType stucture in the ModelClass and in the shader.
    polygonLayout[0].SemanticName := 'POSITION';
    polygonLayout[0].SemanticIndex := 0;
    polygonLayout[0].Format := DXGI_FORMAT_R32G32B32_FLOAT;
    polygonLayout[0].InputSlot := 0;
    polygonLayout[0].AlignedByteOffset := 0;
    polygonLayout[0].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
    polygonLayout[0].InstanceDataStepRate := 0;

    polygonLayout[1].SemanticName := 'TEXCOORD';
    polygonLayout[1].SemanticIndex := 0;
    polygonLayout[1].Format := DXGI_FORMAT_R32G32_FLOAT;
    polygonLayout[1].InputSlot := 0;
    polygonLayout[1].AlignedByteOffset := D3D11_APPEND_ALIGNED_ELEMENT;
    polygonLayout[1].InputSlotClass := D3D11_INPUT_PER_VERTEX_DATA;
    polygonLayout[1].InstanceDataStepRate := 0;

    // Get a count of the elements in the layout.
    numElements := sizeof(polygonLayout) div sizeof(polygonLayout[0]);

    // Create the vertex input layout.
    Result := device.CreateInputLayout(@polygonLayout[0], numElements, vertexShaderBuffer.GetBufferPointer(),
        vertexShaderBuffer.GetBufferSize(), m_layout);
    if (FAILED(Result)) then Exit;

    // Release the vertex shader buffer and pixel shader buffer since they are no longer needed.
    vertexShaderBuffer := nil;

    pixelShaderBuffer := nil;

    // Setup the description of the dynamic matrix buffer that is in the vertex shader.
    matrixBufferDesc.Usage := D3D11_USAGE_DYNAMIC;
    matrixBufferDesc.ByteWidth := sizeof(TMatrixBufferType);
    matrixBufferDesc.BindFlags := Ord(D3D11_BIND_CONSTANT_BUFFER);
    matrixBufferDesc.CPUAccessFlags := Ord(D3D11_CPU_ACCESS_WRITE);
    matrixBufferDesc.MiscFlags := 0;
    matrixBufferDesc.StructureByteStride := 0;

    // Create the matrix buffer pointer so we can access the vertex shader constant buffer from within this class.
    Result := device.CreateBuffer(matrixBufferDesc, nil, m_matrixBuffer);
    if (FAILED(Result)) then Exit;

    // Create a texture sampler state description.
    samplerDesc.Filter := D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    samplerDesc.AddressU := D3D11_TEXTURE_ADDRESS_WRAP;
    samplerDesc.AddressV := D3D11_TEXTURE_ADDRESS_WRAP;
    samplerDesc.AddressW := D3D11_TEXTURE_ADDRESS_WRAP;
    samplerDesc.MipLODBias := 0.0;
    samplerDesc.MaxAnisotropy := 1;
    samplerDesc.ComparisonFunc := D3D11_COMPARISON_ALWAYS;
    samplerDesc.BorderColor[0] := 0;
    samplerDesc.BorderColor[1] := 0;
    samplerDesc.BorderColor[2] := 0;
    samplerDesc.BorderColor[3] := 0;
    samplerDesc.MinLOD := 0;
    samplerDesc.MaxLOD := D3D11_FLOAT32_MAX;

    // Create the texture sampler state.
    Result := device.CreateSamplerState(samplerDesc, m_sampleState);
    if (FAILED(Result)) then Exit;

    // Setup the description of the dynamic pixel constant buffer that is in the pixel shader.
    pixelBufferDesc.Usage := D3D11_USAGE_DYNAMIC;
    pixelBufferDesc.ByteWidth := sizeof(TPixelBufferType);
    pixelBufferDesc.BindFlags := Ord(D3D11_BIND_CONSTANT_BUFFER);
    pixelBufferDesc.CPUAccessFlags := Ord(D3D11_CPU_ACCESS_WRITE);
    pixelBufferDesc.MiscFlags := 0;
    pixelBufferDesc.StructureByteStride := 0;

    // Create the pixel constant buffer pointer so we can access the pixel shader constant buffer from within this class.
    Result := device.CreateBuffer(pixelBufferDesc, nil, m_pixelBuffer);

end;



procedure TFontShaderClass.ShutdownShader();
begin
    // Release the pixel constant buffer.
    m_pixelBuffer := nil;

    // Release the sampler state.
    m_sampleState := nil;

    // Release the constant buffer.
    m_matrixBuffer := nil;

    // Release the layout.
    m_layout := nil;

    // Release the pixel shader.
    m_pixelShader := nil;

    // Release the vertex shader.
    m_vertexShader := nil;
end;



procedure TFontShaderClass.OutputShaderErrorMessage(errorMessage: ID3D10Blob; hwnd: HWND; shaderFilename: WideString);
var
    compileErrors: pansichar;
    lFileStream: TFileStream;
    bufferSize, i: uint64;
begin
    // Get a pointer to the error message text buffer.
    compileErrors := errorMessage.GetBufferPointer();

    // Get the length of the message.
    bufferSize := errorMessage.GetBufferSize();

    // Open a file to write the error message to.
    lFileStream := TFileStream.Create('shader-error.txt', fmCreate);
    try
        // Write out the error message.
        lFileStream.WriteBuffer(compileErrors, bufferSize);
    finally
        // Close the file.
        lFileStream.Free;
    end;
    // Release the error message.
    errorMessage := nil;

    // Pop a message up on the screen to notify the user to check the text file for compile errors.
    MessageBoxW(hwnd, 'Error compiling shader.  Check shader-error.txt for message.', pwidechar(shaderFilename), MB_OK);
end;



function TFontShaderClass.SetShaderParameters(deviceContext: ID3D11DeviceContext; worldMatrix, viewMatrix, projectionMatrix: TXMMATRIX;
    texture: ID3D11ShaderResourceView; pixelColor: TXMFLOAT4): HResult;
var

    mappedResource: TD3D11_MAPPED_SUBRESOURCE;
    dataPtr: ^TMatrixBufferType;
    bufferNumber: uint32;
    dataPtr2: ^TPixelBufferType;

begin
    // Transpose the matrices to prepare them for the shader.
    worldMatrix := XMMatrixTranspose(worldMatrix);
    viewMatrix := XMMatrixTranspose(viewMatrix);
    projectionMatrix := XMMatrixTranspose(projectionMatrix);

    // Lock the matrix buffer so it can be written to.
    Result := deviceContext.Map(m_matrixBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, mappedResource);
    if (FAILED(Result)) then Exit;

    // Get a pointer to the data in the constant buffer.
    dataPtr := mappedResource.pData;
    // Copy the matrices into the constant buffer.
    dataPtr.world := worldMatrix;
    dataPtr.view := viewMatrix;
    dataPtr.projection := projectionMatrix;

    // Unlock the matrix buffer.
    deviceContext.Unmap(m_matrixBuffer, 0);

    // Set the position of the constant buffer in the vertex shader.
    bufferNumber := 0;

    // Now set the matrix buffer in the vertex shader with the updated values.
    deviceContext.VSSetConstantBuffers(bufferNumber, 1, @m_matrixBuffer);

    // Set shader texture resource in the pixel shader.
    deviceContext.PSSetShaderResources(0, 1, @texture);

    // Lock the matrix constant buffer so it can be written to.
    Result := deviceContext.Map(m_pixelBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, mappedResource);
    if (FAILED(Result)) then Exit;

    // Get a pointer to the data in the pixel constant buffer.
    dataPtr2 := mappedResource.pData;

    // Copy the pixel color into the pixel constant buffer.
    dataPtr2.pixelColor := pixelColor;

    // Unlock the pixel constant buffer.
    deviceContext.Unmap(m_pixelBuffer, 0);

    // Set the position of the pixel constant buffer in the pixel shader.
    bufferNumber := 0;

    // Now set the pixel constant buffer in the pixel shader with the updated value.
    deviceContext.PSSetConstantBuffers(bufferNumber, 1, @m_pixelBuffer);

end;



procedure TFontShaderClass.RenderShader(deviceContext: ID3D11DeviceContext; indexCount: integer);
begin
    // Set the vertex input layout.
    deviceContext.IASetInputLayout(m_layout);

    // Set the vertex and pixel shaders that will be used for rendering.
    deviceContext.VSSetShader(m_vertexShader, nil, 0);
    deviceContext.PSSetShader(m_pixelShader, nil, 0);

    // Set the sampler state in the pixel shader.
    deviceContext.PSSetSamplers(0, 1, @m_sampleState);

    // Render the font data.
    deviceContext.DrawIndexed(indexCount, 0, 0);
end;



constructor TFontShaderClass.Create;
begin

end;



destructor TFontShaderClass.Destroy;
begin
    inherited Destroy;
end;



function TFontShaderClass.Initialize(device: ID3D11Device; hwnd: HWND): HResult;
begin
    // Initialize the vertex and pixel shaders.
    Result := InitializeShader(device, hwnd, 'font.vs', 'font.ps');
end;



procedure TFontShaderClass.Shutdown();
begin
    // Shutdown the vertex and pixel shaders as well as the related objects.
    ShutdownShader();
end;



function TFontShaderClass.Render(deviceContext: ID3D11DeviceContext; indexCount: integer;
    worldMatrix, viewMatrix, projectionMatrix: TXMMATRIX; texture: ID3D11ShaderResourceView; pixelColor: TXMFLOAT4): HResult;
begin
    // Set the shader parameters that it will use for rendering.
    Result := SetShaderParameters(deviceContext, worldMatrix, viewMatrix, projectionMatrix, texture, pixelColor);
    if (Result <> S_OK) then Exit;

    // Now render the prepared buffers with the shader.
    RenderShader(deviceContext, indexCount);
end;

end.
