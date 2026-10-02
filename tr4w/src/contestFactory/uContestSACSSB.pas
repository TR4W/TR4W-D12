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

(* THE SCANDINAVIAN ACTIVITY CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 131;  QRZRUID: 175;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: NoDomesticMults;  P: 0;
   AE: RSTQSONumberExchange;  XM: NoDXMults;  QP: ScandinavianQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'Scandinavian Activity Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'SAC-SSB'.

  WHY IT HAS A CLASS NOW. M5b (2026-10-02) moved exchange parsing onto the
  contest, and this contest's parse rule was `if (contest = SACCW) or
  (contest = SACSSB)` inside a shared shape parser. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the rest -- every line of its record but `contest.class` is
  unchanged, which is the proof.

  A SIBLING OF THE CW RUNNING, NOT A FAMILY (design 1.5, Q7). NY4I's ruling
  that a two-mode contest gets a base names NRAU-Baltic only, and extending it
  to every pair is his open Q7 -- so, as with the NA Sprint CW and RTTY, the
  two SAC runnings are siblings and each owns its copy (design 1.4).

  SCORING, transcribed from ScandinavianQSOPointMethod. A Scandinavian
  station scores 0 for another Scandinavian, 2 for the rest of Europe and 3
  for the world. Anybody else scores 1 for a Scandinavian and 0 otherwise,
  tripled on 80 and 40 m for a station outside Europe. 160 m scores 0.
  ITS PARSE: a Russian station (UA, UA2, UA9, EU) entered live, against a call
  in the call window, is not logged -- the entry is abandoned, silently, as
  4.123.10 wrote it. Under this shape, before its parse. *)
unit uContestSACSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSACSSB = class(TContestBase)
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
      (* A RUSSIAN STATION ENTERED LIVE IS NOT LOGGED -- see the header. It
         stood in LOGSTUFF.ProcessRSTAndQSONumberExchange; the entry is
         abandoned through the session, which is what initializeqso did. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   end;

implementation

uses
   uContestRegistry,
   (* ScandinavianCountry -- the leaf the arm asks. *)
   uCallSignRoutines;

procedure TContestSACSSB.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if ScandinavianCountry(Station.MyCountry) then
      begin
      if ScandinavianCountry(rxCty) then
         begin
         aQso.QSOPoints := 0;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      end
   else
      begin
      if ScandinavianCountry(rxCty) then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 0;
         end;

      if Station.MyContinent <> Europe then
         begin
         if aQso.Band in [Band80, Band40] then
            begin
            aQso.QSOPoints := aQso.QSOPoints * 3;
            end;
         end;
      end;

   if aQso.Band = Band160 then
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestSACSSB.ParseReceivedExchange(const aText: string;
                                            const aSession: TReceivedExchangeSession;
                                            var aExch: ContestExchange;
                                            out aErrorMessage: string): boolean;
begin
   if (aSession.Exchange = RSTQSONumberExchange)    and
      aSession.CallWindowHasCall                    and
      ((aExch.QTH.CountryID = 'UA')  or
       (aExch.QTH.CountryID = 'EU')  or
       (aExch.QTH.CountryID = 'UA9') or
       (aExch.QTH.CountryID = 'UA2'))               then
      begin
      aErrorMessage := '';
      aSession.AbandonEntry;
      Result := False;
      Exit;
      end;

   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
end;

function TContestSACSSB.GetDisplayName: string;
begin
   Result := 'Scandinavian Activity Contest, SSB';
end;

function TContestSACSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'SAC-SSB';
end;

function TContestSACSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'SAC-SSB';
end;

function TContestSACSSB.GetWA7BNMId: integer;
begin
   Result := 131;
end;

function TContestSACSSB.GetQRZRUId: integer;
begin
   Result := 175;
end;

function TContestSACSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestSACSSB.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestSACSSB.GetFriendlyName: string;
begin
   Result := 'Scandinavian Activity Contest, SSB';
end;

function TContestSACSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestSACSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestSACSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestSACSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestSACSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSACSSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestSACSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ScandinavianQSOPointMethod;
end;

function TContestSACSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(SACSSB, TContestSACSSB);

end.
