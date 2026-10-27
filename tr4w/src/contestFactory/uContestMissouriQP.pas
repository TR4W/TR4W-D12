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



  THE PEAK-HOUR BONUS -- Q32 (NY4I, 2026-10-15; built 2026-10-17). The
  sponsor's 2026 rules (w0ma.org, moqp-2026-rules-final.pdf, Points, rule 7):
  "Any valid contacts made between the hours of 1400 UTC Saturday to 2000
  UTC Saturday and 1400 UTC Sunday to 2000 UTC Sunday on the 40 and 80 meter
  bands will count as an additional point each. Up to 250-point bonus can be
  added to the total score." WA7BNM's summary omitted it.

  NY4I: "The wall clock logged into the log record determines this." So it
  is counted over the WHOLE LOG (the view), from each QSO's OWN logged time
  and band -- never the clock now (Q13) -- and a reopened, rescored or
  exported log scores it exactly as live entry did. A VALID contact only:
  no dupe, and none the contest does not credit (an off-band QSO, or an
  out-of-state entrant's QSO with a non-Missouri station, Q107 -- the same
  two questions ScoreQSO asks before it scores). Its hour is 14 to 19 UTC on
  any day: the contest runs 1400 Saturday to 0400 Sunday and 1400 to 2000
  Sunday, so the hour alone names both windows. 2000 itself is out.

  UNTIL Q32 THIS WAS A PRESERVED DEFECT: live entry counted it
  (TalliesLiveQSO, LOGDUPE.LiveSessionTally) and the log's loader never did,
  so a reopened log lost it. Both are deleted.

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (#88, 2026-10-26). The text is
  docs/ContestRules/QSOParties/Missouri/MO-QSO-PARTY-Rules.txt.

  POINTS -- "Valid phone contacts equals one point each. Valid CW contacts
    equals two points each. Valid digital contacts equals two points each."
    Digital was 1 until #88: the legacy OnePhoneTwoCW tested CW-versus-not.
    FM is phone.

  BANDS -- "CW, Digital, and phone operation on 160M, 80M, 40M, 20M, 15M,
    10M, 6M, 2M, 1.25M, and 70cm." No WARC. UsesBand.

  MODES -- "FT4/FT8 or similar modes that do not allow free text sending
    will not be allowed." UsesMode refuses the digital submodes TR4W can
    name as such -- FT8, FT4 and JT65, the WSJT structured-message modes --
    so such a QSO is an automatic X-QSO. Every other digital submode, and a
    digital QSO whose submode is not known (eNoMode, eData), is credited.

  BONUSES -- W0MA, K0GQ and the peak-hour bonus are unchanged. The 100-point
    bonus "for successfully submitting a Cabrillo log electronically" is NOT
    added: TR4W cannot know whether a log was submitted (asked of NY4I on
    #88).

  HOLT COUNTY STAYS HTL -- the sponsor's Table 1 says "Holt HTL"; DXLog's
    HLT is the error.

  DC IS MARYLAND -- "Note: 'Maryland' includes the District of Columbia."
    missouri.dom (the in-state file, where states are multipliers) maps
    Dc > Md. *)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* W0MA and K0GQ, 100 each, once -- see the header. *)
      function GetBonusStations: TBonusStationList; override;

      (* IS THIS LOGGED QSO A PEAK-HOUR CONTACT? -- a valid 80 or 40 m QSO
         whose logged hour is 14 to 19 UTC. See the header (Q32). *)
      function IsPeakHourContact(const aQso: ContestExchange): boolean;
   public
      (* 160-10 m without WARC, 6 m, 2 m, 1.25 m and 70 cm -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, phone (FM is phone) and digital but FT8, FT4 and JT65 -- the
         header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* The bonus stations, plus one point per peak-hour contact in the
         log, capped at 250 -- see the header. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
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

function TContestMissouriQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMissouriQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestMissouriQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestMissouriQP.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

procedure TContestMissouriQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestMissouriQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestMissouriQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestMissouriQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestMissouriQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestMissouriQP.GetInStateDomesticFileName: string;
begin
   Result := 'missouri';
end;

function TContestMissouriQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

(* CW 2, PHONE 1, DIGITAL 2 -- the sponsor's Points 1-3 (see the header).
   FM is phone. A QSO off the bands or modes never reaches here (UsesBand,
   UsesMode), nor one an out-of-state entrant may not credit
   (CreditsWorkedStation). Both and NoMode are not modes a contact is made
   in. *)
procedure TContestMissouriQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 2;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestMissouriQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432];
end;

(* "FT4/FT8 or similar modes that do not allow free text sending will not be
   allowed." The submode is tested only to EXCLUDE the ones named: eNoMode
   and eData mean "some digital submode" and are credited, as the contract
   asks (ADDING_A_CONTEST, UsesMode). An identity fact: no station is
   asked. *)
function TContestMissouriQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := not (aExtMode in [eFT8, eFT4, eJT65]);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

const
   (* "Up to 250-point bonus can be added to the total score." *)
   MissouriPeakHourBonusCap = 250;

function TContestMissouriQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 2);
   Result[0].Call := 'W0MA';
   Result[0].Points := 100;
   Result[0].Scope := bsOnce;
   Result[1].Call := 'K0GQ';
   Result[1].Points := 100;
   Result[1].Scope := bsOnce;
end;

function TContestMissouriQP.IsPeakHourContact(const aQso: ContestExchange): boolean;
begin
   (* VALID FIRST, by the questions ScoreQSO asks before it scores, so a
      QSO that scores nothing earns no bonus point either -- an FT8 QSO
      (UsesMode) included. *)
   Result := (not aQso.ceDupe)                                     and
             ContestCreditsBand(Self, aQso.Band)                   and
             ContestCreditsMode(Self, aQso.Mode, aQso.ExtMode)     and
             CreditsWorkedStation(aQso)               and
             (aQso.Band in [Band80, Band40])          and
             (aQso.tSysTime.qtHour >= 14)             and
             (aQso.tSysTime.qtHour < 20);
end;

function TContestMissouriQP.BonusPoints(const aTotals: TScoreTotals;
                                        aView: TLoggedQSOView): longint;
var
   peakHour: longint;
   i: integer;
begin
   peakHour := 0;
   for i := 0 to aView.Count - 1 do
      begin
      if IsPeakHourContact(aView.QSO(i)) then
         begin
         inc(peakHour);
         if peakHour = MissouriPeakHourBonusCap then
            begin
            Break;
            end;
         end;
      end;
   Result := inherited BonusPoints(aTotals, aView) + peakHour;
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestMissouriQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(MOQSOPARTY, TContestMissouriQP);

end.
