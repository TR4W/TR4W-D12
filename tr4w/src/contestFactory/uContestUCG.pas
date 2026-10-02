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

(* THE UCG CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 160;
   Pxm: Prefix;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: NoDXMults;  QP: CQWPXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'UCG'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: CQWPXQSOPointMethod -- our own country 1; our continent 2 on
  160, 80 and 40 m and 1 on 20, 15 and 10 (doubled for a North American
  station; 0 on any other band); another continent 6 on the low bands and 3
  on the high ones (0 elsewhere).

  SET-UP: nothing -- no FoundContest or LogCfg arm named it.

  NOT A MEMBER OF THE CQ WPX FAMILY (M7b batch 2, DECIDED on evidence). It
  scores by the CQ WPX arm, but TContestCQWPXBase holds CQ's CW and SSB
  runnings under CQ's rules -- its own Cabrillo and ADIF columns among them
  -- and this contest has always exported through the shared
  RST-and-serial arm. Another sponsor, so the scoring is a COPY of that
  arm, owned here (design 1.4). *)
unit uContestUCG;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUCG = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry;

(* CQWPXQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestUCG.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.QTH.Continent = Station.MyContinent then
      begin
      if aQso.QTH.CountryID = Station.MyCountry then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         case aQso.Band of
            Band160, Band80, Band40:
               begin
               aQso.QSOPoints := 2;
               end;
            Band20, Band15, Band10:
               begin
               aQso.QSOPoints := 1;
               end;
            end;

         if Station.MyContinent = NorthAmerica then
            begin
            aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
            end;
         end;
      end
   else
      begin
      case aQso.Band of
         Band160, Band80, Band40:
            begin
            aQso.QSOPoints := 6;
            end;
         Band20, Band15, Band10:
            begin
            aQso.QSOPoints := 3;
            end;
         end;
      end;
end;

function TContestUCG.GetDisplayName: string;
begin
   Result := 'UCG';
end;

function TContestUCG.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'UCG';
end;

function TContestUCG.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'UCG';
end;

function TContestUCG.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestUCG.GetQRZRUId: integer;
begin
   Result := 160;
end;

function TContestUCG.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUCG.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestUCG.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'UCG';
end;

function TContestUCG.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := Prefix;
end;

function TContestUCG.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestUCG.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestUCG.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestUCG.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUCG.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestUCG.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQWPXQSOPointMethod;
end;

function TContestUCG.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(UCG, TContestUCG);

end.
