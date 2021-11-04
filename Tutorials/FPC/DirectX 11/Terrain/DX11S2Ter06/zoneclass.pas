unit ZoneClass;

interface

uses
    Classes, SysUtils, Windows,
    D3DClass,
    InputClass,
    ShaderManagerClass,
    TextureManagerClass,
    TimerClass,
    LightClass,
    UserInterfaceClass,
    CameraClass,
    PositionClass,
    TerrainClass;

type

    { TZoneClass }

    TZoneClass = class(TObject)
    private
        m_UserInterface: TUserInterfaceClass;
        m_Camera: TCameraClass;
        m_Position: TPositionClass;
        m_Light: TLightClass;
        m_Terrain: TTerrainClass;
        m_displayUI: boolean;
        m_wireFrame: boolean;
    public
        constructor Create;
        destructor Destroy; override;

        function Initialize(Direct3D: TD3DClass; hwnd: hwnd; screenWidth, screenHeight: integer; screenDepth: single): HResult;
        procedure Shutdown();
        function Frame(Direct3D: TD3DClass; Input: TInputClass; ShaderManager: TShaderManagerClass;
            TextureManager: TTextureManagerClass; frameTime: single; fps: integer): HResult;

    private
        procedure HandleMovementInput(Input: TInputClass; frameTime: single);
        function Render(Direct3D: TD3DClass; ShaderManager: TShaderManagerClass; TextureManager: TTextureManagerClass): HResult;

    end;

implementation

uses
    DirectX.Math;



constructor TZoneClass.Create;
begin
    m_UserInterface := nil;
    m_Camera := nil;
    m_Position := nil;
    m_Terrain := nil;
end;



destructor TZoneClass.Destroy;
begin

end;



function TZoneClass.Initialize(Direct3D: TD3DClass; hwnd: hwnd; screenWidth, screenHeight: integer; screenDepth: single): HResult;
begin
    // Create the user interface object.
    m_UserInterface := TUserInterfaceClass.Create;

    // Initialize the user interface object.
    Result := m_UserInterface.Initialize(Direct3D, screenHeight, screenWidth);
    if (Result <> S_OK) then
    begin
        MessageBoxW(hwnd, 'Could not initialize the user interface object.', 'Error', MB_OK);
        Exit;
    end;

    // Create the camera object.
    m_Camera := TCameraClass.Create;

    // Set the initial position of the camera and build the matrices needed for rendering.
    m_Camera.SetPosition(0.0, 0.0, -10.0);
    m_Camera.Render();
    m_Camera.RenderBaseViewMatrix();

    // Create the light object.
    m_Light := TLightClass.Create;

    // Initialize the light object.
    m_Light.SetDiffuseColor(1.0, 1.0, 1.0, 1.0);
    m_Light.SetDirection(-0.5, -1.0, -0.5);


    // Create the position object.
    m_Position := TPositionClass.Create;

    // Set the initial position and rotation.
    m_Position.SetPosition(128.0, 10.0, -10.0);
    m_Position.SetRotation(0.0, 0.0, 0.0);

    // Create the terrain object.
    m_Terrain := TTerrainClass.Create;

    // Initialize the terrain object.
    Result := m_Terrain.Initialize(Direct3D.GetDevice(), '.\data\setup.txt');
    if (Result <> S_OK) then
    begin
        MessageBoxW(hwnd, 'Could not initialize the terrain object.', 'Error', MB_OK);
        Exit;
    end;

    // Set the UI to display by default.
    m_displayUI := True;

    // Set wire frame rendering initially to enabled.
    m_wireFrame := False;
    Result := S_OK;
end;



procedure TZoneClass.Shutdown();
begin
    // Release the terrain object.
    if (m_Terrain <> nil) then
    begin
        m_Terrain.Shutdown();
        m_Terrain.Free;
        m_Terrain := nil;
    end;

    // Release the position object.
    if (m_Position <> nil) then
    begin
        m_Position.Free;
        m_Position := nil;
    end;

    // Release the light object.
    if (m_Light <> nil) then
    begin
        m_Light.Free;
        m_Light := nil;
    end;

    // Release the camera object.
    if (m_Camera <> nil) then
    begin
        m_Camera.Free;
        m_Camera := nil;
    end;

    // Release the user interface object.
    if (m_UserInterface <> nil) then
    begin
        m_UserInterface.Shutdown();
        m_UserInterface.Free;
        m_UserInterface := nil;
    end;
end;



function TZoneClass.Frame(Direct3D: TD3DClass; Input: TInputClass; ShaderManager: TShaderManagerClass;
    TextureManager: TTextureManagerClass; frameTime: single; fps: integer): HResult;
var
    posX, posY, posZ, rotX, rotY, rotZ: single;
begin

    // Do the frame input processing.
    HandleMovementInput(Input, frameTime);

    // Get the view point position/rotation.
    m_Position.GetPosition(posX, posY, posZ);
    m_Position.GetRotation(rotX, rotY, rotZ);

    // Do the frame processing for the user interface.
    Result := m_UserInterface.Frame(Direct3D.GetDeviceContext(), fps, posX, posY, posZ, rotX, rotY, rotZ);
    if (Result <> S_OK) then
        Exit;
    // Render the graphics.
    Result := Render(Direct3D, ShaderManager, TextureManager);
end;



procedure TZoneClass.HandleMovementInput(Input: TInputClass; frameTime: single);
var
    keyDown: boolean;
    posX, posY, posZ, rotX, rotY, rotZ: single;
begin

    // Set the frame time for calculating the updated position.
    m_Position.SetFrameTime(frameTime);

    // Handle the input.
    keyDown := Input.IsLeftPressed();
    m_Position.TurnLeft(keyDown);

    keyDown := Input.IsRightPressed();
    m_Position.TurnRight(keyDown);

    keyDown := Input.IsUpPressed();
    m_Position.MoveForward(keyDown);

    keyDown := Input.IsDownPressed();
    m_Position.MoveBackward(keyDown);

    keyDown := Input.IsAPressed();
    m_Position.MoveUpward(keyDown);

    keyDown := Input.IsZPressed();
    m_Position.MoveDownward(keyDown);

    keyDown := Input.IsPgUpPressed();
    m_Position.LookUpward(keyDown);

    keyDown := Input.IsPgDownPressed();
    m_Position.LookDownward(keyDown);

    // Get the view point position/rotation.
    m_Position.GetPosition(posX, posY, posZ);
    m_Position.GetRotation(rotX, rotY, rotZ);

    // Set the position of the camera.
    m_Camera.SetPosition(posX, posY, posZ);
    m_Camera.SetRotation(rotX, rotY, rotZ);

    // Determine if the user interface should be displayed or not.
    if (Input.IsF1Toggled()) then
    begin
        m_displayUI := not m_displayUI;
    end;

    // Determine if the terrain should be rendered in wireframe or not.
    if (Input.IsF2Toggled()) then
        m_wireFrame := not m_wireFrame;

end;



function TZoneClass.Render(Direct3D: TD3DClass; ShaderManager: TShaderManagerClass; TextureManager: TTextureManagerClass): HResult;
var
    worldMatrix, viewMatrix, projectionMatrix, baseViewMatrix, orthoMatrix: TXMMATRIX;
begin

    // Generate the view matrix based on the camera's position.
    m_Camera.Render();

    // Get the world, view, and projection matrices from the camera and d3d objects.
    Direct3D.GetWorldMatrix(worldMatrix);
    m_Camera.GetViewMatrix(viewMatrix);
    Direct3D.GetProjectionMatrix(projectionMatrix);
    m_Camera.GetBaseViewMatrix(baseViewMatrix);
    Direct3D.GetOrthoMatrix(orthoMatrix);

    // Clear the buffers to begin the scene.
    Direct3D.BeginScene(0.0, 0.0, 0.0, 1.0);
    Direct3D.TurnZBufferOn();

    // Turn on wire frame rendering of the terrain if needed.
    if (m_wireFrame) then
        Direct3D.EnableWireframe();


    // Render the terrain grid using the terrain shader.
    m_Terrain.Render(Direct3D.GetDeviceContext());
    Result := ShaderManager.RenderTerrainShader(Direct3D.GetDeviceContext(), m_Terrain.GetIndexCount(), worldMatrix,
        viewMatrix, projectionMatrix, TextureManager.GetTexture(0),TextureManager.GetTexture(1), m_Light.GetDirection(), m_Light.GetDiffuseColor());
    if (Result <> S_OK) then
        Exit;


    // Turn off wire frame rendering of the terrain if it was on.
    if (m_wireFrame) then
        Direct3D.DisableWireframe();


    // Render the user interface.
    if (m_displayUI) then
    begin
        Result := m_UserInterface.Render(Direct3D, ShaderManager, worldMatrix, baseViewMatrix, orthoMatrix);
        if (Result <> S_OK) then
            Exit;
    end;
    // Present the rendered scene to the screen.
    Direct3D.EndScene();
end;

end.
