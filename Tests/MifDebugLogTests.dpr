program MifDebugLogTests;

{$APPTYPE CONSOLE}

// 他アプリ由来の四角MIFから互換性調査に必要なログが生成されることを検証する。

uses
  System.IOUtils,
  System.SysUtils,
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas',
  VectArtDesignerMifDebugLog in
    'Source\Persistence\Mif\VectArtDesignerMifDebugLog.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Container: TVectArtMifContainer;
  ErrorMessage: string;
  LogFileName: string;
  LogText: string;
  Reader: IVectArtMifContainerReader;
begin
  Container := nil;
  Reader := CreateVectArtMifContainerReader;
  Require(Reader.TryReadFile('mif' + PathDelim + #$56DB#$89D2 + '.mif',
    Container, ErrorMessage), ErrorMessage);
  try
    LogFileName := WriteMifOpenDebugLog(
      ChangeFileExt(ParamStr(0), '.external-rectangle.mif'), Container,
      'VectArtDesigner editing data was not found in this MIF');
    Require(LogFileName <> '', 'Debug log was not created');
    LogText := TFile.ReadAllText(LogFileName, TEncoding.UTF8);
    Require(Pos('document import: FAILED', LogText) > 0,
      'Import failure was not logged');
    Require(Pos('key: object type', LogText) > 0,
      'Object type metadata was not logged');
    Require(Pos('key: waDAimage position1 x', LogText) > 0,
      'Position metadata was not logged');
    Require(Pos('crc=False', LogText) = 0, 'Invalid PNG CRC was reported');
    Writeln('MIF debug log: PASS');
    Writeln(LogFileName);
  finally
    Container.Free;
  end;
end.
