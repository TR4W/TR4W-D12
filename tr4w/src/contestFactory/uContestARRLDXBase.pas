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

(* ARRL INTERNATIONAL DX -- WHAT CW AND PHONE SHARE.

  THE FAMILY SHAPE IS TR4QT'S, and deliberately so. NY4I pointed at
  src/contests/ARRLDXBase.{h,cpp} with ARRLDXCWContest and ARRLDXPhoneContest
  beside it: a base holding the rules both modes share, and a thin subclass per
  mode carrying only identity and mode validation. That is the right
  decomposition and there is no reason to invent a different one.

  WHAT IS TAKEN FROM TR4QT IS THE STRUCTURE, NOT THE RULES. The standing note on
  that project is that it is useful ABOVE the engine and is "never" an authority
  on scoring, multipliers or exchange -- it is a reimplementation, not a
  specification, and not independent corroboration of anything.

  AND THE TWO PROGRAMS GENUINELY DIFFER HERE, WHICH IS WHY THAT MATTERS.
  TR4QT's ARRLDXBase says "W/VE stations may ONLY work DX stations", and it
  means it literally -- NY4I, 2026-09-02: "when TR4QT says we do not work them,
  we never been we will not allow it to be logged. But they would be zero
  points as TR4W does today." TR4QT REFUSES THE CONTACT; TR4W LOGS IT AT ZERO
  POINTS and sets InhibitMults.

  THIS CODE KEEPS TR4W'S BEHAVIOUR, and test-contest-factory.sh holds it to it
  byte for byte. Whether TR4W should instead refuse the entry is a DECISION,
  not a port detail: it changes what an operator can do at the keyboard, and it
  is the kind of thing that has to be right in a contest rather than discovered
  in one. TR4QT expresses the refusal through isValidQSO, which is on the list
  of virtuals TContestBase grows into -- so there is somewhere for it to go
  when the decision is made.

  The rules below are LOGSTUFF's ARRLDXQSOPointMethod arm, moved verbatim
  (the arm was deleted at M10 S3; see git history or the D7 tree).

  CHOSEN AS THE FIRST FAMILY BECAUSE IT IS PROVABLE, not because it is easy.
  arrl_dx_cw_2025_ny4i is a 66-QSO golden-corpus set with a D7-written
  reference.

  THE SCORING IS THE ARRLDXQSOPointMethod ARM, MOVED VERBATIM. Not tidied, not
  restructured: the point of the first move is to show the seam carries
  behaviour unchanged, and any difference in the exported Cabrillo would then be
  the SEAM rather than an improvement someone made on the way past.

  THE RULE: W/VE WORK DX, DX WORK W/VE. Three points either way; a W station
  working another W scores nothing AND inhibits multipliers, which is the part
  worth noticing -- the arm sets InhibitMults, so scoring and multipliers are
  not as separable here as the base class's comment would like. That coupling is
  inherited from the legacy code and is left exactly as it was; untangling it is
  a change of behaviour and belongs in its own commit, against its own
  measurement. *)
unit uContestARRLDXBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLDXBase = class(TContestBase)
   protected
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* THE FLAG SET IS THE FAMILY'S RULE -- both modes run under one set
         of rules, so it is stated once, here (M10 S5). See
         TContestBase.GetFlags. *)
      function GetFlags: TContestFlags; override;
   public

      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the station test
         DescribeSession stated the DX kind under (deleted at M11 S4 part 2);
         HasDXMultiplier, the key and the country list ask it, so the answers
         cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
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
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   end;

implementation

uses
   uDXMultiplierKey,
   SysUtils,
   uCanonicalExchange;

(* THE EXCHANGE IS RST AND EITHER A STATE OR A POWER.

   W/VE send their state or province; DX send their power. One arm serves both
   because which one you send follows from who you are, and the exporter has
   already resolved that: aMy.MyState holds whichever applies to us, and the
   received side is simply the QSO's Power field, which is where the parser puts
   a state as readily as a number.

   THE FOC MARATHON HALF OF THE LEGACY ARM IS NOT HERE. RSTPowerExchange is
   shared, and inside it sat `if Contest = FOCMARATHON` swapping in the FOC
   membership number. That is FOC Marathon's rule, not ARRL DX's, and since M4
   it is TContestFOCMarathon's own -- copying it here would have put one
   contest's rule in another contest's file. *)
function TContestARRLDXBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyState]);
end;

function TContestARRLDXBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
begin
   (* The QSO's OWN Power, not the his-QTH the exporter selected -- the legacy
      arm reads rx.Power here and ignores csQTHString. *)
   Result := Format('%-3s %-7s', [aCtx.RSTReceived, string(aQso.Power)]);
end;

function TContestARRLDXBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-3d %-7s', [aQso.RSTSent, aMy.MyState]);
end;

procedure TContestARRLDXBase.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   (* The legacy routine reads this into a local at the top and every arm uses
      it; keeping the name makes the moved code diff-able against its origin. *)
   rxCty := aQso.QTH.CountryID;

   if (Station.MyCountry = 'K') or (Station.MyCountry = 'VE') then
      begin
      if (rxCty <> 'K') and (rxCty <> 'VE') then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 0;
         aQso.InhibitMults := True;
         end;
      end
   else if (rxCty = 'K') or (rxCty = 'VE') then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 0;
      aQso.InhibitMults := True;
      end;
end;

function TContestARRLDXBase.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand];
end;

(* NOTHING IS REGISTERED HERE. A family base is not a contest an operator can
  select, and registering it for both modes -- which is what this unit did
  before the split -- makes "which class serves ARRL-DX-CW" answerable only by
  reading the base. Each mode registers itself, in its own unit. *)

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named ARRLDXCW, ARRLDXSSB, one contest in two
   modes, so the family base holds it once. *)
procedure TContestARRLDXBase.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   (* A W/VE STATION SENDS POWER AND COUNTS DXCC; EVERYONE ELSE SENDS A STATE
      OR PROVINCE OUT OF S48P14DC. *)
   if (aStation.MyCountry = 'K') or (aStation.MyCountry = 'VE') then
      begin
      aSession.Exchange := RSTPowerExchange;
      end
   else
      begin
      aSession.DomesticFile := 'S48P14DC';
      aSession.Exchange := RSTDomesticQTHExchange;
      end;

   aSession.ContestName := 'ARRL DX Test';
   aSession.AddDomesticCountries(DomesticCountriesKVE);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the RST and the state or the
   power. It named ARRLDXCW and ARRLDXSSB, the family, so it is the
   family's. See TContestBase.CanonicalReceivedExchange; the caller
   collapses the whitespace. *)
function TContestARRLDXBase.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   (* The US side sends RST and state, the DX side RST and power; the
      parser puts the state in QTHString and the power in Power, so the one
      the worked station sent is the one that is there. *)
   if Trim(string(aQso.QTHString)) <> '' then
      begin
      Result := RSTReceivedText(aQso) + ' ' + Trim(string(aQso.QTHString));
      end
   else
      begin
      Result := RSTReceivedText(aQso) + ' ' + Trim(string(aQso.Power));
      end;
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestARRLDXBase.CountsDXMultiplier: boolean;
begin
   Result := IsUSAOrCanadaCountry(Station.MyCountry);
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for a W or VE entrant; none for anyone else, whose
   multiplier is the state or province. Once, on the family base, as the key
   is. This is the station test the session's DX kind was chosen by (the
   trait, then DescribeSession) until that kind was deleted; DXMultiplierKey
   and the country list ask the same predicate, so the answers cannot
   disagree. *)
function TContestARRLDXBase.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA and Canada, for a W or VE entrant (ARRLDXCCWithNoUSAOrCanada, which DescribeSession
   states for K and VE); none for anyone else, whose multiplier is the state
   or province. Stated once, on the family base, as DescribeSession is. *)
function TContestARRLDXBase.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if CountsDXMultiplier and
      not IsUSAOrCanadaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestARRLDXBase.CountryMode: CountryModeType;
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


(* AN ENTRANT OUTSIDE THE USA AND CANADA LOOKS THE STATE OR PROVINCE UP IN
   S48P14DC -- M11 S6 part 1b, 2026-10-14. The station test
   DescribeSession states DomesticFile under: the negation of the one
   CountsDXMultiplier asks. See TContestBase.UsesDomesticFile. *)
function TContestARRLDXBase.UsesDomesticFile: boolean;
begin
   Result := not CountsDXMultiplier;
end;

end.
