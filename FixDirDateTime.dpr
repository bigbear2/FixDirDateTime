program FixDirDateTime;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

uses
{$IFnDEF FPC}
{$ELSE}
  Interfaces,
{$ENDIF}
  Forms,
  MainForm in 'MainForm.pas' {frmMain};

{$R *.res}

begin
  Application.Title:='FixDirDateTime v2024.06.16 - Fabio L.';
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
