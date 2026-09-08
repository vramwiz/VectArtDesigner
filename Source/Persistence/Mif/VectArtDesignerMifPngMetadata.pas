// MIF内PNGのチャンクとWebArtメタデータの読書きを担当する。
// 図形やDocumentに依存させず、元の画像データを維持したまま付加情報を更新する。
unit VectArtDesignerMifPngMetadata;

interface

uses System.SysUtils;

// 呼び出し側で必要なバイト数を検証してから読む。
function ReadUInt32BE(const Bytes: TBytes; Offset: Integer): UInt32;

procedure WriteUInt32BE(var Bytes: TBytes; Offset: Integer; Value: UInt32);

function IsPng(const Bytes: TBytes): Boolean;

function RemovePngChunk(const Png: TBytes;
  const RemovedChunkType: AnsiString): TBytes;

function RemovePngMetadataKey(const Png: TBytes;
  const RemovedChunkType: AnsiString; const RemovedKey: string): TBytes;

function FindPngMetadataInsertOffset(const Png: TBytes): Integer;

procedure AddText(var Png: TBytes; const Key, Value: string);

procedure AddWadaInteger(var Png: TBytes; const Key: string; Value: Int32);

procedure AddWadaDouble(var Png: TBytes; const Key: string; Value: Double);

procedure AddWadaString(var Png: TBytes; const Key, Value: string);

procedure AddWadaBytes(var Png: TBytes; const Key: string;
  const Value: TBytes);

procedure UpdateWadaInteger(var Png: TBytes; const Key: string;
  Value: Int32);

procedure AddPhysicalDimensions(var Png: TBytes);

function TryReadTextValue(const Png: TBytes; const RequiredKey: string;
  out Value: string): Boolean;

function TryReadPngString(const Png: TBytes; const ChunkType, Key: string;
  out Value: string): Boolean;

function TryReadPngUtf16LeString(const Png: TBytes; const Key: string;
  out Value: string): Boolean;

function TryReadPngInteger(const Png: TBytes; const Key: string;
  out Value: Int32): Boolean;

function TryReadPngDouble(const Png: TBytes; const Key: string;
  out Value: Double): Boolean;

implementation

uses System.Classes;

const
  PNG_SIGNATURE: array[0..7] of Byte =
    ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

// 呼び出し側で必要なバイト数を検証してから読む。
function ReadUInt32BE(const Bytes: TBytes; Offset: Integer): UInt32;
begin
  Result := (UInt32(Bytes[Offset]) shl 24) or
    (UInt32(Bytes[Offset + 1]) shl 16) or
    (UInt32(Bytes[Offset + 2]) shl 8) or UInt32(Bytes[Offset + 3]);
end;

function ReadDoubleBE(const Bytes: TBytes; Offset: Integer): Double;
var
  Bits: UInt64;
  I: Integer;
begin
  Bits := 0;
  for I := 0 to 7 do
    Bits := (Bits shl 8) or Bytes[Offset + I];
  Move(Bits, Result, SizeOf(Result));
end;

procedure WriteUInt32BE(var Bytes: TBytes; Offset: Integer; Value: UInt32);
begin
  Bytes[Offset] := Byte(Value shr 24);
  Bytes[Offset + 1] := Byte(Value shr 16);
  Bytes[Offset + 2] := Byte(Value shr 8);
  Bytes[Offset + 3] := Byte(Value);
end;

procedure WriteDoubleBE(var Bytes: TBytes; Offset: Integer; Value: Double);
var
  Bits: UInt64;
  I: Integer;
begin
  Move(Value, Bits, SizeOf(Bits));
  for I := 0 to 7 do
    Bytes[Offset + I] := Byte(Bits shr ((7 - I) * 8));
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

function IsPng(const Bytes: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(Bytes) < SizeOf(PNG_SIGNATURE) then
    Exit(False);
  for I := Low(PNG_SIGNATURE) to High(PNG_SIGNATURE) do
    if Bytes[I] <> PNG_SIGNATURE[I] then
      Exit(False);
  Result := True;
end;

function RemovePngChunk(const Png: TBytes;
  const RemovedChunkType: AnsiString): TBytes;
var
  ChunkLength: UInt32;
  ChunkType: AnsiString;
  Offset: Integer;
  Output: TMemoryStream;
  TotalLength: Integer;
begin
  if not IsPng(Png) then
    Exit(Copy(Png));
  Output := TMemoryStream.Create;
  try
    Output.WriteBuffer(Png[0], SizeOf(PNG_SIGNATURE));
    Offset := SizeOf(PNG_SIGNATURE);
    while Offset + 12 <= Length(Png) do
    begin
      ChunkLength := ReadUInt32BE(Png, Offset);
      if (ChunkLength > UInt32(High(Integer))) or
        (Int64(Offset) + ChunkLength + 12 > Length(Png)) then
        Exit(Copy(Png));
      TotalLength := Integer(ChunkLength) + 12;
      SetLength(ChunkType, 4);
      Move(Png[Offset + 4], ChunkType[1], 4);
      if ChunkType <> RemovedChunkType then
        Output.WriteBuffer(Png[Offset], TotalLength);
      Inc(Offset, TotalLength);
    end;
    if Offset <> Length(Png) then
      Exit(Copy(Png));
    SetLength(Result, Output.Size);
    if Output.Size > 0 then
    begin
      Output.Position := 0;
      Output.ReadBuffer(Result[0], Output.Size);
    end;
  finally
    Output.Free;
  end;
end;

function RemovePngMetadataKey(const Png: TBytes;
  const RemovedChunkType: AnsiString; const RemovedKey: string): TBytes;
var
  ChunkLength: UInt32;
  ChunkType: AnsiString;
  DataOffset: Integer;
  Key: string;
  NullOffset: Integer;
  Offset: Integer;
  Output: TMemoryStream;
  RemoveChunk: Boolean;
  TotalLength: Integer;
begin
  if not IsPng(Png) then
    Exit(Copy(Png));
  Output := TMemoryStream.Create;
  try
    Output.WriteBuffer(Png[0], SizeOf(PNG_SIGNATURE));
    Offset := SizeOf(PNG_SIGNATURE);
    while Offset + 12 <= Length(Png) do
    begin
      ChunkLength := ReadUInt32BE(Png, Offset);
      if (ChunkLength > UInt32(High(Integer))) or
        (Int64(Offset) + ChunkLength + 12 > Length(Png)) then
        Exit(Copy(Png));
      TotalLength := Integer(ChunkLength) + 12;
      SetLength(ChunkType, 4);
      Move(Png[Offset + 4], ChunkType[1], 4);
      RemoveChunk := False;
      if ChunkType = RemovedChunkType then
      begin
        DataOffset := Offset + 8;
        NullOffset := DataOffset;
        while (NullOffset < DataOffset + Integer(ChunkLength)) and
          (Png[NullOffset] <> 0) do
          Inc(NullOffset);
        if NullOffset < DataOffset + Integer(ChunkLength) then
        begin
          Key := TEncoding.ASCII.GetString(Png, DataOffset,
            NullOffset - DataOffset);
          RemoveChunk := Key = RemovedKey;
        end;
      end;
      if not RemoveChunk then
        Output.WriteBuffer(Png[Offset], TotalLength);
      Inc(Offset, TotalLength);
    end;
    if Offset <> Length(Png) then
      Exit(Copy(Png));
    SetLength(Result, Output.Size);
    if Output.Size > 0 then
    begin
      Output.Position := 0;
      Output.ReadBuffer(Result[0], Output.Size);
    end;
  finally
    Output.Free;
  end;
end;

function MakePngChunk(const ChunkType: AnsiString;
  const Data: TBytes): TBytes;
var
  I: Integer;
begin
  if Length(ChunkType) <> 4 then
    raise EArgumentException.Create('PNG chunk type must contain four bytes');
  SetLength(Result, Length(Data) + 12);
  WriteUInt32BE(Result, 0, UInt32(Length(Data)));
  for I := 1 to 4 do
    Result[3 + I] := Byte(ChunkType[I]);
  if Length(Data) > 0 then
    Move(Data[0], Result[8], Length(Data));
  WriteUInt32BE(Result, Length(Result) - 4,
    Crc32(Result, 4, Length(Data) + 4));
end;

function FindPngMetadataInsertOffset(const Png: TBytes): Integer;
var
  ChunkLength: UInt32;
  Offset: Integer;
begin
  Result := -1;
  if not IsPng(Png) then
    Exit;
  Offset := 8;
  while Offset + 12 <= Length(Png) do
  begin
    ChunkLength := ReadUInt32BE(Png, Offset);
    if (ChunkLength > UInt32(High(Integer))) or
      (Int64(Offset) + ChunkLength + 12 > Length(Png)) then
      Exit;
    if ((Png[Offset + 4] = Ord('I')) and
        (Png[Offset + 5] = Ord('D')) and
        (Png[Offset + 6] = Ord('A')) and
        (Png[Offset + 7] = Ord('T'))) or
       ((Png[Offset + 4] = Ord('I')) and
        (Png[Offset + 5] = Ord('E')) and
        (Png[Offset + 6] = Ord('N')) and
        (Png[Offset + 7] = Ord('D'))) then
      Exit(Offset);
    Inc(Offset, Integer(ChunkLength) + 12);
  end;
end;

procedure InsertPngMetadataChunk(var Png: TBytes;
  const ChunkType: AnsiString; const Data: TBytes);
var
  Chunk: TBytes;
  InsertOffset: Integer;
  TailLength: Integer;
begin
  InsertOffset := FindPngMetadataInsertOffset(Png);
  if InsertOffset < 0 then
    raise EWriteError.Create('PNG IDAT or IEND chunk is missing');
  Chunk := MakePngChunk(ChunkType, Data);
  TailLength := Length(Png) - InsertOffset;
  SetLength(Png, Length(Png) + Length(Chunk));
  Move(Png[InsertOffset], Png[InsertOffset + Length(Chunk)], TailLength);
  Move(Chunk[0], Png[InsertOffset], Length(Chunk));
end;

function TextChunkData(const Key, Value: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(Key + #0 + Value);
end;

function WadaIntegerData(const Key: string; Value: Int32): TBytes;
var
  KeyBytes: TBytes;
begin
  KeyBytes := TEncoding.ASCII.GetBytes(Key);
  SetLength(Result, Length(KeyBytes) + 5);
  if Length(KeyBytes) > 0 then
    Move(KeyBytes[0], Result[0], Length(KeyBytes));
  Result[Length(KeyBytes)] := 0;
  WriteUInt32BE(Result, Length(KeyBytes) + 1, UInt32(Value));
end;

function WadaDoubleData(const Key: string; Value: Double): TBytes;
var
  KeyBytes: TBytes;
begin
  KeyBytes := TEncoding.ASCII.GetBytes(Key);
  SetLength(Result, Length(KeyBytes) + 9);
  if Length(KeyBytes) > 0 then
    Move(KeyBytes[0], Result[0], Length(KeyBytes));
  Result[Length(KeyBytes)] := 0;
  WriteDoubleBE(Result, Length(KeyBytes) + 1, Value);
end;

function WadaStringData(const Key, Value: string): TBytes;
var
  KeyBytes: TBytes;
  ValueBytes: TBytes;
begin
  KeyBytes := TEncoding.ASCII.GetBytes(Key);
  ValueBytes := TEncoding.UTF8.GetBytes(Value);
  SetLength(Result, Length(KeyBytes) + Length(ValueBytes) + 1);
  if Length(KeyBytes) > 0 then
    Move(KeyBytes[0], Result[0], Length(KeyBytes));
  Result[Length(KeyBytes)] := 0;
  if Length(ValueBytes) > 0 then
    Move(ValueBytes[0], Result[Length(KeyBytes) + 1], Length(ValueBytes));
end;

procedure AddText(var Png: TBytes; const Key, Value: string);
begin
  InsertPngMetadataChunk(Png, 'tEXt', TextChunkData(Key, Value));
end;

procedure AddWadaInteger(var Png: TBytes; const Key: string; Value: Int32);
begin
  InsertPngMetadataChunk(Png, 'waDA', WadaIntegerData(Key, Value));
end;

procedure AddWadaDouble(var Png: TBytes; const Key: string; Value: Double);
begin
  InsertPngMetadataChunk(Png, 'waDA', WadaDoubleData(Key, Value));
end;

procedure AddWadaString(var Png: TBytes; const Key, Value: string);
begin
  InsertPngMetadataChunk(Png, 'waDA', WadaStringData(Key, Value));
end;

procedure AddWadaBytes(var Png: TBytes; const Key: string;
  const Value: TBytes);
var
  Data: TBytes;
  KeyBytes: TBytes;
begin
  KeyBytes := TEncoding.ASCII.GetBytes(Key);
  SetLength(Data, Length(KeyBytes) + Length(Value) + 1);
  if Length(KeyBytes) > 0 then
    Move(KeyBytes[0], Data[0], Length(KeyBytes));
  Data[Length(KeyBytes)] := 0;
  if Length(Value) > 0 then
    Move(Value[0], Data[Length(KeyBytes) + 1], Length(Value));
  InsertPngMetadataChunk(Png, 'waDA', Data);
end;

procedure UpdateWadaInteger(var Png: TBytes; const Key: string;
  Value: Int32);
var
  ChunkLength: UInt32;
  DataOffset: Integer;
  ExistingKey: string;
  NullOffset: Integer;
  Offset: Integer;
begin
  if IsPng(Png) then
  begin
    Offset := SizeOf(PNG_SIGNATURE);
    while Offset + 12 <= Length(Png) do
    begin
      ChunkLength := ReadUInt32BE(Png, Offset);
      if (ChunkLength > UInt32(High(Integer))) or
        (Int64(Offset) + ChunkLength + 12 > Length(Png)) then
        Break;
      if TEncoding.ASCII.GetString(Png, Offset + 4, 4) = 'waDA' then
      begin
        DataOffset := Offset + 8;
        NullOffset := DataOffset;
        while (NullOffset < DataOffset + Integer(ChunkLength)) and
          (Png[NullOffset] <> 0) do
          Inc(NullOffset);
        if (NullOffset + 5 = DataOffset + Integer(ChunkLength)) then
        begin
          ExistingKey := TEncoding.ASCII.GetString(Png, DataOffset,
            NullOffset - DataOffset);
          if ExistingKey = Key then
          begin
            WriteUInt32BE(Png, NullOffset + 1, UInt32(Value));
            WriteUInt32BE(Png, DataOffset + Integer(ChunkLength),
              Crc32(Png, Offset + 4, Integer(ChunkLength) + 4));
            Exit;
          end;
        end;
      end;
      Inc(Offset, Integer(ChunkLength) + 12);
    end;
  end;
  AddWadaInteger(Png, Key, Value);
end;

procedure AddPhysicalDimensions(var Png: TBytes);
var
  Data: TBytes;
begin
  SetLength(Data, 9);
  WriteUInt32BE(Data, 0, 2834);
  WriteUInt32BE(Data, 4, 2834);
  Data[8] := 1;
  InsertPngMetadataChunk(Png, 'pHYs', Data);
end;

function TryReadTextValue(const Png: TBytes; const RequiredKey: string;
  out Value: string): Boolean;
var
  ChunkLength: UInt32;
  ChunkType: AnsiString;
  DataOffset: Integer;
  Key: string;
  NullOffset: Integer;
  Offset: Integer;
begin
  Result := False;
  Value := '';
  if not IsPng(Png) then
    Exit;
  Offset := 8;
  while Offset + 12 <= Length(Png) do
  begin
    ChunkLength := ReadUInt32BE(Png, Offset);
    if (ChunkLength > UInt32(High(Integer))) or
      (Int64(Offset) + ChunkLength + 12 > Length(Png)) then
      Exit;
    SetLength(ChunkType, 4);
    Move(Png[Offset + 4], ChunkType[1], 4);
    if ChunkType = 'tEXt' then
    begin
      DataOffset := Offset + 8;
      NullOffset := DataOffset;
      while (NullOffset < DataOffset + Integer(ChunkLength)) and
        (Png[NullOffset] <> 0) do
        Inc(NullOffset);
      if NullOffset < DataOffset + Integer(ChunkLength) then
      begin
        Key := TEncoding.UTF8.GetString(Png, DataOffset,
          NullOffset - DataOffset);
        if Key = RequiredKey then
        begin
          Value := TEncoding.UTF8.GetString(Png, NullOffset + 1,
            DataOffset + Integer(ChunkLength) - NullOffset - 1);
          Exit(True);
        end;
      end;
    end;
    Inc(Offset, Integer(ChunkLength) + 12);
  end;
end;

function TryReadPngMetadata(const Png: TBytes; const RequiredChunkType,
  RequiredKey: string; out Value: TBytes): Boolean;
var
  ChunkLength: UInt32;
  ChunkType: string;
  DataOffset: Integer;
  Key: string;
  NullOffset: Integer;
  Offset: Integer;
  ValueCount: Integer;
begin
  Result := False;
  Value := nil;
  if not IsPng(Png) then
    Exit;
  Offset := 8;
  while Offset + 12 <= Length(Png) do
  begin
    ChunkLength := ReadUInt32BE(Png, Offset);
    if (ChunkLength > UInt32(High(Integer))) or
      (Int64(Offset) + ChunkLength + 12 > Length(Png)) then
      Exit;
    ChunkType := TEncoding.ASCII.GetString(Png, Offset + 4, 4);
    if ChunkType = RequiredChunkType then
    begin
      DataOffset := Offset + 8;
      NullOffset := DataOffset;
      while (NullOffset < DataOffset + Integer(ChunkLength)) and
        (Png[NullOffset] <> 0) do
        Inc(NullOffset);
      if NullOffset < DataOffset + Integer(ChunkLength) then
      begin
        Key := TEncoding.ASCII.GetString(Png, DataOffset,
          NullOffset - DataOffset);
        if Key = RequiredKey then
        begin
          ValueCount := DataOffset + Integer(ChunkLength) - NullOffset - 1;
          SetLength(Value, ValueCount);
          if ValueCount > 0 then
            Move(Png[NullOffset + 1], Value[0], ValueCount);
          Exit(True);
        end;
      end;
    end;
    Inc(Offset, Integer(ChunkLength) + 12);
  end;
end;

function TryReadPngString(const Png: TBytes; const ChunkType, Key: string;
  out Value: string): Boolean;
var
  Bytes: TBytes;
begin
  Result := TryReadPngMetadata(Png, ChunkType, Key, Bytes);
  if not Result then
  begin
    Value := '';
    Exit;
  end;
  if Length(Bytes) = 0 then
    Value := ''
  else if TEncoding.UTF8.IsBufferValid(@Bytes[0], Length(Bytes)) then
    Value := TEncoding.UTF8.GetString(Bytes)
  else
  begin
    Value := '';
    Result := False;
  end;
end;

function TryReadPngUtf16LeString(const Png: TBytes; const Key: string;
  out Value: string): Boolean;
var
  Bytes: TBytes;
begin
  Result := TryReadPngMetadata(Png, 'waDA', Key, Bytes) and
    ((Length(Bytes) mod SizeOf(Char)) = 0);
  if not Result then
  begin
    Value := '';
    Exit;
  end;
  Value := TEncoding.Unicode.GetString(Bytes);
  while (Value <> '') and (Value[Length(Value)] = #0) do
    Delete(Value, Length(Value), 1);
end;

function TryReadPngInteger(const Png: TBytes; const Key: string;
  out Value: Int32): Boolean;
var
  Bytes: TBytes;
begin
  Result := TryReadPngMetadata(Png, 'waDA', Key, Bytes) and
    (Length(Bytes) = 4);
  if Result then
    Value := Int32(ReadUInt32BE(Bytes, 0))
  else
    Value := 0;
end;

function TryReadPngDouble(const Png: TBytes; const Key: string;
  out Value: Double): Boolean;
var
  Bytes: TBytes;
begin
  Result := TryReadPngMetadata(Png, 'waDA', Key, Bytes) and
    (Length(Bytes) = 8);
  if Result then
    Value := ReadDoubleBE(Bytes, 0)
  else
    Value := 0.0;
end;

end.
