unit VectArtDesignerAttributePasteOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

type
  TVectArtAttributePasteKind = (vapkColor, vapkSize, vapkText,
    vapkFontFamily);
  TVectArtAttributePasteKinds = set of TVectArtAttributePasteKind;

function AvailableVectArtAttributePastes(Document: TVectArtDocument):
  TVectArtAttributePasteKinds;
function AvailableVectArtAttributePastesFromSource(Document: TVectArtDocument;
  Source: TVectArtLayer): TVectArtAttributePasteKinds;
function PasteVectArtAttribute(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Kind: TVectArtAttributePasteKind): Boolean;
function PasteVectArtAttributeFromSource(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Source: TVectArtLayer;
  Kind: TVectArtAttributePasteKind): Boolean;

implementation

uses
  System.Math, System.SysUtils, System.Types,
  VectArtDesignerBezierGeometry, VectArtDesignerClipboardOperations,
  VectArtDesignerEditCommands, VectArtDesignerFillCommand,
  VectArtDesignerGeometry, VectArtDesignerObjectAttributes;

function ImageBounds(const Points: TVectArtImagePoints): TRectF;
var
  I: Integer;
begin
  Result := TRectF.Create(Points[0], Points[0]);
  for I := 1 to High(Points) do
  begin
    Result.Left := Min(Result.Left, Points[I].X);
    Result.Top := Min(Result.Top, Points[I].Y);
    Result.Right := Max(Result.Right, Points[I].X);
    Result.Bottom := Max(Result.Bottom, Points[I].Y);
  end;
end;

function TryLayerBounds(Layer: TVectArtLayer; out Bounds: TRectF): Boolean;
var
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
begin
  Result := True;
  if Layer is TVectArtRectangleLayer then
    Bounds := TVectArtRectangleLayer(Layer).Bounds
  else if Layer is TVectArtTextLayer then
    Bounds := TVectArtTextLayer(Layer).Bounds
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
    if Length(Path.Points) = 0 then
      Exit(False);
    Bounds := PointsBounds(BuildPathDisplayPolyline(Path.Points,
      Path.Bezier, Path.Closed, 16));
  end
  else if Layer is TVectArtImageLayer then
    Bounds := ImageBounds(TVectArtImageLayer(Layer).Points)
  else
    Result := False;
end;

function SelectionIsEditable(Document: TVectArtDocument): Boolean;
var
  I: Integer;
begin
  Result := (Document <> nil) and (Document.SelectionCount > 0);
  if not Result then
    Exit;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and Document[I].Locked then
      Exit(False);
end;

function ColorCategory(Layer: TVectArtLayer): TVectArtAttributeCategory;
begin
  Result := CaptureVectArtObjectAttributes(Layer).Category;
end;

function AvailableVectArtAttributePastesFromSource(Document: TVectArtDocument;
  Source: TVectArtLayer): TVectArtAttributePasteKinds;
var
  Bounds: TRectF;
  I: Integer;
  SourceBounds: TRectF;
  SourceCategory: TVectArtAttributeCategory;
begin
  Result := [];
  if (Source = nil) or not SelectionIsEditable(Document) then
    Exit;
  SourceCategory := ColorCategory(Source);
  if TryLayerBounds(Source, SourceBounds) and
    ((SourceBounds.Width > Epsilon) or (SourceBounds.Height > Epsilon)) then
    for I := 1 to Document.LayerCount - 1 do
      if Document.IsLayerSelected(I) and TryLayerBounds(Document[I], Bounds) and
        ((Bounds.Width > Epsilon) or (Bounds.Height > Epsilon)) then
      begin
        Include(Result, vapkSize);
        Break;
      end;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) then
    begin
      if (SourceCategory <> vacNone) and
        (ColorCategory(Document[I]) = SourceCategory) then
        Include(Result, vapkColor);
      if (Source is TVectArtTextLayer) and
        (Document[I] is TVectArtTextLayer) then
      begin
        Include(Result, vapkText);
        Include(Result, vapkFontFamily);
      end;
    end;
end;

function AvailableVectArtAttributePastes(Document: TVectArtDocument):
  TVectArtAttributePasteKinds;
var
  SourceDocument: TVectArtDocument;
begin
  Result := [];
  if not TryReadVectArtObjectClipboard(SourceDocument) then
    Exit;
  try
    if SourceDocument.LayerCount = 2 then
      Result := AvailableVectArtAttributePastesFromSource(Document,
        SourceDocument[1]);
  finally
    SourceDocument.Free;
  end;
end;

procedure AddColorCommand(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; Source: TVectArtLayer);
var
  Attributes: TVectArtObjectAttributes;
  Target: TVectArtLayer;
begin
  Target := Document[Index];
  Attributes := CaptureVectArtObjectAttributes(Source);
  if ColorCategory(Target) <> Attributes.Category then
    Exit;
  if Attributes.Category in [vacLine, vacShape] then
    Command.Add(TVectArtStrokePaintCommand.Create(Document, Index,
      Attributes.StrokeColor, Attributes.StrokePaint));
  if Attributes.Category = vacShape then
  begin
    if Target is TVectArtRectangleLayer then
      Command.Add(TVectArtFillCommand.Create(Document, Index,
        Attributes.FillColor, Attributes.FillStyle,
        TVectArtRectangleLayer(Target).Filled))
    else
      Command.Add(TVectArtFillCommand.Create(Document, Index,
        Attributes.FillColor, Attributes.FillStyle,
        TVectArtPathLayer(Target).Filled));
  end
  else if Attributes.Category = vacText then
    Command.Add(TVectArtFillCommand.Create(Document, Index,
      Attributes.TextColor, Attributes.FillStyle));
end;

function ScalePoint(const Point, Center: TPointF; ScaleX,
  ScaleY: Single): TPointF;
begin
  Result.X := Center.X + (Point.X - Center.X) * ScaleX;
  Result.Y := Center.Y + (Point.Y - Center.Y) * ScaleY;
end;

procedure AddSizeCommand(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; Source: TVectArtLayer);
var
  Bounds, NewBounds, SourceBounds: TRectF;
  Center: TPointF;
  I: Integer;
  Image: TVectArtImageLayer;
  Line: TVectArtLineLayer;
  NewImagePoints: TVectArtImagePoints;
  NewPathPoints: TArray<TPointF>;
  Path: TVectArtPathLayer;
  ScaleX, ScaleY: Single;
begin
  if not TryLayerBounds(Source, SourceBounds) or
    not TryLayerBounds(Document[Index], Bounds) then
    Exit;
  Center := Bounds.CenterPoint;
  if Bounds.Width > Epsilon then
    ScaleX := SourceBounds.Width / Bounds.Width
  else
    ScaleX := 1;
  if Bounds.Height > Epsilon then
    ScaleY := SourceBounds.Height / Bounds.Height
  else
    ScaleY := 1;
  if Document[Index] is TVectArtRectangleLayer then
  begin
    NewBounds := TRectF.Create(Center.X - SourceBounds.Width / 2,
      Center.Y - SourceBounds.Height / 2, Center.X + SourceBounds.Width / 2,
      Center.Y + SourceBounds.Height / 2);
    Command.Add(TVectArtBoundsCommand.Create(Document, [Index],
      [TVectArtRectangleLayer(Document[Index]).Bounds], [NewBounds]));
  end
  else if Document[Index] is TVectArtTextLayer then
  begin
    NewBounds := TRectF.Create(Center.X - SourceBounds.Width / 2,
      Center.Y - SourceBounds.Height / 2, Center.X + SourceBounds.Width / 2,
      Center.Y + SourceBounds.Height / 2);
    Command.Add(TVectArtBoundsCommand.Create(Document, [Index],
      [TVectArtTextLayer(Document[Index]).Bounds], [NewBounds]));
  end
  else if Document[Index] is TVectArtLineLayer then
  begin
    Line := TVectArtLineLayer(Document[Index]);
    Command.Add(TVectArtLinePointsCommand.Create(Document, Index,
      Line.StartPoint, Line.EndPoint,
      ScalePoint(Line.StartPoint, Center, ScaleX, ScaleY),
      ScalePoint(Line.EndPoint, Center, ScaleX, ScaleY)));
  end
  else if Document[Index] is TVectArtPathLayer then
  begin
    Path := TVectArtPathLayer(Document[Index]);
    NewPathPoints := Copy(Path.Points);
    for I := 0 to High(NewPathPoints) do
      NewPathPoints[I] := ScalePoint(NewPathPoints[I], Center,
        ScaleX, ScaleY);
    Command.Add(TVectArtPathPointsCommand.Create(Document, Index,
      Path.Points, NewPathPoints));
  end
  else if Document[Index] is TVectArtImageLayer then
  begin
    Image := TVectArtImageLayer(Document[Index]);
    NewImagePoints := Image.Points;
    for I := 0 to High(NewImagePoints) do
      NewImagePoints[I] := ScalePoint(NewImagePoints[I], Center,
        ScaleX, ScaleY);
    Command.Add(TVectArtImagePointsCommand.Create(Document, Index,
      Image.Points, NewImagePoints));
  end;
end;

procedure AddTextCommand(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; Source: TVectArtTextLayer;
  Kind: TVectArtAttributePasteKind);
var
  AfterData, BeforeData: TVectArtTextData;
begin
  if not (Document[Index] is TVectArtTextLayer) then
    Exit;
  BeforeData := CaptureVectArtTextData(TVectArtTextLayer(Document[Index]));
  AfterData := BeforeData;
  if Kind = vapkText then
    AfterData.Text := Source.Text
  else
    AfterData.FontFamily := Source.FontFamily;
  Command.Add(TVectArtTextDataCommand.Create(Document, Index,
    BeforeData, AfterData));
end;

function PasteVectArtAttributeFromSource(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Source: TVectArtLayer;
  Kind: TVectArtAttributePasteKind): Boolean;
var
  Available: TVectArtAttributePasteKinds;
  Command: TVectArtCompoundCommand;
  I: Integer;
begin
  Result := False;
  Available := AvailableVectArtAttributePastesFromSource(Document, Source);
  if not (Kind in Available) then
    Exit;
  Command := TVectArtCompoundCommand.Create;
  try
    for I := 1 to Document.LayerCount - 1 do
      if Document.IsLayerSelected(I) then
        case Kind of
          vapkColor: AddColorCommand(Command, Document, I, Source);
          vapkSize: AddSizeCommand(Command, Document, I, Source);
          vapkText, vapkFontFamily:
            AddTextCommand(Command, Document, I,
              TVectArtTextLayer(Source), Kind);
        end;
    if Command.Count = 0 then
      Exit;
    Command.Execute;
    if EditHistory <> nil then
    begin
      EditHistory.AddApplied(Command);
      Command := nil;
    end;
    Result := True;
  finally
    Command.Free;
  end;
end;

function PasteVectArtAttribute(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Kind: TVectArtAttributePasteKind): Boolean;
var
  SourceDocument: TVectArtDocument;
begin
  Result := False;
  if not TryReadVectArtObjectClipboard(SourceDocument) then
    Exit;
  try
    if SourceDocument.LayerCount = 2 then
      Result := PasteVectArtAttributeFromSource(Document, EditHistory,
        SourceDocument[1], Kind);
  finally
    SourceDocument.Free;
  end;
end;

end.
