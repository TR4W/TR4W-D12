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
   Result := 'General QSO';
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

initialization
   RegisterContest(GENERALQSO, TContestGeneralQSO);

end.
