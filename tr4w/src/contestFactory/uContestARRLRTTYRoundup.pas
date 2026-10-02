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

(* THE ARRL RTTY ROUNDUP.

  The ContestsArray row this class states, verbatim:

   Email: 'rttyru@arrl.org';  DF: 's48p14dc';  WA7BNM: 217;  QRZRUID: 56;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  DM: DomesticFile;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: ARRLDXCC;  QP: OnePointPerQSO;  ADIFName: 'ARRL-RTTY';
   CABName: '';  FriendlyName: 'ARRL RTTY Roundup'

  Blank CABName resolve to the enum's spelling, 'ARRL-RTTY'.

  THE ROW HAS NO AIE FIELD, so the class deliberately does not state one: the
  InitialExchangeKind comparison in Test_MovedRowValuesStillMatchTheArray is what
  proves that leaving it to the array still gives the array's answer.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7a) have moved since.

  SCORING IS OnePointPerQSO, stated through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  ITS IMPORT: a US or Canadian station sends its RST and a state or province, so
  the QTH is that report and the STATE tag; a DX station sends its RST and a
  serial number, so the QTH is the report and SRX. Either way the whole line is
  the exchange string. (The legacy arm logged QTH.CountryID at debug level; a
  contest class has no logger and the line is not carried.) *)
unit uContestARRLRTTYRoundup;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLRTTYRoundup = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestARRLRTTYRoundup.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

procedure TContestARRLRTTYRoundup.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                                  const aSession: TADIFImportSession;
                                                  var aExch: ContestExchange);
begin
   if (aExch.QTH.CountryID = 'K') or (aExch.QTH.CountryID = 'VE') then
      begin
      aExch.QTHString := ShortString(IntToStr(aExch.RSTReceived) + ' ' +
                                     aTemps.State);
      end
   else
      begin
      aExch.QTHString := IntToStr(aExch.RSTReceived) + ' ' +
                         IntToStr(aExch.NumberReceived);
      end;
   aExch.ExchString := aExch.QTHString;
end;

function TContestARRLRTTYRoundup.GetDisplayName: string;
begin
   Result := 'ARRL RTTY Roundup';
end;

function TContestARRLRTTYRoundup.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'ARRL-RTTY';
end;

function TContestARRLRTTYRoundup.GetADIFContestId: string;
begin
   Result := 'ARRL-RTTY';
end;

function TContestARRLRTTYRoundup.GetWA7BNMId: integer;
begin
   Result := 217;
end;

function TContestARRLRTTYRoundup.GetQRZRUId: integer;
begin
   Result := 56;
end;

function TContestARRLRTTYRoundup.GetSubmissionEmail: string;
begin
   Result := 'rttyru@arrl.org';
end;

function TContestARRLRTTYRoundup.GetDomesticFileName: string;
begin
   Result := 's48p14dc';
end;

function TContestARRLRTTYRoundup.GetFriendlyName: string;
begin
   Result := 'ARRL RTTY Roundup';
end;

function TContestARRLRTTYRoundup.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARRLRTTYRoundup.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARRLRTTYRoundup.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestARRLRTTYRoundup.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestARRLRTTYRoundup.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestARRLRTTYRoundup.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestARRLRTTYRoundup.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARRLRTTYRoundup.DescribeSession(const aStation: TStationContext;
                                                  aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesKVE);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRL10, ARRL160, CQ160CW,
   CQ160SSB, CQWWRTTY.
   The same steps on ticking the box stood for ARRL10, ARRL160, ARRLDXCW.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRLRTTYRoundup.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NORTHAMERICA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
end;

initialization
   RegisterContest(ARRL_RTTY_ROUNDUP, TContestARRLRTTYRoundup);

end.
