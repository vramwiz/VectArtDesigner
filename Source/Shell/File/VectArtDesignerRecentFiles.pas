// 最近使ったファイルの順序、件数上限、設定ファイルとの往復を管理する。
// メニュー表示とファイル読込の実行は呼出側へ残す。
unit VectArtDesignerRecentFiles;

interface

uses
  System.Classes, System.IniFiles;

type
  TVectArtRecentFiles = class
  private
    FItems: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const FileName: string);
    procedure Clear;
    procedure LoadFrom(Ini: TCustomIniFile);
    procedure SaveTo(Ini: TCustomIniFile);
    property Count: Integer read GetCount;
    property Items[Index: Integer]: string read GetItem; default;
  end;

implementation

uses
  System.SysUtils;

const
  MAX_RECENT_FILES = 10;
  RECENT_FILES_SECTION = 'FileHistory';

constructor TVectArtRecentFiles.Create;
begin
  inherited Create;
  FItems := TStringList.Create;
end;

destructor TVectArtRecentFiles.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TVectArtRecentFiles.Add(const FileName: string);
var
  CanonicalName: string;
  I: Integer;
begin
  if Trim(FileName) = '' then
    Exit;
  CanonicalName := ExpandFileName(FileName);
  for I := FItems.Count - 1 downto 0 do
    if SameText(FItems[I], CanonicalName) then
      FItems.Delete(I);
  FItems.Insert(0, CanonicalName);
  while FItems.Count > MAX_RECENT_FILES do
    FItems.Delete(FItems.Count - 1);
end;

procedure TVectArtRecentFiles.Clear;
begin
  FItems.Clear;
end;

function TVectArtRecentFiles.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TVectArtRecentFiles.GetItem(Index: Integer): string;
begin
  if (Index < 0) or (Index >= FItems.Count) then
    Exit('');
  Result := FItems[Index];
end;

procedure TVectArtRecentFiles.LoadFrom(Ini: TCustomIniFile);
var
  FileName: string;
  I: Integer;
begin
  FItems.Clear;
  if Ini = nil then
    Exit;
  for I := 0 to MAX_RECENT_FILES - 1 do
  begin
    FileName := Ini.ReadString(RECENT_FILES_SECTION,
      'File' + IntToStr(I), '');
    if FileName <> '' then
      FItems.Add(FileName);
  end;
end;

procedure TVectArtRecentFiles.SaveTo(Ini: TCustomIniFile);
var
  I: Integer;
begin
  if Ini = nil then
    Exit;
  Ini.EraseSection(RECENT_FILES_SECTION);
  for I := 0 to FItems.Count - 1 do
    Ini.WriteString(RECENT_FILES_SECTION, 'File' + IntToStr(I), FItems[I]);
end;

end.
