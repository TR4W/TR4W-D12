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

  THE DUPE HALF -- PINNED AT M8 (2026-10-02). "An off-band QSO is not a dupe
  and makes no later on-band QSO a dupe" goes through uCallsigns'
  TCallsignsList, and until M8 AddCallsign marked the AllBands bit for EVERY
  logged QSO, off-band included -- so in a contest whose QSOs are NOT counted
  per band an off-band contact made the same station a dupe on every band.
  Idaho counts QSOs per band, so no shipped contest reached it; the test
  turns QSO-by-band OFF for Idaho to stand in for such a contest, and drives
  a list of its own so the program's CallsignsList is untouched.

  THE HINT -- PINNED AT M8. "Off-band should not impact need multiplier":
  LOGEDIT's DetermineIfNewMult says no multiplier is needed on a band the
  contest does not use, uContestBase.CreditedBands clears those bands from
  the needs strip, and DetermineIfNewDomesticMult asked with the AllBands key
  answers for the band the operator is on -- which also fixed it saying
  "not needed" for every Idaho county, always (SetMultFlags credits no
  AllBands for a contest that states its bands). *)

interface

uses
   uTR4WTestFramework;

type
   TOffBandCreditTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OffBandMultiplierLeavesItNeededOnBand;
      procedure Test_OffBandQSOIsNoDupeAndMakesNone;
      procedure Test_EveryBandStillMarksDupesForAContestUsingThemAll;
      procedure Test_CreditedBandsClearsOnlyUnusedBands;
      procedure Test_OffBandShowsNoMultiplierNeeded;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit;

(* A LIST OF THE TEST'S OWN -- zeroed first, because a local object's fields
   are not, and Init grows from the capacity it finds. *)
procedure InitList(var aList: TCallsignsList);
begin
   FillChar(aList, SizeOf(aList), 0);
   aList.Init;
end;

function IsDupe(var aList: TCallsignsList; aBand: BandType): boolean;
var
   index: integer;
begin
   Result := aList.CallsignIsDupe('W7ABC', aBand, CW, index);
end;

procedure TOffBandCreditTests.Test_OffBandQSOIsNoDupeAndMakesNone;
var
   list: TCallsignsList;
   savedContest: ContestType;
   savedByBand: boolean;
   savedByMode: boolean;
begin
   BeginTest('Test_OffBandQSOIsNoDupeAndMakesNone');

   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   InitList(list);
   try
      Contest := IDAHOQSOPARTY;
      Settings.Qso.ByMode := True;

      (* A CONTEST WHOSE QSOs ARE NOT COUNTED PER BAND -- the case M3 found. *)
      Settings.Qso.ByBand := False;

      list.AddCallsign('W7ABC', CW, Band30, False);
      CheckFalse(IsDupe(list, Band20),
                 'a 30 m QSO makes no later 20 m QSO a dupe');
      CheckFalse(IsDupe(list, Band30),
                 'nor a second 30 m QSO');

      list.AddCallsign('W7ABC', CW, Band20, False);
      (* THE CONTROL: an on-band QSO does mark, and, not per band, on every
         band the contest uses. *)
      CheckTrue(IsDupe(list, Band40),
                'a 20 m QSO makes a 40 m QSO a dupe when QSOs are not per band');
      CheckFalse(IsDupe(list, Band30),
                 'an off-band QSO is never a dupe, even of an on-band one');

      (* PER BAND -- Idaho as it ships. *)
      Settings.Qso.ByBand := True;
      CheckTrue(IsDupe(list, Band20), 'per band: 20 m again is a dupe');
      CheckFalse(IsDupe(list, Band40), 'per band: 40 m is new');
      CheckFalse(IsDupe(list, Band30), 'per band: 30 m is still no dupe');
   finally
      list.Done;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
      end;
end;

procedure TOffBandCreditTests.Test_EveryBandStillMarksDupesForAContestUsingThemAll;
var
   list: TCallsignsList;
   savedContest: ContestType;
   savedByBand: boolean;
   savedByMode: boolean;
begin
   BeginTest('Test_EveryBandStillMarksDupesForAContestUsingThemAll');

   (* THE DEFAULT IS UNCHANGED: a contest that states no bands credits every
      band, so a 30 m QSO is a dupe of a 20 m one when QSOs are not per band,
      exactly as before M8. CQ WW CW is one such contest; its class is
      registered and states no UsesBand. *)
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   InitList(list);
   try
      Contest := CQWWCW;
      CheckTrue(ContestCreditsBand(ContestIdentity(Contest), Band30),
                'CQ WW CW states no bands, so it credits 30 m');
      Settings.Qso.ByMode := True;
      Settings.Qso.ByBand := False;

      list.AddCallsign('W7ABC', CW, Band30, False);
      CheckTrue(IsDupe(list, Band20), 'a 30 m QSO still marks the station worked');
      CheckTrue(IsDupe(list, Band30), 'and 30 m again is a dupe');
   finally
      list.Done;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
      end;
end;

procedure TOffBandCreditTests.Test_CreditedBandsClearsOnlyUnusedBands;
var
   idaho: TContestBase;
   mask: Cardinal;
   b: BandType;
begin
   BeginTest('Test_CreditedBandsClearsOnlyUnusedBands');

   CheckEquals(Integer($12345678), Integer(CreditedBands(nil, $12345678)),
               'nil -- a classless contest -- credits every band');

   idaho := ContestIdentity(IDAHOQSOPARTY);
   mask := CreditedBands(idaho, $FFFFFFFF);
   for b := Low(BandType) to BandLight do
      begin
      CheckTrue(idaho.UsesBand(b) = ((mask and (Cardinal(1) shl Ord(b))) <> 0),
                'Idaho band ' + IntToStr(Ord(b)) + ' kept exactly when it is used');
      end;
   CheckTrue((mask and (Cardinal(1) shl Ord(AllBands))) <> 0,
             'the AllBands key is kept -- it is not a band');
end;

procedure TOffBandCreditTests.Test_OffBandShowsNoMultiplierNeeded;
var
   savedContest: ContestType;
   savedByBand: boolean;
   savedByMode: boolean;
   savedDoingDomestic: boolean;
   savedDoingDX: boolean;
   savedDoingPrefix: boolean;
   savedDoingZone: boolean;
   savedDomesticMult: DomesticMultType;
   savedDXMult: DXMultType;
   savedDXCCByBand: TAdditionalMultByBand;
   savedDomesticByBand: TAdditionalMultByBand;
   savedActiveBand: BandType;
   ctyPath: string;
   needs: integer;
   call: CallString;
begin
   BeginTest('Test_OffBandShowsNoMultiplierNeeded');

   (* The DX multiplier asks CTY.DAT for the call's country; the shipped file,
      relative to the test exe, as uTestCTYDAT loads it. *)
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest := Contest;
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedDoingDomestic := DoingDomesticMults;
   savedDoingDX := DoingDXMults;
   savedDoingPrefix := DoingPrefixMults;
   savedDoingZone := DoingZoneMults;
   savedDomesticMult := ActiveDomesticMult;
   savedDXMult := ActiveDXMult;
   savedDXCCByBand := DXCCMultByBand;
   savedDomesticByBand := DomesticMultByBand;
   savedActiveBand := ActiveBand;
   try
      Contest := IDAHOQSOPARTY;
      Settings.Mult.ByBand := False;
      Settings.Mult.ByMode := True;
      DoingDomesticMults := False;
      DoingDXMults := True;
      DoingPrefixMults := False;
      DoingZoneMults := False;
      ActiveDXMult := ARRLDXCCWithNoUSAOrCanada;
      DXCCMultByBand := dmbbDefauld;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;
      call := 'DL1ABC';

      (* THE DX HINT -- DetermineIfNewMult, behind the band map, the spots
         and the call window. *)
      CheckTrue(VisibleLog.DetermineIfNewMult(call, Band20, CW),
                'Germany is a needed multiplier on 20 m (the control)');
      CheckFalse(VisibleLog.DetermineIfNewMult(call, Band30, CW),
                 'and needed on no band Idaho does not use');

      (* THE DOMESTIC HINT, asked with the AllBands key as the not-per-band
         strip asks it: the band it is for is the operator's. *)
      DoingDXMults := False;
      DoingDomesticMults := True;
      ActiveDomesticMult := WYSIWYGDomestic;
      ActiveBand := Band20;
      VisibleLog.DetermineIfNewDomesticMult('ADA', AllBands, CW, needs);
      CheckEquals(1, needs, 'on 20 m, Ada is a needed county (was never, before M8)');
      ActiveBand := Band30;
      VisibleLog.DetermineIfNewDomesticMult('ADA', AllBands, CW, needs);
      CheckEquals(0, needs, 'on 30 m, no county is shown needed');
      VisibleLog.DetermineIfNewDomesticMult('ADA', Band30, CW, needs);
      CheckEquals(0, needs, 'and asked for 30 m itself, neither');
   finally
      mo.ClearAllMults;
      ActiveBand := savedActiveBand;
      DomesticMultByBand := savedDomesticByBand;
      DXCCMultByBand := savedDXCCByBand;
      ActiveDXMult := savedDXMult;
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
   Test_OffBandQSOIsNoDupeAndMakesNone;
   Test_EveryBandStillMarksDupesForAContestUsingThemAll;
   Test_CreditedBandsClearsOnlyUnusedBands;
   Test_OffBandShowsNoMultiplierNeeded;
end;

end.
