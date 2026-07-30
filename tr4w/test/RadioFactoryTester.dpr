program RadioFactoryTester;

{
  Radio Factory Test Harness

  Interactive tool for testing radio commands against physical hardware.
  Supports K4 (network/serial) and IC-9700 (serial) via factory pattern.
}

uses
  Forms,
  uTestMain in 'test\uTestMain.pas' {frmTestMain},
  uTestDefinitions in 'test\uTestDefinitions.pas',
  uRadioFactory in 'src\radioFactory\uRadioFactory.pas',
  uFactoryRadioBase in 'src\radioFactory\uFactoryRadioBase.pas',
  uRadioElecraftK4 in 'src\radioFactory\uRadioElecraftK4.pas',
  uRadioIcomBase in 'src\radioFactory\uRadioIcomBase.pas',
  uRadioIcom9700 in 'src\radioFactory\uRadioIcom9700.pas',
  Log4D in 'src\Log4D.pas';

// {$R *.res}  // Resource file not needed for testing

begin
  Application.Initialize;
  Application.Title := 'TR4W Radio Factory Tester';
  Application.CreateForm(TfrmTestMain, frmTestMain);
  Application.Run;
end.
