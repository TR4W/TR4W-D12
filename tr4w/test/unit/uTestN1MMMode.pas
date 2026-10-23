unit uTestN1MMMode;
{$I ..\..\src\tr4w.inc}

(*
   THE MODE NAME ON THE WIRE TO N1MM-FORMAT LISTENERS.

   uN1MMMode.N1MMModeName is the one answer for the UDP contact broadcast and
   the RadioInfo packet.  VC.ExtendedModeStringArray is TR4W's own vocabulary
   (DATA, CW-R, D-STAR, NoMode ...) and must never reach another program;
   these tests pin every ExtendedModeType value, so a new one cannot slip out
   under a name nobody else knows.

   The external logger's ADIF goes through uADIF.ResolveADIFModeSubmode, which
   is public for that reason; its (MODE, SUBMODE) pairs for the cases the old
   inline copy got wrong are pinned here too.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TN1MMModeTests = class(TTestCase)
   private
      procedure Test_EveryExtModeHasAWireNameNotATR4WName;
      procedure Test_EachRowIsPinned;
      procedure Test_SidebandFollowsTheFrequency;
      procedure Test_NoExtModeFallsBackToTheBaseMode;
      procedure Test_ExternalLoggerAdifModePair;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   uADIF,
   uN1MMMode;

procedure TN1MMModeTests.Test_EveryExtModeHasAWireNameNotATR4WName;
const
   TR4W_ONLY: array[0..11] of string =
      ('DATA', 'DATA-R', 'DATA-FM', 'CW-R', 'RTTY-R', 'FM-N', 'AM-N',
       'D-STAR', 'PSK-R', 'WFM', 'NoMode', 'SSB');
var
   e: ExtendedModeType;
   name: string;
   i: integer;
begin
   BeginTest('Test_EveryExtModeHasAWireNameNotATR4WName');
   for e := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      name := N1MMModeName(Phone, e, 14200000);
      CheckTrue(name <> '', 'non-empty name for ' + ExtendedModeStringArray[e]);
      for i := Low(TR4W_ONLY) to High(TR4W_ONLY) do
         begin
         CheckFalse(UnicodeSameText(name, TR4W_ONLY[i]),
                    ExtendedModeStringArray[e] + ' went out as TR4W-only ' + name);
         end;
      end;
end;

procedure TN1MMModeTests.Test_EachRowIsPinned;
begin
   BeginTest('Test_EachRowIsPinned');
   CheckEquals('CW',    N1MMModeName(CW, eCW, 14025000),      'eCW');
   CheckEquals('CW',    N1MMModeName(CW, eCW_R, 14025000),    'eCW_R');
   CheckEquals('RTTY',  N1MMModeName(Digital, eRTTY, 14080000),   'eRTTY');
   CheckEquals('RTTY',  N1MMModeName(Digital, eRTTY_R, 14080000), 'eRTTY_R');
   CheckEquals('RTTY',  N1MMModeName(Digital, eData, 14080000),   'eData');
   CheckEquals('RTTY',  N1MMModeName(Digital, eData_R, 14080000), 'eData_R');
   CheckEquals('RTTY',  N1MMModeName(Digital, eData_FM, 14080000), 'eData_FM');
   CheckEquals('FT8',   N1MMModeName(Digital, eFT8, 14074000),    'eFT8');
   CheckEquals('FT4',   N1MMModeName(Digital, eFT4, 14080000),    'eFT4');
   CheckEquals('JT65',  N1MMModeName(Digital, eJT65, 14076000),   'eJT65');
   CheckEquals('PSK31', N1MMModeName(Digital, ePSK31, 14070000),  'ePSK31');
   CheckEquals('PSK63', N1MMModeName(Digital, ePSK63, 14070000),  'ePSK63');
   CheckEquals('PSK',   N1MMModeName(Digital, ePSK_R, 14070000),  'ePSK_R');
   CheckEquals('USB',   N1MMModeName(Phone, eUSB, 7150000),       'eUSB at 7 MHz');
   CheckEquals('LSB',   N1MMModeName(Phone, eLSB, 14200000),      'eLSB at 14 MHz');
   CheckEquals('FM',    N1MMModeName(FM, eFM, 146520000),         'eFM');
   CheckEquals('FM',    N1MMModeName(FM, eFM_N, 146520000),       'eFM_N');
   CheckEquals('FM',    N1MMModeName(FM, eWFM, 146520000),        'eWFM');
   CheckEquals('AM',    N1MMModeName(Phone, eAM, 3885000),        'eAM');
   CheckEquals('AM',    N1MMModeName(Phone, eAM_N, 3885000),      'eAM_N');
   CheckEquals('MFSK',  N1MMModeName(Digital, eMFSK, 14080000),   'eMFSK');
   CheckEquals('JS8',   N1MMModeName(Digital, eJS8, 14078000),    'eJS8');
   CheckEquals('C4FM',  N1MMModeName(Digital, eC4FM, 146520000),  'eC4FM');
   CheckEquals('DSTAR', N1MMModeName(Digital, eDStar, 146520000), 'eDStar');
end;

procedure TN1MMModeTests.Test_SidebandFollowsTheFrequency;
begin
   BeginTest('Test_SidebandFollowsTheFrequency');
   CheckEquals('LSB', N1MMSidebandForFreq(3750000),  '3.75 MHz');
   CheckEquals('USB', N1MMSidebandForFreq(5330500),  '60 m channel');
   CheckEquals('USB', N1MMSidebandForFreq(5403500),  '60 m US channel 5403.5');
   CheckEquals('USB', N1MMSidebandForFreq(5300000),  '60 m lower edge inclusive');
   CheckEquals('USB', N1MMSidebandForFreq(5500000),  '60 m upper edge inclusive');
   CheckEquals('LSB', N1MMSidebandForFreq(7150000),  '7.15 MHz');
   CheckEquals('USB', N1MMSidebandForFreq(14200000), '14.2 MHz');
   CheckEquals('LSB', N1MMModeName(Phone, eSSB, 7150000),   'eSSB at 7.15 MHz');
   CheckEquals('USB', N1MMModeName(Phone, eSSB, 14200000),  'eSSB at 14.2 MHz');
   CheckEquals('USB', N1MMModeName(Phone, eSSB, 5403500),   'eSSB on 60 m');
end;

procedure TN1MMModeTests.Test_NoExtModeFallsBackToTheBaseMode;
begin
   BeginTest('Test_NoExtModeFallsBackToTheBaseMode');
   CheckEquals('CW',   N1MMModeName(CW, eNoMode, 14025000),      'CW');
   CheckEquals('LSB',  N1MMModeName(Phone, eNoMode, 7150000),    'Phone 7.15 MHz');
   CheckEquals('USB',  N1MMModeName(Phone, eNoMode, 14200000),   'Phone 14.2 MHz');
   CheckEquals('USB',  N1MMModeName(Phone, eNoMode, 5403500),    'Phone 60 m');
   CheckEquals('RTTY', N1MMModeName(Digital, eNoMode, 14080000), 'Digital');
   CheckEquals('FM',   N1MMModeName(FM, eNoMode, 146520000),     'FM');
   CheckEquals('CW',   N1MMModeName(Both, eNoMode, 14025000),    'Both');
   CheckEquals('CW',   N1MMModeName(NoMode, eNoMode, 14025000),  'NoMode');
end;

procedure TN1MMModeTests.Test_ExternalLoggerAdifModePair;
var
   q: ContestExchange;
   m, s: string;
begin
   BeginTest('Test_ExternalLoggerAdifModePair');
   (* BuildDXKeeperLogMessage is private to a logger that needs a live TCP
     connection to be constructed, so the pair it sends is pinned at the
     routine it calls. *)
   q := Default(ContestExchange);
   q.ExtMode := eData;
   ResolveADIFModeSubmode(q, m, s);
   CheckEquals('RTTY', m, 'eData MODE');
   CheckEquals('', s, 'eData SUBMODE');

   q.ExtMode := eFT4;
   ResolveADIFModeSubmode(q, m, s);
   CheckEquals('MFSK', m, 'eFT4 MODE');
   CheckEquals('FT4', s, 'eFT4 SUBMODE');

   q.ExtMode := eNoMode;
   q.Mode := Digital;
   ResolveADIFModeSubmode(q, m, s);
   CheckEquals('RTTY', m, 'Digital with no ExtMode');
end;

procedure TN1MMModeTests.RunAllTests;
begin
   Test_EveryExtModeHasAWireNameNotATR4WName;
   Test_EachRowIsPinned;
   Test_SidebandFollowsTheFrequency;
   Test_NoExtModeFallsBackToTheBaseMode;
   Test_ExternalLoggerAdifModePair;
end;

end.
