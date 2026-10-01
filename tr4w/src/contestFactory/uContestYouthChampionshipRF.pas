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

(* YOUTH CHAMPIONSHIP OF RUSSIA -- SRR-JR.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'russian';  WA7BNM: 0000;  QRZRUID: 331;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: AgeAndQSONumberExchange;  XM: ARRLDXCC;
   QP: AlwaysOnePointPerQSO;  ADIFName: '';  CABName: '';
   FriendlyName: ''

  SCORING IS AlwaysOnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is SetPoints(1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST has an arm for this contest: a 60-minute tour, RFOBL MODE on,
  phone, and a contest name. uNewContest shares an arm with the All Asian
  and YOTA contests. Both are contest SETUP, not scoring, and stay where
  they are.

  AlwaysOnePointPerQSO SCORES EXACTLY LIKE OnePointPerQSO, and the
  difference is not scoring. Its meaning -- "ignores dupes" in VC.pas --
  is a DUPE POLICY, and since M3 (2026-10-01) this class states it:
  GetMarksDupes answers False, and LOGSUBS2 asks MarksDupes through
  ContestIdentity rather than testing the global ActiveQSOPointMethod. So an
  operator's QSO POINT METHOD line no longer switches dupe marking for this
  contest, in either direction. GetQSOPointMethod still states the row's
  value, for the legacy engine's vocabulary. (The Internet Sprint class says
  the same.)

  FLAGGED, NOT CHANGED: FCONTEST's contest name for this event is
  '?????????? ?????????? ??' -- literal question marks, damaged Cyrillic.
  The D7 source (C:\TR4W, FCONTEST.PAS) holds the same bytes, so this is
  old damage and not a port regression. It is setup and is not touched.

  THE ENUM'S SPELLING IS 'SRR-JR', not the identifier; that is what the
  blank CABName and FriendlyName resolve to.

  NOT A STATE QSO PARTY: P is 0 and DomesticFile names Russian oblasts,
  not a US state's counties. No other family, so it inherits
  TContestFixedPoints.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED. FormatsExchange is
  inherited False, so uCabrilloExchange and uADIFExchange still format
  this contest through its shared AE arm. *)
unit uContestYouthChampionshipRF;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestYouthChampionshipRF = class(TContestFixedPoints)
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
      function GetMarksDupes: boolean; override;
   public
      constructor Create(aContest: ContestType); override;
   end;

implementation

uses
   uContestRegistry;

constructor TContestYouthChampionshipRF.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(1, 1, 1);
end;

function TContestYouthChampionshipRF.GetDisplayName: string;
begin
   Result := 'SRR-JR';
end;

function TContestYouthChampionshipRF.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'SRR-JR';
end;

function TContestYouthChampionshipRF.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'SRR-JR';
end;

function TContestYouthChampionshipRF.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestYouthChampionshipRF.GetQRZRUId: integer;
begin
   Result := 331;
end;

function TContestYouthChampionshipRF.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestYouthChampionshipRF.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestYouthChampionshipRF.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'SRR-JR';
end;

function TContestYouthChampionshipRF.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestYouthChampionshipRF.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestYouthChampionshipRF.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestYouthChampionshipRF.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestYouthChampionshipRF.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestYouthChampionshipRF.GetExchangeKind: ExchangeType;
begin
   Result := AgeAndQSONumberExchange;
end;

function TContestYouthChampionshipRF.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := AlwaysOnePointPerQSO;
end;

function TContestYouthChampionshipRF.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

function TContestYouthChampionshipRF.GetMarksDupes: boolean;
begin
   (* "Ignores dupes" -- the meaning the row's AlwaysOnePointPerQSO carried.
      See the unit header. *)
   Result := False;
end;

initialization
   RegisterContest(YOUTHCHAMPIONSHIPRF, TContestYouthChampionshipRF);

end.
