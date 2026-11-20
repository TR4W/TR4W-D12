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

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (audit, 2026-11-20). The text is
  docs/ContestRules/QSOParties/Ohio/OH-QSO-PARTY-Rules.txt. Until then this
  class was D7's row; five things in it were not the sponsor's.

  EXCHANGE HAS NO SERIAL -- "Ohio stations send RST and their Ohio county.
    Non Ohio W/VE stations (including KH6/KL7) send RST and their state or
    province. DX stations outside of W/VE send RST and "DX"." The row's
    RSTQSONumberAndDomesticQTH asked for a serial too and logged "599 ADAM" as
    serial 599. It is RSTDomesticQTHExchange now, as New York's and North
    Carolina's: a DX station's "DX" is looked up in the file (ohio.dom's
    Dx = DX), so an Ohio entrant can log one.

  NO COUNTY LINES -- "No station may claim simultaneous operation in more than
    one county, state, or province." GetCountyLineCountiesMax is 0, as
    Michigan's: a second QTH in one exchange is refused. It was unlimited
    ("not looked up yet") until this audit.

  BANDS AND MODES -- "CW and SSB on 160, 80, 40, 20, 15, and 10 meters." UsesBand
    is those six. UsesMode credits CW and phone; a digital QSO is an automatic
    X-QSO ("All single operator entries are classified as mixed mode" means CW
    plus SSB). FM is not named, and NY4I ruled (2026-11-20) "Just CW and
    SSB": an FM QSO is an automatic X-QSO too.

  MULTIPLIERS -- "For OHIO STATIONS - multipliers are the 49 American States
    (excluding Ohio), 1 Washington DC, 11 Canadian Provinces (NL, PE, NS,
    NB,VE2-7, NT), 88 Ohio Counties and 1 DX." ohio.dom had no DC and no DX
    entry, so an Ohio entrant could not log either; both are there now
    (DC.DOM, Dx = DX). THE 11 PROVINCES are the sponsor's own list (NY4I,
    2026-11-20, from the party's site): NL PE NS NB QC ON MB SK AB BC and NT
    "= Yukon-NWT-Nu". So ohio.dom includes ohio_ve.dom, not the shared
    P13.DOM: Yukon and Nunavut are their own QTHs (YT, NU, as written) whose
    MULTIPLIER is NT (`Yt > Nt`, the shape of Indiana's `Dc > Md`). "Multipliers
    are counted once per mode" is cfMultByMode, as it was.
 *)
unit uContestOhioQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

type
   TContestOhioQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
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
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;

      (* NO COUNTY LINES -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;
   public
      (* CW and SSB on 160 to 10 m -- see the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- the RSTDomesticQTH shape's rule (M11
         S7). The count is still refused above one: no county lines. *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* OHIO IS NOT A STATE MULTIPLIER FOR A OHIO ENTRANT --
         #88 round 3 (2026-10-26). See the implementation. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_OH carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 330 of 330 non-state rows are county keys of its
         own county file; the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

implementation

uses
   SysUtils,   (* Trim *)
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestOhioQP.GetDisplayName: string;
begin
   Result := 'Ohio QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row OHIO QSO PARTY: rules https://www.ohqp.org/; rules year 2026/2027.
   Checked against the sponsor's 2026 rules (2026-11-20): "the fourth
   Saturday of August. The contest period extends from 1200 EDT [noon] to
   2400 EDT [midnight] (1600Z Saturday until 0400Z Sunday)" -- 12 h. *)
function TContestOhioQP.GetSchedule: string;
begin
   Result := '4th Saturday of August at 16:00 UTC for 12h';
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

function TContestOhioQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOhioQP.GetExchangeKind: ExchangeType;
begin
   (* "Ohio stations send RST and their Ohio county" -- no serial number. *)
   Result := RSTDomesticQTHExchange;
end;

function TContestOhioQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   (* The RSTDomesticQTH shape's field set, as New York's and North
      Carolina's: uTestExchangeFields holds a class to the fields its session
      shape marks. (It marks a serial though the rules send none -- a lead
      for NY4I, reported by the audit.) *)
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

procedure TContestOhioQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestOhioQP.ParseReceivedExchangeFormat(const aText: string;
                                                    aParsers: TExchangeParsers;
                                                    var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

function TContestOhioQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestOhioQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange): string;
begin
   (* A DX entrant sends "DX" -- the rules' "DX stations ... send RST and DX". *)
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestOhioQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestOhioQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestOhioQP.GetInStateDomesticFileName: string;
begin
   Result := 'ohio';
end;

function TContestOhioQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode];
end;

(* CW 2, PHONE 1 (OnePhoneTwoCW). FM and digital never reach here: UsesMode
   refuses them (the header), so the third number is never used. *)
procedure TContestOhioQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestOhioQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* RST and the sent county or state -- no serial (the header). A DX
      entrant has none and sends "DX". *)
   if Trim(aStation.MyState) = '' then
      begin
      Result := ' 5NN DX';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

(* "No station may claim simultaneous operation in more than one county,
   state, or province." Zero, so a second QTH in one exchange is refused --
   the way Michigan's is. *)
function TContestOhioQP.GetCountyLineCountiesMax: integer;
begin
   Result := 0;
end;

(* "CW and SSB on 160, 80, 40, 20, 15, and 10 meters." *)
function TContestOhioQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

(* "CW and SSB": CW and phone. NY4I, 2026-11-20: "Just CW and SSB" -- FM and
   digital QSOs are automatic X-QSOs -- an imported FM QSO (Phone with an FM
   submode) too: uContestBase.ModeIsCWOrSSB. An identity fact: no station is
   asked. *)
function TContestOhioQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := ModeIsCWOrSSB(aMode, aExtMode);
end;

(* OHIO IS NOT A STATE MULTIPLIER FOR A OHIO ENTRANT -- #88
   round 3 (2026-10-26), the sponsor's 2026 rules:
   "For OHIO STATIONS - multipliers are the 49 American States (excluding
   Ohio), 1 Washington DC".
   ohio.dom includes the shared S50.DOM, which holds Oh; an
   in-state entrant's QSO whose domestic multiplier is the host state
   itself earns no multiplier and keeps its points. Outside Ohio the
   multipliers are the counties, and none is spelled as the state. The
   shared file is never edited for this: other contests read it. *)
function TContestOhioQP.CountsAsMultiplier(const aQso: ContestExchange;
                                           aKind: RemainingMultiplierType): boolean;
begin
   Result := not (Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

function TContestOhioQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

function TContestOhioQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestOhioQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_OH';
end;

initialization
   RegisterContest(OHIOQSOPARTY, TContestOhioQP);

end.
