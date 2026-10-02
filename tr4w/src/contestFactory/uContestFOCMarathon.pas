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

(* THE FOC MARATHON -- the First Class CW Operators' Club's annual event.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTPowerExchange;
   XM: CQDXCC;  QP: FOCMarathonQSOPointMethod;  ADIFName: '';
   CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName are the enum's spelling,
  'FOC MARATHON'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = FOCMARATHON` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5) and set-up (M7) are not moved.

  SCORING IS FOCMarathonQSOPointMethod, transcribed exactly:

      if RXData.Callsign = 'G4FOC' then RXData.QSOPoints := 2
      else RXData.QSOPoints := 1;

  THE EXCHANGE IS RST AND THE FOC MEMBERSHIP NUMBER -- and the number rides
  in the QSO's Power field, because the exchange this contest runs
  (RSTPowerExchange) is ARRL DX's shape. Three places knew that by name:
  uCabrilloExchange and uADIFExchange swapped MY FOC NUMBER in for MY STATE
  on the sent side, and uADIF wrote the received number as FOC_NUM instead
  of RX_PWR. All three are this class's now (the Cabrillo received column
  is the shared arm's answer, and is stated here so the exchange is read in
  one file). *)
unit uContestFOCMarathon;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestFOCMarathon = class(TContestBase)
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
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      function GetADIFPowerTag: string; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   end;

implementation

uses
   SysUtils, uContestRegistry;

procedure TContestFOCMarathon.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Callsign = 'G4FOC' then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

(* RST AND OUR MEMBERSHIP NUMBER, in the RSTPowerExchange widths. *)
function TContestFOCMarathon.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyFOCNumber]);
end;

(* RST AND HIS MEMBERSHIP NUMBER, which the parser put in Power. *)
function TContestFOCMarathon.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                            const aQso: ContestExchange;
                                                            const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [aCtx.RSTReceived, string(aQso.Power)]);
end;

function TContestFOCMarathon.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-3d %-7s', [aQso.RSTSent, aMy.MyFOCNumber]);
end;

(* Power holds his membership number, and ADIF's tag for that is FOC_NUM. *)
function TContestFOCMarathon.GetADIFPowerTag: string;
begin
   Result := 'FOC_NUM';
end;

function TContestFOCMarathon.GetDisplayName: string;
begin
   Result := 'FOC MARATHON';
end;

function TContestFOCMarathon.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'FOC MARATHON';
end;

function TContestFOCMarathon.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'FOC MARATHON';
end;

function TContestFOCMarathon.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestFOCMarathon.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestFOCMarathon.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestFOCMarathon.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestFOCMarathon.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; it resolves to the enum's
      spelling. *)
   Result := 'FOC MARATHON';
end;

function TContestFOCMarathon.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestFOCMarathon.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestFOCMarathon.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestFOCMarathon.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestFOCMarathon.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestFOCMarathon.GetExchangeKind: ExchangeType;
begin
   Result := RSTPowerExchange;
end;

function TContestFOCMarathon.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := FOCMarathonQSOPointMethod;
end;

function TContestFOCMarathon.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE MEMBERSHIP NUMBER, FROM FOC_NUM -- or from N1MM's APP_N1MM_EXCHANGE1
   when the record has no FOC_NUM (M5a).

   Export writes the number as FOC_NUM (ADIFPowerTag). The old import read N1MM's
   tag into Power as the tag went by and then OVERWROTE it with FOC_NUM, empty
   or not, so a record that carried only N1MM's tag came in with no number in
   either tag order. The tag now counts, and a record with neither still comes
   in with an empty number, as before. *)
procedure TContestFOCMarathon.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                              const aSession: TADIFImportSession;
                                              var aExch: ContestExchange);
begin
   if (aTemps.FOC_Num = '') and (aTemps.N1MM_Exchange1 <> '') then
      begin
      aExch.Power := ShortString(aTemps.N1MM_Exchange1);
      end
   else
      begin
      aExch.Power := ShortString(aTemps.FOC_Num);
      end;
end;

initialization
   RegisterContest(FOCMARATHON, TContestFOCMarathon);

end.
