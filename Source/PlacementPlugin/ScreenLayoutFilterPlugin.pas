// AviUtl2へ「画面レイアウト」を登録し、編集ボタンとシリアライズ文字列項目だけを公開する。
unit ScreenLayoutFilterPlugin;

interface

uses
  System.SysUtils, AviUtl2FilterTypes;

// AviUtl2へ渡すフィルターテーブルを返す。
function GetScreenLayoutFilterTable: PFILTER_PLUGIN_TABLE;
// 将来の共通UI初期化に備えたDLL初期化境界。現段階では状態を持たない。
procedure InitializeScreenLayoutFilter;
// 将来の共通UI解放に備えたDLL終了境界。現段階では状態を持たない。
procedure FinalizeScreenLayoutFilter;

implementation

uses
  PluginFilterTable, ScreenLayoutEditorHost, System.UITypes, Vcl.Dialogs;

const
  FILTER_EFFECT_NAME = '【画面レイアウト】';

var
  EditButton: TFILTER_ITEM_BUTTON;
  LayoutDataItem: TFILTER_ITEM_STRING;

procedure EditButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  CurrentData: string;
  DataPointer: PAnsiChar;
  ErrorMessage: string;
  Obj: OBJECT_HANDLE;
  UpdatedData: string;
  Utf8Data: UTF8String;
begin
  try
    if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
      not Assigned(Edit^.GetObjectItemValue) or
      not Assigned(Edit^.SetObjectItemValue) then
      raise EInvalidOp.Create('AviUtl2の編集APIを取得できませんでした。');
    Obj := Edit^.GetFocusObject();
    if Obj = nil then
      raise EInvalidOp.Create('編集対象のオブジェクトを取得できませんでした。');

    DataPointer := Edit^.GetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      '配置データ');
    if DataPointer = nil then
      CurrentData := ''
    else
      CurrentData := string(UTF8String(DataPointer));

    if not EditScreenLayout(CurrentData, UpdatedData, ErrorMessage) then
      raise EInvalidOp.Create('画面レイアウトを編集できませんでした。'#13#10 +
        ErrorMessage);

    Utf8Data := UTF8String(UpdatedData);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      '配置データ', PAnsiChar(Utf8Data)) then
      raise EInvalidOp.Create('配置データをAviUtl2へ保存できませんでした。');
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

function PassThroughVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  // 現段階では入力映像を変更せず、フィルター処理成功だけを返す。
  Result := 1;
end;

procedure InitializeScreenLayoutFilter;
begin
end;

procedure FinalizeScreenLayoutFilter;
begin
end;

function GetScreenLayoutFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name = nil then
  begin
    AddButton(EditButton, '編集', EditButtonCallback);
    AddString(LayoutDataItem, '配置データ', '');
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,
      FILTER_EFFECT_NAME,
      'SYNC',
      '文字や線を配置する画面レイアウトフィルター',
      PassThroughVideo,
      nil);
  end;
  Result := @GTable;
end;

end.
