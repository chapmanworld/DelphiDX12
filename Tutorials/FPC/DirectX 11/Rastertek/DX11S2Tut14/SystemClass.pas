unit SystemClass;

{$IFDEF FPC}
{$mode delphiunicode}{$H+}
{$ENDIF}

interface

uses
    Classes, SysUtils, Windows,
    InputClass, GraphicsClass,
    SoundClass;

type

    { TSystemClass }

    TSystemClass = class(TObject)
    private
        m_applicationName: LPCWSTR;
        m_hinstance: HINST;
        m_hwnd: HWND;

        m_Input: TInputClass;
        m_Graphics: TGraphicsClass;
        m_Sound: TSoundClass;
    private
        function Frame(): HResult;
        procedure InitializeWindows(var screenWidth, screenHeight: integer);
        procedure ShutdownWindows();
    public
        constructor Create;
        destructor Destroy; override;

        function Initialize(): HResult;
        procedure Shutdown();
        procedure Run();

        function MessageHandler(hwnd: HWND; umsg: UINT; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
    end;

/////////////
// GLOBALS //
/////////////
var
    ApplicationHandle: TSystemClass = nil;



implementation



function WndProc(hwnd: HWND; umessage: UINT; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
begin
    case (umessage) of

        // Check if the window is being destroyed.
        WM_DESTROY:
        begin
            PostQuitMessage(0);
            Result := 0;
        end;

        // Check if the window is being closed.
        WM_CLOSE:
        begin
            PostQuitMessage(0);
            Result := 0;
        end;

            // All other messages pass to the message handler in the system class.
        else
            Result := ApplicationHandle.MessageHandler(hwnd, umessage, wparam, lparam);
    end;

end;

{ TSystemClass }

function TSystemClass.Frame(): HResult;
begin

    // Do the input frame processing.
    Result := m_Input.Frame();
    if (Result <> S_OK) then Exit;


    // Do the frame processing for the graphics object.
    Result := m_Graphics.Frame(0, 0);

    // Finally render the graphics to the screen.
    Result := m_Graphics.Render(0);

end;



procedure TSystemClass.InitializeWindows(var screenWidth, screenHeight: integer);
var
    wc: TWNDCLASSEXW;
    dmScreenSettings: DEVMODEW;
    posX, posY: integer;
begin

    // Get an external pointer to this object.
    ApplicationHandle := self;

    // Get the instance of this application.
    m_hinstance := GetModuleHandle(nil);

    // Give the application a name.
    m_applicationName := 'Engine';

    // Setup the windows class with default settings.
    wc.style := CS_HREDRAW or CS_VREDRAW or CS_OWNDC;
    wc.lpfnWndProc := @WndProc;
    wc.cbClsExtra := 0;
    wc.cbWndExtra := 0;
    wc.hInstance := m_hinstance;
    wc.hIcon := LoadIcon(0, IDI_WINLOGO);
    wc.hIconSm := wc.hIcon;
    wc.hCursor := LoadCursor(0, IDC_ARROW);
    wc.hbrBackground := HBRUSH(GetStockObject(BLACK_BRUSH));
    wc.lpszMenuName := nil;
    wc.lpszClassName := m_applicationName;
    wc.cbSize := sizeof(TWNDCLASSEXW);

    // Register the window class.
    RegisterClassExW(wc);

    // Determine the resolution of the clients desktop screen.
    screenWidth := GetSystemMetrics(SM_CXSCREEN);
    screenHeight := GetSystemMetrics(SM_CYSCREEN);

    // Setup the screen settings depending on whether it is running in full screen or in windowed mode.
    if (FULL_SCREEN) then
    begin
        // If full screen set the screen to maximum size of the users desktop and 32bit.
        ZeroMemory(@dmScreenSettings, sizeof(dmScreenSettings));
        dmScreenSettings.dmSize := sizeof(dmScreenSettings);
        dmScreenSettings.dmPelsWidth := screenWidth;
        dmScreenSettings.dmPelsHeight := screenHeight;
        dmScreenSettings.dmBitsPerPel := 32;
        dmScreenSettings.dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT;

        // Change the display settings to full screen.
        ChangeDisplaySettingsW(dmScreenSettings, CDS_FULLSCREEN);

        // Set the position of the window to the top left corner.
        posX := 0;
        posY := 0;
    end
    else
    begin
        // If windowed then set it to 800x600 resolution.
        screenWidth := 800;
        screenHeight := 600;

        // Place the window in the middle of the screen.
        posX := (GetSystemMetrics(SM_CXSCREEN) - screenWidth) div 2;
        posY := (GetSystemMetrics(SM_CYSCREEN) - screenHeight) div 2;
    end;

    // Create the window with the screen settings and get the handle to it.
    m_hwnd := CreateWindowExW(WS_EX_APPWINDOW, m_applicationName, m_applicationName, WS_CLIPSIBLINGS or
        WS_CLIPCHILDREN {or WS_POPUP} or WS_CAPTION, posX, posY, screenWidth, screenHeight, 0, 0, m_hinstance, nil);

    // Bring the window up on the screen and set it as main focus.
    ShowWindow(m_hwnd, SW_SHOW);
    SetForegroundWindow(m_hwnd);
    SetFocus(m_hwnd);

    // Hide the mouse cursor.
    ShowCursor(False);
end;



procedure TSystemClass.ShutdownWindows();
begin
    // Show the mouse cursor.
    ShowCursor(True);

    // Fix the display settings if leaving full screen mode.
    if (FULL_SCREEN) then
    begin
        ChangeDisplaySettingsW(TDeviceModeW(nil^), 0);
    end;

    // Remove the window.
    DestroyWindow(m_hwnd);
    m_hwnd := 0;

    // Remove the application instance.
    UnregisterClassW(m_applicationName, m_hinstance);
    m_hinstance := 0;

    // Release the pointer to this class.
    ApplicationHandle := nil;
end;



constructor TSystemClass.Create;
begin

end;



destructor TSystemClass.Destroy;
begin
    inherited Destroy;
end;



function TSystemClass.Initialize(): HResult;
var
    screenWidth, screenHeight: integer;
begin

    // Initialize the width and height of the screen to zero before sending the variables into the function.
    screenWidth := 0;
    screenHeight := 0;

    // Initialize the windows api.
    InitializeWindows(screenWidth, screenHeight);

    // Create the input object.  This object will be used to handle reading the keyboard input from the user.
    m_Input := TInputClass.Create;
    // Initialize the input object.
    Result := m_Input.Initialize(m_hinstance, m_hwnd, screenWidth, screenHeight);
    if (Result <> S_OK) then
    begin
        MessageBox(m_hwnd, 'Could not initialize the input object.', 'Error', MB_OK);
        Exit;
    end;
    // Create the graphics object.  This object will handle rendering all the graphics for this application.
    m_Graphics := TGraphicsClass.Create;

    // Initialize the graphics object.
    Result := m_Graphics.Initialize(screenWidth, screenHeight, m_hwnd);
    if (Result <> S_OK) then
        Exit;

    // Create the sound object.
    m_Sound := TSoundClass.Create;
    // Initialize the sound object.
    Result := m_Sound.Initialize(m_hwnd);
    if (Result <> S_OK) then
    begin
        MessageBox(m_hwnd, 'Could not initialize Direct Sound.', 'Error', MB_OK);
    end;
end;



procedure TSystemClass.Shutdown();
begin
    // Release the sound object.
    if (m_Sound <> nil) then
    begin
        m_Sound.Shutdown();
        m_Sound.Free;
        m_Sound := nil;
    end;

    // Release the graphics object.
    if (m_Graphics <> nil) then
    begin
        m_Graphics.Shutdown();
        m_Graphics.Free;
        m_Graphics := nil;
    end;

    // Release the input object.
    if (m_Input <> nil) then
    begin
        m_Input.Shutdown();
        m_Input.Free;
        m_Input := nil;
    end;

    // Shutdown the window.
    ShutdownWindows();
end;



procedure TSystemClass.Run();
var
    msg: TMSG;
    done: boolean;
    Result: HResult;
begin

    // Initialize the message structure.
    ZeroMemory(@msg, sizeof(TMSG));

    // Loop until there is a quit message from the window or the user.
    done := False;
    while (not done) do
    begin
        // Handle the windows messages.
        if (PeekMessage(msg, 0, 0, 0, PM_REMOVE)) then
        begin
            TranslateMessage(msg);
            DispatchMessage(msg);
        end;

        // If windows signals to end the application then exit out.
        if (msg.message = WM_QUIT) then
        begin
            done := True;
        end
        else
        begin
            // Otherwise do the frame processing.  If frame processing fails then exit.
            Result := Frame();
            if (Result <> S_OK) then
            begin
                MessageBoxA(m_hwnd, 'Frame Processing Failed', 'Error', MB_OK);
                done := True;
            end;
        end;
        // Check if the user pressed escape and wants to exit the application.
        if (m_Input.IsEscapePressed()) then
        begin
            Result := E_FAIL;
            Exit;
        end;
    end;
end;



function TSystemClass.MessageHandler(hwnd: HWND; umsg: UINT; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
begin
    // Any other messages send to the default message handler as our application won't make use of them.

    Result := DefWindowProcW(hwnd, umsg, wparam, lparam);

end;

end.