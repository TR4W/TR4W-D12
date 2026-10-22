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

(* THE RADIO YOC CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 119;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndPreviousQSONumber;
   XM: ARRLDXCC;  QP: ThreePointsPerQSO;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'RADIO-YOC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  IT IS THE POPOV YOUTH CUP (the A.S. Popov Cup, SRR), and its rules are
  the SRR 2026 regulation (QRZ.RU contest 119, read 2026-10-22), built under
  NY4I's standing ruling of that day that a definitive statement in the
  sponsor's current rules is followed (Q136):

    POINTS     "1 point for each contact" -- it was ThreePointsPerQSO (D7).
    EXCHANGE   five digits: the operator's age (two digits; the oldest
               operator's for a multi-op) and the serial from 001. It was the
               previous QSO's received number + the serial (D7). The age is
               MY STATE, as the Youth Championship RF and the All Asian keep
               it; TC_ENTERYOURAGEINMYSTATEFIELD asks for it.
    MULTIPLIER "each subject of the Russian Federation and each country
               outside it, once for the whole contest regardless of band":
               no cfMultByBand, and RFOBL MODE (rfobl.dat over CTY.DAT, the
               Youth Championship RF's mechanism) resolves a Russian call to
               its subject, so the DX key is the subject or the country.
    REPEATS    "allowed in different tours, and in one tour on different
               bands" -- 8 tours of 30 minutes from the 07:00 UTC start
               (DupeKeyTour).
    BANDS      7 and 14 MHz, SSB (UsesBand; the session starts in phone --
               nothing yet credits by mode, Q98).

  NOT BUILT, REPORTED: "at least three minutes must pass between repeat
  contacts on the same band" -- a dupe key cannot see the time of the
  previous QSO. rfobl.dat has 82 subjects of the 89. *)
unit uContestRadioYOC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRadioYOC = class(TContestBase)
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

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
   public
      (* 40 AND 20 METRES -- see TContestBase.UsesBand. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* THE TOUR A QSO FALLS IN -- see TContestBase.DupeKeyTour. *)
      function DupeKeyTour(const aQso: ContestExchange): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* THE NEW CONTEST DIALOG'S PROMPTS -- see
         TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uContestFixedPoints,
   uTR4WStrings,
   SysUtils;

const
   (* THE SRR 2026 REGULATION: 07:00-10:59 UTC, "8 tours of 30 minutes
      each". *)
   CONTEST_START_MINUTE_UTC = 7 * 60;
   TOUR_MINUTES             = 30;
   TOUR_COUNT               = 8;

(* "1 point is awarded for each contact" -- in every mode (SRR 2026 regulation, Q136, 2026-10-22). It was
   ThreePointsPerQSO, D7's arm. *)
procedure TContestRadioYOC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

(* "bands: 7 MHz, 14 MHz" -- 40 and 20 m (and the Q98 ruling, 40/20 m
   phone). A QSO on any other band is logged, scores 0, earns no multiplier
   and is never a dupe (design 7.4). *)
function TContestRadioYOC.UsesBand(aBand: BandType): boolean;
begin
   Result := (aBand = Band40) or (aBand = Band20);
end;

(* "Repeat contacts are allowed in different tours, and within one tour on
   different bands" -- a repeat is allowed in another tour, or in the same
   tour on another band. 8 tours of 30 minutes from 07:00 UTC; the
   tour is read from the QSO's own logged (UTC) time. A QSO outside the
   contest's four hours has no tour, and its key is the call alone. *)
function TContestRadioYOC.DupeKeyTour(const aQso: ContestExchange): string;
var
   minutes: integer;
begin
   Result := '';
   minutes := aQso.tSysTime.qtHour * 60 + aQso.tSysTime.qtMinute - CONTEST_START_MINUTE_UTC;
   if (minutes >= 0) and
      (minutes < TOUR_MINUTES * TOUR_COUNT) then
      begin
      Result := 'TOUR ' + IntToStr(minutes div TOUR_MINUTES + 1);
      end;
end;

(* SET-UP. The 30-minute tour countdown; RFOBL MODE, so a Russian call
   resolves to its subject -- the multiplier "each subject of the Russian
   Federation and each country"; and SSB, the one mode ("mode of emission:
   SSB"). *)
procedure TContestRadioYOC.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   aSession.MinitourDuration := TOUR_MINUTES;
   aSession.RfoblMode := True;
   aSession.Mode := Phone;
end;

(* THE AGE IS SENT FROM MY STATE -- the Youth Championship RF's prompt, for
   the same five-digit age + serial exchange. *)
procedure TContestRadioYOC.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
end;

function TContestRadioYOC.GetDisplayName: string;
begin
   Result := 'RADIO-YOC';
end;

function TContestRadioYOC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RADIO-YOC';
end;

function TContestRadioYOC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RADIO-YOC';
end;

function TContestRadioYOC.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRadioYOC.GetQRZRUId: integer;
begin
   Result := 119;
end;

function TContestRadioYOC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRadioYOC.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRadioYOC.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'RADIO-YOC';
end;

function TContestRadioYOC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

(* THE EXCHANGE IS AGE + SERIAL -- SRR 2026 regulation: "control numbers
   consist of five digits. The first two digits are the operator's age ...
   the last three digits are the serial number of the contact, starting with
   001" (Q136, 2026-10-22). It was QSONumberAndPreviousQSONumber (D7), whose
   previous-number recovery in MainUnit's log loader went with it. *)
function TContestRadioYOC.GetExchangeKind: ExchangeType;
begin
   Result := AgeAndQSONumberExchange;
end;

function TContestRadioYOC.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberAge;
end;

(* THE FIVE DIGITS AS SENT, OR AS TWO WORDS. The engine's age + serial parser
   wants two words ("15 001"); the number is sent as one ("15001"), so one
   five-digit word is split into its age and its serial first. *)
function TContestRadioYOC.ParseReceivedExchangeFormat(const aText: string;
                                                      aParsers: TExchangeParsers;
                                                      var aExch: ContestExchange): boolean;
var
   text: string;
   i: integer;
   allDigits: boolean;
begin
   text := Trim(aText);
   allDigits := Length(text) = 5;
   for i := 1 to Length(text) do
      begin
      if (text[i] < '0') or (text[i] > '9') then
         begin
         allDigits := False;
         end;
      end;

   if allDigits then
      begin
      Result := aParsers.ParseAgeAndQSONumber(Copy(text, 1, 2) + ' ' + Copy(text, 3, 3), aExch);
      end
   else
      begin
      Result := aParsers.ParseAgeAndQSONumber(aText, aExch);
      end;
end;

(* THE AGE (MY STATE) AND THE SERIAL TO THREE DIGITS -- the Youth Championship
   RF's layout, the same sponsor's Ermak report for the same exchange. *)
function TContestRadioYOC.GetADIFSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange): string;
begin
   Result := ADIFSentStateQSONumber2(aMy, aQso);
end;

function TContestRadioYOC.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentStateQSONumber2(aMy, aQso, aCtx);
end;

function TContestRadioYOC.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange;
                                                      const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedAgeQSONumber(aMy, aQso, aCtx);
end;

function TContestRadioYOC.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfErmakSpecification];
end;

function TContestRadioYOC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCC`) until the kind was deleted. *)
function TContestRadioYOC.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's ARRLDXCC. *)
function TContestRadioYOC.DXMultiplierKey(const aQso: ContestExchange;
                                          out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station -- the ARRLDXCC kind was in the ARRL set. *)
function TContestRadioYOC.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;

initialization
   RegisterContest(RADIOYOC, TContestRadioYOC);

end.
