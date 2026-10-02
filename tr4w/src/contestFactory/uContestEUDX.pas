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

(* THE EUROPEAN UNION DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: 'log.eudxc@gmail.com';  DF: 'EUDX';  WA7BNM: 000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTZoneOrDomesticQTH;
   XM: CQDXCC;  QP: EUDXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'EUDX'.

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

  THE "HE IS IN THE EU" TEST IS `DomMultQTH[4] <> ''`, the arm's own
  expression: a character compared with the empty string. Transcribed
  exactly, so the scores do not move; what it was meant to test is design
  Q45.

  SET-UP: nothing; FoundContest's arm for it was empty.

  NOT A SIBLING OF THE IRTS CLASS, which scores by the same arm for
  another sponsor (uContestIRTS). Copies, each owned (design 1.4). *)
unit uContestEUDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestEUDX = class(TContestBase)
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
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

(* EUDXQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestEUDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if Length(Station.MyState) = 4 then
      begin
      (* We are in an EU region. *)
      if aQso.DomMultQTH[4] <> '' then
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
   else if aQso.DomMultQTH[4] <> '' then
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

function TContestEUDX.GetDisplayName: string;
begin
   Result := 'EUDX';
end;

function TContestEUDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'EUDX';
end;

function TContestEUDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'EUDX';
end;

function TContestEUDX.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestEUDX.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestEUDX.GetSubmissionEmail: string;
begin
   Result := 'log.eudxc@gmail.com';
end;

function TContestEUDX.GetDomesticFileName: string;
begin
   Result := 'EUDX';
end;

function TContestEUDX.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'EUDX';
end;

function TContestEUDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestEUDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestEUDX.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestEUDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestEUDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestEUDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestEUDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := EUDXQSOPointMethod;
end;

function TContestEUDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on ticking the box stood for LZDX, OKDX, OKOMSSB,
   RSGB18, SPDX, YODX.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestEUDX.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_EUDX);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
end;

initialization
   RegisterContest(EUDX, TContestEUDX);

end.
