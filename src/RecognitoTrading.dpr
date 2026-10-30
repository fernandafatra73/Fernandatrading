program RecognitoTrading;

{ Fernanda Trading Recognito
  Created By: Fernanda Fatria Fatra,SST.MM }

uses
  Forms, SysUtils,
  uUI in 'uUI.pas',
  uNet in 'uNet.pas',
  uData in 'uData.pas',
  uChart in 'uChart.pas',
  uSession in 'uSession.pas',
  uMT5 in 'uMT5.pas',
  uRec in 'uRec.pas',
  uMain in 'uMain.pas';

{$R *.res}

begin
  DecimalSeparator := '.';
  ThousandSeparator := ',';
  Application.UpdateFormatSettings := False;
  Application.Initialize;
  Application.Title := 'Fernanda Trading Recognito';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
