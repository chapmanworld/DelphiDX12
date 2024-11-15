program DX11S2Ter13;

{$mode delphi}{$H+}

uses
    SystemClass,
    Win32.Pdh;

{$R *.res}

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
