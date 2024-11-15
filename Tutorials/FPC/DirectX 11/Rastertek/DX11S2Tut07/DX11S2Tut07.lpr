program DX11S2Tut07;

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, DirectX.Math, DX12.D3D11, CameraClass, D3DClass, GraphicsClass,
    InputClass, LightClass, LightShaderClass, ModelClass, SystemClass,
    TextureClass;


var
    System: TSystemClass;
    Result: HResult;
begin

    // Create the system object.
    System := TSystemClass.Create;
    if (System = nil) then
        Exit;

    // Initialize and run the system object.
    Result := System.Initialize();
    if (Result = S_OK) then
        System.Run();

    // Shutdown and release the system object.
    System.Shutdown();
    System.Free;
    System := nil;

end.

