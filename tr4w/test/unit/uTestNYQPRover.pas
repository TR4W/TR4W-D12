(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* A NEW YORK QSO PARTY ROVER, WORKED FROM OUTSIDE NEW YORK -- NY4I's field
  report, 2026-10-17 (NYQP running that day): W2TZ/STE called CQ, sent STE
  (Steuben), and later moved to Kings. And Q118, ruled the same day: "New
  QSO per county" -- the same call on the same band and mode with a
  DIFFERENT county received is a new QSO (DXLog's
  DOUBLE_QSO=PER_BAND_MODE_RCVD), and "Keep W2TZ/STE" in Cabrillo.

  THROUGH THE LIVE ENTRY ROUTINE, NOT A COPY OF IT. Each QSO goes through
  MainUnit.ParametersOkay -- the routine TryLogContact calls on Enter, which
  does the rover-stripped CTY lookup, LOGSTUFF.ProcessExchange (the NYQP
  class's ParseReceivedExchangeFormat -> the engine's RSTDomesticQTH parser)
  and the points -- against the REAL newyork_cty.dom (the out-of-state
  station's county file), then the steps LogSubs2.LogContact runs after it,
  through the same routines: the dupe question (VisibleLog.QSOIsADupe), the
  multiplier flags (Sheet.SetMultFlags) and the sheets, and the dupe sheets
  (LOGEDIT.AddQSOToDupeSheets). The rescore is the body of tUpdateLog's
  actRescore loop over the same records: RecomputeQSOScoring,
  VisibleLog.QSOIsADupe, AddQSOToDupeSheets.

  WHAT IS PINNED
    1. W2TZ/STE sending STE: accepted, the call is STORED AS TYPED
       (W2TZ/STE), the country is the stripped call's (K), Steuben is a new
       county multiplier, CW scores 2 and phone 1. ADIF splits it: CALL
       W2TZ, APP_TR4W_ROVERCALL W2TZ/STE (Q90).
    2. W2TZ/KIN sending KIN, same band and mode, is NOT a dupe and IS a new
       multiplier; W2TZ/STE again on the same band and mode IS a dupe;
       W2TZ/KIN on another band or mode is not.
    3. Q118, as narrowed by NY4I on 2026-10-18: after the plain W2TZ
       sending KIN, the CALL WINDOW'S check (VisibleLog.CallIsADupe on the
       call window, band and mode -- the expression ShowInformation and
       WindowDupeCheck evaluate) reports W2TZ a DUPE on the same band and
       mode; logging W2TZ sending STE is NOT a dupe and scores; W2TZ
       sending KIN again IS a dupe. "If we consider it a dupe until that
       second contact with a new county comes in, that is a reasonable
       compromise."
    4. A rescore of that log marks exactly the dupes the live path marked.
    5. NYQP is in the rover set (TContestStateQSOPartyBase, Q90/Q94); every
       state party, and no other contest but New England (its sponsor,
       2026-10-23), the 7QP and IN7QPNE (their sponsors, #88 round 3,
       2026-10-26), qualifies its dupe key by the received QTH ("All state
       parties").

  "Hint, don't block" (2026-10-17) was WITHDRAWN on 2026-10-18 and its
  pins with it: no check made before the exchange exists consults the
  received QTH. *)
unit uTestNYQPRover;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TNYQPRoverTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NYQPIsInTheRoverSet;
      procedure Test_EveryStatePartyQualifiesItsDupeKey;
      procedure Test_TheQualifiedSheetKeepsLongKeysApart;
      procedure Test_ARoverFromOutOfStateLogsScoresAndSplits;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uMults,
   uCallsigns,
   uCTYDAT,
   uADIF,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestStateQSOPartyBase,
   (* TContestNewEnglandQP -- the one contest off the party base that
      qualifies its dupe key (its sponsor, 2026-10-23). *)
   uContestNewEnglandQP,
   (* TContestSevenQP and TContestIN7QPNE -- the multi-state parties that
      qualify it by their sponsors' rules (#88 round 3, 2026-10-26). *)
   uContestSevenQP,
   uContestIN7QPNE,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit;

procedure TNYQPRoverTests.Test_NYQPIsInTheRoverSet;
begin
   BeginTest('Test_NYQPIsInTheRoverSet');
   CheckTrue(ContestStripsRoverCountyFromCall(ContestIdentity(ContestHandleOf(NYQP))),
             'NYQP strips a /county from the call for the country lookup');
   CheckTrue(ContestSplitsRoverCallOnExport(ContestHandleOf(NYQP)),
             'NYQP splits a rover call on ADIF export');
end;

(* Q118, "All state parties": by a walk of the registry, a contest
   qualifies its dupe key by the received QTH exactly when it is on
   TContestStateQSOPartyBase -- or is one of the three multi-state parties
   off that base whose sponsors say so in their own words: New England
   (2026-10-23: "Mobiles that change counties are considered to be new
   stations"; uTestContestNewEnglandQP), and since #88 round 3 (2026-10-26)
   the 7QP ("7th-area mobiles ... may be worked again as they enter new
   counties"; uTestContestSevenQP) and IN7QPNE (every one of its parties
   says so; uTestContestIN7QPNE). Every other contest answers '' -- the
   call alone. *)
procedure TNYQPRoverTests.Test_EveryStatePartyQualifiesItsDupeKey;
var
   contests: TContestIdentityList;
   i: integer;
   qso: ContestExchange;
   isParty: boolean;
   qualifies: boolean;
   parties: integer;
begin
   BeginTest('Test_EveryStatePartyQualifiesItsDupeKey');
   FillChar(qso, SizeOf(ContestExchange), 0);
   qso.Callsign := 'W2TZ';
   qso.QTHString := 'STE';
   qso.DomesticQTH := 'STE';
   qso.DomMultQTH := 'Ste';
   parties := 0;
   contests := RegisteredContests;
   for i := 0 to High(contests) do
      begin
      isParty := contests[i] is TContestStateQSOPartyBase;
      if isParty then
         begin
         Inc(parties);
         end;
      qualifies := isParty or
                   (contests[i] is TContestNewEnglandQP) or
                   (contests[i] is TContestSevenQP) or
                   (contests[i] is TContestIN7QPNE);
      CheckTrue(ContestDupeKeyIncludesReceivedQTH(contests[i]) = qualifies,
                contests[i].ClassName + ': qualifies its dupe key exactly when a state party, New England, 7QP or IN7QPNE');
      CheckTrue((ContestDupeKeyQualifier(contests[i], qso) <> '') = qualifies,
                contests[i].ClassName + ': answers a qualifier exactly when a state party, New England, 7QP or IN7QPNE');
      end;
   CheckTrue(parties >= 21, 'the state parties were found (' + IntToStr(parties) + ')');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(ContestHandleOf(CALQSOPARTY))),
             'California (DXLog RECINFO) qualifies');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(ContestHandleOf(PAQSOPARTY))),
             'Pennsylvania (DXLog RECINFO) qualifies');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(ContestHandleOf(VAQP))),
             'Virginia (DXLog RECINFO) qualifies');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(ContestHandleOf(SEVENQP))),
             '7QP is not on the state-party base and qualifies by its own rule (#88 round 3)');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(ContestHandleOf(IN7QPNE))),
             'IN7QPNE qualifies by its parties'' rules (#88 round 3)');
   CheckFalse(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(ContestHandleOf(NAQSOCW))),
              'NAQP is no state party');
   CheckFalse(ContestDupeKeyIncludesReceivedQTH(nil), 'the classless contest does not');
   CheckEquals('STE', ContestDupeKeyQualifier(ContestIdentity(ContestHandleOf(NYQP)), qso),
               'NYQP: the received county');
   qso.DomesticQTH := '';
   qso.QTHString := 'dx';
   CheckEquals('DX', ContestDupeKeyQualifier(ContestIdentity(ContestHandleOf(NYQP)), qso),
               'NYQP: no domestic QTH, the QTH as typed, upper case');
   qso.QTHString := '';
   CheckEquals('', ContestDupeKeyQualifier(ContestIdentity(ContestHandleOf(NYQP)), qso),
               'NYQP: nothing received, the call alone');
end;

(* A CALL PLUS A COUNTY IS LONGER THAN A CallString: the sheet must not cut
   it, or SCH, SCO and SCU would be one key. *)
procedure TNYQPRoverTests.Test_TheQualifiedSheetKeepsLongKeysApart;
var
   sheet: TQualifiedDupeSheet;
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
begin
   BeginTest('Test_TheQualifiedSheetKeepsLongKeysApart');
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   sheet := TQualifiedDupeSheet.Create;
   try
      Contest := ContestHandleOf(NYQP);
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := True;
      sheet.AddQSO('KC2ABC/STE', 'SCH', CW, Band20);
      CheckTrue(sheet.QSOIsDupe('KC2ABC/STE', 'SCH', Band20, CW), 'SCH again is a dupe');
      CheckFalse(sheet.QSOIsDupe('KC2ABC/STE', 'SCO', Band20, CW), 'SCO is not SCH');
      CheckFalse(sheet.QSOIsDupe('KC2ABC/STE', 'SCU', Band20, CW), 'SCU is not SCH');
      CheckTrue(sheet.QSOIsDupe('kc2abc/ste', 'SCH', Band20, CW), 'the call is case-blind');
      CheckFalse(sheet.QSOIsDupe('KC2ABC/STE', 'SCH', Band40, CW), 'another band is not');
      (* FM IS PHONE'S SLOT (uSortedStringList.DupeSlot), on both sides. *)
      sheet.AddQSO('W2TZ', 'KIN', FM, Band20);
      CheckTrue(sheet.QSOIsDupe('W2TZ', 'KIN', Band20, Phone), 'an FM QSO is a phone dupe');
      CheckTrue(sheet.QSOIsDupe('W2TZ', 'KIN', Band20, FM), 'and an FM one');
      sheet.ClearDupes;
      CheckFalse(sheet.QSOIsDupe('KC2ABC/STE', 'SCH', Band20, CW), 'cleared, nothing is');
   finally
      sheet.Free;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
   end;
end;

procedure TNYQPRoverTests.Test_ARoverFromOutOfStateLogsScoresAndSplits;
const
   LOGGED_MAX = 16;
var
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedInHostState: boolean;
   savedActiveMode: ModeType;
   savedActiveBand: BandType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   ctyPath: string;
   domPath: string;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   adif: string;
   (* The log as written, and the dupe each QSO was marked with live. *)
   logged: array[0..LOGGED_MAX - 1] of ContestExchange;
   liveDupe: array[0..LOGGED_MAX - 1] of boolean;
   loggedCount: integer;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets (a dupe is logged and reaches them
      too). Returns whether it was a dupe; aRX is the logged record. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; out aAccepted: boolean;
                  var aRX: ContestExchange): boolean;
   begin
      FillChar(aRX, SizeOf(ContestExchange), 0);
      ActiveMode := aMode;
      CallWindowString := CallString(aCall);
      aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                                  14025000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
      Result := VisibleLog.QSOIsADupe(aRX);
      if aAccepted then
         begin
         if Result then
            begin
            aRX.ceDupe := True;
            aRX.QSOPoints := 0;
            end;
         Sheet.SetMultFlags(aRX);
         Sheet.AddQSOToSheets(@aRX, False);
         AddQSOToDupeSheets(aRX, False);
         if loggedCount < LOGGED_MAX then
            begin
            logged[loggedCount] := aRX;
            liveDupe[loggedCount] := Result;
            Inc(loggedCount);
            end;
         end;
   end;

begin
   BeginTest('Test_ARoverFromOutOfStateLogsScoresAndSplits');

   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   domPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'dom' + PathDelim +
              'newyork_cty.dom';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   loggedCount := 0;
   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   savedActiveMode := ActiveMode;
   savedActiveBand := ActiveBand;
   savedCallWindow := CallWindowString;
   (* THE ENGINE'S TABLES, swapped for the test's own and put back: the
      domestic table every lookup reads, and both dupe sheets. *)
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      CheckTrue(DomQTHTable.LoadInDomQTHFile(domPath), 'newyork_cty.dom loads');

      (* NYQP, AS FoundContest SETS IT UP FOR A FLORIDA STATION: QSOs and
         multipliers by band and by mode (the class's flags), not in New York,
         so the out-of-state county file. *)
      Contest := ContestHandleOf(NYQP);
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := True;
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := True;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* 1. W2TZ/STE sending STE. *)
      dupe := Enter('W2TZ/STE', 'STE', Band20, CW, accepted, rx);
      CheckTrue(accepted, '1: W2TZ/STE sending STE is accepted');
      CheckFalse(dupe, '1: and is not a dupe');
      CheckEquals('W2TZ/STE', string(rx.Callsign), '1: the call is stored as typed');
      CheckEquals('K', string(rx.QTH.CountryID),
                  '1: the country is the stripped call''s');
      CheckEquals('STE', string(rx.QTHString), '1: the QTH is STE');
      CheckEquals('STE', UpperCase(string(rx.DomMultQTH)), '1: the multiplier is Steuben');
      CheckEquals(2, Integer(rx.QSOPoints), '1: a CW QSO scores 2');
      CheckTrue(rx.DomesticMult, '1: Steuben is a new multiplier');

      adif := EmitADIFRecord(rx);
      CheckTrue(Pos('<CALL:4>W2TZ', adif) > 0, '1: ADIF CALL is the bare W2TZ: ' + adif);
      CheckTrue(Pos('<APP_TR4W_ROVERCALL:8>W2TZ/STE', adif) > 0,
                '1: ADIF keeps W2TZ/STE in APP_TR4W_ROVERCALL');

      (* 2. W2TZ/KIN sending KIN, same band and mode: a new station, a new
         county. *)
      dupe := Enter('W2TZ/KIN', 'KIN', Band20, CW, accepted, rx);
      CheckTrue(accepted, '2: W2TZ/KIN sending KIN is accepted');
      CheckFalse(dupe, '2: W2TZ/KIN on 20 m CW is NOT a dupe of W2TZ/STE');
      CheckEquals(2, Integer(rx.QSOPoints), '2: and scores 2');
      CheckTrue(rx.DomesticMult, '2: Kings is a new multiplier');

      dupe := Enter('W2TZ/STE', 'STE', Band20, CW, accepted, rx);
      CheckTrue(dupe, '2: W2TZ/STE again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), '2: and scores 0');

      dupe := Enter('W2TZ/KIN', 'KIN', Band40, CW, accepted, rx);
      CheckFalse(dupe, '2: W2TZ/KIN on 40 m is not a dupe');
      CheckTrue(rx.DomesticMult, '2: and Kings on 40 m is a new multiplier (by band)');

      dupe := Enter('W2TZ/KIN', 'KIN', Band20, Phone, accepted, rx);
      CheckFalse(dupe, '2: W2TZ/KIN on 20 m phone is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '2: a phone QSO scores 1');

      (* 3. The plain call -- Q118, a new QSO per county; the call window
         still says DUPE (the 2026-10-18 compromise). *)
      dupe := Enter('W2TZ', 'KIN', Band20, CW, accepted, rx);
      CheckTrue(accepted, '3: plain W2TZ sending KIN is accepted');
      CheckFalse(dupe, '3: plain W2TZ is not a dupe of W2TZ/STE or W2TZ/KIN');
      CheckEquals('W2TZ', string(rx.Callsign), '3: and is stored as W2TZ');
      CheckEquals(2, Integer(rx.QSOPoints), '3: it scores 2');
      CheckFalse(rx.DomesticMult, '3: Kings on 20 m CW is already worked');

      (* THE CALL WINDOW, BEFORE ANY EXCHANGE: the expression ShowInformation
         (B4, and so AUTO DUPE) and WindowDupeCheck evaluate, on the call
         window, the active band and the active mode -- the call alone. *)
      ActiveBand := Band20;
      ActiveMode := CW;
      CallWindowString := 'W2TZ';
      CheckTrue(VisibleLog.CallIsADupe(CallWindowString, ActiveBand, ActiveMode),
                '3: the call window reports W2TZ a DUPE on 20 m CW');
      ActiveBand := Band40;
      CheckFalse(VisibleLog.CallIsADupe(CallWindowString, ActiveBand, ActiveMode),
                 '3: and not on 40 m, where plain W2TZ was never worked');
      ActiveBand := Band20;

      dupe := Enter('W2TZ', 'STE', Band20, CW, accepted, rx);
      CheckTrue(accepted, '3: plain W2TZ sending STE is accepted');
      CheckFalse(dupe, '3: Q118 -- plain W2TZ sending STE after KIN, same band and mode, is NOT a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), '3: and scores 2');

      dupe := Enter('W2TZ', 'KIN', Band20, CW, accepted, rx);
      CheckTrue(dupe, '3: plain W2TZ sending KIN again IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), '3: and scores 0');

      (* 4. THE RESCORE of the same log: every dupe sheet emptied, each record
         rescored and re-asked in log order, as tUpdateLog(actRescore). *)
      CheckEquals(8, loggedCount, '4: eight QSOs were logged');
      Sheet.DisposeOfMemoryAndZeroTotals;
      for i := 0 to loggedCount - 1 do
         begin
         rx := logged[i];
         RecomputeQSOScoring(rx);
         dupe := VisibleLog.QSOIsADupe(rx);
         Sheet.AddQSOToSheets(@rx, False);
         AddQSOToDupeSheets(rx, rx.ceClearDupeSheet);
         CheckTrue(dupe = liveDupe[i],
                   '4: the rescore marks QSO ' + IntToStr(i + 1) + ' (' +
                   string(rx.Callsign) + ' ' + string(rx.QTHString) +
                   ') as the live path did');
         end;
   finally
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      ActiveBand := savedActiveBand;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

procedure TNYQPRoverTests.RunAllTests;
begin
   Test_NYQPIsInTheRoverSet;
   Test_EveryStatePartyQualifiesItsDupeKey;
   Test_TheQualifiedSheetKeepsLongKeysApart;
   Test_ARoverFromOutOfStateLogsScoresAndSplits;
end;

end.
