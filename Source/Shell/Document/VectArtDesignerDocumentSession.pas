// Documentの未保存状態と表示名をRevisionから追跡し、破棄前の保存確認を担当する。
// Documentの保存処理自体はコールバックへ委譲する。
unit VectArtDesignerDocumentSession;

interface

uses
  System.Classes, Winapi.Windows, VectArtDesignerDocument;

type
  TVectArtSaveAction = function: Boolean of object;

  TVectArtDocumentSession = class
  private
    FDirty: Boolean;
    FDisplayName: string;
    FDocument: TVectArtDocument;
    FLastRevision: Int64;
    FOnChanged: TNotifyEvent;
    procedure Changed;
    function GetCaption: string;
  public
    constructor Create(ADocument: TVectArtDocument);
    function ConfirmSave(OwnerHandle: HWND;
      SaveAction: TVectArtSaveAction): Boolean;
    procedure MarkClean(const DisplayName: string);
    procedure ObserveDocumentChange;
    property Caption: string read GetCaption;
    property Dirty: Boolean read FDirty;
    property DisplayName: string read FDisplayName;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.SysUtils;

constructor TVectArtDocumentSession.Create(ADocument: TVectArtDocument);
begin
  inherited Create;
  FDocument := ADocument;
  FDisplayName := '新規キャンバス';
  if FDocument <> nil then
    FLastRevision := FDocument.Revision;
end;

procedure TVectArtDocumentSession.Changed;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

function TVectArtDocumentSession.ConfirmSave(OwnerHandle: HWND;
  SaveAction: TVectArtSaveAction): Boolean;
var
  Choice: Integer;
begin
  if not FDirty then
    Exit(True);
  Choice := MessageBox(OwnerHandle, PChar(Format(
    '「%s」への変更を保存しますか？', [FDisplayName])), '変更の保存',
    MB_YESNOCANCEL or MB_ICONWARNING);
  case Choice of
    IDYES:
      Result := Assigned(SaveAction) and SaveAction;
    IDNO:
      Result := True;
  else
    Result := False;
  end;
end;

function TVectArtDocumentSession.GetCaption: string;
begin
  if FDisplayName = '' then
    Result := 'VectArtDesigner - 新規キャンバス'
  else
    Result := 'VectArtDesigner - ' + FDisplayName;
  if FDirty then
    Result := Result + ' *';
end;

procedure TVectArtDocumentSession.MarkClean(const DisplayName: string);
begin
  FDisplayName := DisplayName;
  if FDocument <> nil then
    FLastRevision := FDocument.Revision;
  FDirty := False;
  Changed;
end;

procedure TVectArtDocumentSession.ObserveDocumentChange;
begin
  if (FDocument = nil) or (FDocument.Revision = FLastRevision) then
    Exit;
  FLastRevision := FDocument.Revision;
  if FDirty then
    Exit;
  FDirty := True;
  Changed;
end;

end.
