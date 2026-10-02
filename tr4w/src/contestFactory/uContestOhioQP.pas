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

(* OHIO QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ohio_cty';  WA7BNM: 100;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 5;  AE: RSTQSONumberAndDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;  ADIFName: 'OH-QSO-PARTY';
   CABName: 'MRRC-OHQP';  CountyLineAllowed: True;
   FriendlyName: 'Ohio QSO Party'

  ITS ADIFName IS 'OH-QSO-PARTY', ADIF 3.1.7's id, since 2026-09-29. CABName
  is a different spelling on purpose -- 'MRRC-OHQP' is the sponsoring club's,
  not ADIF's and not the enum's.

  ITS FORMER ADIF ID IS 'OHIO QSO PARTY'. The ADIF id was blank until
  2026-09-29, and while it was, ADIF export fell back to the enum's spelling
  -- so every file exported before then carries CONTEST_ID 'OHIO QSO PARTY'.
  Import accepts it, export never writes it: NY4I, "Yes support old
  spellings."

  NO COUNTY-LINE MAXIMUM IS ESTABLISHED FOR THIS PARTY, so it inherits
  TContestStateQSOPartyBase's CountyLineCountiesUnlimited -- which is exactly
  what TR4W does today, because nothing in the program has ever counted the
  queued counties.

  THAT IS "NOT LOOKED UP YET", NOT "UNLIMITED BY DECISION", and the difference
  matters: a number here would have to come from the sponsor's published rules,
  the way Florida's two and California's four did. It must NOT be derived from
  ContestsArray's CountyLineAllowed boolean, which carries no limit at all --
  reading it as a number is the defect that made a class of any kind start
  refusing a two-QTH exchange.
 *)
unit uContestOhioQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestOhioQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'OH' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
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
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestOhioQP.GetDisplayName: string;
begin
   Result := 'Ohio QSO Party';
end;

function TContestOhioQP.GetHostState: string;
begin
   Result := 'OH';
end;

function TContestOhioQP.GetCabrilloName: string;
begin
   Result := 'MRRC-OHQP';
end;

function TContestOhioQP.GetADIFContestId: string;
begin
   (* STATED, NOT LEFT BLANK. The row held '' until 2026-09-29; ADIF 3.1.7
      defines OH-QSO-PARTY and NY4I had VC.pas corrected.

      ADIFName IS WHAT ADIF EXPORT WRITES AS CONTEST_ID (NY4I, who wrote
      that code), and it is also what import matches on. A BLANK IS NOT
      'no id' -- export falls back to the contest's quoted name -- so a
      blank row still produced a CONTEST_ID, just not the standard one.
      Stating it means the exported file now carries the ADIF identifier
      a sponsor's robot expects, and the class cannot drift from it. *)
   Result := 'OH-QSO-PARTY';
end;

function TContestOhioQP.GetFormerADIFContestIds: TContestIdList;
begin
   (* What ADIF export wrote while the row's ADIFName was blank: the enum's
      spelling. See the unit header. *)
   Result := ContestIdList(['OHIO QSO PARTY']);
end;

function TContestOhioQP.GetWA7BNMId: integer;
begin
   Result := 100;
end;

function TContestOhioQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestOhioQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOhioQP.GetDomesticFileName: string;
begin
   Result := 'ohio_cty';
end;

function TContestOhioQP.GetFriendlyName: string;
begin
   Result := 'Ohio QSO Party';
end;

function TContestOhioQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestOhioQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestOhioQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestOhioQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestOhioQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOhioQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndDomesticQTHExchange;
end;

function TContestOhioQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePhoneTwoCW;
end;

(* OnePhoneTwoCW -- `if Mode = CW then 2 else 1`, so DIGITAL scores the
   PHONE value. That is why the third number is stated rather than left to
   a CW-versus-not test, which would be wrong here and silent about it. *)
procedure TContestOhioQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestOhioQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyState;
end;

initialization
   RegisterContest(OHIOQSOPARTY, TContestOhioQP);

end.
