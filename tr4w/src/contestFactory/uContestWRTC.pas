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

(* THE WRTC (IARU HF WORLD CHAMPIONSHIP RULES).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'iaruhq';  WA7BNM: 67;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTZoneOrSocietyExchange;
   XM: ARRLDXCC;  QP: WRTCQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'IARU HF World Championship'

  THE CABRILLO CONTEST: NAME IS WA7BNM'S IARU-HF SINCE 2026-10-19 (see
  GetCabrilloName), not the enum's spelling the paragraph below
  describes.

  Blank CABName and ADIFName resolve to the enum's spelling, 'WRTC'.

  THE NAME IS WRTC'S OWN SINCE 2026-10-16 (NY4I, design Q58): the friendly
  and display name are 'World Radiosport Team Championship'. The row's
  'IARU HF World Championship' quoted above is history -- it was the event
  WRTC runs inside, and it gave WRTC and IARU-HF one name in the New Contest
  drop-down.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: WRTCQSOPointMethod -- on 80 to 10 m, 2 for Europe and 5
  elsewhere; 0 on any other band, which still earns its multipliers (the
  arm sets no InhibitMults, and this states no UsesBand -- design Q44).

  SET-UP: 80 m. FoundContest's arm named it beside CQ WPX RTTY until M7b
  batch 1; it is its own now.

  NOT MOVED, ON PURPOSE: the main menu and OpenTR4WWindow refuse it the
  TRMASTER, Telnet and post-scores windows; LOGEDIT turns off Super Check
  Partial for it; LOGSUBS2's score posting reports two multipliers for it.
  Each is a display or networking rule with no seam yet (M9) -- the same
  reason All Asian's HamScore arm stayed at batch 1. *)
unit uContestWRTC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWRTC = class(TContestBase)
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
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   protected
      (* THE OPERATING AIDS -- M9a. *)
      function GetPermittedOperatingAids: TOperatingAids; override;
   public
      (* THE SCORE-POSTING XML -- M9a. *)
      function ScorePostingMultiplierType(aKind: RemainingMultiplierType;
                                          aAllModes: boolean): string; override;
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
      (* THE DOMESTIC QTH -- see TContestBase.DomesticMultiplierFromQTH
         (M11 S6). *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; override;
      (* see TContestBase.DomesticQTHReplacesDXMultiplier (M11 S6). *)
      function DomesticQTHReplacesDXMultiplier: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesZone: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry;

(* WRTCQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestWRTC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Band in [Band80..Band10] then
      begin
      if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end;
end;

function TContestWRTC.GetDisplayName: string;
begin
   (* NY4I, 2026-10-16, design Q58 -- see the header. *)
   Result := 'World Radiosport Team Championship';
end;

function TContestWRTC.GetCabrilloName: string;
begin
   (* WA7BNM's Cabrillo name (WA7BNM 67), NY4I 2026-10-19: "do the
      cabrillo renames". TR4W wrote 'WRTC', which the sponsor's log robot
      accepted neither as the name nor as an alias
      (docs/UDC_CROSSWALK_FINDINGS.md). Only the Cabrillo CONTEST: line
      (and the UDP <contestname>) moves: the id, the ADIF id and the
      display names are their own literals. TR4W reads no Cabrillo
      CONTEST: value back, so the old name needs no read alias.

      THE IARU HF CHAMPIONSHIP WRITES IARU-HF TOO, ON PURPOSE: WRTC is
      contested inside it, and WA7BNM and N1MM both write IARU-HF for it.
      Nothing in TR4W maps a Cabrillo name back to a contest, so two
      contests sharing one breaks no reader. *)
   Result := 'IARU-HF';
end;

function TContestWRTC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WRTC';
end;

function TContestWRTC.GetWA7BNMId: integer;
begin
   Result := 67;
end;

function TContestWRTC.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWRTC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWRTC.GetDomesticFileName: string;
begin
   Result := 'iaruhq';
end;

function TContestWRTC.GetFriendlyName: string;
begin
   (* NY4I, 2026-10-16, design Q58 -- see the header. *)
   Result := 'World Radiosport Team Championship';
end;

function TContestWRTC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestWRTC.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrSocietyExchange;
end;

function TContestWRTC.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZoneQTH;
end;

function TContestWRTC.ParseReceivedExchangeFormat(const aText: string;
                                                  aParsers: TExchangeParsers;
                                                  var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTZoneOrSociety(aText, aExch);
end;

procedure TContestWRTC.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrZone(SendsStateAfterZone);
end;

function TContestWRTC.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestWRTC.GetADIFSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZoneOrState(aMy, aQso);
end;

function TContestWRTC.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrZone(aMy, aQso, aCtx);
end;

function TContestWRTC.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrZone(aMy, aQso, aCtx);
end;

function TContestWRTC.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestWRTC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestWRTC.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
end;

(* WRTC IS UNASSISTED: NO SUPER CHECK PARTIAL, NO DX CLUSTER, NO LIVE SCORE
   POSTING -- the three `Contest = WRTC` tests that greyed the menus
   (MainUnit.CreateMainWindow), refused the windows (OpenTR4WWindow) and
   skipped the partial-call check (LOGEDIT's SuperCheckPartial), moved here
   at M9a (2026-10-02) as the one thing they each said. *)
function TContestWRTC.GetPermittedOperatingAids: TOperatingAids;
begin
   Result := [];
end;

(* THE WRTC SCORE COMPUTER WANTS HQ AND COUNTRY, ON THE ALL-MODES ROW ONLY --
   LOGSUBS2's `Contest = WRTC` branch of the dynamic-results XML, moved here at
   M9a: rmDomestic and rmDX with their WRTC labels, nothing else. The writer
   walked only CW, digital and phone until Q109 (2026-10-16), so this row was
   never reached and WRTC posted no multiplier; it now walks the all-modes row
   too, per band and in total, and WRTC's local aggregators receive HQ and
   country there. The UDP score is NOT suppressed for WRTC (NY4I, Q109): this
   message is what that class of listener was built to read. *)
function TContestWRTC.ScorePostingMultiplierType(aKind: RemainingMultiplierType;
                                                 aAllModes: boolean): string;
begin
   Result := '';
   if not aAllModes then
      begin
      Exit;
      end;
   case aKind of
      rmDomestic:
         begin
         Result := 'HQ';
         end;
      rmDX:
         begin
         Result := 'country';
         end;
   end;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCC`) until the kind was deleted. *)
function TContestWRTC.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's ARRLDXCC. *)
function TContestWRTC.DXMultiplierKey(const aQso: ContestExchange;
                                      out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station -- the ARRLDXCC kind was in the ARRL set. *)
function TContestWRTC.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   WYSIWYGDomestic arm (the trait): the text as received is both the multiplier and
   the QTH, cut to the field's ten characters, and it is always found. *)
function TContestWRTC.DomesticMultiplierFromQTH(const aText: Str20;
                                                var aMultiplier: Str10;
                                                var aQTH: Str10;
                                                var aFound: boolean): TDomesticQTHAnswer;
begin
   aMultiplier := aText;
   aQTH := aText;
   aFound := True;
   Result := dqaDecided;
end;

(* A DOMESTIC QTH TAKES THE PLACE OF THE DX MULTIPLIER -- M11 S6 part 1,
   moved from LOGDUPE.GetDXQTH's `= WYSIWYGDomestic` guard (the trait). See
   TContestBase.DomesticQTHReplacesDXMultiplier. *)
function TContestWRTC.DomesticQTHReplacesDXMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(WRTC, TContestWRTC);

end.
