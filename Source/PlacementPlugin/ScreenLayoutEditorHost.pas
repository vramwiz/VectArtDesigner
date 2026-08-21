// AviUtl2の文字列データと共通デザイナー画面を接続するプラグイン用ホスト。
unit ScreenLayoutEditorHost;

interface

function EditScreenLayout(const SerializedData: string;
  out UpdatedData, ErrorMessage: string): Boolean;

implementation

uses
  System.SysUtils, Vcl.Forms, VectArtDesignerDocumentJson,
  VectArtDesignerMainForm;

function EditScreenLayout(const SerializedData: string;
  out UpdatedData, ErrorMessage: string): Boolean;
var
  EditorForm: TMainForm;
begin
  Result := False;
  UpdatedData := SerializedData;
  ErrorMessage := '';
  EditorForm := nil;
  try
    try
      EditorForm := TMainForm.Create(nil);
      EditorForm.Caption := '【画面レイアウト】 - 編集';
      EditorForm.Position := poScreenCenter;
      if (SerializedData <> '') and
        not TryDeserializeVectArtDocument(SerializedData,
          EditorForm.Document, ErrorMessage) then
        Exit;
      EditorForm.ShowModal;
      UpdatedData := SerializeVectArtDocument(EditorForm.Document);
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
    EditorForm.Free;
  end;
end;

end.
