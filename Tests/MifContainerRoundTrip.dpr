program MifContainerRoundTrip;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas';

function StreamsEqual(const Expected: TBytes; Actual: TMemoryStream): Boolean;
begin
  Result := (Length(Expected) = Actual.Size) and
    ((Length(Expected) = 0) or CompareMem(@Expected[0], Actual.Memory,
      Length(Expected)));
end;

procedure TestFile(const FileName: string);
var
  Container: TVectArtMifContainer;
  ErrorMessage: string;
  Expected: TBytes;
  Output: TMemoryStream;
  Reader: IVectArtMifContainerReader;
  Saved: TBytes;
  TempFileName: string;
  Writer: IVectArtMifContainerWriter;
begin
  Reader := CreateVectArtMifContainerReader;
  Writer := CreateVectArtMifContainerWriter;
  if not Reader.TryReadFile(FileName, Container, ErrorMessage) then
    raise Exception.CreateFmt('%s: %s', [FileName, ErrorMessage]);
  try
    Expected := TFile.ReadAllBytes(FileName);
    Output := TMemoryStream.Create;
    try
      if not Writer.TryWrite(Container, Output, ErrorMessage) then
        raise Exception.CreateFmt('%s: %s', [FileName, ErrorMessage]);
      if not StreamsEqual(Expected, Output) then
        raise Exception.CreateFmt('%s: round-trip bytes differ', [FileName]);
      TempFileName := TPath.GetTempFileName;
      try
        if not Writer.TryWriteFile(Container, TempFileName,
          ErrorMessage) then
          raise Exception.CreateFmt('%s: %s', [FileName, ErrorMessage]);
        Saved := TFile.ReadAllBytes(TempFileName);
        if (Length(Expected) <> Length(Saved)) or
          ((Length(Expected) > 0) and
           not CompareMem(@Expected[0], @Saved[0], Length(Expected))) then
          raise Exception.CreateFmt('%s: saved file bytes differ',
            [FileName]);
      finally
        if TFile.Exists(TempFileName) then
          TFile.Delete(TempFileName);
      end;
      Writeln(Format('OK  %s  chunks=%d  bytes=%d',
        [FileName, Container.ChunkCount, Length(Expected)]));
    finally
      Output.Free;
    end;
  finally
    Container.Free;
  end;
end;

var
  I: Integer;
begin
  try
    if ParamCount = 0 then
      raise Exception.Create('Pass one or more MIF files');
    for I := 1 to ParamCount do
      TestFile(ParamStr(I));
  except
    on E: Exception do
    begin
      Writeln('FAILED  ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
