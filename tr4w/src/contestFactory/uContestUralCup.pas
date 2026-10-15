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

(* THE URAL CUP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'grids';  WA7BNM: 0;  QRZRUID: 112;
   Pxm: CallSignPrefix;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: QSONumberDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: '';
   CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName are the enum's spelling,
  'URAL-CUP'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = CUPURAL` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS OnePointPerQSO, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree), stated
  through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  THE QTH COMES FIRST ON ITS CABRILLO LINE. This contest runs
  QSONumberDomesticQTHExchange, whose shared layout writes the serial first
  and the QTH second; the legacy arm tested `(Contest = UKRAINECHAMPIONSHIP)
  or (Contest = CUPURAL)` and swapped them, with a zero-padded serial. That
  swap is this class's own Cabrillo pair now, stated through the two
  swapped-order helpers in uCabrilloExchange (M11 S9c). Its ADIF STX_STRING
  was never swapped. The Ukraine Championship and the Ural Cup call the same
  pair: two sponsors. *)
unit uContestUralCup;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUralCup = class(TContestBase)
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
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* THE FINAL SCORE -- see the implementation. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE CALL'S GRID FROM CTY.DAT, FOR THE NEED-MULTIPLIER HINT -- the
         arm LOGEDIT.GetMultArray held for this contest, moved here at M8:
         ctyGetGrid of the call, which the engine answers through
         aLookups.GridOfCall. *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   protected
      (* THE HOUR-BY-HOUR REPORT -- see TContestBase.ReportsRunningScore (M9a). *)
      function GetReportsRunningScore: boolean; override;
   public
      (* DOES IT HAVE A PREFIX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasPrefixMultiplier (M11 S3 part 2). *)
      function HasPrefixMultiplier: boolean; override;
      (* THE PREFIX MULTIPLIER -- see TContestBase.PrefixMultiplierKey
         (M11 S3). *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
      function PerQSOExchangeLeadsWithSerial: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

function TContestUralCup.DomesticMultiplierFromCall(const aCall: string;
                                                    const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   if Assigned(aLookups.GridOfCall) then
      begin
      Result := aLookups.GridOfCall(aCall);
      end;
end;

procedure TContestUralCup.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

(* THE PREFIXES ARE NOT MULTIPLIERS BUT TEN POINTS EACH, ADDED AFTER THE
   MULTIPLICATION. Transcribed from the two `Contest = CUPURAL` arms of
   LogEdit.TotalScore (M6): on all bands the prefix count comes out of the
   multiplier sum; a single-band entry's sum keeps it, as TotalScore's
   single-band arm did; and the ten per prefix is always the all-band count. *)
function TContestUralCup.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   mults: longint;
begin
   mults := SummedMultipliers(aTotals);
   if aTotals.ScoredBand = AllBands then
      begin
      mults := mults - aTotals.Mults[AllBands, Both, rmPrefix];
      end;

   Result := ContestPoints(aTotals) * mults;
   Result := Result + 10 * aTotals.Mults[AllBands, Both, rmPrefix];
end;

function TContestUralCup.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentStateQSONumber(aMy, aQso, aCtx);
end;

function TContestUralCup.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedQTHQSONumber(aMy, aQso, aCtx);
end;

function TContestUralCup.GetDisplayName: string;
begin
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestUralCup.GetQRZRUId: integer;
begin
   Result := 112;
end;

function TContestUralCup.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUralCup.GetDomesticFileName: string;
begin
   Result := 'grids';
end;

function TContestUralCup.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; it resolves to the enum's
      spelling. *)
   Result := 'URAL-CUP';
end;

function TContestUralCup.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUralCup.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticQTHExchange;
end;

function TContestUralCup.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberQTH;
end;

function TContestUralCup.ParseReceivedExchangeFormat(const aText: string;
                                                     aParsers: TExchangeParsers;
                                                     var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseQSONumberDomesticQTH(aText, aExch);
end;

function TContestUralCup.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestUralCup.PerQSOExchangeLeadsWithSerial: boolean;
begin
   Result := True;
end;

function TContestUralCup.GetADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
begin
   Result := ADIFSentStateThenQSONumber(aMy, aQso);
end;

function TContestUralCup.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfErmakSpecification];
end;

function TContestUralCup.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestUralCup.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState + '#';
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestUralCup.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERFIRSTTWOLETTERSOFYOURGRID, ncfMyState);
end;

(* THE HOUR-BY-HOUR REPORT CARRIES NO RUNNING SCORE -- PostUnit.PrintHourTotals
   named this contest among the seven whose score is not points times
   multipliers hour by hour (M9a, 2026-10-02). Each of the seven holds its own copy (design 1.4). *)
function TContestUralCup.GetReportsRunningScore: boolean;
begin
   Result := False;
end;

(* A PREFIX MULTIPLIER AT EVERY STATION -- M11 S3 part 2, 2026-10-14:
   the trait this class stated (`CallSignPrefix`) until the kind was deleted. *)
function TContestUralCup.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* THE PREFIX MULTIPLIER KEY -- M11 S3, 2026-10-14, moved from
   LOGEDIT.SetPrefix.
   The worked callsign itself, cut to the field's six characters --
   SetPrefix's `CallSignPrefix` arm. *)
function TContestUralCup.PrefixMultiplierKey(const aQso: ContestExchange;
                                             out aKey: PrefixMultiplierString): boolean;
begin
   aKey := aQso.Callsign;
   Result := True;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestUralCup.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(CUPURAL, TContestUralCup);

end.
