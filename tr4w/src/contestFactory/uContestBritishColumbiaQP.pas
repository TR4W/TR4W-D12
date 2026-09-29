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

(* BRITISH COLUMBIA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 've7_cty';  WA7BNM: 269;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 16;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: BCQPQSOPointMethod;  ADIFName: 'BC-QSO-PARTY';  CABName: '';
   FriendlyName: 'British Columbia QSO Party'

  ITS CABName IS BLANK IN THE ROW AND BLANK IS NOT THE ANSWER. PostUnit's rule,
  reproduced by TContestBase.GetCabrilloName, is that an empty CABName means
  ContestTypeSA[ct] -- which for this contest is the four letters BCQP, so that
  is what a submitted log's CONTEST: line reads and what is stated below.
  ADIFName is 'BC-QSO-PARTY', ADIF 3.1.7's id, since 2026-09-29.

  ITS FORMER ADIF ID IS 'BCQP'. The ADIF id was blank until 2026-09-29, and
  while it was, ADIF export fell back to the enum's spelling -- so every file
  exported before then carries CONTEST_ID 'BCQP'. Import accepts it, export
  never writes it: NY4I, "Yes support old spellings."

  ---------------------------------------------------------------------------
  A QUESTION OWED TO NY4I: THIS IS A CANADIAN PROVINCE AND THE PROGRAM CALLS IT
  A US QSO PARTY.

  TContestBase.GetIsUSQSOParty answers ContestsArray[c].P <> 0, and this row
  has P: 16 -- an index into QSOParties, whose sixteenth entry is
  (InsideStateDOMFile: 've7'; StateName: 'VE7'). So the flag that is named "US
  QSO party" is True for British Columbia today, and has been for as long as
  the row has existed.

  NOTHING IS CHANGED HERE. TContestStateQSOPartyBase states True unconditionally
  and this class inherits that, so the answer is exactly what it was before the
  move. Changing it is not a tidy-up: the P index also selects the domestic
  file, and IsUSQSOParty is read where multiplier and country handling are
  decided, so flipping it could move scoring in a way NO GATE IN THIS TREE
  WOULD SEE -- the golden corpus is blind to scoring and test-contest-factory
  compares against the legacy arm, which has the same flag.

  So it is reported, not decided.

  ---------------------------------------------------------------------------
  ITS HOST STATE IS STATED AS 'BC' AND THE DERIVATION WOULD SAY NOTHING AT ALL.

  VC.USQSOPartyStateName returns a StateName only when it is TWO characters, to
  keep the multi-state and non-US rows ('7th area', 'IN7QPNE', 'VE7') out of an
  ADIF STATE field. This party's StateName is the three-letter 'VE7', so the
  derivation answers '' -- and TContestStateQSOPartyBase makes GetHostState
  abstract precisely so a party cannot inherit a blank.

  'BC' is the province's postal code, which is what ADIF's STATE field carries
  for a Canadian station. IT CHANGES NOTHING TODAY: uADIF calls
  USQSOPartyStateName(c) directly and does not go through this class, so the
  exporter still emits no STATE for a BCQP log. If that call site is ever
  repointed at the contest object, this contest starts emitting STATE=BC --
  which is probably right and is NY4I's to confirm.

  ---------------------------------------------------------------------------
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
unit uContestBritishColumbiaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestBritishColumbiaQP = class(TContestStateQSOPartyBase)
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
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestBritishColumbiaQP.GetDisplayName: string;
begin
   Result := 'British Columbia QSO Party';
end;

function TContestBritishColumbiaQP.GetHostState: string;
begin
   Result := 'BC';
end;

function TContestBritishColumbiaQP.GetCabrilloName: string;
begin
   Result := 'BCQP';
end;

function TContestBritishColumbiaQP.GetADIFContestId: string;
begin
   (* STATED, NOT LEFT BLANK. The row held '' until 2026-09-29; ADIF 3.1.7
      defines BC-QSO-PARTY and NY4I had VC.pas corrected.

      ADIFName IS WHAT ADIF EXPORT WRITES AS CONTEST_ID (NY4I, who wrote
      that code), and it is also what import matches on. A BLANK IS NOT
      'no id' -- export falls back to the contest's quoted name -- so a
      blank row still produced a CONTEST_ID, just not the standard one.
      Stating it means the exported file now carries the ADIF identifier
      a sponsor's robot expects, and the class cannot drift from it. *)
   Result := 'BC-QSO-PARTY';
end;

function TContestBritishColumbiaQP.GetFormerADIFContestIds: TContestIdList;
begin
   (* What ADIF export wrote while the row's ADIFName was blank: the enum's
      spelling. See the unit header. *)
   Result := ContestIdList(['BCQP']);
end;

function TContestBritishColumbiaQP.GetWA7BNMId: integer;
begin
   Result := 269;
end;

function TContestBritishColumbiaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestBritishColumbiaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestBritishColumbiaQP.GetDomesticFileName: string;
begin
   Result := 've7_cty';
end;

function TContestBritishColumbiaQP.GetFriendlyName: string;
begin
   Result := 'British Columbia QSO Party';
end;

function TContestBritishColumbiaQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestBritishColumbiaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestBritishColumbiaQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestBritishColumbiaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestBritishColumbiaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestBritishColumbiaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestBritishColumbiaQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := BCQPQSOPointMethod;
end;

(* BCQPQSOPointMethod -- `if Mode = PHONE then 2 else 4`.

   THE INVERTED SHAPE, AND THE THIRD ARGUMENT IS WHERE IT SHOWS. The test is
   PHONE-versus-not, so DIGITAL takes the CW value of 4, not the phone value of
   2. Most of the state parties test CW-versus-not and their digital number is
   the phone one; writing 2 here would reproduce the phone and CW arms
   perfectly and be silently wrong about every digital QSO.

   THE COMMENTED-OUT VA7ODX BONUS IN THE LEGACY ARM IS LEFT COMMENTED AND IS
   NOT IMPLEMENTED:

     if RXData.Callsign = 'VA7ODX' then
        rxdata.QSOPoints := rxdata.qsopoints + 20;

   It is not live code today, so implementing it would be new scoring
   behaviour, and this move changes no score. *)
procedure TContestBritishColumbiaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 4, 2, 4);
end;

initialization
   RegisterContest(BCQP, TContestBritishColumbiaQP);

end.
