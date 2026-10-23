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

(* THE YURI GAGARIN INTERNATIONAL DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'GC';  WA7BNM: 367;  QRZRUID: 82;
   Pxm: GCStation;  ZnM: ITUZones;  AIE: ZoneInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTZoneorDomesticQTH;
   XM: NoDXMults;  QP: GagarinCupQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Yuri Gagarin International DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'GAGARIN-CUP'.
  The Cabrillo name is 'GC' since 2026-10-22 (design Q127); the ADIF id and
  the stored id keep 'GAGARIN-CUP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: GagarinCupQSOPointMethod -- another continent 4, another country
  3, our own 2; tripled on 160 and 80 m, doubled on 40 m; 100 on 2 m and 50
  on 2304 MHz whatever came before; then doubled on phone.

  SET-UP: the R150S list on, the contest name, QSOs by mode, and initial
  exchange overwrite on. *)
unit uContestGagarinCup;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestGagarinCup = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* DOES IT HAVE A PREFIX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasPrefixMultiplier (M11 S3 part 2). *)
      function HasPrefixMultiplier: boolean; override;
      (* THE PREFIX MULTIPLIER -- see TContestBase.PrefixMultiplierKey
         (M11 S3). *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
   public
      (* DOES IT HAVE A ZONE MULTIPLIER? -- see
         TContestBase.HasZoneMultiplier (M11 S5 part 2). *)
      function HasZoneMultiplier: boolean; override;
      (* THE ZONE MULTIPLIER -- see TContestBase.ZoneMultiplierCount and
         ZoneMultiplierZones (M11 S5). *)
      function ZoneMultiplierCount: integer; override;
      function ZoneMultiplierZones: TZoneMultiplierZones; override;
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
      function ExchangeCarriesDomesticQTH: boolean; override;
      function ExchangeCarriesZone: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uTR4WStrings;

procedure TContestGagarinCup.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 4;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;

   if aQso.Band in [Band160, Band80] then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 3;
      end;
   if aQso.Band in [Band40] then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 2;
      end;
   if aQso.Band = Band2 then
      begin
      aQso.QSOPoints := 100;
      end;
   if aQso.Band = Band2304 then
      begin
      aQso.QSOPoints := 50;
      end;
   if aQso.Mode = Phone then
      begin
      aQso.QSOPoints := aQso.QSOPoints * 2;
      end;
end;

function TContestGagarinCup.GetDisplayName: string;
begin
   Result := 'Yuri Gagarin International DX Contest';
end;

function TContestGagarinCup.GetCabrilloName: string;
begin
   (* WA7BNM's Cabrillo name (WA7BNM 367), design Q127 (2026-10-22),
      following NY4I's 2026-10-19 WA7BNM renames. TR4W wrote the enum's
      spelling 'GAGARIN-CUP' (D7's blank CABName). Only the Cabrillo
      CONTEST: line (and the UDP <contestname>) moves: the stored id
      ContestTypeSA and the ADIF id keep 'GAGARIN-CUP'. TR4W reads no
      Cabrillo CONTEST: value back, so the old name needs no read alias. *)
   Result := 'GC';
end;

function TContestGagarinCup.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'GAGARIN-CUP';
end;

function TContestGagarinCup.GetWA7BNMId: integer;
begin
   Result := 367;
end;

function TContestGagarinCup.GetQRZRUId: integer;
begin
   Result := 82;
end;

function TContestGagarinCup.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestGagarinCup.GetDomesticFileName: string;
begin
   Result := 'GC';
end;

function TContestGagarinCup.GetFriendlyName: string;
begin
   Result := 'Yuri Gagarin International DX Contest';
end;

function TContestGagarinCup.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestGagarinCup.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestGagarinCup.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZoneQTH;
end;

function TContestGagarinCup.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTZoneOrDomesticQTH(aText, aExch);
end;

function TContestGagarinCup.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestGagarinCup.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestGagarinCup.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZoneOrState(aMy, aQso);
end;

function TContestGagarinCup.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrZone(aMy, aQso, aCtx);
end;

function TContestGagarinCup.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrZone(aMy, aQso, aCtx);
end;

function TContestGagarinCup.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand,
              cfMultByBand,
              cfErmakSpecification,
              cfVHFBandsEnabled];
end;

function TContestGagarinCup.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestGagarinCup.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.R150SMode := True;
   aSession.ContestName := 'Yuri Gagarin International DX Contest';
   aSession.QSOByMode := True;
   aSession.InitialExchangeOverwrite := True;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestGagarinCup.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_GC);
   aPrompts.AskFieldWithCommentWhenInside(TC_GAGARIN, ncfMyState);
end;

(* A PREFIX MULTIPLIER AT EVERY STATION -- M11 S3 part 2, 2026-10-14:
   the trait this class stated (`GCStation`) until the kind was deleted. *)
function TContestGagarinCup.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* THE PREFIX MULTIPLIER KEY -- M11 S3, 2026-10-14, moved from
   LOGEDIT.SetPrefix.
   The six memorial stations' callsigns, and no key for anyone else --
   SetPrefix's `GCStation` arm, whose list is this contest's own (it was the
   inventory's shape-3 row at logedit:2949). *)
function TContestGagarinCup.PrefixMultiplierKey(const aQso: ContestExchange;
                                                out aKey: PrefixMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if (aQso.Callsign = 'RK1G') or (aQso.Callsign = 'R3K')  or
      (aQso.Callsign = 'RS3A') or (aQso.Callsign = 'RT3F') or
      (aQso.Callsign = 'UP7Z') or (aQso.Callsign = 'UN/RA3VM') then
      begin
      aKey := aQso.Callsign;
      Result := True;
      end;
end;

(* THE ZONE MULTIPLIER -- M11 S5, 2026-10-14: the ITU zones, at every
   station. What the trait's ITUZones gave LOGDUPE's zone count and the
   zone-list readers (LOGEDIT, POSTUNIT) through the session kind until
   S5. *)
function TContestGagarinCup.ZoneMultiplierCount: integer;
begin
   Result := ITU_ZONE_MULTIPLIERS;
end;

(* IT HAS A ZONE MULTIPLIER, AT EVERY STATION -- M11 S5 part 2,
   2026-10-14: the answer the session kind gave (`kind <> NoZoneMults`)
   before the kind was deleted. *)
function TContestGagarinCup.HasZoneMultiplier: boolean;
begin
   Result := True;
end;

function TContestGagarinCup.ZoneMultiplierZones: TZoneMultiplierZones;
begin
   Result := zmzITUZones;
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   WYSIWYGDomestic arm (the trait): the text as received is both the multiplier and
   the QTH, cut to the field's ten characters, and it is always found. *)
function TContestGagarinCup.DomesticMultiplierFromQTH(const aText: Str20;
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
function TContestGagarinCup.DomesticQTHReplacesDXMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(GAGARINCUP, TContestGagarinCup);

end.
