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

(* THE UK/EI DX CONTEST.

  The ContestsArray row this class states, verbatim (its Name comment reads
  'UKEI ' with a trailing space; the enum's spelling, which is what the names
  resolve to, has none):

   Email: '';  DF: 'uk-ei';  WA7BNM: 0;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTQSONumberAndPossibleDomesticQTHExchange;
   XM: CQDXCC;  QP: UKEIQSOPointMethod;  ADIFName: '';
   CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName are the enum's spelling, 'UKEI'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = UKEI` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS UKEIQSOPointMethod, transcribed exactly. Outside Europe: 4 for a
  UK/EI station, 2 for a European, 1 otherwise. In Europe but not UK/EI: 1
  for a non-UK/EI European, 2 otherwise. A UK/EI station: 2 for a European, 4
  otherwise -- DOUBLED when the QSO was recorded in hours 01 to 04 UTC. And
  everything doubles again on 80 and 40 m. "UK/EI" is uCallSignRoutines.UKEIStation
  (G, M, 2 or EI), asked of the worked CALLSIGN and of our own COUNTRY.

  THE NIGHT DOUBLING READS THE QSO'S RECORDED TIME, NEVER THE CLOCK. NY4I,
  2026-10-01: "the event source is the wall clock recorded in the QSO". The
  legacy arm called tGetSystemTime, so a rescore at 02:00 UTC doubled a UK
  station's whole log, and M4 first transcribed that through a station-context
  clock function (design Q21, now fixed). aQso.tSysTime is the UTC time
  stamped when the QSO was logged, or read from TIME_ON on import: 01:00
  doubles, 00:59 does not, 04:59 does, 05:00 does not.

  THE RECEIVED QTH IS '--' WHEN THE QSO CARRIES NONE. The legacy arm wrote
  that as `if Contest = UKEI` inside the shared
  RSTQSONumberAndPossibleDomesticQTHExchange arm; this class sets it and the
  shared arm still lays out the line. *)
unit uContestUKEI;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUKEI = class(TContestBase)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;

      (* A UK OR IRISH STATION MUST SEND MORE THAN ONE WORD -- its district
         as well as its serial. M5b, 2026-10-02: the rule stood in
         LOGSTUFF.ProcessRSTQSONumberAndPossibleDomesticQTHExchange as
         `if Contest = UKEI`, ahead of that shape's parse, and refused with
         TC_INVALID. It is applied here under that shape, before the parse,
         exactly so. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* UKEIStation -- the UK/EI test the arm asks, already a leaf. *)
   uCallSignRoutines,
   (* SplitExchangeInThree -- the engine's own three-word split. *)
   uExchangeTokens,
   uTR4WStrings;

function TContestUKEI.ParseReceivedExchange(const aText: string;
                                           const aSession: TReceivedExchangeSession;
                                           var aExch: ContestExchange;
                                           out aErrorMessage: string): boolean;
var
   firstWord, secondWord, thirdWord: Str10;
begin
   (* NO SHAPE TEST -- THIS CONTEST'S SESSION ALWAYS PARSES
      RSTQSONumberAndPossibleDomesticQTHExchange, its trait, and no DescribeSession
      states another, so the test that stood here was always true.
      Deleted at M11 S2 (plan F11). *)
   if aText <> '' then
      begin
      (* The cast is a typed exchange returning to the width it was typed in. *)
      SplitExchangeInThree(ShortString(aText), firstWord, secondWord, thirdWord);
      if UKEIStation(string(aExch.Callsign)) and (secondWord = '') then
         begin
         aErrorMessage := TC_INVALID;
         Result := False;
         Exit;
         end;
      end;

   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
end;

procedure TContestUKEI.CalculateQSOPoints(var aQso: ContestExchange);
var
   qsoHour: integer;
begin
   if Station.MyContinent <> Europe then
      begin
      if UKEIStation(string(aQso.Callsign)) then
         begin
         aQso.QSOPoints := 4;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 1;
         end;
      end;

   if (Station.MyContinent = Europe)                  and
      (not UKEIStation(string(Station.MyCountry))) then
      begin
      if (aQso.QTH.Continent = Europe)                 and
         (not UKEIStation(string(aQso.Callsign))) then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end;

   if UKEIStation(string(Station.MyCountry)) then
      begin
      if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 4;
         end;

      (* The hour the QSO was recorded in, UTC -- see the header. Never
         the clock. *)
      qsoHour := aQso.tSysTime.qtHour;
      if (qsoHour >= 1) and
         (qsoHour < 5)  then
         begin
         aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
         end;
      end;

   if aQso.Band in [Band80, Band40] then
      begin
      aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
      end;
end;

function TContestUKEI.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
var
   ctx: TCabrilloQSOContext;
begin
   ctx := aCtx;
   if aQso.QTHString = '' then
      begin
      ctx.HisQTH := '--';
      end;
   Result := inherited FormatCabrilloReceivedExchange(aMy, aQso, ctx);
end;

function TContestUKEI.GetDisplayName: string;
begin
   Result := 'UKEI';
end;

function TContestUKEI.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'UKEI';
end;

function TContestUKEI.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'UKEI';
end;

function TContestUKEI.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestUKEI.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestUKEI.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUKEI.GetDomesticFileName: string;
begin
   Result := 'uk-ei';
end;

function TContestUKEI.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; it resolves to the enum's
      spelling. *)
   Result := 'UKEI';
end;

function TContestUKEI.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUKEI.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestUKEI.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestUKEI.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestUKEI.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('G');
   aSession.AddDomesticCountry('GD');
   aSession.AddDomesticCountry('GI');
   aSession.AddDomesticCountry('GJ');
   (* GM TWICE, AS THE ARM ADDED IT -- transcribed, not tidied. *)
   aSession.AddDomesticCountry('GM');
   aSession.AddDomesticCountry('GM');
   aSession.AddDomesticCountry('GW');
   aSession.AddDomesticCountry('GU');
   aSession.AddDomesticCountry('EI');
   if not UKEIStation(string(aStation.MyCountry)) then
      begin
      aSession.UseRSTQSONumberExchangeMemories;
      end;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestUKEI.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_UKEI);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURDISTRICTCODE, ncfMyState);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`CQDXCC`) until the kind was deleted. *)
function TContestUKEI.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's CQDXCC. *)
function TContestUKEI.DXMultiplierKey(const aQso: ContestExchange;
                                      out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestUKEI.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(UKEI, TContestUKEI);

end.
