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

(* THE YOTA CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'YOTA';  WA7BNM: 696;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTAgeExchange;
   XM: NoDXMults;  QP: YOTAQSOPointMethod;
   ADIFName: 'YOTA';  CABName: 'YOTA-CONTEST';
   FriendlyName: 'YOTA Contest'

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: YOTAQSOPointMethod -- the received age is the domestic
  multiplier; an age over 25 (or none) scores 3 off our continent and 1 on
  it; 1-11 score 13, 12-16 12, 17-21 11, 22-25 10.

  SET-UP: 80 m. ALLJA left the arm it shared with this contest in M7a;
  this is that arm, alone. *)
unit uContestYOTA;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestYOTA = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   SysUtils,
   uTR4WStrings;

(* YOTAQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestYOTA.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.DomMultQTH := IntToStr(aQso.Age);
   if (aQso.Age > 25) or (aQso.Age = 0) then
      begin
      if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 1;
         end;
      Exit;
      end;
   case aQso.Age of
      1..11:
         begin
         aQso.QSOPoints := aQso.QSOPoints + 13;
         end;
      12..16:
         begin
         aQso.QSOPoints := aQso.QSOPoints + 12;
         end;
      17..21:
         begin
         aQso.QSOPoints := aQso.QSOPoints + 11;
         end;
      22..25:
         begin
         aQso.QSOPoints := aQso.QSOPoints + 10;
         end;
      end;
end;

function TContestYOTA.GetDisplayName: string;
begin
   Result := 'YOTA Contest';
end;

function TContestYOTA.GetCabrilloName: string;
begin
   Result := 'YOTA-CONTEST';
end;

function TContestYOTA.GetADIFContestId: string;
begin
   Result := 'YOTA';
end;

function TContestYOTA.GetWA7BNMId: integer;
begin
   Result := 696;
end;

function TContestYOTA.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestYOTA.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestYOTA.GetDomesticFileName: string;
begin
   Result := 'YOTA';
end;

function TContestYOTA.GetFriendlyName: string;
begin
   Result := 'YOTA Contest';
end;

function TContestYOTA.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestYOTA.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestYOTA.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestYOTA.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestYOTA.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestYOTA.GetExchangeKind: ExchangeType;
begin
   Result := RSTAgeExchange;
end;

function TContestYOTA.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := YOTAQSOPointMethod;
end;

function TContestYOTA.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestYOTA.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ALLASIANCW, ALLASIANSSB,
   YOUTHCHAMPIONSHIPRF.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestYOTA.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
end;

initialization
   RegisterContest(YOTA, TContestYOTA);

end.
