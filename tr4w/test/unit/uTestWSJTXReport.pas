unit uTestWSJTXReport;
{$I ..\..\src\tr4w.inc}

(*
   A WSJT-X dB SNR BECOMES AN RST ON THE CABRILLO EXPORT (issue 261).

   uWSJTXReport says which modes get the conversion.  FT8, MFSK and JT65 were
   the original three; FT4, FST4 and FST4W belong because their report is the
   same kind of value, a dB SNR.  Every other ExtendedModeType carries a real
   RST and must come through untouched -- the loop over the enum is what makes
   a mode added later choose.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TWSJTXReportTests = class(TTestCase)
   private
      procedure Test_EachSnrModeConverts;
      procedure Test_EveryOtherModeIsLeftAlone;
      procedure Test_TheSnrBandsAndTheirEdges;
      procedure Test_TheStoredLimit;
      procedure Test_NotEnabledGives599;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   uWSJTXReport;

procedure TWSJTXReportTests.Test_EachSnrModeConverts;
begin
   BeginTest('Test_EachSnrModeConverts');
   CheckEquals(549, WSJTXReceivedReportForExport(eFT8,   -2, True), 'FT8');
   CheckEquals(549, WSJTXReceivedReportForExport(eMFSK,  -2, True), 'MFSK');
   CheckEquals(549, WSJTXReceivedReportForExport(eJT65,  -2, True), 'JT65');
   CheckEquals(549, WSJTXReceivedReportForExport(eFT4,   -2, True), 'FT4');
   CheckEquals(549, WSJTXReceivedReportForExport(eFST4,  -2, True), 'FST4');
   CheckEquals(549, WSJTXReceivedReportForExport(eFST4W, -2, True), 'FST4W');
end;

procedure TWSJTXReportTests.Test_EveryOtherModeIsLeftAlone;
var
   e: ExtendedModeType;
begin
   BeginTest('Test_EveryOtherModeIsLeftAlone');
   for e := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      if not (e in [eFT8, eMFSK, eJT65, eFT4, eFST4, eFST4W]) then
         begin
         CheckEquals(-12, WSJTXReceivedReportForExport(e, -12, True),
                     'unchanged for ' + ExtendedModeStringArray[e]);
         CheckEquals(-12, WSJTXReceivedReportForExport(e, -12, False),
                     'unchanged, WSJT-X off, for ' + ExtendedModeStringArray[e]);
         end;
      end;
   CheckEquals(599, WSJTXReceivedReportForExport(eCW,   599, True), 'CW 599');
   CheckEquals(579, WSJTXReceivedReportForExport(eRTTY, 579, True), 'RTTY 579');
   CheckFalse(WSJTXModeReportsSNR(eJS8), 'JS8 is JS8Call''s, not converted');
   CheckFalse(WSJTXModeReportsSNR(eNoMode), 'NoMode (Q65, JT9, MSK144 parse to it)');
end;

procedure TWSJTXReportTests.Test_TheSnrBandsAndTheirEdges;
begin
   BeginTest('Test_TheSnrBandsAndTheirEdges');
   (* The existing table, pinned at both sides of every edge. *)
   CheckEquals(509, WSJTXSnrToRST(-30), 'low end');
   CheckEquals(509, WSJTXSnrToRST(-20), '-20');
   CheckEquals(519, WSJTXSnrToRST(-19), '-19');
   CheckEquals(519, WSJTXSnrToRST(-15), '-15');
   CheckEquals(529, WSJTXSnrToRST(-14), '-14');
   CheckEquals(529, WSJTXSnrToRST(-9),  '-9');
   CheckEquals(539, WSJTXSnrToRST(-8),  '-8');
   CheckEquals(539, WSJTXSnrToRST(-3),  '-3');
   CheckEquals(549, WSJTXSnrToRST(-2),  '-2');
   CheckEquals(549, WSJTXSnrToRST(3),   '3');
   CheckEquals(559, WSJTXSnrToRST(4),   '4');
   CheckEquals(559, WSJTXSnrToRST(9),   '9');
   CheckEquals(569, WSJTXSnrToRST(10),  '10');
   CheckEquals(569, WSJTXSnrToRST(15),  '15');
   CheckEquals(579, WSJTXSnrToRST(16),  '16');
   CheckEquals(579, WSJTXSnrToRST(21),  '21');
   CheckEquals(589, WSJTXSnrToRST(22),  '22');
   CheckEquals(589, WSJTXSnrToRST(27),  '27');
   CheckEquals(599, WSJTXSnrToRST(28),  '28');
   CheckEquals(599, WSJTXSnrToRST(40),  'high end');
   (* The same edges through the export, for a mode this issue added. *)
   CheckEquals(509, WSJTXReceivedReportForExport(eFT4, -30, True), 'FT4 low');
   CheckEquals(589, WSJTXReceivedReportForExport(eFST4, 24, True), 'FST4 24');
end;

procedure TWSJTXReportTests.Test_TheStoredLimit;
begin
   BeginTest('Test_TheStoredLimit');
   (* 24 is the last value taken as an SNR; 25 is already an RST. *)
   CheckEquals(589, WSJTXReceivedReportForExport(eFT4, 24, True), 'FT4 24');
   CheckEquals(25,  WSJTXReceivedReportForExport(eFT4, 25, True), 'FT4 25');
   CheckEquals(599, WSJTXReceivedReportForExport(eFT4, 599, True), 'FT4 599');
   CheckEquals(589, WSJTXReceivedReportForExport(eFT8, 24, True), 'FT8 24');
   CheckEquals(25,  WSJTXReceivedReportForExport(eFT8, 25, True), 'FT8 25');
end;

procedure TWSJTXReportTests.Test_NotEnabledGives599;
begin
   BeginTest('Test_NotEnabledGives599');
   CheckEquals(599, WSJTXReceivedReportForExport(eFT8,   -12, False), 'FT8');
   CheckEquals(599, WSJTXReceivedReportForExport(eFT4,   -12, False), 'FT4');
   CheckEquals(599, WSJTXReceivedReportForExport(eFST4,  -12, False), 'FST4');
   CheckEquals(599, WSJTXReceivedReportForExport(eFST4W, -12, False), 'FST4W');
   CheckEquals(599, WSJTXReceivedReportForExport(eJT65,  -12, False), 'JT65');
   CheckEquals(599, WSJTXReceivedReportForExport(eMFSK,  -12, False), 'MFSK');
end;

procedure TWSJTXReportTests.RunAllTests;
begin
   Test_EachSnrModeConverts;
   Test_EveryOtherModeIsLeftAlone;
   Test_TheSnrBandsAndTheirEdges;
   Test_TheStoredLimit;
   Test_NotEnabledGives599;
end;

end.
