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

(* THE CWOPS TEST (CWT).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 498;  QRZRUID: 0;
   Pxm: CallSignPrefix;  ZnM: NoZoneMults;  AIE: NameQTHInitialExchange;  DM: NoDomesticMults;  P: 0;
   AE: NameAndDomesticOrDXQTHExchange;  XM: NoDXMults;  QP: OnePointPerQSO;
   ADIFName: 'CWOPS-CWT';  CABName: '';  FriendlyName: 'CWops Test (CWT)'

  Blank CABName resolve to the enum's spelling, 'CWOPS'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7) are not moved.

  SCORING IS OnePointPerQSO, stated through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  ITS IMPORT: the exchange is a name and a member number or state, and a
  number in the QTH is the member's age field -- the legacy arm read it so. *)
unit uContestCWOps;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCWOps = class(TContestBase)
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints;

procedure TContestCWOps.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

procedure TContestCWOps.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                        const aSession: TADIFImportSession;
                                        var aExch: ContestExchange);
begin
   aExch.Age := StrToIntDef(aExch.QTHString, 0);
end;

function TContestCWOps.GetDisplayName: string;
begin
   Result := 'CWops Test (CWT)';
end;

function TContestCWOps.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'CWOPS';
end;

function TContestCWOps.GetADIFContestId: string;
begin
   Result := 'CWOPS-CWT';
end;

function TContestCWOps.GetWA7BNMId: integer;
begin
   Result := 498;
end;

function TContestCWOps.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCWOps.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCWOps.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCWOps.GetFriendlyName: string;
begin
   Result := 'CWops Test (CWT)';
end;

function TContestCWOps.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := CallSignPrefix;
end;

function TContestCWOps.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCWOps.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCWOps.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestCWOps.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestCWOps.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestCWOps.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestCWOps.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(CWOPS, TContestCWOps);

end.
