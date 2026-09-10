// WebArtの画像・文字・ベクター属性を編集モデルへ復元する。
// 保存時の互換性判定には依存せず、読込失敗時は呼出し側へ理由を返す。
unit VectArtDesignerMifReader;
interface
uses System.SysUtils, System.Types, VectArtDesignerDocument, VectArtDesignerMifContainer;
function TryReadWebArtVectorPoints(const Png: TBytes;
  out Points: TArray<TPointF>; out Closed: Boolean): Boolean;

function TryReadPngSize(const Png: TBytes; out Width,
  Height: Integer): Boolean;

function TryImportWebArtDocument(Container: TVectArtMifContainer;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
implementation
uses VectArtDesignerMifShadow, Winapi.Windows, VectArtDesignerMifPlacement, System.Classes, System.Generics.Collections, System.Math,
  Vcl.Graphics, Vcl.Imaging.pngimage,
  VectArtDesignerMifPngMetadata, VectArtDesignerMifPaint,
  VectArtDesignerGeometry, VectArtDesignerRoundedRectangleGeometry;
function MifToLineMarker(Value: Integer): TVectArtLineMarker;
begin
  case Value of
    1: Result := vlmOpenArrow;
    2: Result := vlmArrow;
    3: Result := vlmWideArrow;
    4: Result := vlmCircle;
    5: Result := vlmDiamond;
    6: Result := vlmConcaveArrow;
    7: Result := vlmSmallArrow;
    8: Result := vlmSlash;
    9: Result := vlmStar;
  else
    Result := vlmNone;
  end;
end;

function TryReadWebArtVectorPoints(const Png: TBytes;
  out Points: TArray<TPointF>; out Closed: Boolean): Boolean;
const
  RECORD_SIZE = 60;
var
  Command: UInt32;
  Count: UInt32;
  I: Integer;
  Offset: Integer;
  PixelColor: TColor;
  PointList: TList<TPointF>;
  PngImage: TPngImage;
  Raw: TBytes;
  Stream: TBytesStream;
  X: Double;
  Y: Double;
begin
  Result := False;
  Points := nil;
  Closed := False;
  PngImage := TPngImage.Create;
  Stream := TBytesStream.Create(Png);
  try
    PngImage.LoadFromStream(Stream);
    if (PngImage.Height <> 1) or (PngImage.Width < 1) or
      (PngImage.Width > 1000000) then
      Exit;
    SetLength(Raw, PngImage.Width * 4);
    for I := 0 to PngImage.Width - 1 do
    begin
      PixelColor := ColorToRGB(PngImage.Pixels[I, 0]);
      Raw[I * 4] := GetBValue(PixelColor);
      Raw[I * 4 + 1] := GetGValue(PixelColor);
      Raw[I * 4 + 2] := GetRValue(PixelColor);
      if PngImage.AlphaScanline[0] <> nil then
        Raw[I * 4 + 3] := PngImage.AlphaScanline[0]^[I]
      else
        Raw[I * 4 + 3] := 255;
    end;
  finally
    Stream.Free;
    PngImage.Free;
  end;
  if Length(Raw) < 4 then
    Exit;
  Move(Raw[0], Count, SizeOf(Count));
  if (Count = 0) or (Count > 1000000) or
    (UInt64(4) + UInt64(Count) * RECORD_SIZE > UInt64(Length(Raw))) then
    Exit;
  PointList := TList<TPointF>.Create;
  try
    for I := 0 to Integer(Count) - 1 do
    begin
      Offset := 4 + I * RECORD_SIZE;
      Move(Raw[Offset], Command, SizeOf(Command));
      case Command of
        1, 2:
          begin
            Move(Raw[Offset + 4], X, SizeOf(X));
            Move(Raw[Offset + 12], Y, SizeOf(Y));
            if not IsNan(X) and not IsInfinite(X) and
              not IsNan(Y) and not IsInfinite(Y) then
              PointList.Add(TPointF.Create(X, Y));
          end;
        3:
          Closed := True;
      else
        Exit;
      end;
    end;
    Result := PointList.Count >= 2;
    if Result then
      Points := PointList.ToArray;
  finally
    PointList.Free;
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
  BackgroundAlpha: Int32;
  Bottom: Int32;
  CrossProduct: Int64;
  CanvasHeight: Integer;
  CanvasWidth: Integer;
  ClosedValue: Int32;
  Data: TVectArtRectangleData;
  Discarded: TVectArtRectangleData;
  DiscardedLine: TVectArtLineData;
  DiscardedPath: TVectArtPathData;
  DiscardedImage: TVectArtImageData;
  DiscardedText: TVectArtTextData;
  ElementType: Int32;
  EndMarker: Int32;
  EndMarkerSize: Int32;
  FillColor: Int32;
  FillEnabled: Int32;
  FontFace: string;
  FontHeight: Int32;
  FontItalic: Int32;
  FontStrikeOut: Int32;
  FontUnderline: Int32;
  FontWeight: Int32;
  Hidden: Int32;
  I: Integer;
  ImageData: TVectArtImageData;
  Images: TList<TVectArtImageData>;
  Left: Int32;
  LineData: TVectArtLineData;
  Lines: TList<TVectArtLineData>;
  LayerOrder: TList<Integer>;
  MatrixA: Double;
  MatrixB: Double;
  MatrixC: Double;
  MatrixD: Double;
  MatrixE: Double;
  MatrixF: Double;
  OriginalBottom: Int32;
  OriginalLeft: Int32;
  OriginalRight: Int32;
  OriginalTop: Int32;
  Position2X: Int32;
  Position2Y: Int32;
  Position4X: Int32;
  Position4Y: Int32;
  ObjectSubtype: string;
  ObjectType: string;
  PathClosed: Boolean;
  PathData: TVectArtPathData;
  Paths: TList<TVectArtPathData>;
  Rectangles: TList<TVectArtRectangleData>;
  Right: Int32;
  StrokeColor: Int32;
  StrokeCap: Int32;
  StrokeJoin: Int32;
  StartMarker: Int32;
  StartMarkerSize: Int32;
  StrokeEnabled: Int32;
  StrokeStyle: Int32;
  StrokeWidth: Double;
  WritingMode: Int32;
  Top: Int32;
  TextData: TVectArtTextData;
  Texts: TList<TVectArtTextData>;
  TextValue: string;
  LogoFormat: Integer;
  VectorPoints: TArray<TPointF>;
  VectorQuality: Int32;
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
  BackgroundAlpha := 255;
  if (Container[2].Tag = 'IPNG') then
  begin
    TryReadPngInteger(Container[2].Data, 'texture color1', BackgroundColor);
    TryReadPngInteger(Container[2].Data, 'image alpha', BackgroundAlpha);
  end;
  Rectangles := TList<TVectArtRectangleData>.Create;
  Lines := TList<TVectArtLineData>.Create;
  Paths := TList<TVectArtPathData>.Create;
  Images := TList<TVectArtImageData>.Create;
  Texts := TList<TVectArtTextData>.Create;
  LayerOrder := TList<Integer>.Create;
  try
    for I := 2 to Container.ChunkCount - 2 do
    begin
      // ファイルにない所属・装飾が前のレコードやスタック値から混入しないようにする。
      Data := Default(TVectArtRectangleData);
      PathData := Default(TVectArtPathData);
      LineData := Default(TVectArtLineData);
      ImageData := Default(TVectArtImageData);
      if (Container[I].Tag <> 'IPNG') or
        not TryReadPngString(Container[I].Data, 'tEXt', 'object type',
          ObjectType) then
        Continue;
      ObjectSubtype := '';
      TryReadPngString(Container[I].Data, 'waDA', 'object subtype',
        ObjectSubtype);
      if not TryReadPngInteger(Container[I].Data, 'image position1 x', Left) or
        not TryReadPngInteger(Container[I].Data, 'image position1 y', Top) or
        not TryReadPngInteger(Container[I].Data, 'image position2 x', Position2X) or
        not TryReadPngInteger(Container[I].Data, 'image position2 y', Position2Y) or
        not TryReadPngInteger(Container[I].Data, 'image position3 x', Right) or
        not TryReadPngInteger(Container[I].Data, 'image position3 y', Bottom) or
        not TryReadPngInteger(Container[I].Data, 'image position4 x', Position4X) or
        not TryReadPngInteger(Container[I].Data, 'image position4 y', Position4Y)
      then
        Continue;
      if SameText(ObjectType, 'logo') or
        (SameText(ObjectType, 'image') and
          not SameText(ObjectSubtype, 'vector')) then
      begin
        Alpha := 255;
        Hidden := 0;
        TryReadPngInteger(Container[I].Data, 'image alpha', Alpha);
        TryReadPngInteger(Container[I].Data, 'image hidden', Hidden);
        if SameText(ObjectType, 'logo') and
          TryReadPngUtf16LeString(Container[I].Data, 'logo text unicode',
            TextValue) then
        begin
          TextData := Default(TVectArtTextData);
          TextData.Name := Format('Text %d', [Texts.Count + 1]);
          if (Position2Y = Top) and (Position4X = Left) then
            TextData.Bounds := RectF(Min(Left, Right), Min(Top, Bottom),
              Max(Left, Right) + 1, Max(Top, Bottom) + 1)
          else
            TextData.Bounds := RectF(
              (Left + Position2X + Right + Position4X) * 0.25 -
                (Hypot(Position2X - Left, Position2Y - Top) + 1) * 0.5,
              (Top + Position2Y + Bottom + Position4Y) * 0.25 -
                (Hypot(Position4X - Left, Position4Y - Top) + 1) * 0.5,
              (Left + Position2X + Right + Position4X) * 0.25 +
                (Hypot(Position2X - Left, Position2Y - Top) + 1) * 0.5,
              (Top + Position2Y + Bottom + Position4Y) * 0.25 +
                (Hypot(Position4X - Left, Position4Y - Top) + 1) * 0.5);
          FontFace := 'MS UI Gothic';
          TryReadPngString(Container[I].Data, 'waDA', 'font facename',
            FontFace);
          FontHeight := -16;
          FontItalic := 0;
          FontStrikeOut := 0;
          FontUnderline := 0;
          FontWeight := 400;
          TryReadPngInteger(Container[I].Data, 'font height', FontHeight);
          TryReadPngInteger(Container[I].Data, 'font italic', FontItalic);
          TryReadPngInteger(Container[I].Data, 'font strikeout',
            FontStrikeOut);
          TryReadPngInteger(Container[I].Data, 'font underline',
            FontUnderline);
          TryReadPngInteger(Container[I].Data, 'font weight', FontWeight);
          TextData.FontFamily := FontFace;
          TextData.FontSize := Max(Abs(FontHeight), 1);
          TextData.FontStyle := [];
          if FontWeight >= 600 then
            Include(TextData.FontStyle, fsBold);
          if FontItalic <> 0 then
            Include(TextData.FontStyle, fsItalic);
          if FontUnderline <> 0 then
            Include(TextData.FontStyle, fsUnderline);
          if FontStrikeOut <> 0 then
            Include(TextData.FontStyle, fsStrikeOut);
          LogoFormat := 0;
          TryReadPngInteger(Container[I].Data,'logo format',LogoFormat);
          // 元アプリのformat=0は終端CRLFを付ける。空の2行目として拡縮しない。
          if (LogoFormat = 0) and TextValue.EndsWith(#13#10) then
            Delete(TextValue,Length(TextValue)-1,2);
          TextData.Text := TextValue;
          TextData.TextColor := clBlack;
          WritingMode := 0;
          TryReadPngInteger(Container[I].Data, 'logo writing mode',
            WritingMode);
          TextData.Vertical := WritingMode <> 0;
          FillColor := ColorToRGB(clBlack);
          if (I + 1 < Container.ChunkCount) and
            (Container[I + 1].Tag = 'IPNG') then
            TryReadPngInteger(Container[I + 1].Data, 'texture color1',
              FillColor);
          if (I + 1 < Container.ChunkCount) and
            (Container[I + 1].Tag = 'IPNG') then
            begin
            TextData.TextColor := TColor(FillColor);
            TextData.FillStyle := ReadFillTexture(Container[I+1].Data);
            end;
          TextData.Opacity := EnsureRange(Alpha / 255.0, 0.0, 1.0);
          TextData.RotationDegrees := RadToDeg(ArcTan2(Position2Y - Top,
            Position2X - Left));
          CrossProduct := Int64(Position2X - Left) * (Position4Y - Top) -
            Int64(Position2Y - Top) * (Position4X - Left);
          TextData.FlipHorizontal := False;
          TextData.FlipVertical := CrossProduct < 0;
          TextData.Visible := Hidden = 0;
          TextData.Locked := False;
          Texts.Add(TextData);
          LayerOrder.Add(-(3000000 + Texts.Count));
          Continue;
        end;
        if SameText(ObjectType, 'logo') then
        begin
          ImageData.Name := Format('Logo %d', [Images.Count + 1]);
          ImageData.SourceKind := visLogo;
        end
        else
        begin
          ImageData.Name := Format('Image %d', [Images.Count + 1]);
          ImageData.SourceKind := visImage;
        end;
        ImageData.PngData := Copy(Container[I].Data);
        ImageData.SourceFileName := '';
        ImageData.Points[0] := TPointF.Create(Left, Top);
        ImageData.Points[1] := TPointF.Create(Position2X, Position2Y);
        ImageData.Points[2] := TPointF.Create(Right, Bottom);
        ImageData.Points[3] := TPointF.Create(Position4X, Position4Y);
        ImageData.Opacity := EnsureRange(Alpha / 255.0, 0.0, 1.0);
        ImageData.Visible := Hidden = 0;
        ImageData.Locked := False;
        Images.Add(ImageData);
        LayerOrder.Add(-(2000000 + Images.Count));
        Continue;
      end;
      if not SameText(ObjectType, 'image') or
        not SameText(ObjectSubtype, 'vector') or
        not TryReadPngInteger(Container[I].Data, 'vector element type',
          ElementType) or not (ElementType in [2, 4, 6]) then
        Continue;
      FillColor := ColorToRGB(clWhite);
      if (I + 1 < Container.ChunkCount) and
        (Container[I + 1].Tag = 'IPNG') then
        TryReadPngInteger(Container[I + 1].Data, 'texture color1', FillColor);
      Alpha := 255;
      Hidden := 0;
      TryReadPngInteger(Container[I].Data, 'image alpha', Alpha);
      TryReadPngInteger(Container[I].Data, 'image hidden', Hidden);
      StrokeEnabled := 0;
      StartMarker := 0;
      StartMarkerSize := 4;
      FillEnabled := 0;
      EndMarker := 0;
      EndMarkerSize := 4;
      StrokeStyle := 0;
      StrokeCap := 0;
      StrokeJoin := 0;
      StrokeWidth := 1.0;
      VectorQuality := 1;
      TryReadPngInteger(Container[I].Data,
        'vector enable stroke texture', StrokeEnabled);
      TryReadPngInteger(Container[I].Data,
        'vector enable fill texture', FillEnabled);
      TryReadPngInteger(Container[I].Data, 'vector stroke style',
        StrokeStyle);
      TryReadPngInteger(Container[I].Data, 'vector stroke cap', StrokeCap);
      TryReadPngInteger(Container[I].Data, 'vector end stroke marker',
        EndMarker);
      TryReadPngInteger(Container[I].Data, 'vector start stroke marker',
        StartMarker);
      TryReadPngInteger(Container[I].Data, 'vector start marker size',
        StartMarkerSize);
      TryReadPngInteger(Container[I].Data, 'vector end marker size',
        EndMarkerSize);
      TryReadPngInteger(Container[I].Data, 'vector quality', VectorQuality);
      TryReadPngInteger(Container[I].Data, 'vector stroke join', StrokeJoin);
      TryReadPngDouble(Container[I].Data, 'vector stroke width',
        StrokeWidth);
      StrokeColor := ColorToRGB(clBlack);
      if (StrokeEnabled <> 0) and (I + 3 < Container.ChunkCount) and
        (Container[I + 3].Tag = 'IPNG') then
        TryReadPngInteger(Container[I + 3].Data, 'texture color1',
          StrokeColor);
      if ElementType = 6 then
      begin
        VectorPoints := nil;
        PathClosed := False;
        if (I + 2 < Container.ChunkCount) and
          (Container[I + 2].Tag = 'IPNG') and
          TryReadWebArtVectorPoints(Container[I + 2].Data, VectorPoints,
            PathClosed) and (Length(VectorPoints) > 2) then
        begin
          ClosedValue := 0;
          TryReadPngInteger(Container[I].Data, 'vector closed', ClosedValue);
          PathClosed := PathClosed or (ClosedValue <> 0);
          MatrixA := 1.0;
          MatrixB := 0.0;
          MatrixC := 0.0;
          MatrixD := 1.0;
          MatrixE := 0.0;
          MatrixF := 0.0;
          TryReadPngDouble(Container[I].Data, 'vector matrix a', MatrixA);
          TryReadPngDouble(Container[I].Data, 'vector matrix b', MatrixB);
          TryReadPngDouble(Container[I].Data, 'vector matrix c', MatrixC);
          TryReadPngDouble(Container[I].Data, 'vector matrix d', MatrixD);
          TryReadPngDouble(Container[I].Data, 'vector matrix e', MatrixE);
          TryReadPngDouble(Container[I].Data, 'vector matrix f', MatrixF);
          for Position2X := 0 to High(VectorPoints) do
            VectorPoints[Position2X] := TPointF.Create(
              MatrixA * VectorPoints[Position2X].X +
                MatrixC * VectorPoints[Position2X].Y + MatrixE,
              MatrixB * VectorPoints[Position2X].X +
                MatrixD * VectorPoints[Position2X].Y + MatrixF);
          PathData.Name := Format('Path %d', [Paths.Count + 1]);
          PathData.Bezier := False;
          PathData.Points := Copy(VectorPoints);
          // 独自MIF属性は加えず、作成時の固有点列が維持された場合だけ外接枠編集へ戻す。
          PathData.BoundsEditing :=
            IsRoundedRectanglePathPoints(PathData.Points);
          PathData.Closed := PathClosed;
          PathData.Filled := PathClosed and (FillEnabled <> 0);
          PathData.FillColor := TColor(FillColor);
          if I+1 < Container.ChunkCount then PathData.FillStyle := ReadFillTexture(Container[I+1].Data);
          PathData.Opacity := EnsureRange(Alpha / 255.0, 0.0, 1.0);
          PathData.AntiAlias := VectorQuality <> 0;
          PathData.EndMarker := MifToLineMarker(EndMarker);
          PathData.EndMarkerSize := Max(EndMarkerSize, 1);
          if InRange(StrokeCap, Ord(Low(TVectArtLineCap)),
            Ord(High(TVectArtLineCap))) then
            PathData.LineCap := TVectArtLineCap(StrokeCap)
          else
            PathData.LineCap := vlcButt;
          if InRange(StrokeJoin, Ord(Low(TVectArtLineJoin)),
            Ord(High(TVectArtLineJoin))) then
            PathData.LineJoin := TVectArtLineJoin(StrokeJoin)
          else
            PathData.LineJoin := vljMiter;
          PathData.StartMarker := MifToLineMarker(StartMarker);
          PathData.StartMarkerSize := Max(StartMarkerSize, 1);
          PathData.StrokeColor := TColor(StrokeColor);
      if I+3 < Container.ChunkCount then Data.StrokePaint := ReadFillTexture(Container[I+3].Data);
      if I+3 < Container.ChunkCount then PathData.StrokePaint := ReadFillTexture(Container[I+3].Data);
          if InRange(StrokeStyle, Ord(Low(TVectArtStrokeStyle)),
            Ord(High(TVectArtStrokeStyle))) then
            PathData.StrokeStyle := TVectArtStrokeStyle(StrokeStyle)
          else
            PathData.StrokeStyle := vssSolid;
          if StrokeEnabled <> 0 then
            PathData.StrokeWidth := MifPathStrokeWidth(StrokeWidth)
          else
            PathData.StrokeWidth := 0.0;
          PathData.Visible := Hidden = 0;
          PathData.Locked := False;
          PathData.Shadow := ReadMifShadow(Container[I].Data);
          Paths.Add(PathData);
          LayerOrder.Add(-(1000000 + Paths.Count));
          Continue;
        end;
        if not TryReadPngInteger(Container[I].Data,
          'vector original position1 x', OriginalLeft) or
          not TryReadPngInteger(Container[I].Data,
          'vector original position1 y', OriginalTop) or
          not TryReadPngInteger(Container[I].Data,
          'vector original position3 x', OriginalRight) or
          not TryReadPngInteger(Container[I].Data,
          'vector original position3 y', OriginalBottom) then
          Continue;
        MatrixA := 1.0;
        MatrixB := 0.0;
        MatrixC := 0.0;
        MatrixD := 1.0;
        MatrixE := 0.0;
        MatrixF := 0.0;
        TryReadPngDouble(Container[I].Data, 'vector matrix a', MatrixA);
        TryReadPngDouble(Container[I].Data, 'vector matrix b', MatrixB);
        TryReadPngDouble(Container[I].Data, 'vector matrix c', MatrixC);
        TryReadPngDouble(Container[I].Data, 'vector matrix d', MatrixD);
        TryReadPngDouble(Container[I].Data, 'vector matrix e', MatrixE);
        TryReadPngDouble(Container[I].Data, 'vector matrix f', MatrixF);
        LineData.Name := Format('Line %d', [Lines.Count + 1]);
        LineData.StartPoint := TPointF.Create(
          MatrixA * OriginalLeft + MatrixC *
            ((OriginalTop + OriginalBottom) * 0.5) + MatrixE,
          MatrixB * OriginalLeft + MatrixD *
            ((OriginalTop + OriginalBottom) * 0.5) + MatrixF);
        LineData.EndPoint := TPointF.Create(
          MatrixA * OriginalRight + MatrixC *
            ((OriginalTop + OriginalBottom) * 0.5) + MatrixE,
          MatrixB * OriginalRight + MatrixD *
            ((OriginalTop + OriginalBottom) * 0.5) + MatrixF);
        LineData.Opacity := EnsureRange(Alpha / 255.0, 0.0, 1.0);
        LineData.AntiAlias := VectorQuality <> 0;
        LineData.EndMarker := MifToLineMarker(EndMarker);
        LineData.EndMarkerSize := Max(EndMarkerSize, 1);
        LineData.StartMarker := MifToLineMarker(StartMarker);
        LineData.StartMarkerSize := Max(StartMarkerSize, 1);
        if InRange(StrokeCap, Ord(Low(TVectArtLineCap)),
          Ord(High(TVectArtLineCap))) then
          LineData.LineCap := TVectArtLineCap(StrokeCap)
        else
          LineData.LineCap := vlcButt;
        if InRange(StrokeJoin, Ord(Low(TVectArtLineJoin)),
          Ord(High(TVectArtLineJoin))) then
          LineData.LineJoin := TVectArtLineJoin(StrokeJoin)
        else
          LineData.LineJoin := vljMiter;
        LineData.StrokeColor := TColor(StrokeColor);
      if I+3 < Container.ChunkCount then Data.StrokePaint := ReadFillTexture(Container[I+3].Data);
      if I+3 < Container.ChunkCount then LineData.StrokePaint := ReadFillTexture(Container[I+3].Data);
        if InRange(StrokeStyle, Ord(Low(TVectArtStrokeStyle)),
          Ord(High(TVectArtStrokeStyle))) then
          LineData.StrokeStyle := TVectArtStrokeStyle(StrokeStyle)
        else
          LineData.StrokeStyle := vssSolid;
        LineData.StrokeWidth := MifLineStrokeWidth(StrokeWidth);
        LineData.Visible := Hidden = 0;
        LineData.Locked := False;
        Lines.Add(LineData);
        LayerOrder.Add(-Lines.Count);
        Continue;
      end;
      if ElementType = 2 then
      begin
        Data.Name := Format('Ellipse %d', [Rectangles.Count + 1]);
        Data.Shape := vpsEllipse;
      end
      else
      begin
        Data.Name := Format('Rectangle %d', [Rectangles.Count + 1]);
        Data.Shape := vpsRectangle;
      end;
      if (Position2Y = Top) and (Position4X = Left) then
        Data.Bounds := TRectF.Create(Min(Left, Right), Min(Top, Bottom),
          Max(Left, Right) + 1, Max(Top, Bottom) + 1)
      else
        Data.Bounds := TRectF.Create(
          (Left + Position2X + Right + Position4X) * 0.25 -
            (Hypot(Position2X - Left, Position2Y - Top) + 1) * 0.5,
          (Top + Position2Y + Bottom + Position4Y) * 0.25 -
            (Hypot(Position4X - Left, Position4Y - Top) + 1) * 0.5,
          (Left + Position2X + Right + Position4X) * 0.25 +
            (Hypot(Position2X - Left, Position2Y - Top) + 1) * 0.5,
          (Top + Position2Y + Bottom + Position4Y) * 0.25 +
            (Hypot(Position4X - Left, Position4Y - Top) + 1) * 0.5);
      Data.FillColor := TColor(FillColor);
      if I+1 < Container.ChunkCount then Data.FillStyle := ReadFillTexture(Container[I+1].Data);
      Data.Filled := FillEnabled <> 0;
      Data.Opacity := EnsureRange(Alpha / 255.0, 0.0, 1.0);
      Data.RotationDegrees := RadToDeg(ArcTan2(Position2Y - Top,
        Position2X - Left));
      Data.StrokeColor := TColor(StrokeColor);
      if I+3 < Container.ChunkCount then Data.StrokePaint := ReadFillTexture(Container[I+3].Data);
      if InRange(StrokeStyle, Ord(Low(TVectArtStrokeStyle)),
        Ord(High(TVectArtStrokeStyle))) then
        Data.StrokeStyle := TVectArtStrokeStyle(StrokeStyle)
      else
        Data.StrokeStyle := vssSolid;
      if StrokeEnabled <> 0 then
        Data.StrokeWidth := Max(StrokeWidth, 0.0)
      else
        Data.StrokeWidth := 0.0;
      Data.Visible := Hidden = 0;
      Data.Locked := False;
      Data.Shadow := ReadMifShadow(Container[I].Data);
      ReadShadowRectangleGeometry(Container[I].Data,Data);
      Rectangles.Add(Data);
      LayerOrder.Add(Rectangles.Count);
    end;

    while Document.LayerCount > 1 do
      if Document[Document.LayerCount - 1] is TVectArtRectangleLayer then
        Document.RemoveRectangle(Document.LayerCount - 1, Discarded)
      else if Document[Document.LayerCount - 1] is TVectArtLineLayer then
        Document.RemoveLine(Document.LayerCount - 1, DiscardedLine)
      else if Document[Document.LayerCount - 1] is TVectArtPathLayer then
        Document.RemovePath(Document.LayerCount - 1, DiscardedPath)
      else if Document[Document.LayerCount - 1] is TVectArtImageLayer then
        Document.RemoveImage(Document.LayerCount - 1, DiscardedImage)
      else if Document[Document.LayerCount - 1] is TVectArtTextLayer then
        Document.RemoveText(Document.LayerCount - 1, DiscardedText)
      else
        raise EInvalidOp.Create('Document contains an unsupported layer');
    Document.CanvasLayer.Width := CanvasWidth;
    Document.CanvasLayer.Height := CanvasHeight;
    Document.CanvasLayer.BackgroundColor := TColor(BackgroundColor);
    Document.CanvasLayer.Transparent := BackgroundAlpha = 0;
    for I in LayerOrder do
      if I > 0 then
        Document.InsertRectangle(Document.LayerCount, Rectangles[I - 1])
      else if I <= -3000000 then
        Document.InsertText(Document.LayerCount,
          Texts[-I - 3000001])
      else if I <= -2000000 then
        Document.InsertImage(Document.LayerCount,
          Images[-I - 2000001])
      else if I <= -1000000 then
        Document.InsertPath(Document.LayerCount,
          Paths[-I - 1000001])
      else
        Document.InsertLine(Document.LayerCount, Lines[-I - 1]);
    Document.SelectedIndex := -1;
    Document.Changed;
    Result := True;
  finally
    LayerOrder.Free;
    Texts.Free;
    Lines.Free;
    Paths.Free;
    Images.Free;
    Rectangles.Free;
  end;
end;

end.
