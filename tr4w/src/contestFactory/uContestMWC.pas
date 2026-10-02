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

(* THE MEMORIAL OK1WC (MWC).

  The ContestsArray row this class states, verbatim:

   Email: 'memorial-ok1wc.cz/index.php?page=logs';  DF: 'mwc';  WA7BNM: 0;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTQSONumberExchange;
   XM: NoDXMults;  QP: MWCQP;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'MWC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: MWCQP -- 1, and the domestic multiplier is the call's last
  character, or the character before a '/' followed by a letter.

  SET-UP: 80 m, MWC as a domestic country.

  THE CALL IS CUT TO TEN CHARACTERS AND WALKED TO ITS FULL LENGTH, as the
  arm did (a string[10] copy, indexed to Length(Callsign)): a call longer
  than ten reads past the copy, and one ending in '/' reads one byte past
  its end. Transcribed, not judged -- no real call reaches either. *)
unit uContestMWC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestMWC = class(TContestBase)
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
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry;

(* MWCQP -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestMWC.CalculateQSOPoints(var aQso: ContestExchange);
var
   callLength: integer;
   i: integer;
   k: string[10];
begin
   aQso.QSOPoints := 1;
   callLength := Length(aQso.Callsign);
   k := aQso.Callsign;
   for i := 1 to callLength do
      begin
      (* The rules specify the multiplier number following a slash. *)
      if (k[i] = '/') and (k[i + 1] in ['A'..'Z']) then
         begin
         aQso.DomMultQTH := k[i - 1];
         Exit;
         end;
      end;
   aQso.DomMultQTH := k[callLength];
end;

function TContestMWC.GetDisplayName: string;
begin
   Result := 'MWC';
end;

function TContestMWC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'MWC';
end;

function TContestMWC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'MWC';
end;

function TContestMWC.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestMWC.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMWC.GetSubmissionEmail: string;
begin
   Result := 'memorial-ok1wc.cz/index.php?page=logs';
end;

function TContestMWC.GetDomesticFileName: string;
begin
   Result := 'mwc';
end;

function TContestMWC.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'MWC';
end;

function TContestMWC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestMWC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMWC.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMWC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestMWC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMWC.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestMWC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := MWCQP;
end;

function TContestMWC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestMWC.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
   aSession.AddDomesticCountry('MWC');
end;

initialization
   RegisterContest(MWC, TContestMWC);

end.
