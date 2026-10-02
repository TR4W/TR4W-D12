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

(* THE WORKED ALL GERMANY CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 163;  QRZRUID: 74;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndQSONumberOrDomesticQTHExchange;
   XM: NoDXMults;  QP: WAGQSOPointMethod;  ADIFName: '';
   CABName: '';  FriendlyName: 'Worked All Germany Contest'

  Blank ADIFName and CABName are the enum's spelling, 'WAG'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = WAG` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS WAGQSOPointMethod, transcribed exactly. A German station (our
  country DL): 1 for another German, 3 for a European, 5 otherwise. Anyone
  else: 3 for a German, 0 otherwise.

  ITS ADIF FIELD: a German station's DOK goes to the DOK tag -- the WAG arm
  of postunit's EmitContestSpecificTailForExport. Import does not read DOK
  back (uADIF has no DOK field) -- M5's. *)
unit uContestWAG;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWAG = class(TContestBase)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
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
   public
      (* WHERE ON THE BAND THE SPONSOR WANTS NO WAG QSO -- M9b. See the
         body. *)
      function CallEntryFrequencyWarning(aFreqKHz: integer): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   uTR4WStrings;

procedure TContestWAG.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyCountry = 'DL' then
      begin
      if aQso.QTH.CountryID = 'DL' then
         begin
         aQso.QSOPoints := 1;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end
   else
      begin
      if aQso.QTH.CountryID = 'DL' then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestWAG.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := EmitADIFField('DOK', string(aQso.QTHString));
end;

function TContestWAG.GetDisplayName: string;
begin
   Result := 'Worked All Germany Contest';
end;

function TContestWAG.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'WAG';
end;

function TContestWAG.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WAG';
end;

function TContestWAG.GetWA7BNMId: integer;
begin
   Result := 163;
end;

function TContestWAG.GetQRZRUId: integer;
begin
   Result := 74;
end;

function TContestWAG.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWAG.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestWAG.GetFriendlyName: string;
begin
   Result := 'Worked All Germany Contest';
end;

function TContestWAG.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWAG.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestWAG.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestWAG.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestWAG.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWAG.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestWAG.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := WAGQSOPointMethod;
end;

function TContestWAG.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* WAG WRITES ITS DOK AS THE DOK TAG AND READS IT BACK (M5a). Export puts the
   QSO's QTHString in DOK (EmitADIFContestFields), so a record that carries one
   gets it back as the QTH -- the round trip the design asks of every class.
   A record from another logger has no DOK, and keeps what this arm has always
   done: SRX_STRING as the QTH. *)
procedure TContestWAG.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                      const aSession: TADIFImportSession;
                                      var aExch: ContestExchange);
begin
   aExch.QTHString := ShortString(aTemps.SRX_String);
   if aTemps.DOK <> '' then
      begin
      aExch.QTHString := ShortString(aTemps.DOK);
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestWAG.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   (* A German station counts countries, everyone else counts DOKs. For the
      WAG, German stations count Germany as a country multiplier by hand after
      the contest. *)
   if aStation.MyCountry = 'DL' then
      begin
      aSession.DXMult := CQDXCC;
      end
   else
      begin
      aSession.DomesticMult := DOKCodes;
      end;
   aSession.LiteralDomesticQTH := True;
   aSession.AddDomesticCountry('DL');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for DARC10M, DARCXMAS.
   The same steps on ticking the box stood for DARC10M, DARCXMAS.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestWAG.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_GERMANY);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURDOK, ncfMyState);
end;

(* MainUnit.WagCheck's seven windows, moved here as they stood at M9b
   (2026-10-02) -- "added by n4af at behest of wag contest mgr", 4.90.3.
   Every bound is EXCLUSIVE, as the `(ARF > a) and (ARF < b)` tests were, so
   7080 kHz itself, between two windows, does not warn. MainUnit asks this as
   a call is typed and shows the answer as a notice. *)
function TContestWAG.CallEntryFrequencyWarning(aFreqKHz: integer): string;
const
   WINDOWS: array[0..6, 0..1] of integer = (
      (3650, 3700),
      (7043, 7080),
      (7080, 7143),
      (14060, 14125),
      (14280, 14350),
      (21347, 21450),
      (28225, 28400));
var
   i: integer;
begin
   Result := '';
   for i := Low(WINDOWS) to High(WINDOWS) do
      begin
      if (aFreqKHz > WINDOWS[i, 0]) and (aFreqKHz < WINDOWS[i, 1]) then
         begin
         Result := TC_WAGWarn;
         Exit;
         end;
      end;
end;

initialization
   RegisterContest(WAG, TContestWAG);

end.
