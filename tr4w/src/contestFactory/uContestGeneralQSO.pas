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

(* General QSO.

  OnePointPerQSO -- the plainest rule there is, and the default for 31 contests. GENERAL QSO is TR4W's everyday non-contest logging mode, so this is the one that runs when nothing else does.

  ON TContestBase SINCE M3 (2026-10-01): TContestFixedPoints, the mechanism
  base it descended from, retired (CONTEST_OWNERSHIP_DESIGN.md 1.5). The one
  point is stated here, through the FixedModePoints helper. *)
unit uContestGeneralQSO;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestGeneralQSO = class(TContestBase)
   protected
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      function GetWritesADIFContestId: boolean; override;
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
      (* WHAT THE UI ASKS -- M9b. General QSO is a log, not a contest: call
         entry shows no contest status, the summary never warns of too many
         dates, and band stepping reaches the WARC bands. Each was an
         `if Contest <> GENERALQSO` in the code that showed it. *)
      function GetShowsContestStatus: boolean; override;
      function GetMaximumContestDates: integer; override;
      function GetBandStepIncludesWARC: boolean; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE CABRILLO CONTEST: NAME -- M9a. *)
      function CabrilloContestName(const aContestTitle: string;
                                   const aSessionName: string): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints;

procedure TContestGeneralQSO.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestGeneralQSO.GetDisplayName: string;
begin
   Result := 'General QSO/DX Logging';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestGeneralQSO.GetCabrilloName: string;
begin
   Result := 'GENERAL QSO';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestGeneralQSO.GetADIFContestId: string;
begin
   Result := 'GENERAL QSO';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestGeneralQSO.GetFriendlyName: string;
begin
   Result := 'General QSO/DX Logging';
end;

(* THE EXCHANGE IS RST, A NAME AND A QTH -- the plain ragchew-style log.

   SYMMETRIC, which is rare enough here to be worth saying: both sides use the
   same three widths, because General QSO has no rule about who sends what. It
   is the fallback contest, so there is nothing contest-specific to encode.

   THE SHARED ARM STAYS: RSTNameAndQTHExchange is TContestBase's default for
   every other contest that runs it.

   NO CONTEST_ID IN ADIF (WritesADIFContestId False): General QSO is an
   operating mode, not a contest, and uADIF.EmitADIFRecord has never written
   one for it. It tested `ceContest in [POTA, GENERALQSO]` until M4. *)
function TContestGeneralQSO.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-5s %-7s', [aCtx.RSTSent, aMy.MyName, aMy.MyState]);
end;

function TContestGeneralQSO.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-5s %-7s', [aCtx.RSTReceived, string(aQso.Name), aCtx.HisQTH]);
end;

function TContestGeneralQSO.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-3d %-5s %-7s', [aQso.RSTSent, aMy.MyName, aMy.MyState]);
end;

function TContestGeneralQSO.GetWritesADIFContestId: boolean;
begin
   (* An operating mode, not a contest -- see the note above
      FormatCabrilloSentExchange. *)
   Result := False;
end;

(* THE GRID IS THE EXCHANGE, for any ADIF source -- not just WSJT-X, which does
   not always include PROGRAMID. Gating on that flag left ExchString empty
   when PROGRAMID was absent. A record with no grid keeps what the generic
   import gave it: this contest has no other rule. *)
procedure TContestGeneralQSO.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                             const aSession: TADIFImportSession;
                                             var aExch: ContestExchange);
begin
   if aTemps.GridSquare <> '' then
      begin
      aExch.ExchString  := ShortString(aTemps.GridSquare);
      aExch.QTHString   := ShortString(aTemps.GridSquare);
      aExch.DomesticQTH := ShortString(aTemps.GridSquare);
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestGeneralQSO.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.AutoDupeEnableCQ := False;
   aSession.AutoDupeEnableSAndP := False;
   aSession.ContestName := 'General QSOs';
   aSession.WARCEnabled := True;
end;

(* THE CABRILLO CONTEST: LINE NAMES WHAT THE OPERATOR CALLED THIS LOG --
   PostUnit's GENERALQSO test (4.78.3, "ALLOW CUSTOM CONFIG Contest Title or
   Contest Name"), moved here at M9a (2026-10-02). General QSO is a log, not
   a contest, so the title the operator gave it, else the session's contest
   name, else the Cabrillo name. *)
function TContestGeneralQSO.CabrilloContestName(const aContestTitle: string;
                                                const aSessionName: string): string;
begin
   if Length(aContestTitle) <> 0 then
      begin
      Result := aContestTitle;
      end
   else if Length(aSessionName) <> 0 then
      begin
      Result := aSessionName;
      end
   else
      begin
      Result := inherited CabrilloContestName(aContestTitle, aSessionName);
      end;
end;

(* MainUnit (station information and possible calls), LOGEDIT (the
   domestic-multiplier status), LOGSUBS2 x2 and LOGWIND (multiplier and QSO
   status) each skipped these for General QSO -- M9b. *)
function TContestGeneralQSO.GetShowsContestStatus: boolean;
begin
   Result := False;
end;

(* PostUnit.CheckForNewContestDate tested `( NumberDates > 10 ) and
   ( Contest <> GENERALQSO )` (4.72.1): a log never warns -- M9b. *)
function TContestGeneralQSO.GetMaximumContestDates: integer;
begin
   Result := 0;
end;

(* LOGSTUFF's band stepping skipped a WARC band when `CONTEST <> GeneralQSO`
   (n4af 4.37.11), so General QSO alone steps onto WARC -- M9b. *)
function TContestGeneralQSO.GetBandStepIncludesWARC: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(GENERALQSO, TContestGeneralQSO);

end.
