unit uTestOffBandCredit;

{$I ..\..\src\tr4w.inc}

(* AN OFF-BAND QSO EARNS NO MULTIPLIER, AND MAKES NONE WORKED -- M3, 2026-10-01.

  NY4I, 2026-10-01: "if I work an off-band multiplier, it should not make it
  appear worked when I find the same mult on-band" (docs/CONTEST_OWNERSHIP_DESIGN.md
  7.4). 1e4f66f9 made LOGDUPE's DupeAndMultSheet.SetMultFlags return before
  any multiplier flag is set for a band the contest does not use, and
  AddQSOToSheets marks the sheet only from those flags -- so this should hold.
  Until now it was READ FROM THE CODE; this pins it through the real sheet.

  WHAT IS DRIVEN IS THE ENGINE'S OWN PAIR, in the order logsubs2 logs a QSO:
  Sheet.SetMultFlags, then Sheet.AddQSOToSheets, on the program's own mult
  object (uMults.mo). Idaho is the contest: it is the one that states its
  bands (160/80/40/20/15/10 m), and its multipliers count once per MODE, not
  per band (the frozen contest matrix: MULT BY MODE TRUE, MULT BY BAND
  unset). That is the case that matters, because a multiplier not counted
  per band is exactly the one an off-band QSO could steal.

  THE GLOBALS SET-UP WOULD WRITE ARE SET BY HAND -- the contest, the mult by
  band/mode flags, DoingDomesticMults and the domestic multiplier kind -- and
  restored afterwards, so no other suite sees them. The domestic multiplier
  is used because its store (a sorted string list) needs no CTY.DAT, where
  the DX store refuses a country number until a country file is loaded.

  THE POSITIVE CONTROL IS THE THIRD QSO. Without it, "the on-band QSO is
  still a new multiplier" would also pass if the sheet never marked anything
  at all. 40 m after 20 m on CW must NOT be new, which proves the sheet
  does record a worked multiplier when it is given one.

  NOT PINNED HERE -- THE DUPE HALF. "An off-band QSO is not a dupe and makes
  no later on-band QSO a dupe" goes through uCallsigns.CallsignsList, and
  TCallsignsList.AddCallsign marks the AllBands bit for EVERY logged QSO,
  off-band included. For a contest whose QSOs are NOT counted per band, that
  makes an off-band contact a dupe of a later on-band one. Idaho counts QSOs
  per band, so no shipped contest reaches it today; it is recorded for M8
  (design doc 7.4) rather than pinned as a failing test. *)

interface

uses
   uTR4WTestFramework;

type
   TOffBandCreditTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OffBandMultiplierLeavesItNeededOnBand;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uMults,
   uContestBase,
   uContestFactory,
   LogDupe,
   LogDom,
   LogStuff,
   PostUnit;

procedure TOffBandCreditTests.Test_OffBandMultiplierLeavesItNeededOnBand;
var
   savedContest: ContestType;
   savedByBand: boolean;
   savedByMode: boolean;
   savedDoingDomestic: boolean;
   savedDoingDX: boolean;
   savedDoingPrefix: boolean;
   savedDoingZone: boolean;
   savedDomesticMult: DomesticMultType;
   savedDomesticByBand: TAdditionalMultByBand;
   savedRestart: RestartInfo;

   (* One QSO with Idaho's Ada county, as SetMultFlags leaves it -- then
      added to the sheets, as logsubs2 does next. Returns the domestic
      multiplier flag SetMultFlags set. *)
   function LogAda(aBand: BandType): boolean;
   var
      rx: ContestExchange;
   begin
      FillChar(rx, SizeOf(rx), 0);
      rx.ceRecordKind := rkQSO;
      rx.Callsign := 'W7ABC';
      rx.Band := aBand;
      rx.Mode := CW;
      rx.Zone := DUMMYZONE;
      rx.DomesticQTH := 'ADA';
      rx.DomMultQTH := 'ADA';
      Sheet.SetMultFlags(rx);
      Result := rx.DomesticMult;
      Sheet.AddQSOToSheets(@rx, False);
   end;

begin
   BeginTest('Test_OffBandMultiplierLeavesItNeededOnBand');

   savedContest := Contest;
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedDoingDomestic := DoingDomesticMults;
   savedDoingDX := DoingDXMults;
   savedDoingPrefix := DoingPrefixMults;
   savedDoingZone := DoingZoneMults;
   savedDomesticMult := ActiveDomesticMult;
   savedDomesticByBand := DomesticMultByBand;
   savedRestart := tRestartInfo;
   try
      Contest := IDAHOQSOPARTY;
      Settings.Mult.ByBand := False;
      Settings.Mult.ByMode := True;
      DoingDomesticMults := True;
      DoingDXMults := False;
      DoingPrefixMults := False;
      DoingZoneMults := False;
      ActiveDomesticMult := DomesticFile;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      CheckTrue(ActiveContest(Contest) <> nil, 'Idaho QSO Party has no registered class');
      CheckFalse(ContestCreditsBand(ActiveContest(Contest), Band30),
                 'Idaho does not use 30 m');

      (* Off-band: logged, no multiplier, nothing marked. *)
      CheckFalse(LogAda(Band30), 'a 30 m QSO with Ada earns no multiplier');
      CheckEquals(0, Integer(mo.MTotals[AllBands, Both, rmDomestic]),
                  'and the sheet counts no domestic multiplier');

      (* On-band, same multiplier, same mode: still new. *)
      CheckTrue(LogAda(Band20), 'Ada on 20 m is still a NEW multiplier after 30 m');
      CheckEquals(1, Integer(mo.MTotals[AllBands, Both, rmDomestic]),
                  'the on-band QSO is the one that counts');

      (* THE CONTROL: the sheet does mark a worked multiplier. Not per band,
         so 40 m CW after 20 m CW is not new. *)
      CheckFalse(LogAda(Band40), 'Ada on 40 m CW is worked -- the sheet marks');
      CheckEquals(1, Integer(mo.MTotals[AllBands, Both, rmDomestic]),
                  'and is not counted twice');
   finally
      mo.ClearAllMults;
      tRestartInfo := savedRestart;
      DomesticMultByBand := savedDomesticByBand;
      ActiveDomesticMult := savedDomesticMult;
      DoingZoneMults := savedDoingZone;
      DoingPrefixMults := savedDoingPrefix;
      DoingDXMults := savedDoingDX;
      DoingDomesticMults := savedDoingDomestic;
      Settings.Mult.ByMode := savedByMode;
      Settings.Mult.ByBand := savedByBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

procedure TOffBandCreditTests.RunAllTests;
begin
   Test_OffBandMultiplierLeavesItNeededOnBand;
end;

end.
