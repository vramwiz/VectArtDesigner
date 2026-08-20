program VectArtDesigner;

uses
  Vcl.Forms,
  TextRendererSkiaBootstrap in 'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererTypes in 'Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in 'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Lib\TextRenderer\TextRendererSkia.pas',
  VectArtDesignerMainForm in 'Source\Shell\VectArtDesignerMainForm.pas' {MainForm},
  VectArtDesignerEditActionsUI in 'Source\Shell\VectArtDesignerEditActionsUI.pas',
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditorState in 'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerEditCommands in 'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerLayerStructureCommands in 'Source\Core\Commands\VectArtDesignerLayerStructureCommands.pas',
  VectArtDesignerLayerBatchCommands in 'Source\Core\Commands\VectArtDesignerLayerBatchCommands.pas',
  VectArtDesignerEditHistory in 'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerCanvas in 'Source\Editor\VectArtDesignerCanvas.pas',
  VectArtDesignerCanvasInteraction in 'Source\Editor\VectArtDesignerCanvasInteraction.pas',
  VectArtDesignerShapeCreation in 'Source\Editor\VectArtDesignerShapeCreation.pas',
  VectArtDesignerKeyboardMovement in 'Source\Editor\VectArtDesignerKeyboardMovement.pas',
  VectArtDesignerEditorWorkspaceFrame in 'Source\Editor\VectArtDesignerEditorWorkspaceFrame.pas',
  VectArtDesignerSelectionGeometry in 'Source\Editor\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerLayerList in 'Source\Layers\VectArtDesignerLayerList.pas',
  VectArtDesignerLayerRenderer in 'Source\Layers\VectArtDesignerLayerRenderer.pas',
  VectArtDesignerLayerActions in 'Source\Layers\VectArtDesignerLayerActions.pas',
  VectArtDesignerLayerOperations in 'Source\Layers\VectArtDesignerLayerOperations.pas',
  VectArtDesignerLayerDuplication in 'Source\Layers\VectArtDesignerLayerDuplication.pas',
  VectArtDesignerLayerPanelFrame in 'Source\Layers\VectArtDesignerLayerPanelFrame.pas',
  VectArtDesignerDockManager in 'Source\Layout\VectArtDesignerDockManager.pas',
  VectArtDesignerToolFrames in 'Source\Layout\VectArtDesignerToolFrames.pas',
  VectArtDesignerObjectPropertiesControl in 'Source\ObjectProperties\VectArtDesignerObjectPropertiesControl.pas',
  VectArtDesignerObjectPropertiesFrame in 'Source\ObjectProperties\VectArtDesignerObjectPropertiesFrame.pas',
  VectArtDesignerToolPaletteFrame in 'Source\ToolPalette\VectArtDesignerToolPaletteFrame.pas',
  VectArtDesignerToolPalette in 'Source\ToolPalette\VectArtDesignerToolPalette.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'VectArtDesigner';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
