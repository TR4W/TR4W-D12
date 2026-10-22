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

(* THE IRTS CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: 'IRTS.contests@gmail.com';  DF: 'ireland';  WA7BNM: 000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTZoneOrDomesticQTH;
   XM: NoDXMults;  QP: EUDXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  THE CABRILLO CONTEST: NAME IS WA7BNM'S IRTS-80-CONTEST SINCE 2026-10-19 (see
  GetCabrilloName), not the enum's spelling the paragraph below
  describes.

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'IRTS'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: EUDXQSOPointMethod -- the sponsor's table: an EU station (MY
  STATE is a four-character region) 10 for another EU country, 2 for its
  own, 5 off its continent, 3 on it; anyone else 10 for the EU, 5 off its
  continent, 3 for another country, 2 for its own.

  "HE IS IN THE EU" IS HIS RESOLVED DOMESTIC QTH -- Q45 (NY4I, 2026-10-16:
  "DomMultQTH is a catch-all left over from the D7 shared fields
  implementation. I would expect in the new implementation to use the
  discrete values."). The arm tested `DomMultQTH[4] <> ''`, never false, so
  every worked station scored as an EU one. It is WorkedStationIsInEU now:
  the QTH his exchange matched in THIS contest's file, false when he sent
  none. THIS CONTEST'S FILE IS ireland.dom -- the 32 Irish counties, the
  six of Northern Ireland among them -- so here "in the EU" means "sent an
  Irish county". That is the ruling applied to the file this contest has;
  whether the EUDX table is IRTS's scoring at all is the sponsor's question
  (see the report of 2026-10-17).

  NOT IRTSQSOPointMethod: the row names EUDXQSOPointMethod, and that is what
  this contest has always scored by. The IRTS arm in LOGSTUFF was reached
  only through an operator's QSO POINT METHOD line (inventory D3), and was
  deleted with the legacy scoring case at M10 S3.

  SET-UP: 80 m, digital off, the initial exchange's cursor at the start,
  and -- for a station outside EI and GI only -- no DX multiplier.

  NOT A SIBLING OF THE EUDX CLASS: it shares EUDX's scoring arm by its row,
  but is another sponsor's contest with its own set-up. The arm is COPIED
  (design 1.4). *)
unit uContestIRTS;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestIRTS = class(TContestBase)
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

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   private
      (* IS THE WORKED STATION "IN THE EU"? -- Q45; see the body. *)
      function WorkedStationIsInEU(const aQso: ContestExchange): boolean;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
      function ExchangeCarriesZone: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uTR4WStrings;

(* THE DISCRETE VALUE -- Q45: the record's DomesticQTH, which the domestic
   lookup writes ONLY when the received QTH matched an entry of the contest's
   file (ireland.dom; LOGDUPE.FoundDomesticQTH). Empty when he sent a zone.
   Not DomMultQTH, the shared multiplier string. A logged QSO is judged from
   its record (Q13): the field is stored with it. A copy of the EUDX class's
   test, owned here (design 1.4). *)
function TContestIRTS.WorkedStationIsInEU(const aQso: ContestExchange): boolean;
begin
   Result := aQso.DomesticQTH <> '';
end;

(* EUDXQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2), its "he is
   in the EU" test made real at Q45 (WorkedStationIsInEU). The arm was
   deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestIRTS.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if Length(Station.MyState) = 4 then
      begin
      (* We are in an EU region. *)
      if WorkedStationIsInEU(aQso) then
         begin
         (* He is in the EU. *)
         if rxCty <> Station.MyCountry then
            begin
            aQso.QSOPoints := 10;
            end
         else
            begin
            aQso.QSOPoints := 2;
            end;
         Exit;
         end
      else if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 5;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      end
   else if WorkedStationIsInEU(aQso) then
      begin
      (* We are not in the EU, and he is. *)
      aQso.QSOPoints := 10;
      end
   else if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

function TContestIRTS.GetDisplayName: string;
begin
   (* The contest's human name: WA7BNM, accepted (design Q53,
      docs/Q53_CONTEST_NAMES.csv). *)
   Result := 'IRTS 80m Counties Contest';
end;

function TContestIRTS.GetCabrilloName: string;
begin
   (* WA7BNM's Cabrillo name (WA7BNM 756), NY4I 2026-10-19: "do the
      cabrillo renames". TR4W wrote 'IRTS', which the sponsor's log robot
      accepted neither as the name nor as an alias
      (docs/UDC_CROSSWALK_FINDINGS.md). Only the Cabrillo CONTEST: line
      (and the UDP <contestname>) moves: the id, the ADIF id and the
      display names are their own literals. TR4W reads no Cabrillo
      CONTEST: value back, so the old name needs no read alias. *)
   Result := 'IRTS-80-CONTEST';
end;

function TContestIRTS.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'IRTS';
end;

function TContestIRTS.GetWA7BNMId: integer;
begin
   (* WA7BNM's ref, accepted by NY4I with its name (design Q53). *)
   Result := 756;
end;

function TContestIRTS.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestIRTS.GetSubmissionEmail: string;
begin
   Result := 'IRTS.contests@gmail.com';
end;

function TContestIRTS.GetDomesticFileName: string;
begin
   Result := 'ireland';
end;

function TContestIRTS.GetFriendlyName: string;
begin
   (* The display name above -- design Q53. *)
   Result := 'IRTS 80m Counties Contest';
end;

function TContestIRTS.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestIRTS.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestIRTS.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZoneQTH;
end;

function TContestIRTS.ParseReceivedExchangeFormat(const aText: string;
                                                  aParsers: TExchangeParsers;
                                                  var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTZoneOrDomesticQTH(aText, aExch);
end;

function TContestIRTS.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestIRTS.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestIRTS.GetADIFSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZoneOrState(aMy, aQso);
end;

function TContestIRTS.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrZone(aMy, aQso, aCtx);
end;

function TContestIRTS.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrZone(aMy, aQso, aCtx);
end;

function TContestIRTS.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestIRTS.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestIRTS.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
   aSession.DigitalModeEnable := False;
   aSession.InitialExchangeCursorAtStart := True;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestIRTS.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_IRTS);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURCOUNTYCODE, ncfMyState);
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestIRTS.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(IRTS, TContestIRTS);

end.
