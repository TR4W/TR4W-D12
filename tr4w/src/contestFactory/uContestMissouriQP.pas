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

(* MISSOURI QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: 'moqsoparty@w0ma.org';  DF: 'missouri_cty';  WA7BNM: 327;
   QRZRUID: 0;  Pxm: NoPrefixMults;  ZnM: NoZoneMults;
   AIE: NoInitialExchange;  DM: DomesticFile;  P: 20;
   AE: RSTDomesticQTHExchange;  XM: NoDXMults;  QP: OnePhoneTwoCW;
   ADIFName: 'MO-QSO-PARTY';  CABName: 'MO-QSO-PARTY';
   CountyLineAllowed: True;  FriendlyName: 'Missouri QSO Party'

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



  ---------------------------------------------------------------------------

  THE BONUSES -- M6, 2026-10-02, moved with ZERO change.



  TWO BONUS STATIONS, W0MA AND K0GQ, 100 POINTS EACH, ONCE. The legacy score

  set a flag when either was logged (LOGDUPE.CheckMOQSOPartyBonusStation, from

  live entry and from the log's loader) and LogEdit.TotalScore added 100 per

  flag after the multiplication. They are this class's declared data now

  (GetBonusStations), counted over the whole log by the base -- any mode, and

  dupes included, because the loader's walk included them. WA7BNM states the

  same rule: "100 points for at least one QSO with a special event station

  (W0MA, K0GQ)".



  THE PEAK-HOUR TALLY IS A PRESERVED DEFECT. Live entry counted each 80 or

  40 m QSO logged from 1400 to 1959 UTC, up to 250, and TotalScore added the

  count; the log's loader never counted, so a reopened log lost it. That is

  kept exactly (TalliesLiveQSO, TContestBase's header on it) and asked of NY4I

  as design Q32: WA7BNM's summary of the sponsor's rules has no such bonus. *)
unit uContestMissouriQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestMissouriQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'MO' -- but the base makes it abstract
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

      (* W0MA and K0GQ, 100 each, once -- see the header. *)
      function GetBonusStations: TBonusStationList; override;
   public
      (* An 80 or 40 m QSO logged from 1400 to 1959 UTC -- see the header. *)
      function TalliesLiveQSO(const aQso: ContestExchange): boolean; override;

      (* The bonus stations, plus the live tally capped at 250. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestMissouriQP.GetDisplayName: string;
begin
   Result := 'Missouri QSO Party';
end;

function TContestMissouriQP.GetHostState: string;
begin
   Result := 'MO';
end;

function TContestMissouriQP.GetCabrilloName: string;
begin
   Result := 'MO-QSO-PARTY';
end;

function TContestMissouriQP.GetADIFContestId: string;
begin
   Result := 'MO-QSO-PARTY';
end;

function TContestMissouriQP.GetWA7BNMId: integer;
begin
   Result := 327;
end;

function TContestMissouriQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMissouriQP.GetSubmissionEmail: string;
begin
   Result := 'moqsoparty@w0ma.org';
end;

function TContestMissouriQP.GetDomesticFileName: string;
begin
   Result := 'missouri_cty';
end;

function TContestMissouriQP.GetFriendlyName: string;
begin
   Result := 'Missouri QSO Party';
end;

function TContestMissouriQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestMissouriQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMissouriQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMissouriQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestMissouriQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMissouriQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestMissouriQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePhoneTwoCW;
end;

(* OnePhoneTwoCW -- `if Mode = CW then 2 else 1`, so DIGITAL scores the
   PHONE value. That is why the third number is stated rather than left to
   a CW-versus-not test, which would be wrong here and silent about it. *)
procedure TContestMissouriQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

const
   (* The legacy tally stopped counting at 250. *)
   MissouriLiveTallyCap = 250;

function TContestMissouriQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 2);
   Result[0].Call := 'W0MA';
   Result[0].Points := 100;
   Result[0].OncePerMode := False;
   Result[1].Call := 'K0GQ';
   Result[1].Points := 100;
   Result[1].OncePerMode := False;
end;

function TContestMissouriQP.TalliesLiveQSO(const aQso: ContestExchange): boolean;
begin
   Result := (aQso.Band in [Band80, Band40])  and
             (aQso.tSysTime.qtHour >= 14)    and
             (aQso.tSysTime.qtHour < 20);
end;

function TContestMissouriQP.BonusPoints(const aTotals: TScoreTotals;
                                        aView: TLoggedQSOView): longint;
var
   tally: longint;
begin
   tally := aTotals.LiveSessionTally;
   if tally > MissouriLiveTallyCap then
      begin
      tally := MissouriLiveTallyCap;
      end;
   Result := inherited BonusPoints(aTotals, aView) + tally;
end;

initialization
   RegisterContest(MOQSOPARTY, TContestMissouriQP);

end.
