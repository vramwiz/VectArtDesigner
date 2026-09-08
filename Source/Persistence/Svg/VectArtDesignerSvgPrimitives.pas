// SVG入出力で共有する名前と埋め込み画像の検証を担当する。
// 名前空間と装飾名を共通化し、書出しと読込みの解釈の差を防ぐ。
unit VectArtDesignerSvgPrimitives;

interface

uses System.SysUtils, VectArtDesignerDocument;

const
  SVG_NAMESPACE = 'http://www.w3.org/2000/svg';
  VAD_NAMESPACE = 'urn:vectartdesigner:document:1';
  VAD_FORMAT_VERSION = 1;

function IsDecodablePng(const Data: TBytes): Boolean;

function LineMarkerName(Value: TVectArtLineMarker): string;

function TryParseLineMarkerName(const Value: string;
  out Marker: TVectArtLineMarker): Boolean;

implementation

uses System.Classes, Vcl.Imaging.pngimage;

function IsDecodablePng(const Data: TBytes): Boolean;
var
  Image: TPngImage;
  Stream: TBytesStream;
begin
  Result := False;
  if Length(Data) = 0 then
    Exit;
  Image := TPngImage.Create;
  Stream := TBytesStream.Create(Data);
  try
    try
      Image.LoadFromStream(Stream);
      Result := (Image.Width > 0) and (Image.Height > 0);
    except
      on Exception do
        Result := False;
    end;
  finally
    Stream.Free;
    Image.Free;
  end;
end;

function LineMarkerName(Value: TVectArtLineMarker): string;
begin
  case Value of
    vlmArrow: Result := 'arrow';
    vlmOpenArrow: Result := 'open-arrow';
    vlmWideArrow: Result := 'wide-arrow';
    vlmCircle: Result := 'circle';
    vlmDiamond: Result := 'diamond';
    vlmConcaveArrow: Result := 'concave-arrow';
    vlmSmallArrow: Result := 'small-arrow';
    vlmSlash: Result := 'slash';
    vlmStar: Result := 'star';
  else
    Result := 'none';
  end;
end;

function TryParseLineMarkerName(const Value: string;
  out Marker: TVectArtLineMarker): Boolean;
var
  Candidate: TVectArtLineMarker;
begin
  for Candidate := Low(TVectArtLineMarker) to High(TVectArtLineMarker) do
    if SameText(Trim(Value), LineMarkerName(Candidate)) then
    begin
      Marker := Candidate;
      Exit(True);
    end;
  Result := False;
end;

end.
