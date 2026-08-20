// 選択枠と8個のリサイズマーカーの位置計算とヒットテストを提供する。
unit VectArtDesignerSelectionGeometry;

interface

uses
  System.Types, Vcl.Controls;

type
  TVectArtSelectionHandle = (vshNone, vshTopLeft, vshTop,
    vshTopRight, vshRight, vshBottomRight, vshBottom,
    vshBottomLeft, vshLeft);

  TVectArtSelectionGeometry = record
    FrameRect: TRect;
    Handles: array[vshTopLeft..vshLeft] of TRect;
  end;

function BuildSelectionGeometry(const LayerRect: TRect): TVectArtSelectionGeometry;
function HitTestSelectionHandle(const Point: TPoint;
  const Geometry: TVectArtSelectionGeometry): TVectArtSelectionHandle;
function SelectionHandleCursor(Handle: TVectArtSelectionHandle): TCursor;

implementation

const
  SELECTION_FRAME_OFFSET = 8;
  SELECTION_HANDLE_SIZE = 8;

function BuildSelectionGeometry(
  const LayerRect: TRect): TVectArtSelectionGeometry;
var
  CenterX: Integer;
  CenterY: Integer;
  HalfHandle: Integer;

  function HandleRect(X, Y: Integer): TRect;
  begin
    Result := Rect(X - HalfHandle, Y - HalfHandle,
      X - HalfHandle + SELECTION_HANDLE_SIZE,
      Y - HalfHandle + SELECTION_HANDLE_SIZE);
  end;

begin
  Result.FrameRect := LayerRect;
  InflateRect(Result.FrameRect, SELECTION_FRAME_OFFSET,
    SELECTION_FRAME_OFFSET);
  CenterX := (Result.FrameRect.Left + Result.FrameRect.Right) div 2;
  CenterY := (Result.FrameRect.Top + Result.FrameRect.Bottom) div 2;
  HalfHandle := SELECTION_HANDLE_SIZE div 2;
  Result.Handles[vshTopLeft] := HandleRect(Result.FrameRect.Left,
    Result.FrameRect.Top);
  Result.Handles[vshTop] := HandleRect(CenterX, Result.FrameRect.Top);
  Result.Handles[vshTopRight] := HandleRect(Result.FrameRect.Right,
    Result.FrameRect.Top);
  Result.Handles[vshRight] := HandleRect(Result.FrameRect.Right, CenterY);
  Result.Handles[vshBottomRight] := HandleRect(Result.FrameRect.Right,
    Result.FrameRect.Bottom);
  Result.Handles[vshBottom] := HandleRect(CenterX, Result.FrameRect.Bottom);
  Result.Handles[vshBottomLeft] := HandleRect(Result.FrameRect.Left,
    Result.FrameRect.Bottom);
  Result.Handles[vshLeft] := HandleRect(Result.FrameRect.Left, CenterY);
end;

function HitTestSelectionHandle(const Point: TPoint;
  const Geometry: TVectArtSelectionGeometry): TVectArtSelectionHandle;
var
  Handle: TVectArtSelectionHandle;
begin
  for Handle := vshTopLeft to vshLeft do
    if PtInRect(Geometry.Handles[Handle], Point) then
      Exit(Handle);
  Result := vshNone;
end;

function SelectionHandleCursor(Handle: TVectArtSelectionHandle): TCursor;
begin
  case Handle of
    vshTopLeft, vshBottomRight:
      Result := crSizeNWSE;
    vshTopRight, vshBottomLeft:
      Result := crSizeNESW;
    vshTop, vshBottom:
      Result := crSizeNS;
    vshLeft, vshRight:
      Result := crSizeWE;
  else
    Result := crDefault;
  end;
end;

end.
