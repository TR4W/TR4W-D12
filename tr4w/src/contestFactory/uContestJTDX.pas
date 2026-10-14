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

(* THE MONGOLIAN (JT) DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: MongolianCallSignPrefix;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;
   XM: ARRLDXCCWithNoJT;  QP: JTDXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'MONGOLIAN DX'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: JTDXQSOPointMethod -- another continent 3, another country 2,
  our own 1; a JT station working JT 0.

  SET-UP: a zone initial exchange, and Mongolian call-sign prefixes as the
  prefix multiplier -- both the row's own values, restated as the arm did,
  so a statement made before the CONTEST line is still overwritten. *)
unit uContestJTDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestJTDX = class(TContestBase)
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
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* NO DescribeSession -- M11 S2, 2026-10-14 (plan 1.3). It stated the
         zone initial exchange and the Mongolian prefix multiplier, both
         already its traits, for every station; with those two gone it
         stated nothing, and the base's says nothing. *)
   public
      (* DOES IT HAVE A PREFIX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasPrefixMultiplier (M11 S3 part 2). *)
      function HasPrefixMultiplier: boolean; override;
      (* THE PREFIX MULTIPLIER -- see TContestBase.PrefixMultiplierKey
         (M11 S3). *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestJTDX.CalculateQSOPoints(var aQso: ContestExchange);
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
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;

   if rxCty = 'JT' then
      begin
      if Station.MyCountry = 'JT' then
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestJTDX.GetDisplayName: string;
begin
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestJTDX.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestJTDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestJTDX.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestJTDX.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'MONGOLIAN DX';
end;

function TContestJTDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestJTDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestJTDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestJTDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestJTDX.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfCQZoneMode];
end;

function TContestJTDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* A PREFIX MULTIPLIER AT EVERY STATION -- M11 S3 part 2, 2026-10-14:
   the trait this class stated (`MongolianCallSignPrefix`) until the kind was deleted. *)
function TContestJTDX.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* THE PREFIX MULTIPLIER KEY -- M11 S3, 2026-10-14, moved from
   LOGEDIT.SetPrefix.
   A Mongolian station's callsign, and no key for anyone else -- SetPrefix's
   `MongolianCallSignPrefix` arm. *)
function TContestJTDX.PrefixMultiplierKey(const aQso: ContestExchange;
                                          out aKey: PrefixMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if aQso.QTH.CountryID = 'JT' then
      begin
      aKey := aQso.Callsign;
      Result := True;
      end;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCCWithNoJT`) until the kind was deleted. *)
function TContestJTDX.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but Mongolia -- the ARRLDXCCWithNoJT arm. *)
function TContestJTDX.DXMultiplierKey(const aQso: ContestExchange;
                                      out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if aQso.QTH.CountryID <> 'JT' then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station. *)
function TContestJTDX.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;

initialization
   RegisterContest(JTDX, TContestJTDX);

end.
