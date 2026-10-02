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

(* THE R9W AND UW9WK MEMORIAL CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 41;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndZone;
   XM: NoDXMults;  QP: R9WUW9WKMemorialQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'R9W-UW9WK-MEMORIAL'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: R9WUW9WKMemorialQSOPointMethod -- by the received zone (the
  station class): 1 and 2 score 3, 3 scores 4, 5 scores 10, anything else
  0.

  SET-UP: 20-minute minitours. LogCfg's CQ exchange: MY STATE and the
  serial. *)
unit uContestR9WUW9WKMemorial;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestR9WUW9WKMemorial = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

(* R9WUW9WKMemorialQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestR9WUW9WKMemorial.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Zone of
      1, 2:
         begin
         aQso.QSOPoints := 3;
         end;
      3:
         begin
         aQso.QSOPoints := 4;
         end;
      5:
         begin
         aQso.QSOPoints := 10;
         end;
      end;
end;

function TContestR9WUW9WKMemorial.GetDisplayName: string;
begin
   Result := 'R9W-UW9WK-MEMORIAL';
end;

function TContestR9WUW9WKMemorial.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'R9W-UW9WK-MEMORIAL';
end;

function TContestR9WUW9WKMemorial.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'R9W-UW9WK-MEMORIAL';
end;

function TContestR9WUW9WKMemorial.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestR9WUW9WKMemorial.GetQRZRUId: integer;
begin
   Result := 41;
end;

function TContestR9WUW9WKMemorial.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestR9WUW9WKMemorial.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestR9WUW9WKMemorial.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'R9W-UW9WK-MEMORIAL';
end;

function TContestR9WUW9WKMemorial.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestR9WUW9WKMemorial.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestR9WUW9WKMemorial.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestR9WUW9WKMemorial.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestR9WUW9WKMemorial.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestR9WUW9WKMemorial.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndZone;
end;

function TContestR9WUW9WKMemorial.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := R9WUW9WKMemorialQSOPointMethod;
end;

function TContestR9WUW9WKMemorial.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestR9WUW9WKMemorial.DescribeSession(const aStation: TStationContext;
                                                   aSession: TSessionDefaults);
begin
   aSession.MinitourDuration := 20;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestR9WUW9WKMemorial.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState + '#';
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestR9WUW9WKMemorial.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_STATIONCLASS, ncfMyState);
end;

initialization
   RegisterContest(R9W_UW9WK_MEMORIAL, TContestR9WUW9WKMemorial);

end.
