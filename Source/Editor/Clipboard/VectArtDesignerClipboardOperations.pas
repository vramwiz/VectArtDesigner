// 選択オブジェクトと透明PNGを同時にWindowsクリップボードへ入出力する。
// 独自形式を優先して編集可能なレイヤーとして貼り付け、外部画像はImageへ変換する。
unit VectArtDesignerClipboardOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

function CanCopyVectArtSelection(Document: TVectArtDocument): Boolean;
function CanCutVectArtSelection(Document: TVectArtDocument): Boolean;
function CanPasteVectArtClipboard: Boolean;
function CopyVectArtSelectionToClipboard(Document: TVectArtDocument): Boolean;
procedure CutVectArtSelectionToClipboard(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
procedure DeleteVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
procedure PasteVectArtClipboard(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);

implementation

uses
  System.Classes, System.Generics.Collections, System.Math, System.SysUtils,
  System.Types, Vcl.Clipbrd, Vcl.Graphics, Vcl.Imaging.pngimage,
  Winapi.Windows, VectArtDesignerBezierGeometry,
  VectArtDesignerDocumentJson, VectArtDesignerEditCommands,
  VectArtDesignerGeometry, VectArtDesignerLayerDataTransfer,
  VectArtDesignerLayerOperations,
  VectArtDesignerMifRaster, VectArtDesignerRenderer;

const
  CLIPBOARD_FORMAT_NAME = 'VectArtDesigner.Objects.v1';
  CLIPBOARD_PNG_FORMAT_NAME = 'PNG';
  PASTE_OFFSET = 24;

type
  TVectArtClipboardPasteCommand = class(TVectArtEditCommand)
  private
    FAfterSelection: TArray<Integer>;
    FBeforeSelection: TArray<Integer>;
    FDocument: TVectArtDocument;
    FLayerKinds: TArray<TVectArtLayerKind>;
    FPayload: string;
    FStartIndex: Integer;
  public
    constructor Create(ADocument: TVectArtDocument; AStartIndex: Integer;
      const APayload: string; const ALayerKinds: TArray<TVectArtLayerKind>;
      const ABeforeSelection, AAfterSelection: TArray<Integer>);
    procedure Execute; override;
    procedure Undo; override;
  end;

function ClipboardObjectFormat: UINT;
begin
  Result := RegisterClipboardFormat(CLIPBOARD_FORMAT_NAME);
end;

function ClipboardPngFormat: UINT;
begin
  Result := RegisterClipboardFormat(CLIPBOARD_PNG_FORMAT_NAME);
end;

function CreateSelectionDocument(Document: TVectArtDocument): TVectArtDocument;
var
  ErrorMessage: string;
  I: Integer;
begin
  Result := TVectArtDocument.Create;
  if not TryDeserializeVectArtDocument(SerializeVectArtDocument(Document),
    Result, ErrorMessage) then
  begin
    Result.Free;
    Exit(nil);
  end;
  for I := Result.LayerCount - 1 downto 1 do
    if not Document.IsLayerSelected(I) then
      RemoveVectArtLayer(Result, I);
end;

function ImagePointsBounds(const Points: TVectArtImagePoints): TRectF;
var
  I: Integer;
begin
  Result := TRectF.Create(Points[0], Points[0]);
  for I := 1 to High(Points) do
    Result := TRectF.Union(Result, TRectF.Create(Points[I], Points[I]));
end;

function TryLayerBounds(Layer: TVectArtLayer; out Bounds: TRectF): Boolean;
var
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
  Rectangle: TVectArtRectangleLayer;
  Text: TVectArtTextLayer;
begin
  Result := True;
  if Layer is TVectArtRectangleLayer then
  begin
    Rectangle := TVectArtRectangleLayer(Layer);
    Bounds := QuadBounds(RectangleCorners(Rectangle.Bounds,
      Rectangle.RotationDegrees));
  end
  else if Layer is TVectArtTextLayer then
  begin
    Text := TVectArtTextLayer(Layer);
    Bounds := QuadBounds(RectangleCorners(Text.Bounds,
      Text.RotationDegrees));
  end
  else if Layer is TVectArtLineLayer then
  begin
    Line := TVectArtLineLayer(Layer);
    Bounds := RectF(Min(Line.StartPoint.X, Line.EndPoint.X),
      Min(Line.StartPoint.Y, Line.EndPoint.Y),
      Max(Line.StartPoint.X, Line.EndPoint.X),
      Max(Line.StartPoint.Y, Line.EndPoint.Y));
  end
  else if Layer is TVectArtPathLayer then
  begin
    Path := TVectArtPathLayer(Layer);
    Bounds := PointsBounds(BuildPathDisplayPolyline(Path.Points,
      Path.Bezier, Path.Closed, 16));
  end
  else if Layer is TVectArtImageLayer then
    Bounds := ImagePointsBounds(TVectArtImageLayer(Layer).Points)
  else
    Result := False;
end;

function LayerPadding(Layer: TVectArtLayer): Single;
var
  Shadow: TVectArtShadow;
begin
  Result := 2;
  if Layer is TVectArtRectangleLayer then
    Result := Max(Result, TVectArtRectangleLayer(Layer).StrokeWidth)
  else if Layer is TVectArtLineLayer then
    Result := Max(Result, TVectArtLineLayer(Layer).StrokeWidth)
  else if Layer is TVectArtPathLayer then
    Result := Max(Result, TVectArtPathLayer(Layer).StrokeWidth);
  Shadow := Layer.Shadow;
  if Shadow.Enabled then
    Result := Max(Result, Shadow.Blur * 2 +
      Max(Abs(Shadow.OffsetX), Abs(Shadow.OffsetY)) + 2);
end;

function CreateSelectionPng(Document: TVectArtDocument): TBytes;
var
  Bounds: TRectF;
  Buffer: TVectArtRenderBuffer;
  I: Integer;
  LayerBounds: TRectF;
  Padding: Single;
  Valid: Boolean;
  Width: Integer;
  Height: Integer;
begin
  Result := nil;
  Bounds := TRectF.Empty;
  Padding := 2;
  Valid := False;
  for I := 1 to Document.LayerCount - 1 do
    if TryLayerBounds(Document[I], LayerBounds) then
    begin
      if Valid then
        Bounds := TRectF.Union(Bounds, LayerBounds)
      else
      begin
        Bounds := LayerBounds;
        Valid := True;
      end;
      Padding := Max(Padding, LayerPadding(Document[I]));
    end;
  if not Valid then
    Exit;
  Bounds.Inflate(Padding, Padding);
  Width := EnsureRange(Ceil(Bounds.Width), 1, 16384);
  Height := EnsureRange(Ceil(Bounds.Height), 1, 16384);
  Buffer := TVectArtRenderBuffer.Create;
  try
    RenderVectArtDocumentRegion(Document, Buffer, Width, Height, Bounds,
      VECTART_NO_GROUP, 0, False);
    Result := EncodeRgba(Buffer.Data, Buffer.Width, Buffer.Height);
  finally
    Buffer.Free;
  end;
end;

function BytesToGlobalHandle(const Data: TBytes): HGLOBAL;
var
  Target: Pointer;
begin
  Result := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, Length(Data));
  if Result = 0 then
    RaiseLastOSError;
  Target := GlobalLock(Result);
  if Target = nil then
  begin
    GlobalFree(Result);
    RaiseLastOSError;
  end;
  try
    if Length(Data) > 0 then
      Move(Data[0], Target^, Length(Data));
  finally
    GlobalUnlock(Result);
  end;
end;

function ReadClipboardBytes(Format: UINT): TBytes;
var
  Data: THandle;
  Size: NativeUInt;
  Source: Pointer;
begin
  Result := nil;
  Clipboard.Open;
  try
    Data := GetClipboardData(Format);
    if Data = 0 then
      Exit;
    Size := GlobalSize(Data);
    if Size = 0 then
      Exit;
    Source := GlobalLock(Data);
    if Source = nil then
      Exit;
    try
      SetLength(Result, Size);
      Move(Source^, Result[0], Size);
    finally
      GlobalUnlock(Data);
    end;
  finally
    Clipboard.Close;
  end;
end;

function WriteClipboard(const ObjectJson: string;
  const PngData: TBytes): Boolean;
var
  Handle: HGLOBAL;
  ObjectBytes: TBytes;
  Png: TPngImage;
  Stream: TBytesStream;
begin
  try
    ObjectBytes := TEncoding.UTF8.GetBytes(ObjectJson);
    Stream := TBytesStream.Create(PngData);
    Png := TPngImage.Create;
    try
      Png.LoadFromStream(Stream);
      Clipboard.Open;
      try
        Clipboard.Assign(Png);
        Handle := BytesToGlobalHandle(ObjectBytes);
        Clipboard.SetAsHandle(ClipboardObjectFormat, Handle);
        Handle := BytesToGlobalHandle(PngData);
        Clipboard.SetAsHandle(ClipboardPngFormat, Handle);
        Result := True;
      finally
        Clipboard.Close;
      end;
    finally
      Png.Free;
      Stream.Free;
    end;
  except
    Result := False;
  end;
end;

function CanCopyVectArtSelection(Document: TVectArtDocument): Boolean;
begin
  Result := (Document <> nil) and (Document.SelectionCount > 0);
end;

function CanCutVectArtSelection(Document: TVectArtDocument): Boolean;
var
  Operations: TVectArtLayerOperations;
begin
  Operations := TVectArtLayerOperations.Create;
  try
    Operations.Document := Document;
    Result := Operations.CanExecute(vlaDelete);
  finally
    Operations.Free;
  end;
end;

function CanPasteVectArtClipboard: Boolean;
begin
  Result := IsClipboardFormatAvailable(ClipboardObjectFormat) or
    IsClipboardFormatAvailable(ClipboardPngFormat) or
    IsClipboardFormatAvailable(CF_BITMAP) or
    IsClipboardFormatAvailable(CF_DIB);
end;

function CopyVectArtSelectionToClipboard(Document: TVectArtDocument): Boolean;
var
  ObjectJson: string;
  PngData: TBytes;
  SelectionDocument: TVectArtDocument;
begin
  Result := False;
  if not CanCopyVectArtSelection(Document) then
    Exit;
  SelectionDocument := CreateSelectionDocument(Document);
  if SelectionDocument = nil then
    Exit;
  try
    ObjectJson := SerializeVectArtDocument(SelectionDocument);
    PngData := CreateSelectionPng(SelectionDocument);
    if Length(PngData) = 0 then
      Exit;
    Result := WriteClipboard(ObjectJson, PngData);
  finally
    SelectionDocument.Free;
  end;
end;

procedure DeleteVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
var
  Operations: TVectArtLayerOperations;
begin
  Operations := TVectArtLayerOperations.Create;
  try
    Operations.Document := Document;
    Operations.EditHistory := EditHistory;
    Operations.Execute(vlaDelete);
  finally
    Operations.Free;
  end;
end;

procedure CutVectArtSelectionToClipboard(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
begin
  if CanCutVectArtSelection(Document) and
    CopyVectArtSelectionToClipboard(Document) then
    DeleteVectArtSelection(Document, EditHistory);
end;

procedure OffsetLayer(Document: TVectArtDocument; Index: Integer);
var
  Bounds: TRectF;
  I: Integer;
  Image: TVectArtImageLayer;
  ImagePoints: TVectArtImagePoints;
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
  Points: TArray<TPointF>;
begin
  if (Document[Index] is TVectArtRectangleLayer) or
    (Document[Index] is TVectArtTextLayer) then
  begin
    if Document[Index] is TVectArtRectangleLayer then
      Bounds := TVectArtRectangleLayer(Document[Index]).Bounds
    else
      Bounds := TVectArtTextLayer(Document[Index]).Bounds;
    Bounds.Offset(PASTE_OFFSET, PASTE_OFFSET);
    Document.SetRectangleBounds(Index, Bounds);
  end
  else if Document[Index] is TVectArtLineLayer then
  begin
    Line := TVectArtLineLayer(Document[Index]);
    Document.SetLinePoints(Index,
      PointF(Line.StartPoint.X + PASTE_OFFSET,
        Line.StartPoint.Y + PASTE_OFFSET),
      PointF(Line.EndPoint.X + PASTE_OFFSET,
        Line.EndPoint.Y + PASTE_OFFSET));
  end
  else if Document[Index] is TVectArtPathLayer then
  begin
    Path := TVectArtPathLayer(Document[Index]);
    Points := Copy(Path.Points);
    for I := 0 to High(Points) do
      Points[I].Offset(PASTE_OFFSET, PASTE_OFFSET);
    Document.SetPathPoints(Index, Points);
  end
  else if Document[Index] is TVectArtImageLayer then
  begin
    Image := TVectArtImageLayer(Document[Index]);
    ImagePoints := Image.Points;
    for I := 0 to High(ImagePoints) do
      ImagePoints[I].Offset(PASTE_OFFSET, PASTE_OFFSET);
    Document.SetImagePoints(Index, ImagePoints);
  end;
end;

function CopyName(const SourceName: string; UsedNames: TStrings): string;
var
  Number: Integer;
begin
  Result := SourceName;
  if UsedNames.IndexOf(Result) < 0 then
  begin
    UsedNames.Add(Result);
    Exit;
  end;
  Result := SourceName + ' Copy';
  Number := 2;
  while UsedNames.IndexOf(Result) >= 0 do
  begin
    Result := SourceName + ' Copy ' + Number.ToString;
    Inc(Number);
  end;
  UsedNames.Add(Result);
end;

procedure PreparePastedDocument(Source, Destination: TVectArtDocument;
  ApplyOffset: Boolean);
var
  GroupMap: TDictionary<TVectArtGroupId, TVectArtGroupId>;
  I: Integer;
  NewGroupId: TVectArtGroupId;
  OldGroupId: TVectArtGroupId;
  UsedNames: TStringList;
begin
  UsedNames := TStringList.Create;
  GroupMap := TDictionary<TVectArtGroupId, TVectArtGroupId>.Create;
  try
    UsedNames.CaseSensitive := False;
    for I := 0 to Destination.LayerCount - 1 do
      UsedNames.Add(Destination[I].Name);
    for I := 1 to Source.LayerCount - 1 do
    begin
      Source[I].Name := CopyName(Source[I].Name, UsedNames);
      Source[I].Locked := False;
      OldGroupId := Source[I].GroupId;
      if OldGroupId <> VECTART_NO_GROUP then
      begin
        if not GroupMap.TryGetValue(OldGroupId, NewGroupId) then
        begin
          NewGroupId := Destination.AllocateGroupId;
          GroupMap.Add(OldGroupId, NewGroupId);
        end;
        Source.SetLayerGroup(I, NewGroupId);
      end;
      if ApplyOffset then
        OffsetLayer(Source, I);
    end;
  finally
    GroupMap.Free;
    UsedNames.Free;
  end;
end;

function LayerKinds(Document: TVectArtDocument): TArray<TVectArtLayerKind>;
var
  I: Integer;
begin
  SetLength(Result, Max(Document.LayerCount - 1, 0));
  for I := 1 to Document.LayerCount - 1 do
    Result[I - 1] := Document[I].Kind;
end;

constructor TVectArtClipboardPasteCommand.Create(ADocument: TVectArtDocument;
  AStartIndex: Integer; const APayload: string;
  const ALayerKinds: TArray<TVectArtLayerKind>; const ABeforeSelection,
  AAfterSelection: TArray<Integer>);
begin
  inherited Create;
  FDocument := ADocument;
  FStartIndex := AStartIndex;
  FPayload := APayload;
  FLayerKinds := Copy(ALayerKinds);
  FBeforeSelection := Copy(ABeforeSelection);
  FAfterSelection := Copy(AAfterSelection);
end;

procedure TVectArtClipboardPasteCommand.Execute;
var
  ErrorMessage: string;
  I: Integer;
  Source: TVectArtDocument;
begin
  if FDocument = nil then
    Exit;
  Source := TVectArtDocument.Create;
  try
    if not TryDeserializeVectArtDocument(FPayload, Source, ErrorMessage) then
      Exit;
    FDocument.BeginUpdate;
    try
      for I := 1 to Source.LayerCount - 1 do
        if Source[I] is TVectArtRectangleLayer then
          FDocument.InsertRectangle(FStartIndex + I - 1,
            CaptureVectArtRectangleData(TVectArtRectangleLayer(Source[I])))
        else if Source[I] is TVectArtLineLayer then
          FDocument.InsertLine(FStartIndex + I - 1,
            CaptureVectArtLineData(TVectArtLineLayer(Source[I])))
        else if Source[I] is TVectArtPathLayer then
          FDocument.InsertPath(FStartIndex + I - 1,
            CaptureVectArtPathData(TVectArtPathLayer(Source[I])))
        else if Source[I] is TVectArtImageLayer then
          FDocument.InsertImage(FStartIndex + I - 1,
            CaptureVectArtImageData(TVectArtImageLayer(Source[I])))
        else if Source[I] is TVectArtTextLayer then
          FDocument.InsertText(FStartIndex + I - 1,
            CaptureVectArtTextData(TVectArtTextLayer(Source[I])));
      FDocument.SetSelectedLayers(FAfterSelection);
    finally
      FDocument.EndUpdate;
    end;
  finally
    Source.Free;
  end;
end;

procedure TVectArtClipboardPasteCommand.Undo;
var
  I: Integer;
begin
  if FDocument = nil then
    Exit;
  FDocument.BeginUpdate;
  try
    for I := High(FLayerKinds) downto 0 do
      RemoveVectArtLayer(FDocument, FStartIndex + I);
    FDocument.SetSelectedLayers(FBeforeSelection);
  finally
    FDocument.EndUpdate;
  end;
end;

function TryClipboardPng(out PngData: TBytes): Boolean;
var
  Bitmap: Vcl.Graphics.TBitmap;
  Picture: TPicture;
  Png: TPngImage;
  Stream: TMemoryStream;
begin
  PngData := ReadClipboardBytes(ClipboardPngFormat);
  if Length(PngData) > 0 then
    Exit(True);
  Result := False;
  if not (IsClipboardFormatAvailable(CF_BITMAP) or
    IsClipboardFormatAvailable(CF_DIB)) then
    Exit;
  Picture := TPicture.Create;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  Png := TPngImage.Create;
  Stream := TMemoryStream.Create;
  try
    Picture.Assign(Clipboard);
    Bitmap.Assign(Picture.Graphic);
    Png.Assign(Bitmap);
    Png.SaveToStream(Stream);
    SetLength(PngData, Stream.Size);
    if Stream.Size > 0 then
    begin
      Stream.Position := 0;
      Stream.ReadBuffer(PngData[0], Length(PngData));
    end;
    Result := Length(PngData) > 0;
  finally
    Stream.Free;
    Png.Free;
    Bitmap.Free;
    Picture.Free;
  end;
end;

function CreateImageDocument(const PngData: TBytes;
  Destination: TVectArtDocument): TVectArtDocument;
var
  Data: TVectArtImageData;
  DisplayHeight: Single;
  DisplayWidth: Single;
  Image: TPngImage;
  Scale: Single;
  Stream: TBytesStream;
begin
  Result := nil;
  Stream := TBytesStream.Create(PngData);
  Image := TPngImage.Create;
  try
    Image.LoadFromStream(Stream);
    if Image.Empty or (Image.Width <= 0) or (Image.Height <= 0) then
      Exit;
    Scale := Min(1.0, Min(Destination.CanvasLayer.Width * 0.8 / Image.Width,
      Destination.CanvasLayer.Height * 0.8 / Image.Height));
    DisplayWidth := Max(Image.Width * Scale, 1.0);
    DisplayHeight := Max(Image.Height * Scale, 1.0);
    Data := Default(TVectArtImageData);
    Data.Name := 'Clipboard Image';
    Data.Opacity := 1.0;
    Data.PngData := Copy(PngData);
    Data.Points[0] := PointF((Destination.CanvasLayer.Width - DisplayWidth) / 2,
      (Destination.CanvasLayer.Height - DisplayHeight) / 2);
    Data.Points[1] := PointF(Data.Points[0].X + DisplayWidth,
      Data.Points[0].Y);
    Data.Points[2] := PointF(Data.Points[1].X,
      Data.Points[1].Y + DisplayHeight);
    Data.Points[3] := PointF(Data.Points[0].X, Data.Points[2].Y);
    Data.SourceKind := visImage;
    Data.Visible := True;
    Result := TVectArtDocument.Create;
    Result.SetCanvasSize(Destination.CanvasLayer.Width,
      Destination.CanvasLayer.Height);
    Result.InsertImage(1, Data);
  finally
    Image.Free;
    Stream.Free;
  end;
end;

procedure ExecutePaste(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Source: TVectArtDocument;
  ApplyOffset: Boolean);
var
  AfterSelection: TArray<Integer>;
  BeforeSelection: TArray<Integer>;
  Command: TVectArtClipboardPasteCommand;
  I: Integer;
  Kinds: TArray<TVectArtLayerKind>;
  Payload: string;
  StartIndex: Integer;
begin
  if (Document = nil) or (Source = nil) or (Source.LayerCount <= 1) then
    Exit;
  PreparePastedDocument(Source, Document, ApplyOffset);
  Payload := SerializeVectArtDocument(Source);
  Kinds := LayerKinds(Source);
  StartIndex := Document.LayerCount;
  BeforeSelection := Document.GetSelectedLayerIndices;
  SetLength(AfterSelection, Length(Kinds));
  for I := 0 to High(AfterSelection) do
    AfterSelection[I] := StartIndex + I;
  Command := TVectArtClipboardPasteCommand.Create(Document, StartIndex,
    Payload, Kinds, BeforeSelection, AfterSelection);
  Command.Execute;
  if EditHistory <> nil then
    EditHistory.AddApplied(Command)
  else
    Command.Free;
end;

procedure PasteVectArtClipboard(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
var
  ErrorMessage: string;
  ObjectBytes: TBytes;
  ObjectJson: string;
  PngData: TBytes;
  Source: TVectArtDocument;
begin
  try
    if Document = nil then
      Exit;
    Source := nil;
    ObjectBytes := ReadClipboardBytes(ClipboardObjectFormat);
    if Length(ObjectBytes) > 0 then
    begin
      ObjectJson := TEncoding.UTF8.GetString(ObjectBytes);
      Source := TVectArtDocument.Create;
      if not TryDeserializeVectArtDocument(ObjectJson, Source,
        ErrorMessage) or (Source.LayerCount <= 1) then
        FreeAndNil(Source);
    end;
    if Source <> nil then
    try
      ExecutePaste(Document, EditHistory, Source, True);
      Exit;
    finally
      Source.Free;
    end;
    if not TryClipboardPng(PngData) then
      Exit;
    Source := CreateImageDocument(PngData, Document);
    try
      ExecutePaste(Document, EditHistory, Source, False);
    finally
      Source.Free;
    end;
  except
    // クリップボードが他プロセスに占有中、または画像が破損している場合は変更しない。
  end;
end;

end.
