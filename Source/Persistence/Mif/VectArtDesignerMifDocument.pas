// Rectangle DocumentとIBM WebArt Designer互換MIFの相互変換を担当する。
// MIF保存では独自情報を出力せず、読み込み元の互換用ベクター情報を可能な範囲で再利用する。
unit VectArtDesignerMifDocument;

interface

uses
  System.SysUtils, VectArtDesignerDocument, VectArtDesignerMifContainer;

// MIF内のVectArtDesigner編集情報をDocumentへ適用する。ContainerとDocumentを所有しない。
function TryLoadVectArtDocumentFromMif(Container: TVectArtMifContainer;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
// 現在のDocumentから新しいMIFを生成し、成功時の所有権を呼び出し側へ渡す。
function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  out Container: TVectArtMifContainer; out ErrorMessage: string): Boolean; overload;
// SourceContainer内のRectangle互換情報を順番に再利用してMIFを生成する。両Containerを所有しない。
function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  SourceContainer: TVectArtMifContainer; out Container: TVectArtMifContainer;
  out ErrorMessage: string): Boolean; overload;

implementation

uses
  System.Classes, System.Generics.Collections, System.Math,
  System.NetEncoding, System.Skia, System.Types, Vcl.Graphics, Winapi.Windows,
  VectArtDesignerDocumentJson, VectArtDesignerRenderer;

const
  // 旧版が埋め込んだ編集情報は読み込みだけを継続し、互換保存には出力しない。
  DOCUMENT_TEXT_KEY = 'VectArtDesigner document';
  RECTANGLE_VECTOR_PNG_BASE64 =
    'iVBORw0KGgoAAAANSUhEUgAAAEwAAAABCAYAAAB0UUiZAAAACXBIWXMAAAsSAAALEgHS3X78' +
    'AAAAEnRFWHRvYmplY3QgdHlwZQB2ZWN0b3KhamnfAAAAPUlEQVR4nGNgYGBlYGBgZACBGA' +
    'cGBxAdBaWJA0wMfwPO/S+S/0+R3l8L5/zPjP9Pkl4QALmZdL3MxCtFAwBmBRfKcYTSHQAA' +
    'AABJRU5ErkJggg==';
  PNG_SIGNATURE: array[0..7] of Byte =
    ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

type
  TRectangleMifSource = record
    OriginalLeft: Integer;       // ベクターペイロードが使用する基準矩形の左端
    OriginalTop: Integer;        // ベクターペイロードが使用する基準矩形の上端
    OriginalRight: Integer;      // ベクターペイロードが使用する基準矩形の右端
    OriginalBottom: Integer;     // ベクターペイロードが使用する基準矩形の下端
    StrokeEnabled: Boolean;      // 元オブジェクトのストロークテクスチャ有効状態
    VectorPng: TBytes;           // 元オブジェクトのWebArtベクターペイロード
    StrokeTexturePng: TBytes;    // 元オブジェクトのストロークテクスチャ
    Valid: Boolean;              // 基準座標とペイロードを安全に再利用できる場合True
  end;

function ReadUInt32BE(const Bytes: TBytes; Offset: Integer): UInt32;
begin
  Result := (UInt32(Bytes[Offset]) shl 24) or
    (UInt32(Bytes[Offset + 1]) shl 16) or
    (UInt32(Bytes[Offset + 2]) shl 8) or UInt32(Bytes[Offset + 3]);
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

function EncodeRgba(const Pixels: Pointer; Width, Height: Integer): TBytes;
var
  ImageInfo: TSkImageInfo;
begin
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Result := TSkImageEncoder.Encode(ImageInfo, Pixels,
    NativeUInt(Width) * SizeOf(TVectArtRgbaPixel), TSkEncodedImageFormat.PNG);
  if Length(Result) = 0 then
    raise EWriteError.Create('PNG encoding failed');
  // WebArt製PNGに存在しないSkia固有のsBITは、厳密な読込側との互換性を優先して除去する。
  Result := RemovePngChunk(Result, 'sBIT');
end;

procedure CompositeCanvasBackground(Buffer: TVectArtRenderBuffer;
  Canvas: TVectArtCanvasLayer);
var
  Alpha: Cardinal;
  Background: TColor;
  BackgroundB: Cardinal;
  BackgroundG: Cardinal;
  BackgroundR: Cardinal;
  I: NativeInt;
  Pixel: PVectArtRgbaPixel;
begin
  if (Buffer = nil) or (Canvas = nil) or Canvas.Transparent then
    Exit;
  Background := ColorToRGB(Canvas.BackgroundColor);
  BackgroundR := GetRValue(Background);
  BackgroundG := GetGValue(Background);
  BackgroundB := GetBValue(Background);
  Pixel := Buffer.Data;
  for I := 0 to Buffer.PixelCount - 1 do
  begin
    Alpha := Pixel^.A;
    Pixel^.R := (Cardinal(Pixel^.R) * Alpha +
      BackgroundR * (255 - Alpha) + 127) div 255;
    Pixel^.G := (Cardinal(Pixel^.G) * Alpha +
      BackgroundG * (255 - Alpha) + 127) div 255;
    Pixel^.B := (Cardinal(Pixel^.B) * Alpha +
      BackgroundB * (255 - Alpha) + 127) div 255;
    Pixel^.A := 255;
    Inc(Pixel);
  end;
end;

function CreateCompositePng(Document: TVectArtDocument): TBytes;
var
  Buffer: TVectArtRenderBuffer;
  Canvas: TVectArtCanvasLayer;
begin
  Canvas := Document.CanvasLayer;
  Buffer := TVectArtRenderBuffer.Create;
  try
    RenderVectArtDocument(Document, Buffer, Canvas.Width, Canvas.Height);
    CompositeCanvasBackground(Buffer, Canvas);
    Result := EncodeRgba(Buffer.Data, Buffer.Width, Buffer.Height);
    AddPhysicalDimensions(Result);
    AddText(Result, 'application name', 'WebArt Designer');
    AddWadaInteger(Result, 'application version', 700);
    AddWadaInteger(Result, 'background page index', 0);
  finally
    Buffer.Free;
  end;
end;

function CreateSolidPng(Width, Height: Integer; Color: TColor): TBytes;
var
  ColorValue: TColor;
  I: Integer;
  Pixels: TArray<TVectArtRgbaPixel>;
begin
  Width := EnsureRange(Width, 1, 16384);
  Height := EnsureRange(Height, 1, 16384);
  SetLength(Pixels, Width * Height);
  ColorValue := ColorToRGB(Color);
  for I := 0 to High(Pixels) do
  begin
    Pixels[I].R := GetRValue(ColorValue);
    Pixels[I].G := GetGValue(ColorValue);
    Pixels[I].B := GetBValue(ColorValue);
    Pixels[I].A := 255;
  end;
  Result := EncodeRgba(@Pixels[0], Width, Height);
  AddPhysicalDimensions(Result);
end;

procedure AddImagePlacementMetadata(var Png: TBytes;
  const Bounds: TRectF; Alpha: Integer; Hidden: Boolean);
begin
  AddWadaInteger(Png, 'image position1 x', Round(Bounds.Left));
  AddWadaInteger(Png, 'image position1 y', Round(Bounds.Top));
  AddWadaInteger(Png, 'image position2 x', Round(Bounds.Right));
  AddWadaInteger(Png, 'image position2 y', Round(Bounds.Top));
  AddWadaInteger(Png, 'image position3 x', Round(Bounds.Right));
  AddWadaInteger(Png, 'image position3 y', Round(Bounds.Bottom));
  AddWadaInteger(Png, 'image position4 x', Round(Bounds.Left));
  AddWadaInteger(Png, 'image position4 y', Round(Bounds.Bottom));
  AddWadaInteger(Png, 'image alpha', EnsureRange(Alpha, 0, 255));
  AddWadaInteger(Png, 'image hidden', Ord(Hidden));
end;

function CreateTexturePng(Color: TColor): TBytes;
var
  BgrColor: Int32;
begin
  Result := CreateSolidPng(64, 64, Color);
  AddText(Result, 'object type', 'texture');
  AddImagePlacementMetadata(Result, TRectF.Create(0, 0, 63, 63), 255,
    False);
  AddWadaString(Result, 'texture object type', 'color');
  BgrColor := ColorToRGB(Color);
  AddWadaInteger(Result, 'texture color1', BgrColor);
  AddWadaInteger(Result, 'texture color2', 0);
  AddWadaInteger(Result, 'texture angle', 0);
  AddWadaInteger(Result, 'texture level', 0);
  AddWadaString(Result, 'texture pathname', '@');
end;

procedure AddRectangleVectorMetadata(var Png: TBytes;
  Rectangle: TVectArtRectangleLayer; Width, Height: Integer;
  const Source: TRectangleMifSource);
const
  TEMPLATE_LEFT = 113;
  TEMPLATE_TOP = 105;
  TEMPLATE_RIGHT = 289;
  TEMPLATE_BOTTOM = 202;
var
  OriginalBottom: Integer;
  OriginalLeft: Integer;
  OriginalRight: Integer;
  OriginalTop: Integer;
  ScaleX: Double;
  ScaleY: Double;
  StrokeEnabled: Boolean;
begin
  if Source.Valid then
  begin
    OriginalLeft := Source.OriginalLeft;
    OriginalTop := Source.OriginalTop;
    OriginalRight := Source.OriginalRight;
    OriginalBottom := Source.OriginalBottom;
    StrokeEnabled := Source.StrokeEnabled;
  end
  else
  begin
    OriginalLeft := TEMPLATE_LEFT;
    OriginalTop := TEMPLATE_TOP;
    OriginalRight := TEMPLATE_RIGHT;
    OriginalBottom := TEMPLATE_BOTTOM;
    StrokeEnabled := False;
  end;
  AddWadaInteger(Png, 'vector closed', 1);
  AddWadaInteger(Png, 'vector quality', 1);
  AddWadaInteger(Png, 'vector element type', 4);
  AddWadaInteger(Png, 'vector stroke style', 0);
  AddWadaInteger(Png, 'vector stroke cap', 0);
  AddWadaInteger(Png, 'vector stroke join', 2);
  AddWadaInteger(Png, 'vector start stroke marker', 0);
  AddWadaInteger(Png, 'vector end stroke marker', 0);
  AddWadaInteger(Png, 'vector start marker size', 4);
  AddWadaInteger(Png, 'vector end marker size', 4);
  AddWadaDouble(Png, 'vector stroke width', 1.0);
  ScaleX := Max(Width - 1, 0) / (OriginalRight - OriginalLeft);
  ScaleY := Max(Height - 1, 0) / (OriginalBottom - OriginalTop);
  AddWadaDouble(Png, 'vector matrix a', ScaleX);
  AddWadaDouble(Png, 'vector matrix b', 0.0);
  AddWadaDouble(Png, 'vector matrix c', 0.0);
  AddWadaDouble(Png, 'vector matrix d', ScaleY);
  AddWadaDouble(Png, 'vector matrix e', Rectangle.Bounds.Left -
    OriginalLeft * ScaleX);
  AddWadaDouble(Png, 'vector matrix f', Rectangle.Bounds.Top -
    OriginalTop * ScaleY);
  AddWadaInteger(Png, 'vector original position1 x', OriginalLeft);
  AddWadaInteger(Png, 'vector original position1 y', OriginalTop);
  AddWadaInteger(Png, 'vector original position2 x', OriginalRight);
  AddWadaInteger(Png, 'vector original position2 y', OriginalTop);
  AddWadaInteger(Png, 'vector original position3 x', OriginalRight);
  AddWadaInteger(Png, 'vector original position3 y', OriginalBottom);
  AddWadaInteger(Png, 'vector original position4 x', OriginalLeft);
  AddWadaInteger(Png, 'vector original position4 y', OriginalBottom);
  AddWadaInteger(Png, 'vector enable stroke texture', Ord(StrokeEnabled));
  AddWadaInteger(Png, 'vector enable fill texture', 1);
  AddWadaString(Png, 'vector effect object type', 'none');
end;

function CreateRectangleVectorPng(const Source: TRectangleMifSource): TBytes;
begin
  if Source.Valid then
    Result := Copy(Source.VectorPng)
  else
    Result := TNetEncoding.Base64.DecodeStringToBytes(
      RECTANGLE_VECTOR_PNG_BASE64);
  Result := RemovePngChunk(Result, 'sBIT');
end;

function CreateRectangleImagePng(Rectangle: TVectArtRectangleLayer;
  const Source: TRectangleMifSource): TBytes;
var
  Height: Integer;
  PlacementBounds: TRectF;
  Width: Integer;
begin
  Width := Max(Round(Abs(Rectangle.Bounds.Width)), 1);
  Height := Max(Round(Abs(Rectangle.Bounds.Height)), 1);
  Result := CreateSolidPng(Width, Height, Rectangle.FillColor);
  AddText(Result, 'object type', 'image');
  AddWadaString(Result, 'object subtype', 'vector');
  // WebArtの四隅座標はPNGの最終ピクセルを指すため、右端と下端は包含座標へ直す。
  PlacementBounds := TRectF.Create(Rectangle.Bounds.Left,
    Rectangle.Bounds.Top, Rectangle.Bounds.Left + Width - 1,
    Rectangle.Bounds.Top + Height - 1);
  AddImagePlacementMetadata(Result, PlacementBounds,
    Round(Rectangle.Opacity * 255), not Rectangle.Visible);
  AddRectangleVectorMetadata(Result, Rectangle, Width, Height, Source);
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

procedure CollectRectangleSources(Container: TVectArtMifContainer;
  Sources: TList<TRectangleMifSource>);
var
  Bottom: Int32;
  ElementType: Int32;
  I: Integer;
  Left: Int32;
  ObjectSubtype: string;
  ObjectType: string;
  Right: Int32;
  Source: TRectangleMifSource;
  StrokeEnabled: Int32;
  Top: Int32;
begin
  if (Container = nil) or (Sources = nil) then
    Exit;
  for I := 2 to Container.ChunkCount - 2 do
  begin
    if (Container[I].Tag <> 'IPNG') or
      not TryReadPngString(Container[I].Data, 'tEXt', 'object type',
        ObjectType) or not SameText(ObjectType, 'image') or
      not TryReadPngString(Container[I].Data, 'waDA', 'object subtype',
        ObjectSubtype) or not SameText(ObjectSubtype, 'vector') or
      not TryReadPngInteger(Container[I].Data, 'vector element type',
        ElementType) or (ElementType <> 4) then
      Continue;
    Source := Default(TRectangleMifSource);
    StrokeEnabled := 0;
    TryReadPngInteger(Container[I].Data, 'vector enable stroke texture',
      StrokeEnabled);
    Source.StrokeEnabled := StrokeEnabled <> 0;
    Source.Valid := (I + 2 < Container.ChunkCount) and
      (Container[I + 2].Tag = 'IPNG') and IsPng(Container[I + 2].Data) and
      TryReadPngInteger(Container[I].Data, 'vector original position1 x',
        Left) and
      TryReadPngInteger(Container[I].Data, 'vector original position1 y',
        Top) and
      TryReadPngInteger(Container[I].Data, 'vector original position3 x',
        Right) and
      TryReadPngInteger(Container[I].Data, 'vector original position3 y',
        Bottom) and (Right <> Left) and (Bottom <> Top);
    if Source.Valid then
    begin
      Source.OriginalLeft := Left;
      Source.OriginalTop := Top;
      Source.OriginalRight := Right;
      Source.OriginalBottom := Bottom;
      Source.VectorPng := Copy(Container[I + 2].Data);
      if (I + 3 < Container.ChunkCount) and
        (Container[I + 3].Tag = 'IPNG') and IsPng(Container[I + 3].Data) then
        Source.StrokeTexturePng := Copy(Container[I + 3].Data);
    end;
    Sources.Add(Source);
  end;
end;

function TryReadPngSize(const Png: TBytes; out Width,
  Height: Integer): Boolean;
begin
  Result := IsPng(Png) and (Length(Png) >= 33) and
    (TEncoding.ASCII.GetString(Png, 12, 4) = 'IHDR');
  if Result then
  begin
    Width := Integer(ReadUInt32BE(Png, 16));
    Height := Integer(ReadUInt32BE(Png, 20));
    Result := (Width > 0) and (Height > 0);
  end
  else
  begin
    Width := 0;
    Height := 0;
  end;
end;

function TryImportWebArtDocument(Container: TVectArtMifContainer;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
var
  Alpha: Int32;
  ApplicationName: string;
  BackgroundColor: Int32;
  Bottom: Int32;
  CanvasHeight: Integer;
  CanvasWidth: Integer;
  Data: TVectArtRectangleData;
  Discarded: TVectArtRectangleData;
  ElementType: Int32;
  FillColor: Int32;
  Hidden: Int32;
  I: Integer;
  Left: Int32;
  ObjectSubtype: string;
  ObjectType: string;
  Rectangles: TList<TVectArtRectangleData>;
  Right: Int32;
  Top: Int32;
begin
  Result := False;
  ErrorMessage := '';
  if (Container.ChunkCount < 3) or (Container[1].Tag <> 'IPNG') or
    not TryReadPngString(Container[1].Data, 'tEXt', 'application name',
      ApplicationName) or not SameText(ApplicationName, 'WebArt Designer') or
    not TryReadPngSize(Container[1].Data, CanvasWidth, CanvasHeight) then
  begin
    ErrorMessage := 'WebArt Designer MIF metadata was not found';
    Exit;
  end;

  BackgroundColor := ColorToRGB(clWhite);
  if (Container[2].Tag = 'IPNG') then
    TryReadPngInteger(Container[2].Data, 'texture color1', BackgroundColor);
  Rectangles := TList<TVectArtRectangleData>.Create;
  try
    for I := 2 to Container.ChunkCount - 2 do
    begin
      if (Container[I].Tag <> 'IPNG') or
        not TryReadPngString(Container[I].Data, 'tEXt', 'object type',
          ObjectType) or not SameText(ObjectType, 'image') or
        not TryReadPngString(Container[I].Data, 'waDA', 'object subtype',
          ObjectSubtype) or not SameText(ObjectSubtype, 'vector') or
        not TryReadPngInteger(Container[I].Data, 'vector element type',
          ElementType) or (ElementType <> 4) then
        Continue;
      if not TryReadPngInteger(Container[I].Data, 'image position1 x', Left) or
        not TryReadPngInteger(Container[I].Data, 'image position1 y', Top) or
        not TryReadPngInteger(Container[I].Data, 'image position3 x', Right) or
        not TryReadPngInteger(Container[I].Data, 'image position3 y', Bottom)
      then
        Continue;
      FillColor := ColorToRGB(clWhite);
      if (I + 1 < Container.ChunkCount) and
        (Container[I + 1].Tag = 'IPNG') then
        TryReadPngInteger(Container[I + 1].Data, 'texture color1', FillColor);
      Alpha := 255;
      Hidden := 0;
      TryReadPngInteger(Container[I].Data, 'image alpha', Alpha);
      TryReadPngInteger(Container[I].Data, 'image hidden', Hidden);
      Data.Name := Format('Rectangle %d', [Rectangles.Count + 1]);
      Data.Bounds := TRectF.Create(Min(Left, Right), Min(Top, Bottom),
        Max(Left, Right) + 1, Max(Top, Bottom) + 1);
      Data.FillColor := TColor(FillColor);
      Data.Opacity := EnsureRange(Alpha / 255.0, 0.0, 1.0);
      Data.Visible := Hidden = 0;
      Data.Locked := False;
      Rectangles.Add(Data);
    end;

    while Document.LayerCount > 1 do
      Document.RemoveRectangle(Document.LayerCount - 1, Discarded);
    Document.CanvasLayer.Width := CanvasWidth;
    Document.CanvasLayer.Height := CanvasHeight;
    Document.CanvasLayer.BackgroundColor := TColor(BackgroundColor);
    Document.CanvasLayer.Transparent := False;
    for Data in Rectangles do
      Document.InsertRectangle(Document.LayerCount, Data);
    Document.SelectedIndex := -1;
    Document.Changed;
    Result := True;
  finally
    Rectangles.Free;
  end;
end;

function TryLoadVectArtDocumentFromMif(Container: TVectArtMifContainer;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
var
  I: Integer;
  Json: string;
begin
  Result := False;
  ErrorMessage := '';
  if Container = nil then
  begin
    ErrorMessage := 'MIF container is not assigned';
    Exit;
  end;
  if Document = nil then
  begin
    ErrorMessage := 'Document is not assigned';
    Exit;
  end;
  for I := 0 to Container.ChunkCount - 1 do
    if (Container[I].Tag = 'IPNG') and
      TryReadTextValue(Container[I].Data, DOCUMENT_TEXT_KEY, Json) then
      Exit(TryDeserializeVectArtDocument(Json, Document, ErrorMessage));
  Result := TryImportWebArtDocument(Container, Document, ErrorMessage);
end;

function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  out Container: TVectArtMifContainer; out ErrorMessage: string): Boolean;
begin
  Result := TryCreateVectArtMifFromDocument(Document, nil, Container,
    ErrorMessage);
end;

function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  SourceContainer: TVectArtMifContainer; out Container: TVectArtMifContainer;
  out ErrorMessage: string): Boolean;
var
  Candidate: TVectArtMifContainer;
  Canvas: TVectArtCanvasLayer;
  Header: TBytes;
  I: Integer;
  Layer: TVectArtLayer;
  Rectangle: TVectArtRectangleLayer;
  RectangleCount: Integer;
  RectangleIndex: Integer;
  RectangleSource: TRectangleMifSource;
  RectangleSources: TList<TRectangleMifSource>;
  StrokeTexturePng: TBytes;
begin
  Result := False;
  Container := nil;
  ErrorMessage := '';
  Candidate := nil;
  RectangleSources := TList<TRectangleMifSource>.Create;
  try
    try
      if Document = nil then
        raise EArgumentNilException.Create('Document');
      Canvas := Document.CanvasLayer;
      if Canvas = nil then
        raise EInvalidOp.Create('Document canvas is missing');
      CollectRectangleSources(SourceContainer, RectangleSources);
      Candidate := TVectArtMifContainer.Create;
      RectangleCount := 0;
      for I := 1 to Document.LayerCount - 1 do
        if Document[I] is TVectArtRectangleLayer then
          Inc(RectangleCount);
      SetLength(Header, 4);
      // MHDRはヘッダーと終端を除く外側チャンク数を保持する。
      WriteUInt32BE(Header, 0, 2 + RectangleCount * 4);
      Candidate.AddChunk('MHDR', Header);
      Candidate.AddChunk('IPNG', CreateCompositePng(Document));
      Candidate.AddChunk('IPNG', CreateTexturePng(Canvas.BackgroundColor));
      RectangleIndex := 0;
      for I := 1 to Document.LayerCount - 1 do
      begin
        Layer := Document[I];
        if not (Layer is TVectArtRectangleLayer) then
          Continue;
        Rectangle := TVectArtRectangleLayer(Layer);
        RectangleSource := Default(TRectangleMifSource);
        if RectangleIndex < RectangleSources.Count then
          RectangleSource := RectangleSources[RectangleIndex];
        Candidate.AddChunk('IPNG', CreateRectangleImagePng(Rectangle,
          RectangleSource));
        Candidate.AddChunk('IPNG', CreateTexturePng(Rectangle.FillColor));
        Candidate.AddChunk('IPNG', CreateRectangleVectorPng(RectangleSource));
        if RectangleSource.Valid and
          (Length(RectangleSource.StrokeTexturePng) > 0) then
        begin
          StrokeTexturePng := RemovePngChunk(
            RectangleSource.StrokeTexturePng, 'sBIT');
          Candidate.AddChunk('IPNG', StrokeTexturePng);
        end
        else
          Candidate.AddChunk('IPNG', CreateTexturePng(clBlack));
        Inc(RectangleIndex);
      end;
      Candidate.AddChunk('MEND', nil);
      Container := Candidate;
      Candidate := nil;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
    RectangleSources.Free;
    Candidate.Free;
  end;
end;

end.
