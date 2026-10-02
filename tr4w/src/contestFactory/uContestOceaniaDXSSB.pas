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

(* THE OCEANIA DX CONTEST, PHONE.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 142;  QRZRUID: 73;
   Pxm: Prefix;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: NoDXMults;  QP: VKZLQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Oceania DX Contest, Phone'

  Blank CABName and ADIFName resolve to the enum's spelling, 'OCEANIA-DX-SSB'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: VKZLQSOPointMethod -- a contact with Oceania at either end: 20
  on 160 m, 10 on 80, 5 on 40, 1 on 20, 2 on 15, 3 on 10 (another band keeps
  0: the arm's `case` had no else); any other contact 0.

  A SIBLING, NOT A FAMILY MEMBER (M7b, DECIDED on evidence). The two runnings share a
  rule today, but their rows already differ (their QRZ.RU ids).
  Extending NY4I's NRAU-Baltic ruling to every two-mode pair is his open
  Q7, so this class is a COPY of its sibling and owns it (design 1.4).
  Never merge the two, and never extract a base for them. *)
unit uContestOceaniaDXSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestOceaniaDXSSB = class(TContestBase)
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

procedure TContestOceaniaDXSSB.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if (Station.MyContinent = Oceania) or
      (aQso.QTH.Continent = Oceania) then
      begin
      case aQso.Band of
         Band160:
            begin
            aQso.QSOPoints := 20;
            end;
         Band80:
            begin
            aQso.QSOPoints := 10;
            end;
         Band40:
            begin
            aQso.QSOPoints := 5;
            end;
         Band20:
            begin
            aQso.QSOPoints := 1;
            end;
         Band15:
            begin
            aQso.QSOPoints := 2;
            end;
         Band10:
            begin
            aQso.QSOPoints := 3;
            end;
         end;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestOceaniaDXSSB.GetDisplayName: string;
begin
   Result := 'OCEANIA-DX-SSB';
end;

function TContestOceaniaDXSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'OCEANIA-DX-SSB';
end;

function TContestOceaniaDXSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'OCEANIA-DX-SSB';
end;

function TContestOceaniaDXSSB.GetWA7BNMId: integer;
begin
   Result := 142;
end;

function TContestOceaniaDXSSB.GetQRZRUId: integer;
begin
   Result := 73;
end;

function TContestOceaniaDXSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOceaniaDXSSB.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestOceaniaDXSSB.GetFriendlyName: string;
begin
   Result := 'Oceania DX Contest, Phone';
end;

function TContestOceaniaDXSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := Prefix;
end;

function TContestOceaniaDXSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestOceaniaDXSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestOceaniaDXSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestOceaniaDXSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOceaniaDXSSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestOceaniaDXSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := VKZLQSOPointMethod;
end;

function TContestOceaniaDXSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(OCEANIADXSSB, TContestOceaniaDXSSB);

end.
