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

(* THE JOCK WHITE MEMORIAL FIELD DAY (NZART) -- enum NZFIELDDAY.

  NY4I renamed the event on 2026-09-29 (bf395987): it is the Jock White
  Memorial Field Day, https://www.nzart.org.nz/activities/contests/jwfd, ADIF
  and Cabrillo id JW-FD. The enum keeps its old name because the ordinal is
  persisted.

  NOT A RELATIVE OF EITHER ARRL FIELD DAY OR WINTER FIELD DAY. A different
  sponsor and a different rule; nothing is shared with those classes.

  TRANSCRIBED FROM THE CURRENT CODE, AS NY4I ASKED ("I will check the rules
  when you implement per the current code"). Anything the sponsor's page
  contradicts is his to rule on, and is listed with M3 in
  docs/CONTEST_OWNERSHIP_DESIGN.md -- not changed here.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: BranchZones;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: NZFieldDayExchange;
   XM: NoDXMults;  QP: NZFieldDayQSOPointMethod;
   ADIFName: 'JW-FD';  CABName: 'JW-FD';
   FriendlyName: 'Jock White Memorial Field Day'

  WA7BNM 0 is deliberate: the calendar does not list the event, and 0
  disables the calendar menu item rather than opening a wrong page.

  FORMER ADIF ID 'NZ FIELD DAY'. Until bf395987 the row's ADIFName was blank,
  so export wrote the enum's spelling. ADDING_A_CONTEST.md recorded that this
  old spelling could not resolve on import only because the contest had no
  class to carry it; it has one now, so it carries it (NY4I, 2026-09-29: "Yes
  support old spellings"). Export never writes it.

  SCORING IS NZFieldDayQSOPointMethod, one arm of LOGSTUFF.CalculateQSOPoints,
  transcribed exactly:

      if RXCty = 'ZL' then             (RXCty is RXData.QTH.CountryID)
         if Mode = CW then 5 else 3    (phone, FM and digital all score 3)
      else
         10;
      if RXData.Zone = StrToIntDef(MY ZONE, 0) then
         begin
         RXData.ZoneMult := False;
         end;

  THE SECOND HALF WRITES A FIELD OTHER THAN THE POINTS, and it is the
  contest's rule, so it is here too: a contact with a station in our own
  branch earns no branch (zone) multiplier. MY ZONE arrives as
  Station.MyZone, which is 0 when it is unset or not a number -- exactly
  what StrToIntDef(..., 0) gave the arm.

  LOGDUPE.SetMultFlags named this contest for the same branch rule, and also
  skipped zone 00. That is CountsAsMultiplier's since M8 (2026-10-02),
  transcribed exactly, and SetMultFlags names no contest. THE TWO RULES ARE
  NOT THE SAME RULE, and both are kept as they were: scoring clears ZoneMult
  for our own branch only; the sheet refuses our own branch AND branch 00.
  Whether the sponsor counts one's own branch at all is design Q18.
  The branch exchange is NZFieldDayExchange (M5); export is the base's
  default (M4). LOGCFG's CQ exchange is CQExchangeDefault since M7a;
  uNewContest still names it (M9). *)
unit uContestJockWhiteFieldDay;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestJockWhiteFieldDay = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFormerADIFContestIds: TContestIdList; override;
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* OUR OWN BRANCH AND BRANCH 00 EARN NO BRANCH (ZONE) MULTIPLIER --
         see the header. MY ZONE is Station.MyZone, 0 when unset or not a
         number: what the legacy StrToIntDef(MY ZONE, 0) gave. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
   end;

implementation

uses
   uContestRegistry;

function TContestJockWhiteFieldDay.CountsAsMultiplier(const aQso: ContestExchange;
                                                      aKind: RemainingMultiplierType): boolean;
begin
   Result := not ((aKind = rmZone) and
                  ((aQso.Zone = Station.MyZone) or (aQso.Zone = 0)));
end;

procedure TContestJockWhiteFieldDay.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.QTH.CountryID = 'ZL' then
      begin
      if aQso.Mode = CW then
         begin
         aQso.QSOPoints := 5;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      end
   else
      begin
      aQso.QSOPoints := 10;
      end;

   if aQso.Zone = Station.MyZone then
      begin
      aQso.ZoneMult := False;
      end;
end;

function TContestJockWhiteFieldDay.GetDisplayName: string;
begin
   Result := 'Jock White Memorial Field Day';
end;

function TContestJockWhiteFieldDay.GetCabrilloName: string;
begin
   Result := 'JW-FD';
end;

function TContestJockWhiteFieldDay.GetADIFContestId: string;
begin
   Result := 'JW-FD';
end;

function TContestJockWhiteFieldDay.GetFormerADIFContestIds: TContestIdList;
begin
   (* The enum's spelling, which export wrote while the row's ADIFName was
      blank -- see the unit header. *)
   Result := ContestIdList(['NZ FIELD DAY']);
end;

function TContestJockWhiteFieldDay.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestJockWhiteFieldDay.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestJockWhiteFieldDay.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestJockWhiteFieldDay.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestJockWhiteFieldDay.GetFriendlyName: string;
begin
   Result := 'Jock White Memorial Field Day';
end;

function TContestJockWhiteFieldDay.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestJockWhiteFieldDay.GetZoneMultiplierType: ZoneMultType;
begin
   Result := BranchZones;
end;

function TContestJockWhiteFieldDay.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestJockWhiteFieldDay.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestJockWhiteFieldDay.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestJockWhiteFieldDay.GetExchangeKind: ExchangeType;
begin
   Result := NZFieldDayExchange;
end;

function TContestJockWhiteFieldDay.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := NZFieldDayQSOPointMethod;
end;

function TContestJockWhiteFieldDay.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestJockWhiteFieldDay.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN # ' + aStation.MyZoneText;
end;

initialization
   RegisterContest(NZFIELDDAY, TContestJockWhiteFieldDay);

end.
