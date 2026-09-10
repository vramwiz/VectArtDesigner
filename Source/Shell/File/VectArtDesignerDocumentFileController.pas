// SVG／MIFの読込・保存とMIFコンテナーの所有権を管理する。
// メニュー、最近使ったファイル、タイトル表示はMainFormへ残す。
unit VectArtDesignerDocumentFileController;

interface

uses
  Winapi.Windows, VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerMifContainer;

type
  TVectArtDocumentFileController = class
  private
    FContainer: TVectArtMifContainer;
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FHasEditableDocument: Boolean;
    FReader: IVectArtMifContainerReader;
    FWriter: IVectArtMifContainerWriter;
  public
    constructor Create(ADocument: TVectArtDocument;
      AEditHistory: TVectArtEditHistory);
    destructor Destroy; override;
    function OpenFile(OwnerHandle: HWND; const FileName: string;
      out StatusText: string; ShowDialogs: Boolean = True): Boolean;
    procedure Reset;
    function SaveFile(OwnerHandle: HWND; const FileName: string;
      out StatusText: string; ShowDialogs: Boolean = True): Boolean;
  end;

implementation

uses
  System.SysUtils,
  {$IFDEF DEBUG} VectArtDesignerMifDebugLog, {$ENDIF}
  VectArtDesignerMifDocument, VectArtDesignerSvgDocument;

constructor TVectArtDocumentFileController.Create(ADocument: TVectArtDocument;
  AEditHistory: TVectArtEditHistory);
begin
  inherited Create;
  FDocument := ADocument;
  FEditHistory := AEditHistory;
  FReader := CreateVectArtMifContainerReader;
  FWriter := CreateVectArtMifContainerWriter;
  FHasEditableDocument := True;
end;

destructor TVectArtDocumentFileController.Destroy;
begin
  FContainer.Free;
  FReader := nil;
  FWriter := nil;
  inherited Destroy;
end;

function TVectArtDocumentFileController.OpenFile(OwnerHandle: HWND;
  const FileName: string; out StatusText: string;
  ShowDialogs: Boolean): Boolean;
var
  Container: TVectArtMifContainer;
  {$IFDEF DEBUG} DebugLogFileName: string; {$ENDIF}
  ErrorMessage: string;
  Extension: string;
  ImportMessage: string;
  SvgImportReport: TSvgImportReport;
begin
  Result := False;
  ErrorMessage := '';
  Extension := LowerCase(ExtractFileExt(FileName));
  if Extension = '.svg' then
  begin
    if not TryLoadVectArtDocumentFromSvgFile(FileName, FDocument,
      SvgImportReport, ErrorMessage) then
    begin
      StatusText := 'SVG open error: ' + ErrorMessage;
      Exit;
    end;
    FreeAndNil(FContainer);
    FHasEditableDocument := True;
    if FEditHistory <> nil then
      FEditHistory.Clear;
    if SvgImportReport.HasIssues then
    begin
      if ShowDialogs then
        MessageBox(OwnerHandle, PChar(
          'MIF編集モデルへ変換または無視したSVG要素があります。' +
          sLineBreak + sLineBreak + SvgImportReport.ToDisplayText),
          'SVG読込結果', MB_OK or MB_ICONWARNING);
      StatusText := Format('SVG document loaded with %d notice(s): %s',
        [Length(SvgImportReport.Issues), ExtractFileName(FileName)]);
    end
    else
      StatusText := 'SVG document loaded: ' + ExtractFileName(FileName);
    Exit(True);
  end;
  if Extension <> '.mif' then
  begin
    StatusText := 'Open error: unsupported file extension';
    Exit;
  end;
  Container := nil;
  if (FReader = nil) or
    not FReader.TryReadFile(FileName, Container, ErrorMessage) then
  begin
    StatusText := 'MIF open error: ' + ErrorMessage;
    Exit;
  end;
  FreeAndNil(FContainer);
  FContainer := Container;
  ImportMessage := '';
  FHasEditableDocument := TryLoadVectArtDocumentFromMif(FContainer,
    FDocument, ImportMessage);
  {$IFDEF DEBUG}
  DebugLogFileName := WriteMifOpenDebugLog(FileName, FContainer,
    ImportMessage);
  {$ENDIF}
  if FHasEditableDocument and (FEditHistory <> nil) then
    FEditHistory.Clear;
  if ImportMessage = '' then
    StatusText := Format('MIF document loaded: %s   Chunks: %d',
      [ExtractFileName(FileName), FContainer.ChunkCount])
  else
    StatusText := Format(
      'MIF container loaded without editable data: %s   Chunks: %d',
      [ExtractFileName(FileName), FContainer.ChunkCount]);
  {$IFDEF DEBUG}
  if DebugLogFileName <> '' then
    StatusText := StatusText + '   Debug log: ' +
      ExtractFileName(DebugLogFileName);
  {$ENDIF}
  Result := True;
end;

procedure TVectArtDocumentFileController.Reset;
begin
  FreeAndNil(FContainer);
  FHasEditableDocument := True;
end;

function TVectArtDocumentFileController.SaveFile(OwnerHandle: HWND;
  const FileName: string; out StatusText: string;
  ShowDialogs: Boolean): Boolean;
var
  Container: TVectArtMifContainer;
  ErrorMessage: string;
  ExportMessage: string;
  ExportReport: TMifExportReport;
  Extension: string;
begin
  Result := False;
  ErrorMessage := '';
  Container := nil;
  Extension := LowerCase(ExtractFileExt(FileName));
  if Extension = '.svg' then
  begin
    if not TrySaveVectArtDocumentToSvgFile(FDocument, FileName,
      ErrorMessage) then
    begin
      StatusText := 'SVG save error: ' + ErrorMessage;
      Exit;
    end;
    Reset;
    StatusText := 'SVG document saved: ' + ExtractFileName(FileName);
    Exit(True);
  end;
  if Extension <> '.mif' then
  begin
    StatusText := 'Save error: unsupported file extension';
    Exit;
  end;
  if (FContainer <> nil) and not FHasEditableDocument then
  begin
    if (FWriter = nil) or
      not FWriter.TryWriteFile(FContainer, FileName, ErrorMessage) then
    begin
      StatusText := 'MIF save error: ' + ErrorMessage;
      Exit;
    end;
    StatusText := 'MIF container preserved: ' + ExtractFileName(FileName);
    Exit(True);
  end;
  if not TryCreateVectArtMifFromDocument(FDocument, FContainer, Container,
    ExportReport, ErrorMessage) then
  begin
    if ExportReport.Compatibility = mecUnsupported then
    begin
      ExportMessage := 'MIFへ書き出せない項目があります。' +
        sLineBreak + sLineBreak + ExportReport.ToDisplayText;
      if ShowDialogs then
        MessageBox(OwnerHandle, PChar(ExportMessage), 'MIF書き出し',
          MB_OK or MB_ICONWARNING);
      StatusText := 'MIF save cancelled: unsupported content';
    end
    else
      StatusText := 'MIF document generation error: ' + ErrorMessage;
    Exit;
  end;
  if ExportReport.Compatibility = mecNeedsConfirmation then
  begin
    ExportMessage := 'MIFへの書き出しには注意が必要です。' +
      sLineBreak + sLineBreak + ExportReport.ToDisplayText +
      sLineBreak + sLineBreak + 'この内容で書き出しますか？';
    // 非対話呼出しでは、確認が必要な変換を暗黙に承認しない。
    if not ShowDialogs or
      (MessageBox(OwnerHandle, PChar(ExportMessage), 'MIF書き出しの確認',
        MB_OKCANCEL or MB_ICONWARNING) <> IDOK) then
    begin
      Container.Free;
      StatusText := 'MIF save cancelled';
      Exit;
    end;
  end;
  try
    if (FWriter = nil) or
      not FWriter.TryWriteFile(Container, FileName, ErrorMessage) then
    begin
      StatusText := 'MIF save error: ' + ErrorMessage;
      Exit;
    end;
    FreeAndNil(FContainer);
    FContainer := Container;
    Container := nil;
    FHasEditableDocument := True;
  finally
    Container.Free;
  end;
  StatusText := 'MIF document saved: ' + ExtractFileName(FileName);
  Result := True;
end;

end.
