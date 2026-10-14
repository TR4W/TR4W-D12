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

(* THE JAPAN INTERNATIONAL DX CONTEST, CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'jidx';  WA7BNM: 314;  QRZRUID: 57;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;
   XM: NoDXMults;  QP: JapanInternationalDXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'JIDX CW Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'JIDX-CW'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: JapanInternationalDXQSOPointMethod -- 4 on 160 m, 2 on 80 and
  10, 1 on 40, 20 and 15. A JA station working JA, or anyone else working
  a station that is neither JA nor JD: 0 and no multiplier.

  SET-UP, both branches stated. A JA station counts DXCC, CQ zones and a
  zone initial exchange, and sends RST and its zone; everyone else counts
  prefectures from `JIDX` and sends RST and a prefecture. Either way the
  closing set-up writes no zone-exchange messages for it (a test of this
  contest's name in FoundContest until M7b, now
  TSessionDefaults.SuppressZoneExchangeMessages). LogCfg's CQ exchange: 5NN
  and MY STATE, or 5NN and MY ZONE with no state.

  A SIBLING, NOT A FAMILY MEMBER (M7b, DECIDED on evidence). The two runnings share every rule
  today -- one contest in two modes, which is NRAU-Baltic's shape -- and
  that is exactly the case Q7 asks NY4I about.
  Extending NY4I's NRAU-Baltic ruling to every two-mode pair is his open
  Q7, so this class is a COPY of its sibling and owns it (design 1.4).
  Never merge the two, and never extract a base for them. *)
unit uContestJIDXCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestJIDXCW = class(TContestBase)
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
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   private
      (* IS THE ENTRANT IN JAPAN? -- DescribeSession's station test, asked of
         Station. It chose the DX kind and the zone kind, both deleted
         (M11 S4 and S5 part 2); HasDXMultiplier, the DX key, the country
         list, HasZoneMultiplier and both zone answers ask it, so the
         answers cannot disagree (M11 S4; renamed from CountsDXMultiplier at
         M11 S5, when the zone answers became its second use). *)
      function IsJapaneseEntrant: boolean;
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
      (* DOES IT HAVE A ZONE MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasZoneMultiplier (M11 S5 part 2). *)
      function HasZoneMultiplier: boolean; override;
      (* THE ZONE MULTIPLIER -- see TContestBase.ZoneMultiplierCount and
         ZoneMultiplierZones (M11 S5). *)
      function ZoneMultiplierCount: integer; override;
      function ZoneMultiplierZones: TZoneMultiplierZones; override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

procedure TContestJIDXCW.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   case aQso.Band of
      Band160:
         begin
         aQso.QSOPoints := 4;
         end;
      Band80:
         begin
         aQso.QSOPoints := 2;
         end;
      Band40:
         begin
         aQso.QSOPoints := 1;
         end;
      Band20:
         begin
         aQso.QSOPoints := 1;
         end;
      Band15:
         begin
         aQso.QSOPoints := 1;
         end;
      Band10:
         begin
         aQso.QSOPoints := 2;
         end;
      end;

   if Station.MyCountry = 'JA' then
      begin
      if rxCty = 'JA' then
         begin
         aQso.QSOPoints := 0;
         aQso.InhibitMults := True;
         end;
      end
   else if (rxCty <> 'JA') and
           (Copy(string(rxCty), 1, 2) <> 'JD') then
      begin
      aQso.QSOPoints := 0;
      aQso.InhibitMults := True;
      end;
end;

function TContestJIDXCW.GetDisplayName: string;
begin
   Result := 'JIDX CW Contest';
end;

function TContestJIDXCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'JIDX-CW';
end;

function TContestJIDXCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'JIDX-CW';
end;

function TContestJIDXCW.GetWA7BNMId: integer;
begin
   Result := 314;
end;

function TContestJIDXCW.GetQRZRUId: integer;
begin
   Result := 57;
end;

function TContestJIDXCW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestJIDXCW.GetDomesticFileName: string;
begin
   Result := 'jidx';
end;

function TContestJIDXCW.GetFriendlyName: string;
begin
   Result := 'JIDX CW Contest';
end;

function TContestJIDXCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestJIDXCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestJIDXCW.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestJIDXCW.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand, cfCQZoneMode];
end;

function TContestJIDXCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestJIDXCW.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   if aStation.MyCountry = 'JA' then
      begin
      aSession.InitialExchange := ZoneInitialExchange;
      aSession.Exchange := RSTZoneExchange;
      end
   else
      begin
      aSession.DomesticMult := DomesticFile;
      aSession.Exchange := RSTPrefectureExchange;
      aSession.DomesticFile := 'JIDX';
      end;

   (* WITH EITHER EXCHANGE, the closing set-up writes no zone-exchange
      messages for this contest: FoundContest named it there --
      `if not (Contest in [JIDXCW, JIDXSSB])` -- until M7b. *)
   aSession.SuppressZoneExchangeMessages := True;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestJIDXCW.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' 5NN ' + aStation.MyState;
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyZoneText;
      end;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for JIDXSSB.
   The same steps on ticking the box stood for JIDXSSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestJIDXCW.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_JAPAN);
   aPrompts.AskFieldWithCommentWhenInside(TC_PREFECTURE, ncfMyState);
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestJIDXCW.IsJapaneseEntrant: boolean;
begin
   Result := Station.MyCountry = 'JA';
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for a Japanese entrant; none for anyone else. This is the
   station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey and the
   country list ask the same predicate, so the answers cannot disagree. *)
function TContestJIDXCW.HasDXMultiplier: boolean;
begin
   Result := IsJapaneseEntrant;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country, for a Japanese entrant (ARRLDXCC, which DescribeSession stated for JA);
   none for anyone else, whose multiplier is the prefecture. *)
function TContestJIDXCW.DXMultiplierKey(const aQso: ContestExchange;
                                        out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if IsJapaneseEntrant then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only for a Japanese entrant; the CQ list for anyone else, who
   counts no DX multiplier. *)
function TContestJIDXCW.CountryMode: CountryModeType;
begin
   if IsJapaneseEntrant then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;

(* DOES IT HAVE A ZONE MULTIPLIER AT THIS STATION? -- M11 S5 part 2,
   2026-10-14. Yes for a Japanese entrant; none for anyone else. This is
   the station test the session's zone kind was chosen by (DescribeSession
   stated CQZones for JA over the trait's NoZoneMults) until that kind was
   deleted; the zone count and list ask the same predicate, so the
   answers cannot disagree. *)
function TContestJIDXCW.HasZoneMultiplier: boolean;
begin
   Result := IsJapaneseEntrant;
end;

(* THE ZONE MULTIPLIER -- M11 S5, 2026-10-14: the CQ zones, for a Japanese
   entrant only; none for anyone else, whose multiplier is the prefecture.
   DescribeSession stated CQZones for a JA station over the trait's
   NoZoneMults, and LOGDUPE's zone count and the zone-list readers took it
   from the session kind until S5; these ask the same station test. *)
function TContestJIDXCW.ZoneMultiplierCount: integer;
begin
   if IsJapaneseEntrant then
      begin
      Result := CQ_ZONE_MULTIPLIERS;
      end
   else
      begin
      Result := 0;
      end;
end;

function TContestJIDXCW.ZoneMultiplierZones: TZoneMultiplierZones;
begin
   if IsJapaneseEntrant then
      begin
      Result := zmzCQZones;
      end
   else
      begin
      Result := zmzNotCQOrITU;
      end;
end;

initialization
   RegisterContest(JIDXCW, TContestJIDXCW);

end.
