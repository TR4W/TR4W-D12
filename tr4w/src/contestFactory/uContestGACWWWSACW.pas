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

(* THE GACW WWSA CW DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 45;  QRZRUID: 321;
   Pxm: NoPrefixMults;  ZnM: CQZones;  AIE: ZoneInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;
   XM: CQDXCC;  QP: GACWWWSACWQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'GACW WWSA CW DX Contest'

  THE CABRILLO CONTEST: NAME IS WA7BNM'S WWSA SINCE 2026-10-19 (see
  GetCabrilloName), not the enum's spelling the paragraph below
  describes.

  Blank CABName and ADIFName resolve to the enum's spelling, 'GACW-WWSA-CW'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: GACWWWSACWQSOPointMethod -- another continent 3, another country
  1, our own country 0; then a South American station 5. *)
unit uContestGACWWWSACW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestGACWWWSACW = class(TContestBase)
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
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* DOES IT HAVE A ZONE MULTIPLIER? -- see
         TContestBase.HasZoneMultiplier (M11 S5 part 2). *)
      function HasZoneMultiplier: boolean; override;
      (* THE ZONE MULTIPLIER -- see TContestBase.ZoneMultiplierCount and
         ZoneMultiplierZones (M11 S5). *)
      function ZoneMultiplierCount: integer; override;
      function ZoneMultiplierZones: TZoneMultiplierZones; override;
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

procedure TContestGACWWWSACW.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;

   if aQso.QTH.Continent = SouthAmerica then
      begin
      aQso.QSOPoints := 5;
      end;
end;

function TContestGACWWWSACW.GetDisplayName: string;
begin
   Result := 'GACW WWSA CW DX Contest';
end;

function TContestGACWWWSACW.GetCabrilloName: string;
begin
   (* WA7BNM's Cabrillo name (WA7BNM 45), NY4I 2026-10-19: "do the
      cabrillo renames". TR4W wrote 'GACW-WWSA-CW', which the sponsor's log robot
      accepted neither as the name nor as an alias
      (docs/UDC_CROSSWALK_FINDINGS.md). Only the Cabrillo CONTEST: line
      (and the UDP <contestname>) moves: the id, the ADIF id and the
      display names are their own literals. TR4W reads no Cabrillo
      CONTEST: value back, so the old name needs no read alias. *)
   Result := 'WWSA';
end;

function TContestGACWWWSACW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'GACW-WWSA-CW';
end;

function TContestGACWWWSACW.GetWA7BNMId: integer;
begin
   Result := 45;
end;

function TContestGACWWWSACW.GetQRZRUId: integer;
begin
   Result := 321;
end;

function TContestGACWWWSACW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestGACWWWSACW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestGACWWWSACW.GetFriendlyName: string;
begin
   Result := 'GACW WWSA CW DX Contest';
end;

function TContestGACWWWSACW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestGACWWWSACW.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestGACWWWSACW.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZone;
end;

function TContestGACWWWSACW.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTZone(aText, aExch);
end;

procedure TContestGACWWWSACW.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTZone(SendsStateAfterZone);
end;

function TContestGACWWWSACW.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestGACWWWSACW.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZone(aMy, aQso);
end;

function TContestGACWWWSACW.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTZone(aMy, aQso, aCtx);
end;

function TContestGACWWWSACW.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTZone(aMy, aQso, aCtx);
end;

function TContestGACWWWSACW.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand, cfCQZoneMode];
end;

function TContestGACWWWSACW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`CQDXCC`) until the kind was deleted. *)
function TContestGACWWWSACW.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's CQDXCC. *)
function TContestGACWWWSACW.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* THE ZONE MULTIPLIER -- M11 S5, 2026-10-14: the CQ zones, at every
   station. What the trait's CQZones gave LOGDUPE's zone count and the
   zone-list readers (LOGEDIT, POSTUNIT) through the session kind until
   S5. *)
function TContestGACWWWSACW.ZoneMultiplierCount: integer;
begin
   Result := CQ_ZONE_MULTIPLIERS;
end;

(* IT HAS A ZONE MULTIPLIER, AT EVERY STATION -- M11 S5 part 2,
   2026-10-14: the answer the session kind gave (`kind <> NoZoneMults`)
   before the kind was deleted. *)
function TContestGACWWWSACW.HasZoneMultiplier: boolean;
begin
   Result := True;
end;

function TContestGACWWWSACW.ZoneMultiplierZones: TZoneMultiplierZones;
begin
   Result := zmzCQZones;
end;

initialization
   RegisterContest(GACWWWSACW, TContestGACWWWSACW);

end.
