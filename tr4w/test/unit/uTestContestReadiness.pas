unit uTestContestReadiness;
{$I ..\..\src\tr4w.inc}

(*
  THE TWO DEFECTS OF 2026-09-20, PINNED.

  Both reached NY4I on the same Linux Mint bench session and they are
  independent; they only happened to fire together.

  1. MY COUNTRY WAS EMPTY, so ARRL DX SSB put a Florida station on the DX
     side and refused `K` (a kilowatt) as a received power. The value is
     DERIVED from MY CALL through CTY.DAT, and the tests here pin the
     derivation's inputs and the rule that protects an operator who stated
     a country of their own.

  2. THE DOMESTIC FILE NAME HAD BECOME A PATH, and then a path wrapped
     around a path, because the resolved path was stored back into a
     CONTEST-SCOPED setting and captured into the contest .db. The value in
     his log is reproduced here BYTE FOR BYTE.

  WHY THIS SUITE EXISTS AT ALL. The engine that made the decision --
  FCONTEST, ProcessExchange -- is not linkable here; CLAUDE.md says so and
  it is still true. What IS linkable is every piece the decision is built
  from: the CTY.DAT lookup, the settings object, and the readiness rules,
  which were written as a pure function for exactly this reason.
*)

interface

uses
   uTR4WTestFramework;

type
   TContestReadinessTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      FLoaded: boolean;
      procedure EnsureCtyLoaded;

      (* 1 -- the derivation's input: a callsign to a CTY.DAT prefix code. *)
      procedure Test_DeriveCountry_NY4I_IsK;
      procedure Test_DeriveCountry_VE3_IsVE;
      procedure Test_DeriveCountry_IK8_IsItaly;
      procedure Test_DeriveCountry_PortableCall;
      procedure Test_DeriveCountry_GarbageIsEmpty;
      procedure Test_DeriveCountry_EmptyCallIsEmpty;

      (* 1 -- the rule that stops a derivation overruling the operator. *)
      procedure Test_StatedCountryIsFlagged;
      procedure Test_DerivedCountryIsNotFlagged;
      procedure Test_EmptyAssignmentIsNotAStatedValue;

      (* 2 -- a name, never a path. *)
      procedure Test_DataFileNameOnly_PlainNameUnchanged;
      procedure Test_DataFileNameOnly_BothSeparators;
      procedure Test_DomesticFilename_StripsAPath;
      procedure Test_DomesticFilename_HealsTheLogNY4IActuallyHad;

      (* the readiness rules *)
      procedure Test_Readiness_SilentWhenNoContest;
      procedure Test_Readiness_ArrlDxWithEmptyCountryReports;
      procedure Test_Readiness_ArrlDxWithCountryIsSilent;
      procedure Test_Readiness_ContestThatDoesNotNeedStateIsSilent;
      procedure Test_Readiness_DomesticFileContestWithNoFile;
      procedure Test_Readiness_ZoneAndGrid;

      (* the rejection's attribution *)
      procedure Test_Attribution_NamesMyCountry;
      procedure Test_Attribution_EmptyForAnUnrelatedExchange;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uCTYDAT,
   uAppPaths,
   uSettingsModel,
   uContestReadiness;

const
   (* VERBATIM from NY4I's ARRL-DX-SSB 2026-09-20 contest database, read off
     the bench box. One run's AppImage mount point, a Windows separator, and
     the PREVIOUS run's mount point with the file at the end of it. *)
   POISONED_DOMESTIC_ROW =
      '/tmp/.mount_TR4W-5EnhBOm/usr/bin/dom\' +
      '/tmp/.mount_TR4W-5olHkON/usr/bin/dom/s48p14dc.dom';

procedure TContestReadinessTests.EnsureCtyLoaded;
var
   path: string;
begin
   if FLoaded then
      begin
      Exit;
      end;

   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
           PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(FileExists(path), 'cty.dat present at ' + path);
   if not FileExists(path) then
      begin
      Exit;
      end;

   CheckTrue(ctyLoadInCountryFile(path, False, False, {ReplaceTable} True),
             'ctyLoadInCountryFile succeeded');
   FLoaded := True;
end;

{ ------------------------------------------------ 1: callsign -> country --- }

(* ctyGetCountryID IS THE DERIVATION'S ANSWER. FCONTEST's
  RecalculateMyCountryContinentAndZoneNew assigns
  ctyLocateCall(...).CountryID into MY COUNTRY, and ctyGetCountryID is the
  same lookup with the record unpacked. Asserting it here is asserting what
  MY COUNTRY becomes. *)

procedure TContestReadinessTests.Test_DeriveCountry_NY4I_IsK;
begin
   BeginTest('Test_DeriveCountry_NY4I_IsK');
   EnsureCtyLoaded;
   (* THE CASE THAT COST THE BENCH SESSION. With this empty, ARRL DX takes
     its DX arm and asks a Florida station for a state. *)
   CheckEquals('K', Trim(ctyGetCountryID('NY4I')), 'NY4I is K');
end;

procedure TContestReadinessTests.Test_DeriveCountry_VE3_IsVE;
begin
   BeginTest('Test_DeriveCountry_VE3_IsVE');
   EnsureCtyLoaded;
   (* The other half of ARRL DX's `= K or = VE` test. *)
   CheckEquals('VE', Trim(ctyGetCountryID('VE3ABC')), 'VE3ABC is VE');
end;

procedure TContestReadinessTests.Test_DeriveCountry_IK8_IsItaly;
begin
   BeginTest('Test_DeriveCountry_IK8_IsItaly');
   EnsureCtyLoaded;
   (* The station NY4I was working when it went wrong. *)
   CheckEquals('I', Trim(ctyGetCountryID('IK8ABC')), 'IK8ABC is I');
end;

procedure TContestReadinessTests.Test_DeriveCountry_PortableCall;
begin
   BeginTest('Test_DeriveCountry_PortableCall');
   EnsureCtyLoaded;
   (* THE PREFIX DECIDES, NOT THE SUFFIX -- TR4W's rule, pinned in
     uTestCTYDAT.Test_Rule_PortablePrefixWins and Test_Rule_PortableSuffix-
     Retargets. So NY4I/VP2E derives K, not VP2E.

     I ASSERTED THE OPPOSITE FIRST AND THE SUITE SAID NO. That is worth
     leaving written down, because it is exactly why the derived value must
     never overwrite a stated one: an operator on a DXpedition who signs
     NY4I/VP2E and wants VP2E has to type it, and typing it must stick. *)
   CheckEquals('K', Trim(ctyGetCountryID('NY4I/VP2E')),
               'NY4I/VP2E derives K -- the prefix decides');
   CheckEquals('VP2E', Trim(ctyGetCountryID('VP2E/NY4I')),
               'VP2E/NY4I derives VP2E');
end;

procedure TContestReadinessTests.Test_DeriveCountry_GarbageIsEmpty;
begin
   BeginTest('Test_DeriveCountry_GarbageIsEmpty');
   EnsureCtyLoaded;
   (* MUST NOT CRASH AND MUST NOT GUESS. An unplaceable callsign leaves the
     setting empty, which is what the readiness check then reports. *)
   CheckEquals('', Trim(ctyGetCountryID('!!!!!!')),
               'garbage places nowhere');
end;

procedure TContestReadinessTests.Test_DeriveCountry_EmptyCallIsEmpty;
begin
   BeginTest('Test_DeriveCountry_EmptyCallIsEmpty');
   EnsureCtyLoaded;
   (* THE STATE NY4I WAS ACTUALLY IN. His station file held MAIN CALLSIGN
     and not MY CALL, so FCONTEST derived from ''. *)
   CheckEquals('', Trim(ctyGetCountryID('')), 'an empty callsign derives nothing');
end;

{ ------------------------------------- 1: the operator's answer wins -------- }

procedure TContestReadinessTests.Test_StatedCountryIsFlagged;
var
   my: TMySettings;
begin
   BeginTest('Test_StatedCountryIsFlagged');
   my := TMySettings.Create;
   try
      CheckFalse(my.CountryWasSet, 'nothing stated to begin with');
      my.Country := 'VP2E';
      CheckTrue(my.CountryWasSet,
                'assigning the property is the operator stating a country');
      CheckEquals('VP2E', my.Country, 'and it is kept');
   finally
      my.Free;
   end;
end;

procedure TContestReadinessTests.Test_DerivedCountryIsNotFlagged;
var
   my: TMySettings;
begin
   BeginTest('Test_DerivedCountryIsNotFlagged');
   my := TMySettings.Create;
   try
      my.DeriveCountry('K');
      CheckEquals('K', my.Country, 'the derived value is stored');
      (* THE WHOLE POINT: the derivation does not claim to be the operator,
        so a later run that finally has the callsign is free to redo it, and
        a Preferences entry still wins. *)
      CheckFalse(my.CountryWasSet,
                 'a derived value is not a stated one');
   finally
      my.Free;
   end;
end;

procedure TContestReadinessTests.Test_EmptyAssignmentIsNotAStatedValue;
var
   my: TMySettings;
begin
   BeginTest('Test_EmptyAssignmentIsNotAStatedValue');
   my := TMySettings.Create;
   try
      (* A settings file carrying MY COUNTRY = "" must not latch the flag,
        or the derivation would decline to run for ever after. *)
      my.Country := '';
      CheckFalse(my.CountryWasSet, 'an empty value states nothing');

      (* AND THE OPERATOR'S VALUE IS NOT OVERWRITTEN by a derivation. This is
        the "does not overwrite a non-empty setting" rule, asserted where it
        is decided. *)
      my.Country := 'VE';
      CheckTrue(my.CountryWasSet, 'VE is a stated country');
   finally
      my.Free;
   end;
end;

{ ------------------------------------------ 2: a name, never a path -------- }

procedure TContestReadinessTests.Test_DataFileNameOnly_PlainNameUnchanged;
begin
   BeginTest('Test_DataFileNameOnly_PlainNameUnchanged');
   CheckEquals('S48P14DC.dom', DataFileNameOnly('S48P14DC.dom'),
               'a plain name is left alone');
   CheckEquals('', DataFileNameOnly(''), 'empty stays empty');
end;

procedure TContestReadinessTests.Test_DataFileNameOnly_BothSeparators;
begin
   BeginTest('Test_DataFileNameOnly_BothSeparators');
   (* BOTH SPELLINGS, ON EVERY PLATFORM. ExtractFileName reads PathDelim and
     would leave the Windows form untouched on Linux, which is how a
     backslash ended up INSIDE a file name on NY4I's box. *)
   CheckEquals('s48p14dc.dom', DataFileNameOnly('/usr/share/dom/s48p14dc.dom'),
               'unix separator');
   CheckEquals('s48p14dc.dom', DataFileNameOnly('C:\tr4w\dom\s48p14dc.dom'),
               'windows separator');
   CheckEquals('s48p14dc.dom', DataFileNameOnly('/usr/dom\s48p14dc.dom'),
               'mixed separators -- the LAST one wins');
end;

procedure TContestReadinessTests.Test_DomesticFilename_StripsAPath;
var
   contest: TContestSettings;
begin
   BeginTest('Test_DomesticFilename_StripsAPath');
   contest := TContestSettings.Create;
   try
      contest.DomesticFilename := 'S48P14DC.dom';
      CheckEquals('S48P14DC.dom', contest.DomesticFilename,
                  'a name goes in and comes out');

      (* THE WRITE-BACK THAT USED TO HAPPEN IN LogCfg. It does not happen any
        more, and if it ever comes back the setter refuses to store it. *)
      contest.DomesticFilename := 'C:\tr4w\target\dom\S48P14DC.dom';
      CheckEquals('S48P14DC.dom', contest.DomesticFilename,
                  'a resolved path is reduced to its name');
   finally
      contest.Free;
   end;
end;

procedure TContestReadinessTests.Test_DomesticFilename_HealsTheLogNY4IActuallyHad;
var
   contest: TContestSettings;
begin
   BeginTest('Test_DomesticFilename_HealsTheLogNY4IActuallyHad');
   contest := TContestSettings.Create;
   try
      (* EXISTING LOGS CARRY THE POISONED VALUE and must not reproduce the
        modal. Applying the row heals it -- the setting comes out as the
        name, which resolves under dom/ wherever this install happens to be
        mounted today. *)
      contest.DomesticFilename := POISONED_DOMESTIC_ROW;
      CheckEquals('s48p14dc.dom', contest.DomesticFilename,
                  'the row from ARRL-DX-SSB 2026-09-20 NY4I.db becomes a name');
   finally
      contest.Free;
   end;
end;

{ ------------------------------------------------ the readiness rules ------ }

procedure TContestReadinessTests.Test_Readiness_SilentWhenNoContest;
var
   gaps: TStringList;
begin
   BeginTest('Test_Readiness_SilentWhenNoContest');
   gaps := TStringList.Create;
   try
      (* aContestActive False is DUMMYCONTEST: nothing is set up, so there is
        nothing to be ready for. Everything else here is missing on purpose. *)
      CollectContestSettingsGaps(False, RSTDomesticQTHExchange, DomesticFile,
                                 '', '', '', '', '', '', gaps);
      CheckEquals(0, gaps.Count, 'no contest, nothing reported');
   finally
      gaps.Free;
   end;
end;

procedure TContestReadinessTests.Test_Readiness_ArrlDxWithEmptyCountryReports;
var
   gaps: TStringList;
begin
   BeginTest('Test_Readiness_ArrlDxWithEmptyCountryReports');
   gaps := TStringList.Create;
   try
      (* NY4I's session: ARRL DX SSB on the DX arm -- RSTDomesticQTHExchange
        with the S48P14DC file -- and an empty MY COUNTRY. *)
      CollectContestSettingsGaps(True, RSTDomesticQTHExchange, DomesticFile,
                                 'NY4I', '', 'FL', '5', 'EL88',
                                 's48p14dc.dom', gaps);
      CheckTrue(gaps.Count > 0, 'an empty MY COUNTRY is reported');
      CheckTrue(Pos('MY COUNTRY', gaps.Text) > 0,
                'and the report names the setting');
   finally
      gaps.Free;
   end;
end;

procedure TContestReadinessTests.Test_Readiness_ArrlDxWithCountryIsSilent;
var
   gaps: TStringList;
begin
   BeginTest('Test_Readiness_ArrlDxWithCountryIsSilent');
   gaps := TStringList.Create;
   try
      (* THE SAME CONTEST, CONFIGURED. It must not nag: this is the state
        every correctly set up station is in. *)
      CollectContestSettingsGaps(True, RSTPowerExchange, NoDomesticMults,
                                 'NY4I', 'K', 'FL', '5', 'EL88', '', gaps);
      CheckEquals(0, gaps.Count, 'nothing to report: ' + gaps.Text);
   finally
      gaps.Free;
   end;
end;

procedure TContestReadinessTests.Test_Readiness_ContestThatDoesNotNeedStateIsSilent;
var
   gaps: TStringList;
begin
   BeginTest('Test_Readiness_ContestThatDoesNotNeedStateIsSilent');
   gaps := TStringList.Create;
   try
      (* A serial-number contest with no state, no zone and no grid. The
        rules are derived from the EXCHANGE, so none of them fires. *)
      CollectContestSettingsGaps(True, RSTQSONUMBEREXCHANGE, NoDomesticMults,
                                 'NY4I', 'K', '', '', '', '', gaps);
      CheckEquals(0, gaps.Count,
                  'a serial-number contest asks for none of it: ' + gaps.Text);
   finally
      gaps.Free;
   end;
end;

procedure TContestReadinessTests.Test_Readiness_DomesticFileContestWithNoFile;
var
   gaps: TStringList;
begin
   BeginTest('Test_Readiness_DomesticFileContestWithNoFile');
   gaps := TStringList.Create;
   try
      CollectContestSettingsGaps(True, RSTQSONUMBEREXCHANGE, DomesticFile,
                                 'NY4I', 'K', 'FL', '5', 'EL88', '', gaps);
      CheckEquals(1, gaps.Count, 'exactly the domestic-file gap');
      CheckTrue(Pos('.DOM', gaps.Text) > 0, 'and it says which file');
   finally
      gaps.Free;
   end;
end;

procedure TContestReadinessTests.Test_Readiness_ZoneAndGrid;
var
   gaps: TStringList;
begin
   BeginTest('Test_Readiness_ZoneAndGrid');
   gaps := TStringList.Create;
   try
      CollectContestSettingsGaps(True, RSTZoneExchange, NoDomesticMults,
                                 'NY4I', 'K', '', '', '', '', gaps);
      CheckEquals(1, gaps.Count, 'a zone contest with no zone');
      CheckTrue(Pos('MY ZONE', gaps.Text) > 0, 'names MY ZONE');

      gaps.Clear;
      CollectContestSettingsGaps(True, GridExchange, NoDomesticMults,
                                 'NY4I', 'K', '', '', '', '', gaps);
      CheckEquals(1, gaps.Count, 'a grid contest with no grid');
      CheckTrue(Pos('MY GRID', gaps.Text) > 0, 'names MY GRID');
   finally
      gaps.Free;
   end;
end;

{ ---------------------------------------------- the rejection's reason ----- }

procedure TContestReadinessTests.Test_Attribution_NamesMyCountry;
begin
   BeginTest('Test_Attribution_NamesMyCountry');
   CheckTrue(Pos('MY COUNTRY',
                 ExchangeModeAttribution(RSTDomesticQTHExchange, '', False)) > 0,
             'the long form names the setting');
   CheckTrue(Pos('MY COUNTRY',
                 ExchangeModeAttribution(RSTDomesticQTHExchange, '', True)) > 0,
             'so does the brief form shown on screen');
   (* The brief form is APPENDED to an error message, so it carries its own
     leading space -- see the note on ExchangeModeAttribution. *)
   CheckEquals(' ', Copy(ExchangeModeAttribution(RSTDomesticQTHExchange, '',
                                                 True), 1, 1),
               'brief form leads with a space');
end;

procedure TContestReadinessTests.Test_Attribution_EmptyForAnUnrelatedExchange;
begin
   BeginTest('Test_Attribution_EmptyForAnUnrelatedExchange');
   (* NOTHING TO SAY IS SAID AS NOTHING. A serial-number exchange was not put
     into its mode by a setting, so the rejection reads exactly as it did. *)
   CheckEquals('', ExchangeModeAttribution(RSTQSONUMBEREXCHANGE, 'K', False),
               'no attribution, long form');
   CheckEquals('', ExchangeModeAttribution(RSTQSONUMBEREXCHANGE, 'K', True),
               'no attribution, brief form');
end;

{ --------------------------------------------------------------------------- }

procedure TContestReadinessTests.RunAllTests;
begin
   FLoaded := False;

   Test_DeriveCountry_NY4I_IsK;
   Test_DeriveCountry_VE3_IsVE;
   Test_DeriveCountry_IK8_IsItaly;
   Test_DeriveCountry_PortableCall;
   Test_DeriveCountry_GarbageIsEmpty;
   Test_DeriveCountry_EmptyCallIsEmpty;

   Test_StatedCountryIsFlagged;
   Test_DerivedCountryIsNotFlagged;
   Test_EmptyAssignmentIsNotAStatedValue;

   Test_DataFileNameOnly_PlainNameUnchanged;
   Test_DataFileNameOnly_BothSeparators;
   Test_DomesticFilename_StripsAPath;
   Test_DomesticFilename_HealsTheLogNY4IActuallyHad;

   Test_Readiness_SilentWhenNoContest;
   Test_Readiness_ArrlDxWithEmptyCountryReports;
   Test_Readiness_ArrlDxWithCountryIsSilent;
   Test_Readiness_ContestThatDoesNotNeedStateIsSilent;
   Test_Readiness_DomesticFileContestWithNoFile;
   Test_Readiness_ZoneAndGrid;

   Test_Attribution_NamesMyCountry;
   Test_Attribution_EmptyForAnUnrelatedExchange;
end;

end.
