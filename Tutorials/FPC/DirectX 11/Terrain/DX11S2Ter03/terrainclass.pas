unit TerrainClass;

interface

uses
    Classes, SysUtils, Windows,
    DX12.D3D11,
    DirectX.Math;

type
    TVertexType = record
        position: TXMFLOAT3;
        texture: TXMFLOAT2;
    end;

    THeightMapType = record
        x, y, z: single;
    end;

    TModelType = record
        x, y, z: single;
        tu, tv: single;
    end;


    { TTerrainClass }

    TTerrainClass = class(TObject)
    private
        m_vertexBuffer, m_indexBuffer: ID3D11Buffer;
        m_vertexCount, m_indexCount: int32;

        m_terrainHeight, m_terrainWidth: integer;
        m_heightScale: single;
        m_terrainFilename: WideString;
        m_heightMap: array of THeightMapType;
        m_terrainModel: array of TModelType;
    public
        constructor Create;
        destructor Destroy; override;

        function Initialize(device: ID3D11Device; setupFilename: WideString): HResult;
        procedure Shutdown();
        function Render(deviceContext: ID3D11DeviceContext): HResult;
        function GetIndexCount(): int32;
    private
        function InitializeBuffers(device: ID3D11Device): HResult;
        procedure ShutdownBuffers();
        procedure RenderBuffers(deviceContext: ID3D11DeviceContext);

        function LoadSetupFile(filename: WideString): HResult;
        function LoadBitmapHeightMap(): HResult;
        procedure ShutdownHeightMap();
        procedure SetTerrainCoordinates();
        function BuildTerrainModel(): HResult;
        procedure ShutdownTerrainModel();
    end;


implementation

uses
    DX12.DXGI,
    DX12.D3DCommon;



constructor TTerrainClass.Create;
begin
end;



destructor TTerrainClass.Destroy;
begin
    inherited;
end;



function TTerrainClass.Initialize(device: ID3D11Device; setupFilename: WideString): HResult;
begin

    // Get the terrain filename, dimensions, and so forth from the setup file.
    Result := LoadSetupFile(setupFilename);
    if (Result <> S_OK) then Exit;

    // Initialize the terrain height map with the data from the bitmap file.
    Result := LoadBitmapHeightMap();
    if (Result <> S_OK) then Exit;

    // Setup the X and Z coordinates for the height map as well as scale the terrain height by the height scale value.
    SetTerrainCoordinates();

    // Now build the 3D model of the terrain.
    Result := BuildTerrainModel();
    if (Result <> S_OK) then Exit;

    // We can now release the height map since it is no longer needed in memory once the 3D terrain model has been built.
    ShutdownHeightMap();


    // Load the rendering buffers with the terrain data.
    Result := InitializeBuffers(device);

    // Release the terrain model now that the rendering buffers have been loaded.
    ShutdownTerrainModel();

end;



procedure TTerrainClass.Shutdown();
begin
    // Release the rendering buffers.
    ShutdownBuffers();

    // Release the terrain model.
    ShutdownTerrainModel();

    // Release the height map.
    ShutdownHeightMap();
end;



function TTerrainClass.Render(deviceContext: ID3D11DeviceContext): HResult;
begin
    // Put the vertex and index buffers on the graphics pipeline to prepare them for drawing.
    RenderBuffers(deviceContext);
    Result := S_OK;
end;



function TTerrainClass.GetIndexCount(): int32;
begin
    Result := m_indexCount;
end;



function TTerrainClass.InitializeBuffers(device: ID3D11Device): HResult;
var
    vertices: array of TVertexType;
    indices: array of ULONG;
    vertexBufferDesc, indexBufferDesc: TD3D11_BUFFER_DESC;
    vertexData, indexData: TD3D11_SUBRESOURCE_DATA;

    i, j, index: integer;
    color: TXMFLOAT4;
begin

    // Set the color of the terrain grid.
    color := TXMFLOAT4.Create(1.0, 1.0, 1.0, 1.0);

    // Calculate the number of vertices in the terrain.
    m_vertexCount := (m_terrainWidth - 1) * (m_terrainHeight - 1) * 6;

    // Set the index count to the same as the vertex count.
    m_indexCount := m_vertexCount;

    // Create the vertex array.
    SetLength(vertices, m_vertexCount);

    // Create the index array.
    SetLength(indices, m_indexCount);

    // Initialize the index into the vertex and index arrays.
    index := 0;

    // Load the vertex array and index array with 3D terrain model data.
    for i := 0 to m_vertexCount - 1 do
    begin
        vertices[i].position := TXMFLOAT3.Create(m_terrainModel[i].x, m_terrainModel[i].y, m_terrainModel[i].z);
        vertices[i].texture := TXMFLOAT2.Create(m_terrainModel[i].tu, m_terrainModel[i].tv);
        indices[i] := i;
    end;

    // Set up the description of the static vertex buffer.
    vertexBufferDesc.Usage := D3D11_USAGE_DEFAULT;
    vertexBufferDesc.ByteWidth := sizeof(TVertexType) * m_vertexCount;
    vertexBufferDesc.BindFlags := Ord(D3D11_BIND_VERTEX_BUFFER);
    vertexBufferDesc.CPUAccessFlags := 0;
    vertexBufferDesc.MiscFlags := 0;
    vertexBufferDesc.StructureByteStride := 0;

    // Give the subresource structure a pointer to the vertex data.
    vertexData.pSysMem := @vertices[0];
    vertexData.SysMemPitch := 0;
    vertexData.SysMemSlicePitch := 0;

    // Now create the vertex buffer.
    Result := device.CreateBuffer(vertexBufferDesc, @vertexData, m_vertexBuffer);
    if (Result <> S_OK) then
        Exit;

    // Set up the description of the static index buffer.
    indexBufferDesc.Usage := D3D11_USAGE_DEFAULT;
    indexBufferDesc.ByteWidth := sizeof(ULONG) * m_indexCount;
    indexBufferDesc.BindFlags := Ord(D3D11_BIND_INDEX_BUFFER);
    indexBufferDesc.CPUAccessFlags := 0;
    indexBufferDesc.MiscFlags := 0;
    indexBufferDesc.StructureByteStride := 0;

    // Give the subresource structure a pointer to the index data.
    indexData.pSysMem := @indices[0];
    indexData.SysMemPitch := 0;
    indexData.SysMemSlicePitch := 0;

    // Create the index buffer.
    Result := device.CreateBuffer(indexBufferDesc, @indexData, m_indexBuffer);
    if (Result <> S_OK) then
        Exit;

    // Release the arrays now that the buffers have been created and loaded.
    SetLength(vertices, 0);
    SetLength(indices, 0);
end;



procedure TTerrainClass.ShutdownBuffers();
begin
    // Release the index buffer.
    m_indexBuffer := nil;

    // Release the vertex buffer.
    m_vertexBuffer := nil;
end;



procedure TTerrainClass.RenderBuffers(deviceContext: ID3D11DeviceContext);
var
    stride: uint32;
    offset: uint32;
begin

    // Set vertex buffer stride and offset.
    stride := sizeof(TVertexType);
    offset := 0;

    // Set the vertex buffer to active in the input assembler so it can be rendered.
    deviceContext.IASetVertexBuffers(0, 1, @m_vertexBuffer, @stride, @offset);

    // Set the index buffer to active in the input assembler so it can be rendered.
    deviceContext.IASetIndexBuffer(m_indexBuffer, DXGI_FORMAT_R32_UINT, 0);

    // Set the type of primitive that should be rendered from this vertex buffer, in this case triangles.
    deviceContext.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
end;



function TTerrainClass.LoadSetupFile(filename: WideString): HResult;
var
    F: textFile;
    input: ansichar;
    lValue: ansistring;
    lCode: integer;
begin

    // Open the setup file.  If it could not open the file then exit.
    AssignFile(F, filename);
    Reset(F);

    // Read up to the terrain file name.
    Read(F, input);


    while (input <> ':') do
        Read(F, input);

    // Read in the terrain file name.
    ReadLn(f, lValue);
    m_terrainFilename := trim(lValue);

    // Read up to the value of terrain height.
    Read(F, input);
    while (input <> ':') do
        Read(F, input);


    // Read in the terrain height.
    ReadLn(f, lValue);
    Val(lValue, m_terrainHeight, lCode);


    // Read up to the value of terrain width.
    Read(F, input);
    while (input <> ':') do
        Read(F, input);


    // Read in the terrain width.
    ReadLn(f, lValue);
    Val(lValue, m_terrainWidth, lCode);

    // Read up to the value of terrain height scaling.
    Read(F, input);
    while (input <> ':') do
        Read(F, input);


    // Read in the terrain height scaling.
    ReadLn(f, lValue);
    Val(lValue, m_heightScale, lCode);


    // Close the setup file.
    closeFile(F);

    Result := S_OK;
end;



function TTerrainClass.LoadBitmapHeightMap(): HResult;
var
    error, imageSize, i, j, k, index: integer;
    lFileStream: TFileStream;
    Count: uint64;
    bitmapFileHeader: TBITMAPFILEHEADER;
    bitmapInfoHeader: TBITMAPINFOHEADER;
    bitmapImage: pbyte;
    Height: byte;
begin
    Result := E_FAIL;

    // Start by creating the array structure to hold the height map data.
    setLength(m_heightMap, m_terrainWidth * m_terrainHeight);

    // Open the bitmap map file in binary.
    lFileStream := TFileStream.Create(m_terrainFilename, fmOpenRead);

    // Read in the bitmap file header.
    Count := lFileStream.Read(bitmapFileHeader, sizeof(TBITMAPFILEHEADER));
    if (Count <> sizeof(TBITMAPFILEHEADER)) then Exit;

    // Read in the bitmap info header.
    Count := lFileStream.Read(bitmapInfoHeader, sizeof(TBITMAPINFOHEADER));
    if (Count <> sizeof(TBITMAPINFOHEADER)) then Exit;

    // Make sure the height map dimensions are the same as the terrain dimensions for easy 1 to 1 mapping.
    if ((bitmapInfoHeader.biHeight <> m_terrainHeight) or (bitmapInfoHeader.biWidth <> m_terrainWidth)) then Exit;

    // Calculate the size of the bitmap image data.
    // Since we use non-divide by 2 dimensions (eg. 257x257) we need to add an extra byte to each line.
    imageSize := m_terrainHeight * ((m_terrainWidth * 3) + 1);

    // Allocate memory for the bitmap image data.
    bitmapImage := GetMem(imageSize);
    // Move to the beginning of the bitmap data.
    lFileStream.Seek(bitmapFileHeader.bfOffBits, soBeginning);


    // Read in the bitmap image data.
    Count := lFileStream.Read(bitmapImage^, imageSize);
    if (Count <> imageSize) then Exit;

    // Close the file.
    lFileStream.Free;

    // Initialize the position in the image data buffer.
    k := 0;

    // Read the image data into the height map array.
    for j := 0 to m_terrainHeight - 1 do
    begin
        for i := 0 to m_terrainWidth - 1 do
        begin
            // Bitmaps are upside down so load bottom to top into the height map array.
            index := (m_terrainWidth * (m_terrainHeight - 1 - j)) + i;

            // Get the grey scale pixel value from the bitmap image data at this location.
            Height := bitmapImage[k];

            // Store the pixel value as the height at this point in the height map array.
            m_heightMap[index].y := Height;

            // Increment the bitmap image data index.
            Inc(k, 3);
        end;

        // Compensate for the extra byte at end of each line in non-divide by 2 bitmaps (eg. 257x257).
        Inc(k);
    end;

    // Release the bitmap image data now that the height map array has been loaded.
    Dispose(bitmapImage);

    // Release the terrain filename now that is has been read in.
    m_terrainFilename := '';

    Result := S_OK;
end;



procedure TTerrainClass.ShutdownHeightMap();
begin
    // Release the height map array.
    SetLength(m_heightMap, 0);
end;



procedure TTerrainClass.SetTerrainCoordinates();
var
    i, j, index: integer;
begin

    // Loop through all the elements in the height map array and adjust their coordinates correctly.
    for j := 0 to m_terrainHeight - 1 do
    begin
        for i := 0 to m_terrainWidth - 1 do
        begin
            index := (m_terrainWidth * j) + i;

            // Set the X and Z coordinates.
            m_heightMap[index].x := i;
            m_heightMap[index].z := -j;

            // Move the terrain depth into the positive range.  For example from (0, -256) to (256, 0).
            m_heightMap[index].z := m_heightMap[index].z + (m_terrainHeight - 1);

            // Scale the height.
            m_heightMap[index].y := m_heightMap[index].y / m_heightScale;
        end;
    end;
end;



function TTerrainClass.BuildTerrainModel(): HResult;
var
    i, j, index, index1, index2, index3, index4: integer;
begin

    // Calculate the number of vertices in the 3D terrain model.
    m_vertexCount := (m_terrainHeight - 1) * (m_terrainWidth - 1) * 6;

    // Create the 3D terrain model array.
    SetLength(m_terrainModel, m_vertexCount);

    // Initialize the index into the height map array.
    index := 0;

    // Load the 3D terrain model with the height map terrain data.
    // We will be creating 2 triangles for each of the four points in a quad.
    for j := 0 to m_terrainHeight - 2 do
    begin
        for i := 0 to m_terrainWidth - 2 do
        begin
            // Get the indexes to the four points of the quad.
            index1 := (m_terrainWidth * j) + i;          // Upper left.
            index2 := (m_terrainWidth * j) + (i + 1);      // Upper right.
            index3 := (m_terrainWidth * (j + 1)) + i;      // Bottom left.
            index4 := (m_terrainWidth * (j + 1)) + (i + 1);  // Bottom right.

            // Now create two triangles for that quad.
            // Triangle 1 - Upper left.
            m_terrainModel[index].x := m_heightMap[index1].x;
            m_terrainModel[index].y := m_heightMap[index1].y;
            m_terrainModel[index].z := m_heightMap[index1].z;
            m_terrainModel[index].tu := 0.0;
            m_terrainModel[index].tv := 0.0;
            Inc(index);

            // Triangle 1 - Upper right.
            m_terrainModel[index].x := m_heightMap[index2].x;
            m_terrainModel[index].y := m_heightMap[index2].y;
            m_terrainModel[index].z := m_heightMap[index2].z;
            m_terrainModel[index].tu := 1.0;
            m_terrainModel[index].tv := 0.0;
            Inc(index);

            // Triangle 1 - Bottom left.
            m_terrainModel[index].x := m_heightMap[index3].x;
            m_terrainModel[index].y := m_heightMap[index3].y;
            m_terrainModel[index].z := m_heightMap[index3].z;
            m_terrainModel[index].tu := 0.0;
            m_terrainModel[index].tv := 1.0;
            Inc(index);

            // Triangle 2 - Bottom left.
            m_terrainModel[index].x := m_heightMap[index3].x;
            m_terrainModel[index].y := m_heightMap[index3].y;
            m_terrainModel[index].z := m_heightMap[index3].z;
            m_terrainModel[index].tu := 0.0;
            m_terrainModel[index].tv := 1.0;
            Inc(index);

            // Triangle 2 - Upper right.
            m_terrainModel[index].x := m_heightMap[index2].x;
            m_terrainModel[index].y := m_heightMap[index2].y;
            m_terrainModel[index].z := m_heightMap[index2].z;
            m_terrainModel[index].tu := 1.0;
            m_terrainModel[index].tv := 0.0;
            Inc(index);

            // Triangle 2 - Bottom right.
            m_terrainModel[index].x := m_heightMap[index4].x;
            m_terrainModel[index].y := m_heightMap[index4].y;
            m_terrainModel[index].z := m_heightMap[index4].z;
            m_terrainModel[index].tu := 1.0;
            m_terrainModel[index].tv := 1.0;
            Inc(index);
        end;
    end;

    Result := S_OK;
end;



procedure TTerrainClass.ShutdownTerrainModel();
begin
    // Release the terrain model data.
    SetLength(m_terrainModel, 0);
end;


end.
