program VectArtDesigner;

uses
  Vcl.Forms,
  VectArtDesignerMainForm in 'Source\VectArtDesignerMainForm.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'VectArtDesigner';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
