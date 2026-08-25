program ScreenLayoutFilterContextTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  AviUtl2FilterTypes in 'Lib\AviUtl2\AviUtl2FilterTypes.pas',
  PluginFilterContextManager in 'Lib\AviUtl2\PluginFilterContextManager.pas',
  ScreenLayoutFrameCapture in 'Source\PlacementPlugin\ScreenLayoutFrameCapture.pas',
  ScreenLayoutFilterContext in 'Source\PlacementPlugin\ScreenLayoutFilterContext.pas',
  TextRendererSkiaBootstrap in 'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in 'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerDocumentJson in 'Source\Persistence\VectArtDesignerDocumentJson.pas',
  VectArtDesignerRenderer in 'Source\Rendering\VectArtDesignerRenderer.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  CapturedCenter: TPIXEL_RGBA;
  CapturedHeight: Integer;
  CapturedWidth: Integer;

procedure MockGetImageData(Buffer: PPIXEL_RGBA); cdecl;
var
  I: Integer;
begin
  for I := 0 to 63 do
  begin
    Buffer^.R := 0;
    Buffer^.G := 0;
    Buffer^.B := 255;
    Buffer^.A := 255;
    Inc(Buffer);
  end;
end;

procedure MockSetImageData(Buffer: PPIXEL_RGBA;
  Width, Height: Integer); cdecl;
begin
  CapturedWidth := Width;
  CapturedHeight := Height;
  Inc(Buffer, NativeInt(3) * Width + 3);
  CapturedCenter := Buffer^;
end;

var
  Context1: TScreenLayoutFilterContext;
  Context1Again: TScreenLayoutFilterContext;
  Context2: TScreenLayoutFilterContext;
  ContextOtherEffect: TScreenLayoutFilterContext;
  Contexts: TScreenLayoutFilterContexts;
  Data: TVectArtRectangleData;
  ObjectInfo1: TOBJECT_INFO;
  ObjectInfo2: TOBJECT_INFO;
  Serialized: string;
  SourceDocument: TVectArtDocument;
  Video1: TFILTER_PROC_VIDEO;
  Video2: TFILTER_PROC_VIDEO;
  VideoOtherEffect: TFILTER_PROC_VIDEO;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Contexts := TScreenLayoutFilterContexts.Create;
  SourceDocument := TVectArtDocument.Create;
  try
    ObjectInfo1.ID := 101;
    ObjectInfo1.EffectID := 1001;
    ObjectInfo1.Width := 8;
    ObjectInfo1.Height := 8;
    ObjectInfo1.Layer := 3;
    ObjectInfo1.FrameS := 10;
    ObjectInfo1.FrameE := 40;
    ObjectInfo2.ID := 202;
    ObjectInfo2.EffectID := 2002;
    ObjectInfo2.Layer := 5;
    ObjectInfo2.FrameS := 20;
    ObjectInfo2.FrameE := 60;
    Video1.Object_ := @ObjectInfo1;
    Video1.GetImageData := MockGetImageData;
    Video1.SetImageData := MockSetImageData;
    Video2.Object_ := @ObjectInfo2;

    Context1 := Contexts.GetContext(@Video1);
    Context1Again := Contexts.GetContext(@Video1);
    Context2 := Contexts.GetContext(@Video2);
    Require(Context1 = Context1Again, '同じオブジェクトのコンテキストが再利用されない');
    Require(Context1 <> Context2, '異なるオブジェクトがコンテキストを共有している');
    ObjectInfo1.EffectID := 1002;
    VideoOtherEffect.Object_ := @ObjectInfo1;
    ContextOtherEffect := Contexts.GetContext(@VideoOtherEffect);
    Require(Context1 <> ContextOtherEffect,
      '同一オブジェクトの異なるエフェクトがコンテキストを共有している');
    Require(Context1.ObjectID = 101, 'オブジェクトIDが保持されていない');
    Require(Context1.EffectID = 1001, 'エフェクトIDが保持されていない');
    Require(Contexts.FindByKey(101, 1001) = Context1,
      'Object IDとEffect IDでコンテキストを取得できない');
    Require(Contexts.FindByObjectLocation(3, 10, 40) = Context1,
      '編集APIの配置情報でコンテキストを取得できない');
    Require(Contexts.GetContext(nil) = nil, 'nil映像からコンテキストが生成された');

    SourceDocument.CanvasLayer.Width := 8;
    SourceDocument.CanvasLayer.Height := 8;
    Data.Bounds := TRectF.Create(2, 2, 6, 6);
    Data.FillColor := TColor($000000FF);
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 0.5;
    Data.Visible := True;
    SourceDocument.InsertRectangle(SourceDocument.LayerCount, Data);
    Serialized := SerializeVectArtDocument(SourceDocument);
    Require(Context1.UpdateSerializedData(Serialized), Context1.LastError);
    Require(Context1.SerializedData = Serialized, '配置データが保持されていない');
    Require(not Context1.UpdateSerializedData('{broken'), '不正JSONが受理された');
    Require(Context1.SerializedData = Serialized, '不正JSONが正常な配置データを壊した');
    Require(Context1.RenderVideo(@Video1), 'AviUtl2映像へ描画できない');
    Require((CapturedWidth = 8) and (CapturedHeight = 8),
      'AviUtl2出力サイズが異なる');
    Require((CapturedCenter.R >= 127) and (CapturedCenter.R <= 128) and
      (CapturedCenter.G = 0) and
      (CapturedCenter.B >= 127) and (CapturedCenter.B <= 128) and
      (CapturedCenter.A = 255), 'AviUtl2合成結果が異なる');
    Writeln('Screen layout filter contexts: PASS');
  finally
    SourceDocument.Free;
    Contexts.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
