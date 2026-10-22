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

(* THE MAKROTHEN RTTY CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 159;  QRZRUID: 515;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: GridInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: GridExchange;
   XM: NoDXMults;  QP: MakrothenQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Makrothen RTTY Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'MAKROTHEN-RTTY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: MakrothenQSOPointMethod -- with MY GRID: 100 for a station in
  our own four-character square; otherwise the distance to its grid,
  times 1.5 (rounded) on 40 m and 2 on 80 m. With no MY GRID, 0.

  SET-UP: nothing in FoundContest. LogCfg's CQ exchange: the first four
  characters of MY GRID, twice.

  DESIGN Q37 REACHES THIS CONTEST. LOGGRID.GetDistanceBetweenGrids pads a
  grid that is not six characters with 'LL', and ConvertGridToLatLon reads
  four characters of it: a grid shorter than four is read past its end, and
  such a QSO's points followed the heap. Q37 (NY4I, 2026-10-15) is BUILT
  (2026-10-17): the distance refuses a text that is not a grid and
  answers 0, so this contest scores such a QSO by its own rule at no
  distance -- and the grid exchange parsers refuse one when typed. An empty received grid
  reaches it whenever MY GRID is set. *)
unit uContestMakrothen;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestMakrothen = class(TContestBase)
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
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;
      function GetReceivesGridSquareExchange: boolean; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesGridSquare: boolean; override;
   public
      (* MAY AN EXCHANGE WORD BE A GRID? -- see
         TContestBase.ExchangeTextMayHoldGridSquare (M11 S9e part 1). *)
      function ExchangeTextMayHoldGridSquare: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   LOGGRID,
   uTR4WStrings;

(* MakrothenQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestMakrothen.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyGrid <> '' then
      begin
      if Copy(Station.MyGrid, 1, 4) = Copy(aQso.DomesticQTH, 1, 4) then
         begin
         aQso.QSOPoints := 100;
         end
      else
         begin
         aQso.QSOPoints := GetDistanceBetweenGrids(Station.MyGrid,
                                                   aQso.DomesticQTH);
         if aQso.Band = Band40 then
            begin
            aQso.QSOPoints := Round(aQso.QSOPoints * 1.5);
            end;

         if aQso.Band = Band80 then
            begin
            aQso.QSOPoints := aQso.QSOPoints * 2;
            end;
         end;
      end;
end;

function TContestMakrothen.GetDisplayName: string;
begin
   Result := 'Makrothen RTTY Contest';
end;

function TContestMakrothen.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'MAKROTHEN-RTTY';
end;

function TContestMakrothen.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'MAKROTHEN-RTTY';
end;

function TContestMakrothen.GetWA7BNMId: integer;
begin
   Result := 159;
end;

function TContestMakrothen.GetQRZRUId: integer;
begin
   Result := 515;
end;

function TContestMakrothen.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMakrothen.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestMakrothen.GetFriendlyName: string;
begin
   Result := 'Makrothen RTTY Contest';
end;

function TContestMakrothen.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := GridInitialExchange;
end;

function TContestMakrothen.GetExchangeKind: ExchangeType;
begin
   Result := GridExchange;
end;

function TContestMakrothen.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQTH;
end;

function TContestMakrothen.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseGrid(aText, aExch);
end;

function TContestMakrothen.ExchangeTextMayHoldGridSquare: boolean;
begin
   Result := True;
end;

function TContestMakrothen.ExchangeCarriesGridSquare: boolean;
begin
   Result := True;
end;

function TContestMakrothen.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentGrid(aMy, aQso);
end;

function TContestMakrothen.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentGrid(aMy, aQso, aCtx);
end;

function TContestMakrothen.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedGrid(aMy, aQso, aCtx);
end;

function TContestMakrothen.GetReceivesGridSquareExchange: boolean;
begin
   Result := True;
end;

function TContestMakrothen.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand];
end;

function TContestMakrothen.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestMakrothen.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + Copy(aStation.MyGrid, 1, 4) + ' ' + Copy(aStation.MyGrid, 1, 4);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN,
   ARRLVHFSEP, BATAVIA_FT8, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, RTC,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestMakrothen.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

initialization
   RegisterContest(MAKROTHEN, TContestMakrothen);

end.
