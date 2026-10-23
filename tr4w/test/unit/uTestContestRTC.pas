(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE REAL TIME CONTEST (RTC) -- the 2026 rules
   (https://blog.contestonlinescore.com/real-time-contest-rtc-rules/, read
   2026-10-23).

   "Each station may be worked only ONCE per band on CW, and ONCE per band
   on SSB" -- the sponsor's "most important change". Multipliers are
   "unique 4-character grid locators worked per band" -- per band, NOT per
   mode. Bands 40, 20, 15 and 10 m; modes CW and SSB.

   Test_RTCDupesPerBandAndModeMultipliersPerBand drives the REAL engine --
   ParametersOkay, the dupe question LogContact asks, SetMultFlags and the
   sheets -- with the dupe and multiplier settings taken FROM THE CLASS, as
   FCONTEST.ApplyContestTraits writes them, so a wrong flag is seen as a
   wrong dupe or a wrong multiplier, not only as a wrong set. *)
unit uTestContestRTC;

{$I tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestRTCTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RTCStatesItsBandsModesAndFlags;
      procedure Test_RTCDupesPerBandAndModeMultipliersPerBand;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestRegistry,
   (* ReleaseActiveContest *)
   uContestFactory,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   LogDupe,
   LogEdit,
   LogWind,
   LogStuff,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   MainUnit;

(* ---------------------------------------------------------------------------
   WHAT THE CLASS STATES
   --------------------------------------------------------------------------- *)

procedure TContestRTCTests.Test_RTCStatesItsBandsModesAndFlags;
var
   c: TContestBase;
   b: BandType;
begin
   BeginTest('Test_RTCStatesItsBandsModesAndFlags');
   c := ContestIdentity(RTC);

   (* "Bands: 40m, 20m, 15m, 10m." Every real band -- AllBands and NoBand
      are keys, not bands. *)
   for b := Band160 to BandLight do
      begin
      if b in [Band40, Band20, Band15, Band10] then
         begin
         CheckTrue(ContestCreditsBand(c, b), 'RTC credits band ' + IntToStr(Ord(b)));
         end
      else
         begin
         CheckFalse(ContestCreditsBand(c, b), 'RTC refuses band ' + IntToStr(Ord(b)));
         end;
      end;

   (* "mixed mode format (CW and SSB)": SSB is Phone, FM refused (Q120(a)). *)
   CheckTrue(ContestCreditsMode(c, CW, eNoMode), 'credits CW');
   CheckTrue(ContestCreditsMode(c, Phone, eUSB), 'credits SSB');
   CheckTrue(ContestCreditsMode(c, Phone, eNoMode), 'phone with no submode is never off-mode');
   CheckFalse(ContestCreditsMode(c, FM, eFM), 'refuses FM');
   CheckFalse(ContestCreditsMode(c, Digital, eRTTY), 'refuses RTTY');
   CheckFalse(ContestCreditsMode(c, Digital, eFT8), 'refuses FT8');

   (* Dupes per band AND mode; multipliers per band, NOT per mode. *)
   CheckTrue(c.QSOByBand, 'QSOs by band');
   CheckTrue(c.QSOByMode, 'QSOs by mode -- once per band on CW, once on SSB (2026)');
   CheckTrue(c.MultByBand, 'grids by band');
   CheckFalse(c.MultByMode, 'grids NOT by mode');
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay, the dupe question and the sheets
   --------------------------------------------------------------------------- *)

procedure TContestRTCTests.Test_RTCDupesPerBandAndModeMultipliersPerBand;
var
   rtcHandle: TContestHandle;
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedGrid: string;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   ctyPath: string;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets. Returns whether it was a dupe. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; out aAccepted: boolean;
                  var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      ActiveMode := aMode;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                                  14025000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
      Result := False;
      if aAccepted then
         begin
         Result := VisibleLog.QSOIsADupe(aRX);
         if Result then
            begin
            aRX.ceDupe := True;
            aRX.QSOPoints := 0;
            end;
         Sheet.SetMultFlags(aRX);
         Sheet.AddQSOToSheets(@aRX, False);
         AddQSOToDupeSheets(aRX, False);
         end;
   end;

begin
   BeginTest('Test_RTCDupesPerBandAndModeMultipliersPerBand');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   rtcHandle := ContestHandleOf(RTC);
   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedGrid := Settings.My.Grid;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      (* AS FoundContest SETS IT UP: no domestic countries (the matrix's
         `domestic.countries =` line for RTC is empty), MY GRID FN36, and
         the class's flags. *)
      DomesticCountries.Clear;
      Settings.My.Grid := 'FN36';
      CheckEquals('FN36', Settings.My.ResolvedGrid,
                  'precondition: MY GRID resolves to FN36 (no contest override)');
      Contest := rtcHandle;
      ReleaseActiveContest;
      Settings.Qso.ByBand := ContestIdentity(rtcHandle).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(rtcHandle).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(rtcHandle).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(rtcHandle).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* 20 m CW: FN36 to JO62 is between 4000 and 8000 km -- 3 points, and
         JO62 is a new grid on 20 m. *)
      dupe := Enter('DL1AAA', '599 001 JO62', Band20, CW, accepted, rx);
      CheckTrue(accepted, '599 001 JO62 is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the first QSO is not a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), 'FN36 to JO62 scores 3');
      CheckTrue(rx.DomesticMult, 'JO62 is a new multiplier on 20 m');

      (* "ONCE per band on CW, and ONCE per band on SSB": the same station on
         20 m SSB is a new QSO and earns its points ... *)
      dupe := Enter('DL1AAA', '59 002 JO62', Band20, Phone, accepted, rx);
      CheckTrue(accepted, '59 002 JO62 on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB after 20 m CW is NOT a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores its 3 points');
      (* ... but "grid locators worked per band": JO62 is not a new
         multiplier on 20 m SSB once worked on 20 m CW. *)
      CheckFalse(rx.DomesticMult, 'JO62 on 20 m SSB is NOT a new multiplier after 20 m CW');

      (* Same band, same mode: a dupe, 0 points. *)
      dupe := Enter('DL1AAA', '599 003 JO62', Band20, CW, accepted, rx);
      CheckTrue(dupe, 'the same station again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      dupe := Enter('DL1AAA', '59 004 JO62', Band20, Phone, accepted, rx);
      CheckTrue(dupe, 'the same station again on 20 m SSB IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* THE CONTROL, per band: the same grid on 40 m is a new multiplier. *)
      dupe := Enter('DL1AAA', '599 005 JO62', Band40, CW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckTrue(rx.DomesticMult, 'JO62 IS a new multiplier on 40 m');

      (* Off its bands: logged, an automatic X-QSO, nothing earned. *)
      dupe := Enter('DL2BBB', '599 006 JO51', Band80, CW, accepted, rx);
      CheckTrue(accepted, 'an 80 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(rtcHandle), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      Settings.My.Grid := savedGrid;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestRTCTests.RunAllTests;
begin
   Test_RTCStatesItsBandsModesAndFlags;
   Test_RTCDupesPerBandAndModeMultipliersPerBand;
end;

end.
