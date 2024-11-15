unit TextureClass;

interface

uses
classes, SysUtils, Windows,
	DX12.D3D11,
	DX12.D3DX11;

	
type
    { TTextureClass }

 TTextureClass = class(TObject)
private
	 m_texture: ID3D11ShaderResourceView;
public
	constructor Create;
	destructor Destroy; override;

	function Initialize(device:ID3D11Device; filename:widestring):HResult;
	procedure Shutdown();

	function GetTexture():ID3D11ShaderResourceView;
end;

implementation

constructor TTextureClass.Create;
begin
	m_texture := nil;
end;




destructor TTextureClass.Destroy;
begin
inherited;
end;


function TTextureClass.Initialize(device:ID3D11Device; filename:widestring): HResult;
begin
	// Load the texture in.
	result := D3DX11CreateShaderResourceViewFromFileW(device, PWideChar(filename), nil, nil, m_texture, nil);
end;


procedure TTextureClass.Shutdown();
begin
	// Release the texture resource.
		m_texture := nil;
end;


function TTextureClass.GetTexture():ID3D11ShaderResourceView;
begin
	result:= m_texture;
end;

end.