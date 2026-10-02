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

(* VIRGINIA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'va_cty';  WA7BNM: 302;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 17;  AE: QSONumberDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: VAQSOPointMethod;  ADIFName: 'VA-QSO-PARTY';
   CABName: 'VA-QSO-PARTY';  FriendlyName: 'Virginia QSO Party'

  THE ENUM IS MIXED CASE AND THE LEGACY ARM IS NOT. VC.pas declares
  VAQSOPointMethod; LOGSTUFF spells the same identifier VAQSOPOINTMETHOD at its
  case arm. Pascal identifiers are case-insensitive so both are the one value,
  but a case-sensitive search for the enum's spelling finds no arm and invites
  the conclusion that the contest is unscored. Search case-insensitively.

  THE ONLY ONE OF THESE FOUR WHOSE POINTS DEPEND ON THE CALLSIGN'S SHAPE -- see
  the note on CalculateQSOPoints.

  NO COUNTY-LINE MAXIMUM IS ESTABLISHED FOR THIS PARTY, so it inherits
  TContestStateQSOPartyBase's CountyLineCountiesUnlimited -- exactly what TR4W
  does today, because nothing in the program has ever counted the queued
  counties.

  ITS ROW CARRIES NO CountyLineAllowed FIELD AT ALL, so the array's boolean
  reads False. THAT MEANS UNKNOWN, NOT ZERO. Nobody has looked the rule up; a
  number here would have to come from the sponsor's published rules the way
  Florida's two and California's four did. Deriving one from the boolean is the
  defect that made a contest start refusing a two-QTH exchange the moment it
  got a class.
 *)
unit uContestVirginiaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestVirginiaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same answer -- but the base makes it
         abstract for state parties precisely so that answer is never an
         accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
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
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   (* MarineOrAirMobileStation. IT IS NOT IN LOGSTUFF ANY MORE -- it was lifted
      into this leaf callsign unit on 2026-09-29 so that this class could ask
      the question without the TRDOS engine in its dependency cone. See the
      note at the function.

      uCallSignRoutines is the right home rather than a new unit: it already
      holds MobileCall, RoverCall and CaliforniaCall, which are the same kind
      of suffix test, it depends on nothing that starts TR4W, and it has its
      own unit tests. A contest class can still be constructed and asked to
      score a QSO with no part of the program running, which is the property
      uContestBase exists to protect. *)
   uCallSignRoutines,
   uContestRegistry;

function TContestVirginiaQP.GetDisplayName: string;
begin
   Result := 'Virginia QSO Party';
end;

function TContestVirginiaQP.GetHostState: string;
begin
   Result := 'VA';
end;

function TContestVirginiaQP.GetCabrilloName: string;
begin
   Result := 'VA-QSO-PARTY';
end;

function TContestVirginiaQP.GetADIFContestId: string;
begin
   Result := 'VA-QSO-PARTY';
end;

function TContestVirginiaQP.GetWA7BNMId: integer;
begin
   Result := 302;
end;

function TContestVirginiaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestVirginiaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestVirginiaQP.GetDomesticFileName: string;
begin
   Result := 'va_cty';
end;

function TContestVirginiaQP.GetFriendlyName: string;
begin
   Result := 'Virginia QSO Party';
end;

function TContestVirginiaQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestVirginiaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestVirginiaQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestVirginiaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestVirginiaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestVirginiaQP.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticOrDXQTHExchange;
end;

function TContestVirginiaQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := VAQSOPointMethod;
end;

(* VAQSOPointMethod -- phone one, an air-mobile or maritime-mobile station
   three, everything else two:

     if RXData.Mode = PHONE then 1
     else if MarineOrAirMobileStation(RXData.Callsign) then 3
     else 2;

   THE ORDER IS LOAD-BEARING AND IS REPRODUCED EXACTLY. A /MM station worked on
   PHONE scores ONE, not three -- the phone test comes first and returns. That
   is what TR4W does today, and this move changes no score.

   SO DIGITAL SCORES TWO, or three for a /AM or /MM station: the first test is
   PHONE-versus-not, so digital falls into the same arms CW does. Stating that
   explicitly is the point of the note, because there is no third argument to
   get wrong here -- the shape is a chain, not a table, and a reader arriving
   from the FixedModePoints contests would otherwise have to work it out.

   MarineOrAirMobileStation IS CASE-SENSITIVE and requires at least four
   characters, both faithfully preserved in the lift. 'K4ABC/MM' scores three;
   'k4abc/mm' does not. *)
procedure TContestVirginiaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Mode = Phone then
      begin
      aQso.QSOPoints := 1;
      end
   else if MarineOrAirMobileStation(string(aQso.Callsign)) then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestVirginiaQP.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.AllowDupeQSOs := True;
end;

initialization
   RegisterContest(VAQP, TContestVirginiaQP);

end.
