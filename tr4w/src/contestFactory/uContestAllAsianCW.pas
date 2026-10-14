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

(* THE ALL ASIAN DX CONTEST, CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 47;  QRZRUID: 146;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAgeExchange;
   XM: NoDXMults;  QP: AllAsianQSOPointMethod;
   ADIFName: 'ALL-ASIAN-DX-CW';  CABName: '';
   FriendlyName: 'All Asian DX Contest, CW'

  A blank CABName resolves to the enum's spelling, 'ALL-ASIAN-DX-CW'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: AllAsianQSOPointMethod. An Asian station: another continent 9
  on 160, 6 on 80 and 10, else 3; another Asian country 3 / 2 / 2, else 1;
  its own country 0 and no multiplier. Anyone else: an Asian station 3 / 2
  / 2, else 1; a non-Asian one 0 and no multiplier.

  SET-UP: an Asian station counts DXCC, everyone else prefixes -- each
  branch states only its own value. LogCfg's CQ exchange: 5NN and MY STATE.

  A SIBLING, NOT A FAMILY MEMBER (M7b, DECIDED on evidence). The two runnings share a row
  shape and an arm today, but the phone running owns a former ADIF id
  this one does not.
  Extending NY4I's NRAU-Baltic ruling to every two-mode pair is his open
  Q7, so this class is a COPY of its sibling and owns it (design 1.4).
  Never merge the two, and never extract a base for them. *)
unit uContestAllAsianCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestAllAsianCW = class(TContestBase)
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
      function GetDXMultiplierType: DXMultType; override;
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
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   public
      (* DOES IT HAVE A PREFIX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasPrefixMultiplier (M11 S3 part 2). *)
      function HasPrefixMultiplier: boolean; override;
      (* THE PREFIX MULTIPLIER -- see TContestBase.PrefixMultiplierKey
         (M11 S3). *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the station test
         DescribeSession states the session's DX kind under; the key and the
         country list ask it, so the two cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   public
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings,
   SysUtils,
   uCanonicalExchange;

procedure TContestAllAsianCW.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if Station.MyContinent = Asia then
      begin
      if aQso.QTH.Continent <> Asia then
         begin
         case aQso.Band of
            Band160:
               begin
               aQso.QSOPoints := 9;
               end;
            Band80:
               begin
               aQso.QSOPoints := 6;
               end;
            Band10:
               begin
               aQso.QSOPoints := 6;
               end;
            else
               begin
               aQso.QSOPoints := 3;
               end;
            end;
         end
      else if Station.MyCountry <> rxCty then
         begin
         case aQso.Band of
            Band160:
               begin
               aQso.QSOPoints := 3;
               end;
            Band80:
               begin
               aQso.QSOPoints := 2;
               end;
            Band10:
               begin
               aQso.QSOPoints := 2;
               end;
            else
               begin
               aQso.QSOPoints := 1;
               end;
            end;
         end
      else
         begin
         (* Same country. *)
         aQso.QSOPoints := 0;
         aQso.InhibitMults := True;
         end;
      end
   else if aQso.QTH.Continent = Asia then
      begin
      (* We are not in Asia; they are. *)
      case aQso.Band of
         Band160:
            begin
            aQso.QSOPoints := 3;
            end;
         Band80:
            begin
            aQso.QSOPoints := 2;
            end;
         Band10:
            begin
            aQso.QSOPoints := 2;
            end;
         else
            begin
            aQso.QSOPoints := 1;
            end;
         end;
      end
   else
      begin
      aQso.QSOPoints := 0;
      aQso.InhibitMults := True;
      end;
end;

function TContestAllAsianCW.GetDisplayName: string;
begin
   Result := 'All Asian DX Contest, CW';
end;

function TContestAllAsianCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ALL-ASIAN-DX-CW';
end;

function TContestAllAsianCW.GetADIFContestId: string;
begin
   Result := 'ALL-ASIAN-DX-CW';
end;

function TContestAllAsianCW.GetWA7BNMId: integer;
begin
   Result := 47;
end;

function TContestAllAsianCW.GetQRZRUId: integer;
begin
   Result := 146;
end;

function TContestAllAsianCW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestAllAsianCW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestAllAsianCW.GetFriendlyName: string;
begin
   Result := 'All Asian DX Contest, CW';
end;

function TContestAllAsianCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestAllAsianCW.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestAllAsianCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestAllAsianCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestAllAsianCW.GetExchangeKind: ExchangeType;
begin
   Result := RSTAgeExchange;
end;

function TContestAllAsianCW.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand];
end;

function TContestAllAsianCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestAllAsianCW.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   if aStation.MyContinent = Asia then
      begin
      aSession.DXMult := ARRLDXCC;
      end;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestAllAsianCW.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ALLASIANSSB, YOTA,
   YOUTHCHAMPIONSHIPRF.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestAllAsianCW.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the RST and the age. The arm
   named ALLASIANCW and ALLASIANSSB; each holds its own copy (design 1.4).
   See TContestBase.CanonicalReceivedExchange; the caller collapses the
   whitespace. *)
function TContestAllAsianCW.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := RSTReceivedText(aQso) + ' ' + IntToStr(aQso.Age);
end;

(* DOES IT HAVE A PREFIX MULTIPLIER AT THIS STATION? -- M11 S3 part 2,
   2026-10-14. Yes for an entrant outside Asia; none for an Asian one. This
   is the station test DescribeSession chose the session's prefix kind by,
   until that kind was deleted; PrefixMultiplierKey asks it, so the two
   cannot disagree. *)
function TContestAllAsianCW.HasPrefixMultiplier: boolean;
begin
   Result := Station.MyContinent <> Asia;
end;

(* THE PREFIX MULTIPLIER KEY -- M11 S3, 2026-10-14, moved from
   LOGEDIT.SetPrefix.
   The CTY prefix for an entrant outside Asia (`Prefix`, which
   DescribeSession chose there); none for an Asian entrant, whose session ran
   the trait's NoPrefixMults. *)
function TContestAllAsianCW.PrefixMultiplierKey(const aQso: ContestExchange;
                                                out aKey: PrefixMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if not HasPrefixMultiplier then
      begin
      Exit;
      end;
   aKey := aQso.QTH.Prefix;
   Result := True;
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestAllAsianCW.CountsDXMultiplier: boolean;
begin
   Result := Station.MyContinent = Asia;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country, for an Asian entrant (ARRLDXCC, which DescribeSession states for Asia);
   none for anyone else, whose multiplier is the Asian prefix. *)
function TContestAllAsianCW.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if CountsDXMultiplier then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only for an Asian entrant; the CQ list for anyone else, who counts
   no DX multiplier. *)
function TContestAllAsianCW.CountryMode: CountryModeType;
begin
   if CountsDXMultiplier then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;

initialization
   RegisterContest(ALLASIANCW, TContestAllAsianCW);

end.
