program MifDiagnostics;

{$APPTYPE CONSOLE}

// MIF Reader/Writerを実データへ一括適用し、保存互換性とコンテナー構造を
// AIと人の両方が調査できるMarkdown、JSON、テキストへ出力する診断プログラム。

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas';

type
  TMifDiagnosticResult = record
    ChunkCount: Integer;         // MIF外側コンテナーのチャンク数。
    DifferenceCount: Int64;      // 元データと保存データで異なるバイト数。
    ErrorMessage: string;        // 読込または保存に失敗した場合の理由。
    FirstDifference: Int64;      // 最初の差分位置。完全一致の場合は-1。
    Identical: Boolean;          // 元データと保存データがバイト単位で一致したか。
    OriginalBytes: Int64;        // 入力ファイルのバイト数。
    RelativeFileName: string;    // 入力ルートを基準にしたファイル名。
    SavedBytes: Int64;           // 往復保存後のファイルのバイト数。
    SavedFileName: string;       // 診断用に生成したMIFの絶対パス。
    SemanticFileName: string;    // 構造化テキスト出力の絶対パス。
    Sha256: string;              // 入力ファイルのSHA-256。
  end;

function ReadUInt32BE(const Bytes: TBytes; Offset: Integer): UInt32;
begin
  Result := (UInt32(Bytes[Offset]) shl 24) or
    (UInt32(Bytes[Offset + 1]) shl 16) or
    (UInt32(Bytes[Offset + 2]) shl 8) or UInt32(Bytes[Offset + 3]);
end;

function ReadInt32BE(const Bytes: TBytes; Offset: Integer): Int32;
begin
  Result := Int32(ReadUInt32BE(Bytes, Offset));
end;

function ReadAscii(const Bytes: TBytes; Offset, Count: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
    Result[I + 1] := Char(Bytes[Offset + I]);
end;

function BytesAsHex(const Bytes: TBytes; Offset, Count: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    if I > 0 then
      Result := Result + ' ';
    Result := Result + IntToHex(Bytes[Offset + I], 2);
  end;
end;

function SafeText(const Value: string): string;
begin
  Result := StringReplace(Value, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function JsonEscape(const Value: string): string;
begin
  Result := StringReplace(Value, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function Sha256OfBytes(const Bytes: TBytes): string;
var
  Stream: TBytesStream;
begin
  Stream := TBytesStream.Create(Bytes);
  try
    Result := THashSHA2.GetHashString(Stream);
  finally
    Stream.Free;
  end;
end;

function DecodeUtf8OrBinary(const Bytes: TBytes; Offset, Count: Integer): string;
begin
  if Count = 0 then
    Exit('');
  if not TEncoding.UTF8.IsBufferValid(@Bytes[Offset], Count) then
    Exit('<non-UTF8 binary>');
  Result := TEncoding.UTF8.GetString(Bytes, Offset, Count);
end;

function Crc32(const Bytes: TBytes; Offset, Count: Integer): UInt32;
var
  BitIndex: Integer;
  I: Integer;
begin
  Result := $FFFFFFFF;
  for I := 0 to Count - 1 do
  begin
    Result := Result xor Bytes[Offset + I];
    for BitIndex := 0 to 7 do
      if (Result and 1) <> 0 then
        Result := (Result shr 1) xor $EDB88320
      else
        Result := Result shr 1;
  end;
  Result := not Result;
end;

procedure WritePngMetadata(Writer: TStreamWriter; const Bytes: TBytes;
  DataOffset, DataLength, PngIndex: Integer);
var
  ChunkCrc: UInt32;
  ChunkDataOffset: Integer;
  ChunkLength: UInt32;
  ChunkOffset: Integer;
  ChunkType: string;
  ComputedCrc: UInt32;
  Key: string;
  NullOffset: Integer;
  PngEnd: Integer;
  TextValue: string;
  ValueCount: Integer;
  ValueOffset: Integer;
begin
  Writer.WriteLine(Format('  PNG[%d] offset=0x%s bytes=%d',
    [PngIndex, IntToHex(DataOffset, 8), DataLength]));
  if (DataLength < 8) or
    (BytesAsHex(Bytes, DataOffset, 8) <> '89 50 4E 47 0D 0A 1A 0A') then
  begin
    Writer.WriteLine('    ERROR: PNG signature is invalid');
    Exit;
  end;
  ChunkOffset := DataOffset + 8;
  PngEnd := DataOffset + DataLength;
  while ChunkOffset < PngEnd do
  begin
    if PngEnd - ChunkOffset < 12 then
    begin
      Writer.WriteLine('    ERROR: incomplete PNG chunk header');
      Exit;
    end;
    ChunkLength := ReadUInt32BE(Bytes, ChunkOffset);
    if (ChunkLength > UInt32(High(Integer))) or
      (Int64(ChunkLength) + 12 > PngEnd - ChunkOffset) then
    begin
      Writer.WriteLine('    ERROR: PNG chunk exceeds IPNG boundary');
      Exit;
    end;
    ChunkType := ReadAscii(Bytes, ChunkOffset + 4, 4);
    ChunkDataOffset := ChunkOffset + 8;
    ChunkCrc := ReadUInt32BE(Bytes,
      ChunkDataOffset + Integer(ChunkLength));
    ComputedCrc := Crc32(Bytes, ChunkOffset + 4,
      Integer(ChunkLength) + 4);
    Writer.WriteLine(Format(
      '    0x%s  %-4s  data=%d  crc=%s',
      [IntToHex(ChunkOffset, 8), ChunkType, ChunkLength,
       BoolToStr(ChunkCrc = ComputedCrc, True)]));

    if (ChunkType = 'tEXt') or (ChunkType = 'waDA') then
    begin
      NullOffset := ChunkDataOffset;
      while (NullOffset < ChunkDataOffset + Integer(ChunkLength)) and
        (Bytes[NullOffset] <> 0) do
        Inc(NullOffset);
      if NullOffset < ChunkDataOffset + Integer(ChunkLength) then
      begin
        Key := ReadAscii(Bytes, ChunkDataOffset,
          NullOffset - ChunkDataOffset);
        ValueOffset := NullOffset + 1;
        ValueCount := ChunkDataOffset + Integer(ChunkLength) - ValueOffset;
        if ChunkType = 'waDA' then
          Key := 'waDA' + Key;
        if ValueCount = 4 then
          Writer.WriteLine(Format('      %s = %d (0x%s)',
            [Key, ReadInt32BE(Bytes, ValueOffset),
             BytesAsHex(Bytes, ValueOffset, ValueCount)]))
        else
        begin
          TextValue := DecodeUtf8OrBinary(Bytes, ValueOffset, ValueCount);
          Writer.WriteLine(Format('      %s = "%s"  hex=%s',
            [Key, SafeText(TextValue),
             BytesAsHex(Bytes, ValueOffset, ValueCount)]));
        end;
      end;
    end;
    Inc(ChunkOffset, Integer(ChunkLength) + 12);
    if ChunkType = 'IEND' then
      Break;
  end;
end;

procedure WriteSemanticDump(const FileName, OutputFileName: string;
  const Bytes: TBytes);
var
  ChunkIndex: Integer;
  ChunkLength: UInt32;
  ChunkOffset: Integer;
  ChunkTag: string;
  DataOffset: Integer;
  PngIndex: Integer;
  Writer: TStreamWriter;
begin
  Writer := TStreamWriter.Create(OutputFileName, False, TEncoding.UTF8);
  try
    Writer.WriteLine('# MIF semantic dump');
    Writer.WriteLine('File: ' + FileName);
    Writer.WriteLine('Bytes: ' + IntToStr(Length(Bytes)));
    Writer.WriteLine('SHA-256: ' + Sha256OfBytes(Bytes));
    Writer.WriteLine;
    if (Length(Bytes) < 8) or
      (BytesAsHex(Bytes, 0, 8) <> '4D 49 4D 47 0D 0A 1A 00') then
    begin
      Writer.WriteLine('ERROR: MIF signature is invalid');
      Exit;
    end;
    Writer.WriteLine('Signature: MIMG 0D 0A 1A 00');
    ChunkOffset := 8;
    ChunkIndex := 0;
    PngIndex := 0;
    while ChunkOffset < Length(Bytes) do
    begin
      if Length(Bytes) - ChunkOffset < 8 then
      begin
        Writer.WriteLine('ERROR: incomplete MIF chunk header');
        Exit;
      end;
      ChunkLength := ReadUInt32BE(Bytes, ChunkOffset);
      ChunkTag := ReadAscii(Bytes, ChunkOffset + 4, 4);
      DataOffset := ChunkOffset + 8;
      if (ChunkLength > UInt32(High(Integer))) or
        (Int64(ChunkLength) > Length(Bytes) - DataOffset) then
      begin
        Writer.WriteLine('ERROR: MIF chunk exceeds file boundary');
        Exit;
      end;
      Writer.WriteLine(Format('Chunk[%d] offset=0x%s tag=%s data=%d',
        [ChunkIndex, IntToHex(ChunkOffset, 8), ChunkTag, ChunkLength]));
      if ChunkTag = 'IPNG' then
      begin
        WritePngMetadata(Writer, Bytes, DataOffset, Integer(ChunkLength),
          PngIndex);
        Inc(PngIndex);
      end
      else if ChunkLength <= 32 then
        Writer.WriteLine('  data: ' + BytesAsHex(Bytes, DataOffset,
          Integer(ChunkLength)));
      Inc(ChunkOffset, Integer(ChunkLength) + 8);
      Inc(ChunkIndex);
    end;
  finally
    Writer.Free;
  end;
end;

procedure WriteHexDump(const SourceFileName, OutputFileName: string;
  const Bytes: TBytes);
var
  Ascii: string;
  Count: Integer;
  I: Integer;
  J: Integer;
  Writer: TStreamWriter;
begin
  Writer := TStreamWriter.Create(OutputFileName, False, TEncoding.UTF8);
  try
    Writer.WriteLine('# MIF hexadecimal dump');
    Writer.WriteLine('Source: ' + SourceFileName);
    Writer.WriteLine('Bytes: ' + IntToStr(Length(Bytes)));
    Writer.WriteLine('SHA-256: ' + Sha256OfBytes(Bytes));
    Writer.WriteLine;
    for I := 0 to (Length(Bytes) - 1) div 16 do
    begin
      Count := Length(Bytes) - I * 16;
      if Count > 16 then
        Count := 16;
      Ascii := '';
      for J := 0 to Count - 1 do
        if Bytes[I * 16 + J] in [32..126] then
          Ascii := Ascii + Char(Bytes[I * 16 + J])
        else
          Ascii := Ascii + '.';
      Writer.WriteLine(Format('%s | %-47s | %s',
        [IntToHex(I * 16, 16), BytesAsHex(Bytes, I * 16, Count), Ascii]));
    end;
  finally
    Writer.Free;
  end;
end;

procedure CompareBytes(const Original, Saved: TBytes;
  out Identical: Boolean; out FirstDifference, DifferenceCount: Int64);
var
  I: Integer;
  SharedLength: Integer;
begin
  FirstDifference := -1;
  DifferenceCount := 0;
  SharedLength := Length(Original);
  if Length(Saved) < SharedLength then
    SharedLength := Length(Saved);
  for I := 0 to SharedLength - 1 do
    if Original[I] <> Saved[I] then
    begin
      if FirstDifference < 0 then
        FirstDifference := I;
      Inc(DifferenceCount);
    end;
  if Length(Original) <> Length(Saved) then
  begin
    if FirstDifference < 0 then
      FirstDifference := SharedLength;
    Inc(DifferenceCount, Abs(Length(Original) - Length(Saved)));
  end;
  Identical := DifferenceCount = 0;
end;

procedure WriteDifferenceReport(const FileName: string;
  const Original, Saved: TBytes; const Result: TMifDiagnosticResult);
var
  ContextCount: Integer;
  ContextOffset: Integer;
  Writer: TStreamWriter;
begin
  Writer := TStreamWriter.Create(FileName, False, TEncoding.UTF8);
  try
    if Result.Identical then
    begin
      Writer.WriteLine('IDENTICAL');
      Writer.WriteLine('No byte differences were found.');
      Exit;
    end;
    Writer.WriteLine('DIFFERENT');
    Writer.WriteLine('First difference: 0x' +
      IntToHex(Result.FirstDifference, 16));
    Writer.WriteLine('Difference count: ' +
      IntToStr(Result.DifferenceCount));
    ContextOffset := Result.FirstDifference - 32;
    if ContextOffset < 0 then
      ContextOffset := 0;
    ContextCount := 64;
    if ContextOffset + ContextCount > Length(Original) then
      ContextCount := Length(Original) - ContextOffset;
    if ContextCount > 0 then
      Writer.WriteLine('Original: ' + BytesAsHex(Original, ContextOffset,
        ContextCount));
    ContextCount := 64;
    if ContextOffset + ContextCount > Length(Saved) then
      ContextCount := Length(Saved) - ContextOffset;
    if ContextCount > 0 then
      Writer.WriteLine('Saved:    ' + BytesAsHex(Saved, ContextOffset,
        ContextCount));
  finally
    Writer.Free;
  end;
end;

function ParseArgument(const Name, DefaultValue: string): string;
var
  I: Integer;
begin
  Result := DefaultValue;
  for I := 1 to ParamCount - 1 do
    if SameText(ParamStr(I), Name) then
      Exit(ParamStr(I + 1));
end;

function HasArgument(const Name: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), Name) then
      Exit(True);
  Result := False;
end;

procedure WriteReports(const OutputDirectory: string;
  const Results: TArray<TMifDiagnosticResult>);
var
  DifferentCount: Integer;
  ErrorCount: Integer;
  I: Integer;
  IdenticalCount: Integer;
  Json: TStreamWriter;
  Markdown: TStreamWriter;
  Status: string;
begin
  DifferentCount := 0;
  ErrorCount := 0;
  IdenticalCount := 0;
  for I := 0 to High(Results) do
    if Results[I].ErrorMessage <> '' then
      Inc(ErrorCount)
    else if Results[I].Identical then
      Inc(IdenticalCount)
    else
      Inc(DifferentCount);
  Markdown := TStreamWriter.Create(TPath.Combine(OutputDirectory,
    'report.md'), False, TEncoding.UTF8);
  Json := TStreamWriter.Create(TPath.Combine(OutputDirectory,
    'report.json'), False, TEncoding.UTF8);
  try
    Markdown.WriteLine('# MIF round-trip diagnostics');
    Markdown.WriteLine;
    Markdown.WriteLine(Format('Files: %d / Identical: %d / Different: %d / Errors: %d',
      [Length(Results), IdenticalCount, DifferentCount, ErrorCount]));
    Markdown.WriteLine;
    Markdown.WriteLine('| File | Status | Bytes | Chunks | First difference |');
    Markdown.WriteLine('|---|---:|---:|---:|---:|');
    Json.WriteLine('{');
    Json.WriteLine('  "file_count": ' + IntToStr(Length(Results)) + ',');
    Json.WriteLine('  "identical_count": ' + IntToStr(IdenticalCount) + ',');
    Json.WriteLine('  "different_count": ' + IntToStr(DifferentCount) + ',');
    Json.WriteLine('  "error_count": ' + IntToStr(ErrorCount) + ',');
    Json.WriteLine('  "files": [');
    for I := 0 to High(Results) do
    begin
      if Results[I].ErrorMessage <> '' then
        Status := 'ERROR'
      else if Results[I].Identical then
        Status := 'IDENTICAL'
      else
        Status := 'DIFFERENT';
      Markdown.WriteLine(Format('| %s | %s | %d | %d | %d |',
        [Results[I].RelativeFileName, Status, Results[I].OriginalBytes,
         Results[I].ChunkCount, Results[I].FirstDifference]));
      Json.WriteLine('    {');
      Json.WriteLine('      "file": "' +
        JsonEscape(Results[I].RelativeFileName) + '",');
      Json.WriteLine('      "status": "' + Status + '",');
      Json.WriteLine('      "original_bytes": ' +
        IntToStr(Results[I].OriginalBytes) + ',');
      Json.WriteLine('      "saved_bytes": ' +
        IntToStr(Results[I].SavedBytes) + ',');
      Json.WriteLine('      "chunk_count": ' +
        IntToStr(Results[I].ChunkCount) + ',');
      Json.WriteLine('      "first_difference": ' +
        IntToStr(Results[I].FirstDifference) + ',');
      Json.WriteLine('      "difference_count": ' +
        IntToStr(Results[I].DifferenceCount) + ',');
      Json.WriteLine('      "sha256": "' + Results[I].Sha256 + '",');
      Json.WriteLine('      "saved_file": "' +
        JsonEscape(Results[I].SavedFileName) + '",');
      Json.WriteLine('      "semantic_dump": "' +
        JsonEscape(Results[I].SemanticFileName) + '",');
      Json.WriteLine('      "error": "' +
        JsonEscape(Results[I].ErrorMessage) + '"');
      if I < High(Results) then
        Json.WriteLine('    },')
      else
        Json.WriteLine('    }');
    end;
    Json.WriteLine('  ]');
    Json.WriteLine('}');
  finally
    Json.Free;
    Markdown.Free;
  end;
end;

procedure DiagnoseFile(const InputDirectory, OutputDirectory, FileName: string;
  GenerateHex: Boolean; out Diagnostic: TMifDiagnosticResult);
var
  Container: TVectArtMifContainer;
  DifferenceFileName: string;
  ErrorMessage: string;
  HexDirectory: string;
  Original: TBytes;
  Reader: IVectArtMifContainerReader;
  RelativeDirectory: string;
  Saved: TBytes;
  SavedDirectory: string;
  SemanticDirectory: string;
  Writer: IVectArtMifContainerWriter;
begin
  Diagnostic := Default(TMifDiagnosticResult);
  Diagnostic.FirstDifference := -1;
  Diagnostic.RelativeFileName := ExtractRelativePath(
    IncludeTrailingPathDelimiter(InputDirectory), FileName);
  RelativeDirectory := ExtractFileDir(Diagnostic.RelativeFileName);
  SavedDirectory := TPath.Combine(OutputDirectory, 'saved');
  SemanticDirectory := TPath.Combine(OutputDirectory, 'semantic');
  HexDirectory := TPath.Combine(OutputDirectory, 'hex');
  if RelativeDirectory <> '' then
  begin
    SavedDirectory := TPath.Combine(SavedDirectory, RelativeDirectory);
    SemanticDirectory := TPath.Combine(SemanticDirectory, RelativeDirectory);
    HexDirectory := TPath.Combine(HexDirectory, RelativeDirectory);
  end;
  TDirectory.CreateDirectory(SavedDirectory);
  TDirectory.CreateDirectory(SemanticDirectory);
  if GenerateHex then
    TDirectory.CreateDirectory(HexDirectory);
  Diagnostic.SavedFileName := TPath.Combine(SavedDirectory,
    TPath.GetFileNameWithoutExtension(FileName) + '.roundtrip.mif');
  Diagnostic.SemanticFileName := TPath.Combine(SemanticDirectory,
    TPath.GetFileNameWithoutExtension(FileName) + '.semantic.txt');
  DifferenceFileName := TPath.Combine(SemanticDirectory,
    TPath.GetFileNameWithoutExtension(FileName) + '.diff.txt');

  Reader := CreateVectArtMifContainerReader;
  Writer := CreateVectArtMifContainerWriter;
  Container := nil;
  try
    if not Reader.TryReadFile(FileName, Container, ErrorMessage) then
    begin
      Diagnostic.ErrorMessage := ErrorMessage;
      Exit;
    end;
    Diagnostic.ChunkCount := Container.ChunkCount;
    Original := TFile.ReadAllBytes(FileName);
    Diagnostic.OriginalBytes := Length(Original);
    Diagnostic.Sha256 := Sha256OfBytes(Original);
    if not Writer.TryWriteFile(Container, Diagnostic.SavedFileName,
      ErrorMessage) then
    begin
      Diagnostic.ErrorMessage := ErrorMessage;
      Exit;
    end;
    Saved := TFile.ReadAllBytes(Diagnostic.SavedFileName);
    Diagnostic.SavedBytes := Length(Saved);
    CompareBytes(Original, Saved, Diagnostic.Identical,
      Diagnostic.FirstDifference, Diagnostic.DifferenceCount);
    WriteSemanticDump(FileName, Diagnostic.SemanticFileName, Original);
    WriteDifferenceReport(DifferenceFileName, Original, Saved, Diagnostic);
    if GenerateHex then
    begin
      WriteHexDump(FileName, TPath.Combine(HexDirectory,
        TPath.GetFileNameWithoutExtension(FileName) + '.original.hex.txt'),
        Original);
      WriteHexDump(Diagnostic.SavedFileName, TPath.Combine(HexDirectory,
        TPath.GetFileNameWithoutExtension(FileName) + '.saved.hex.txt'),
        Saved);
    end;
  finally
    Container.Free;
  end;
end;

var
  Diagnostic: TMifDiagnosticResult;
  Files: TStringDynArray;
  GenerateHex: Boolean;
  I: Integer;
  InputDirectory: string;
  OutputDirectory: string;
  Results: TArray<TMifDiagnosticResult>;
begin
  try
    SetTextCodePage(Output, CP_UTF8);
    InputDirectory := ExpandFileName(ParseArgument('--input', 'mif'));
    OutputDirectory := ExpandFileName(ParseArgument('--output',
      TPath.Combine('Win64', 'MifDiagnostics')));
    GenerateHex := HasArgument('--hex');
    if not TDirectory.Exists(InputDirectory) then
      raise Exception.Create('Input directory does not exist: ' +
        InputDirectory);
    Files := TDirectory.GetFiles(InputDirectory, '*.mif',
      TSearchOption.soAllDirectories);
    TArray.Sort<string>(Files);
    if Length(Files) = 0 then
      raise Exception.Create('No MIF files were found');
    TDirectory.CreateDirectory(OutputDirectory);
    SetLength(Results, Length(Files));
    for I := 0 to High(Files) do
    begin
      DiagnoseFile(InputDirectory, OutputDirectory, Files[I], GenerateHex,
        Diagnostic);
      Results[I] := Diagnostic;
      if Results[I].ErrorMessage <> '' then
        Writeln(Format('[%d/%d] ERROR', [I + 1, Length(Files)]))
      else if Results[I].Identical then
        Writeln(Format('[%d/%d] IDENTICAL', [I + 1, Length(Files)]))
      else
        Writeln(Format('[%d/%d] DIFFERENT', [I + 1, Length(Files)]));
      if Results[I].ErrorMessage <> '' then
        ExitCode := 1
      else if (not Results[I].Identical) and (ExitCode = 0) then
        ExitCode := 2;
    end;
    WriteReports(OutputDirectory, Results);
    Writeln('REPORT=' + TPath.Combine(OutputDirectory, 'report.md'));
  except
    on E: Exception do
    begin
      Writeln('FATAL=' + E.Message);
      ExitCode := 3;
    end;
  end;
end.
