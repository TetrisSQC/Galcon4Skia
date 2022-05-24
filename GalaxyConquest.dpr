program GalaxyConquest;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  Skia.FMX,
  UGame in 'UGame.pas',
  UMain in 'UMain.pas' {frmMain};

{$R *.res}

begin
  GlobalUseSkia := True;
  GlobalUseMetal := True;
  GlobalUseSkiaRasterWhenAvailable := False;


  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
