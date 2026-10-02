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

(* IARU HF WORLD CHAMPIONSHIP.

    same ITU zone as me     1
    same continent          3
    anywhere else           5
    a society station       1

  THE ZONE IS THE ITU ZONE, and this contest is the reason TR4W now knows the
  difference. MyZone is one global holding the CQ zone, and every arm that sends
  or scores "my zone" used it -- so an IARU entrant sent the wrong number on
  every QSO until PostUnit.ZoneSentForThisContest was written. The SCORING side
  compares MyZone with the received zone, and the same confusion is latent here:
  if MyZone holds a CQ zone, the "same zone" case matches the wrong stations.
  That is a live question for the bench, not something this move changes -- the
  comparison is reproduced exactly as it was.

  A SOCIETY STATION IS RECOGNISED BY HAVING A DomesticQTH, which is how the
  exchange parser records an HQ or official's abbreviation rather than a zone
  number. Those are worth one point wherever they are.

  THE ZONE CONVERSION IS THE STATION SNAPSHOT'S, not a Val() here. The legacy arm
  does `Val(MyZone, MyZoneValue, Result)` per QSO and ignores the error code, so
  an unset or non-numeric MyZone becomes zone 0 and silently matches any station
  whose zone failed to parse the same way. TStationContext converts once and
  says whether it worked, so "no zone set" can be told from "zone 0". *)
unit uContestIARU;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestIARU = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
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
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;

      (* A MEMBER SOCIETY'S EXCHANGE STILL CARRIES THE STATION'S ZONE -- M5b.

         NY4I, 2026JUL07: when the exchange is a society (ARRL, DARC) rather
         than a zone, RXData.Zone was never set, and the zone matters to the
         external processors that read it (UDP). So the zone comes from the
         call. It stood in LOGSTUFF.ProcessRSTAndDomesticQTHExchange as
         `if Contest = IARU`, inside the single-word QTH branch, reached only
         for RSTZoneOrSocietyExchange; it is IARU's rule, stated here under
         exactly those conditions: that shape, a word that is not all digits
         (the shape's own split between a zone and a society), one word once
         '/' is read as a blank (uExchangeTokens, the test that branch makes),
         and a zone not set yet. Applied after the parse whatever it
         answered, as it was. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   (* StringIsAllNumbersOrSpaces -- the shape's zone-or-society split. *)
   utils_text,
   (* IsSingleNonNumericToken -- the single-word test. *)
   uExchangeTokens;

function TContestIARU.ParseReceivedExchange(const aText: string;
                                           const aSession: TReceivedExchangeSession;
                                           var aExch: ContestExchange;
                                           out aErrorMessage: string): boolean;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);

   if (aSession.Exchange = RSTZoneOrSocietyExchange) and
      (not StringIsAllNumbersOrSpaces(aText))        and
      IsSingleNonNumericToken(aText)                 and
      (aExch.Zone = DUMMYZONE)                       then
      begin
      aExch.Zone := aSession.ZoneOfCall(string(aExch.Callsign));
      end;
end;

procedure TContestIARU.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.DomesticQTH <> '' then
      begin
      (* A society station -- one point wherever it is. *)
      aQso.QSOPoints := 1;
      Exit;
      end;

   if aQso.Zone = Station.MyZone then
      begin
      aQso.QSOPoints := 1;
      end
   else if aQso.QTH.Continent = Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 5;
      end;
end;

function TContestIARU.GetDisplayName: string;
begin
   Result := 'IARU HF World Championship';
end;

(* THE EXCHANGE IS RST AND EITHER A SOCIETY ABBREVIATION OR AN ITU ZONE.

   WHICH ONE FOLLOWS FROM WHO IS SENDING, on both sides independently: a society
   station sends its abbreviation, everybody else sends a zone. So our side asks
   whether aMy.MyState is set and his side asks whether the QSO carried a QTH
   string -- the same question asked of the two stations.

   THE ZONE IS THE ITU ZONE, AND aMy.MyZone IS WHERE THAT LIVES.
   PostUnit.ZoneSentForThisContest resolves CQ-versus-ITU per contest and puts
   the answer there; Station.MyZone is the raw global and is always the CQ zone.
   Reading the snapshot here would re-break the very contest that made the
   distinction necessary. See the header of this unit.

   %-7u FOR HIS ZONE AND %-7d FOR OURS, reproduced exactly. His is a
   word from the QSO record, ours is a converted integer, and the legacy arm
   spelled them differently. The output is identical for every legal zone; the
   spellings are kept so a future reader diffing against the legacy sees no
   difference at all.

   THE SHARED ARM STAYS: RSTZoneOrDomesticQTH sits on the same body and is
   TContestBase's default for the contests that run it. *)
function TContestIARU.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   if aMy.MyState <> '' then
      begin
      Result := Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyState]);
      end
   else
      begin
      Result := Format('%-3s %-7d', [aCtx.RSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
      end;
end;

function TContestIARU.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   (* aQso.QTHString, not aCtx.HisQTH: the legacy arm TESTS rx.QTHString, and
      formats csQTHString, which the exporter set from it. The test and the
      value are the same source. *)
   if aQso.QTHString <> '' then
      begin
      Result := Format('%-3s %-7s', [aCtx.RSTReceived, aCtx.HisQTH]);
      end
   else
      begin
      Result := Format('%-3s %-7u', [aCtx.RSTReceived, aQso.Zone]);
      end;
end;

function TContestIARU.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             aSessionExchange: ExchangeType): string;
begin
   if aMy.MyState <> '' then
      begin
      Result := Format('%-3d %-7s', [aQso.RSTSent, aMy.MyState]);
      end
   else
      begin
      Result := Format('%-3d %-7d', [aQso.RSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
      end;
end;

(* A HEADQUARTERS STATION'S SOCIETY GOES TO APP_TR4W_HQ -- M4, 2026-10-01,
   the IARU arm of postunit's EmitContestSpecificTailForExport, moved here.
   ADIF has no standard tag for an IARU society; this is TR4W's own, and
   import reads it back (with N1MM's APP_N1MM_HQ). PostUnit asks only for a
   non-empty QTH, and writes it, as the arm did. *)
function TContestIARU.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := EmitADIFField('APP_TR4W_HQ', string(aQso.QTHString));
end;

(* IARU SENDS RST PLUS EITHER A ZONE OR A SOCIETY, and only the society is a
   QTH. The zone already arrived through ITUZ, and QTHString is what the export
   tail turns into APP_TR4W_HQ -- so storing a zone here put both a <QTH> and
   an <APP_TR4W_HQ> of '59 8' into every re-exported record, neither of which
   D7 wrote.

   The alphabetic test tells a society from a number. *)
procedure TContestIARU.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                       const aSession: TADIFImportSession;
                                       var aExch: ContestExchange);
var
   srxExchange: string;
begin
   srxExchange := ExchangeFromSRXString(aTemps.SRX_String, aExch.RSTReceived);
   if ADIFTextIsAlphabetic(srxExchange) then
      begin
      aExch.QTHString := ShortString(srxExchange);
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestIARU.CQExchangeDefault(const aStation: TStationContext): string;
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

initialization
   RegisterContest(IARU, TContestIARU);

end.
