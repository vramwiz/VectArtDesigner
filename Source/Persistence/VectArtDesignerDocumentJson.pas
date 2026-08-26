// 配置DocumentをAviUtl2の文字列項目へ保存できるJSONへ相互変換する。
unit VectArtDesignerDocumentJson;

interface

uses
  VectArtDesignerDocument;

function SerializeVectArtDocument(Document: TVectArtDocument): string;
function TryDeserializeVectArtDocument(const Text: string;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;

implementation

uses
  System.Generics.Collections, System.JSON, System.Math, System.SysUtils, System.Types,
  Vcl.Graphics;

const
  DOCUMENT_FORMAT_VERSION = 1;

type
  TRequiredJSONValueClass = class of TJSONValue;

function RequireValue(Parent: TJSONObject; const Name: string;
  ValueClass: TRequiredJSONValueClass): TJSONValue;
begin
  Result := Parent.GetValue(Name);
  if (Result = nil) or not Result.InheritsFrom(ValueClass) then
    raise EConvertError.CreateFmt('JSON field "%s" has an invalid type',
      [Name]);
end;

function ReadBoolean(Parent: TJSONObject; const Name: string): Boolean;
begin
  Result := TJSONBool(RequireValue(Parent, Name, TJSONBool)).AsBoolean;
end;

function ReadInteger(Parent: TJSONObject; const Name: string): Integer;
begin
  if not TryStrToInt(RequireValue(Parent, Name, TJSONNumber).Value,
    Result) then
    raise EConvertError.CreateFmt('JSON field "%s" is not an integer',
      [Name]);
end;

function ReadSingle(Parent: TJSONObject; const Name: string): Single;
begin
  Result := TJSONNumber(RequireValue(Parent, Name,
    TJSONNumber)).AsDouble;
end;

function ReadString(Parent: TJSONObject; const Name: string): string;
begin
  Result := TJSONString(RequireValue(Parent, Name, TJSONString)).Value;
end;

function SerializeVectArtDocument(Document: TVectArtDocument): string;
var
  Canvas: TVectArtCanvasLayer;
  CanvasJson: TJSONObject;
  I: Integer;
  Layer: TVectArtLayer;
  Line: TVectArtLineLayer;
  LineJson: TJSONObject;
  LayersJson: TJSONArray;
  Rectangle: TVectArtRectangleLayer;
  RectangleJson: TJSONObject;
  Root: TJSONObject;
begin
  if Document = nil then
    raise EArgumentNilException.Create('Document');
  Canvas := Document.CanvasLayer;
  if Canvas = nil then
    raise EInvalidOp.Create('Document canvas is missing');

  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(DOCUMENT_FORMAT_VERSION));
    CanvasJson := TJSONObject.Create;
    CanvasJson.AddPair('width', TJSONNumber.Create(Canvas.Width));
    CanvasJson.AddPair('height', TJSONNumber.Create(Canvas.Height));
    CanvasJson.AddPair('backgroundColor',
      TJSONNumber.Create(Integer(Canvas.BackgroundColor)));
    CanvasJson.AddPair('transparent', TJSONBool.Create(Canvas.Transparent));
    Root.AddPair('canvas', CanvasJson);

    LayersJson := TJSONArray.Create;
    Root.AddPair('layers', LayersJson);
    for I := 1 to Document.LayerCount - 1 do
    begin
      Layer := Document.Layers[I];
      if Layer is TVectArtLineLayer then
      begin
        Line := TVectArtLineLayer(Layer);
        LineJson := TJSONObject.Create;
        LineJson.AddPair('type', 'line');
        LineJson.AddPair('name', Line.Name);
        LineJson.AddPair('startX', TJSONNumber.Create(Line.StartPoint.X));
        LineJson.AddPair('startY', TJSONNumber.Create(Line.StartPoint.Y));
        LineJson.AddPair('endX', TJSONNumber.Create(Line.EndPoint.X));
        LineJson.AddPair('endY', TJSONNumber.Create(Line.EndPoint.Y));
        LineJson.AddPair('opacity', TJSONNumber.Create(Line.Opacity));
        LineJson.AddPair('strokeColor',
          TJSONNumber.Create(Integer(Line.StrokeColor)));
        LineJson.AddPair('strokeWidth',
          TJSONNumber.Create(Line.StrokeWidth));
        LineJson.AddPair('strokeStyle',
          TJSONNumber.Create(Ord(Line.StrokeStyle)));
        LineJson.AddPair('visible', TJSONBool.Create(Line.Visible));
        LineJson.AddPair('locked', TJSONBool.Create(Line.Locked));
        LayersJson.AddElement(LineJson);
        Continue;
      end;
      if not (Layer is TVectArtRectangleLayer) then
        Continue;
      Rectangle := TVectArtRectangleLayer(Layer);
      RectangleJson := TJSONObject.Create;
      RectangleJson.AddPair('type', 'rectangle');
      RectangleJson.AddPair('name', Rectangle.Name);
      RectangleJson.AddPair('left',
        TJSONNumber.Create(Rectangle.Bounds.Left));
      RectangleJson.AddPair('top',
        TJSONNumber.Create(Rectangle.Bounds.Top));
      RectangleJson.AddPair('right',
        TJSONNumber.Create(Rectangle.Bounds.Right));
      RectangleJson.AddPair('bottom',
        TJSONNumber.Create(Rectangle.Bounds.Bottom));
      RectangleJson.AddPair('fillColor',
        TJSONNumber.Create(Integer(Rectangle.FillColor)));
      RectangleJson.AddPair('opacity', TJSONNumber.Create(Rectangle.Opacity));
      RectangleJson.AddPair('rotation',
        TJSONNumber.Create(Rectangle.RotationDegrees));
      RectangleJson.AddPair('strokeColor',
        TJSONNumber.Create(Integer(Rectangle.StrokeColor)));
      RectangleJson.AddPair('strokeWidth',
        TJSONNumber.Create(Rectangle.StrokeWidth));
      RectangleJson.AddPair('strokeStyle',
        TJSONNumber.Create(Ord(Rectangle.StrokeStyle)));
      RectangleJson.AddPair('visible', TJSONBool.Create(Rectangle.Visible));
      RectangleJson.AddPair('locked', TJSONBool.Create(Rectangle.Locked));
      LayersJson.AddElement(RectangleJson);
    end;
    Root.AddPair('selectedIndex',
      TJSONNumber.Create(Document.SelectedIndex));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TryDeserializeVectArtDocument(const Text: string;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
var
  Canvas: TVectArtCanvasLayer;
  CanvasColor: Integer;
  CanvasHeight: Integer;
  CanvasJson: TJSONObject;
  CanvasTransparent: Boolean;
  CanvasWidth: Integer;
  Data: TVectArtRectangleData;
  Discarded: TVectArtRectangleData;
  DiscardedLine: TVectArtLineData;
  I: Integer;
  Json: TJSONValue;
  LayerJson: TJSONObject;
  LayerTypes: TArray<string>;
  LayersJson: TJSONArray;
  RectangleData: TArray<TVectArtRectangleData>;
  LineData: TArray<TVectArtLineData>;
  LineValue: TVectArtLineData;
  Root: TJSONObject;
  SelectedIndex: Integer;
  StrokeStyleValue: Integer;
  Version: Integer;
begin
  Result := False;
  ErrorMessage := '';
  if Document = nil then
  begin
    ErrorMessage := 'Document is not assigned';
    Exit;
  end;
  Json := nil;
  try
    try
      Json := TJSONObject.ParseJSONValue(Text);
      if not (Json is TJSONObject) then
        raise EConvertError.Create('Serialized layout is not a JSON object');
      Root := TJSONObject(Json);
      Version := ReadInteger(Root, 'version');
      if Version <> DOCUMENT_FORMAT_VERSION then
        raise EConvertError.CreateFmt('Unsupported layout version: %d',
          [Version]);

      CanvasJson := TJSONObject(RequireValue(Root, 'canvas', TJSONObject));
      CanvasWidth := ReadInteger(CanvasJson, 'width');
      CanvasHeight := ReadInteger(CanvasJson, 'height');
      CanvasColor := ReadInteger(CanvasJson, 'backgroundColor');
      CanvasTransparent := ReadBoolean(CanvasJson, 'transparent');
      if (CanvasWidth <= 0) or (CanvasHeight <= 0) then
        raise EConvertError.Create('Canvas size must be positive');

      LayersJson := TJSONArray(RequireValue(Root, 'layers', TJSONArray));
      SetLength(RectangleData, LayersJson.Count);
      SetLength(LineData, LayersJson.Count);
      SetLength(LayerTypes, LayersJson.Count);
      for I := 0 to LayersJson.Count - 1 do
      begin
        if not (LayersJson.Items[I] is TJSONObject) then
          raise EConvertError.CreateFmt('Layer %d is not a JSON object', [I]);
        LayerJson := TJSONObject(LayersJson.Items[I]);
        LayerTypes[I] := ReadString(LayerJson, 'type');
        if LayerTypes[I] = 'line' then
        begin
          LineValue.Name := ReadString(LayerJson, 'name');
          LineValue.StartPoint := TPointF.Create(
            ReadSingle(LayerJson, 'startX'), ReadSingle(LayerJson, 'startY'));
          LineValue.EndPoint := TPointF.Create(ReadSingle(LayerJson, 'endX'),
            ReadSingle(LayerJson, 'endY'));
          LineValue.Opacity := ReadSingle(LayerJson, 'opacity');
          LineValue.StrokeColor := TColor(ReadInteger(LayerJson,
            'strokeColor'));
          LineValue.StrokeWidth := Max(ReadSingle(LayerJson,
            'strokeWidth'), 0.1);
          StrokeStyleValue := ReadInteger(LayerJson, 'strokeStyle');
          LineValue.StrokeStyle := vssSolid;
          if InRange(StrokeStyleValue, Ord(Low(TVectArtStrokeStyle)),
            Ord(High(TVectArtStrokeStyle))) then
            LineValue.StrokeStyle := TVectArtStrokeStyle(StrokeStyleValue);
          LineValue.Visible := ReadBoolean(LayerJson, 'visible');
          LineValue.Locked := ReadBoolean(LayerJson, 'locked');
          LineData[I] := LineValue;
          Continue;
        end;
        if LayerTypes[I] <> 'rectangle' then
          raise EConvertError.CreateFmt('Layer %d has an unsupported type',
            [I]);
        Data.Name := ReadString(LayerJson, 'name');
        Data.Bounds := TRectF.Create(
          ReadSingle(LayerJson, 'left'),
          ReadSingle(LayerJson, 'top'),
          ReadSingle(LayerJson, 'right'),
          ReadSingle(LayerJson, 'bottom'));
        Data.FillColor := TColor(ReadInteger(LayerJson, 'fillColor'));
        Data.Opacity := ReadSingle(LayerJson, 'opacity');
        Data.RotationDegrees := 0.0;
        if LayerJson.GetValue('rotation') is TJSONNumber then
          Data.RotationDegrees := TJSONNumber(
            LayerJson.GetValue('rotation')).AsDouble;
        Data.StrokeColor := clBlack;
        if LayerJson.GetValue('strokeColor') is TJSONNumber then
          Data.StrokeColor := TColor(TJSONNumber(
            LayerJson.GetValue('strokeColor')).AsInt);
        Data.StrokeWidth := 0.0;
        if LayerJson.GetValue('strokeWidth') is TJSONNumber then
          Data.StrokeWidth := Max(TJSONNumber(
            LayerJson.GetValue('strokeWidth')).AsDouble, 0.0);
        Data.StrokeStyle := vssSolid;
        if LayerJson.GetValue('strokeStyle') is TJSONNumber then
        begin
          StrokeStyleValue := TJSONNumber(
            LayerJson.GetValue('strokeStyle')).AsInt;
          if InRange(StrokeStyleValue, Ord(Low(TVectArtStrokeStyle)),
            Ord(High(TVectArtStrokeStyle))) then
            Data.StrokeStyle := TVectArtStrokeStyle(StrokeStyleValue);
        end;
        Data.Visible := ReadBoolean(LayerJson, 'visible');
        Data.Locked := ReadBoolean(LayerJson, 'locked');
        RectangleData[I] := Data;
      end;
      SelectedIndex := ReadInteger(Root, 'selectedIndex');

      Canvas := Document.CanvasLayer;
      if Canvas = nil then
        raise EInvalidOp.Create('Document canvas is missing');
      while Document.LayerCount > 1 do
        if Document[Document.LayerCount - 1] is TVectArtRectangleLayer then
          Document.RemoveRectangle(Document.LayerCount - 1, Discarded)
        else if Document[Document.LayerCount - 1] is TVectArtLineLayer then
          Document.RemoveLine(Document.LayerCount - 1, DiscardedLine)
        else
          raise EInvalidOp.Create('Document contains an unsupported layer');
      Canvas.Width := CanvasWidth;
      Canvas.Height := CanvasHeight;
      Canvas.BackgroundColor := TColor(CanvasColor);
      Canvas.Transparent := CanvasTransparent;
      for I := 0 to High(RectangleData) do
        if LayerTypes[I] = 'rectangle' then
          Document.InsertRectangle(Document.LayerCount, RectangleData[I])
        else
          Document.InsertLine(Document.LayerCount, LineData[I]);
      Document.SelectedIndex := SelectedIndex;
      Document.Changed;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
    Json.Free;
  end;
end;

end.
