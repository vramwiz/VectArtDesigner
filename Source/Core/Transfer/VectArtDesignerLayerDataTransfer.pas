// レイヤー固有の状態を、挿入・削除コマンドで扱えるデータへ写す。
// クリップボードと複製で同じ属性集合を使い、機能ごとの取りこぼしを防ぐ。
unit VectArtDesignerLayerDataTransfer;

interface

uses
  VectArtDesignerDocument;

function CaptureVectArtRectangleData(Layer: TVectArtRectangleLayer):
  TVectArtRectangleData;
function CaptureVectArtLineData(Layer: TVectArtLineLayer): TVectArtLineData;
function CaptureVectArtPathData(Layer: TVectArtPathLayer): TVectArtPathData;
function CaptureVectArtImageData(Layer: TVectArtImageLayer): TVectArtImageData;
procedure RemoveVectArtLayer(Document: TVectArtDocument; Index: Integer);

implementation

function CaptureVectArtRectangleData(Layer: TVectArtRectangleLayer):
  TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := Layer.Bounds;
  Result.FillStyle := Layer.FillStyle;
  Result.FillColor := Layer.FillColor;
  Result.Filled := Layer.Filled;
  Result.GroupId := Layer.GroupId;
  Result.Locked := Layer.Locked;
  Result.Name := Layer.Name;
  Result.Opacity := Layer.Opacity;
  Result.RotationDegrees := Layer.RotationDegrees;
  Result.Shape := Layer.Shape;
  Result.Shadow := Layer.Shadow;
  Result.StrokePaint := Layer.StrokePaint;
  Result.StrokeColor := Layer.StrokeColor;
  Result.StrokeStyle := Layer.StrokeStyle;
  Result.StrokeWidth := Layer.StrokeWidth;
  Result.Visible := Layer.Visible;
end;

function CaptureVectArtLineData(Layer: TVectArtLineLayer): TVectArtLineData;
begin
  Result := Default(TVectArtLineData);
  Result.AntiAlias := Layer.AntiAlias;
  Result.EndPoint := Layer.EndPoint;
  Result.EndMarker := Layer.EndMarker;
  Result.EndMarkerSize := Layer.EndMarkerSize;
  Result.GroupId := Layer.GroupId;
  Result.LineCap := Layer.LineCap;
  Result.LineJoin := Layer.LineJoin;
  Result.Locked := Layer.Locked;
  Result.Name := Layer.Name;
  Result.Opacity := Layer.Opacity;
  Result.StartMarker := Layer.StartMarker;
  Result.StartMarkerSize := Layer.StartMarkerSize;
  Result.StartPoint := Layer.StartPoint;
  Result.StrokePaint := Layer.StrokePaint;
  Result.StrokeColor := Layer.StrokeColor;
  Result.StrokeStyle := Layer.StrokeStyle;
  Result.StrokeWidth := Layer.StrokeWidth;
  Result.Visible := Layer.Visible;
end;

function CaptureVectArtPathData(Layer: TVectArtPathLayer): TVectArtPathData;
begin
  Result := Default(TVectArtPathData);
  Result.AntiAlias := Layer.AntiAlias;
  Result.Bezier := Layer.Bezier;
  Result.BoundsEditing := Layer.BoundsEditing;
  Result.Closed := Layer.Closed;
  Result.EndMarker := Layer.EndMarker;
  Result.EndMarkerSize := Layer.EndMarkerSize;
  Result.FillStyle := Layer.FillStyle;
  Result.FillColor := Layer.FillColor;
  Result.Filled := Layer.Filled;
  Result.GroupId := Layer.GroupId;
  Result.LineCap := Layer.LineCap;
  Result.LineJoin := Layer.LineJoin;
  Result.Locked := Layer.Locked;
  Result.Name := Layer.Name;
  Result.Opacity := Layer.Opacity;
  Result.Points := Copy(Layer.Points);
  Result.Shadow := Layer.Shadow;
  Result.StartMarker := Layer.StartMarker;
  Result.StartMarkerSize := Layer.StartMarkerSize;
  Result.StrokePaint := Layer.StrokePaint;
  Result.StrokeColor := Layer.StrokeColor;
  Result.StrokeStyle := Layer.StrokeStyle;
  Result.StrokeWidth := Layer.StrokeWidth;
  Result.Visible := Layer.Visible;
end;

function CaptureVectArtImageData(Layer: TVectArtImageLayer):
  TVectArtImageData;
begin
  Result := Default(TVectArtImageData);
  Result.GroupId := Layer.GroupId;
  Result.Locked := Layer.Locked;
  Result.Name := Layer.Name;
  Result.Opacity := Layer.Opacity;
  // 画像所有者の寿命と転送データを分離するため、バイト列は共有しない。
  Result.PngData := Copy(Layer.PngData);
  Result.Points := Layer.Points;
  Result.SourceFileName := Layer.SourceFileName;
  Result.SourceKind := Layer.SourceKind;
  Result.Visible := Layer.Visible;
end;

procedure RemoveVectArtLayer(Document: TVectArtDocument; Index: Integer);
var
  ImageData: TVectArtImageData;
  LineData: TVectArtLineData;
  PathData: TVectArtPathData;
  RectangleData: TVectArtRectangleData;
  TextData: TVectArtTextData;
begin
  if (Document = nil) or (Index <= 0) or
    (Index >= Document.LayerCount) then
    Exit;
  case Document[Index].Kind of
    vlkRectangle:
      Document.RemoveRectangle(Index, RectangleData);
    vlkLine:
      Document.RemoveLine(Index, LineData);
    vlkPath:
      Document.RemovePath(Index, PathData);
    vlkImage:
      Document.RemoveImage(Index, ImageData);
    vlkText:
      Document.RemoveText(Index, TextData);
  end;
end;

end.
