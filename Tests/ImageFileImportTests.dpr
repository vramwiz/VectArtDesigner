program ImageFileImportTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLayerBatchCommands in
    'Source\Core\Commands\VectArtDesignerLayerBatchCommands.pas',
  VectArtDesignerImageFileImport in
    'Source\Editor\Import\VectArtDesignerImageFileImport.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Bitmap: TBitmap;
  Data: TVectArtImageData;
  Document: TVectArtDocument;
  ErrorMessage: string;
  History: TVectArtEditHistory;
  ImageLayer: TVectArtImageLayer;
  ImageStream: TBytesStream;
  SourceFileName: string;
  WicImage: TWICImage;
begin
  SourceFileName := ChangeFileExt(TPath.GetTempFileName, '.bmp');
  TFile.Delete(ChangeFileExt(SourceFileName, '.tmp'));
  Bitmap := TBitmap.Create;
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  try
    Bitmap.SetSize(20, 10);
    Bitmap.Canvas.Brush.Color := clRed;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    Bitmap.SaveToFile(SourceFileName);
    Require(TryCreateVectArtImageFromFile(SourceFileName,
      PointF(100, 80), 300, 200, Data, ErrorMessage),
      'Image import failed: ' + ErrorMessage);
    Require((Length(Data.PngData) > 8) and
      (Data.PngData[0] = $89) and (Data.PngData[1] = $50) and
      (Data.PngData[2] = $4E) and (Data.PngData[3] = $47),
      'Imported data is not an embedded PNG');
    Require(Data.SourceFileName = TPath.GetFullPath(SourceFileName),
      'Source full path differs');
    Require((Data.Points[0].X = 90) and (Data.Points[0].Y = 75) and
      (Data.Points[2].X = 110) and (Data.Points[2].Y = 85),
      'Drop placement differs');
    TFile.Delete(SourceFileName);
    Require(Length(Data.PngData) > 8,
      'Embedded image disappeared with the source file');
    ImageStream := TBytesStream.Create(Data.PngData);
    WicImage := TWICImage.Create;
    try
      WicImage.LoadFromStream(ImageStream);
      Require((WicImage.Width = 20) and (WicImage.Height = 10),
        'Embedded image cannot be decoded after source deletion');
    finally
      WicImage.Free;
      ImageStream.Free;
    end;
    Document.InsertImage(1, Data);
    Document.SetSelectedLayers([1]);
    History.AddApplied(TVectArtInsertImagesCommand.Create(Document, 1,
      [Data], [], [1]));
    History.Undo;
    Require(Document.LayerCount = 1, 'Imported image undo differs');
    History.Redo;
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtImageLayer), 'Imported image redo differs');
    ImageLayer := TVectArtImageLayer(Document[1]);
    Require((ImageLayer.SourceFileName = Data.SourceFileName) and
      (Length(ImageLayer.PngData) = Length(Data.PngData)),
      'Redo did not retain embedded image or source path');
    Writeln('Image file import tests: PASS');
  finally
    if TFile.Exists(SourceFileName) then
      TFile.Delete(SourceFileName);
    History.Free;
    Document.Free;
    Bitmap.Free;
  end;
end.
