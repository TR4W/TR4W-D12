{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit ZoneCont;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  Generics.Collections,   // TList<AnsiString> -- the domestic country list
  TF,
  VC,
  { Windows stood here with nothing behind it -- not one reference in code
    (2026-09-08). }
  Tree,
  uCTYDAT,
  utils_text,
  uCallSignRoutines;

  //Country9;

//const
//  UpdateListDate                        = '3 Apr 93';

type
  (* THE SESSION'S DOMESTIC COUNTRY LIST -- the CTY country IDs that count as
    "domestic" (not DX) for the contest. 2026-10-16, pointer audit P5.

    IT WAS A HAND-BUILT LINKED LIST (a ^record with a NextRecord field, New
    per entry, Dispose per entry on clear, and a walk to the tail on every
    add). It owns a list now; the rules it kept, read from that code:

      * ORDER: entries are kept in the order they were added -- the old add
        walked to the tail. The contest matrix prints them in that order.
      * DUPLICATES ARE KEPT: adding an ID that is already there appends it
        again (UKEI adds GM twice). Only the order of the print shows it.
      * CASE: an added ID is upper-cased in place, ASCII a..z only
        (TF.strU), and the comparison is EXACT and case-sensitive -- a CTY ID
        carrying a lowercase letter is never matched by an added one.
      * WIDTH: an ID arrives as a CallString (13) and is stored as its first
        SIX characters, as CountryID: string[6] stored it. A CTY ID is at
        most five (DXMultiplierString), so a stored ID longer than five can
        never match; it is kept anyway, and printed.
      * AN EMPTY ID IS STORED, and it matches a call whose CTY ID is empty
        (an unknown country). 'ADD DOMESTIC COUNTRY =' with no value adds one.
      * AN EMPTY LIST is a missing input, not an answer: DomesticCountryCall
        logs it ONCE (ClaimEmptyReport) and answers False -- "DX". UNLESS THE
        CONTEST'S SET-UP SAID NONE (2026-10-23): a DX contest -- CQ WW, which
        neither D7 nor its class ever gave a domestic country -- runs on an
        empty list by design, and FoundContest records that through
        RecordContestSetUp. Reporting it was a false error on every DX
        contest (NY4I's CQ WW SSB log, File > Clear log).
      * RESET: only Clear empties it, and Clear also re-arms the once-only
        empty report and forgets what the last set-up stated -- so a .cfg
        that never reaches its CONTEST line (the case the report was built
        for) is reported, not excused by the previous contest. FoundContest does NOT clear -- it appends -- so a
        CONTEST applied twice without a .cfg read between accumulates, as it
        always did. Clear is reached from LogCfg (just before a text .cfg is
        parsed) and 'ADD DOMESTIC COUNTRY = CLEAR'.

    THE ENTRIES ARE AnsiString, NOT string, ON PURPOSE: the IDs are bytes out
    of a ShortString (CallString, the CTY table), and an AnsiString holds and
    compares those bytes exactly, as the record's string[6] did. A
    UnicodeString round trip would put a code-page conversion in the compare. *)
  TDomesticCountryList = class
  private
    FIDs: TList<AnsiString>;
    FEmptyReported: boolean;
    (* True once a contest's set-up ran and stated NO domestic country; False
      after Create and Clear, and after a set-up that stated some. *)
    FContestStatesNone: boolean;
    function GetID(aIndex: integer): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add(ID: CallString);
    procedure Clear;
    function Count: integer;
    (* True when aCountryID equals an entry exactly. *)
    function HoldsCountry(const aCountryID: ShortString): boolean;
    (* WHAT THE CONTEST'S SET-UP STATED -- FoundContest, after it has added
      the contest's countries (FCONTEST.ContestSetUpStatesDomesticCountries).
      The latest set-up's answer stands; Clear forgets it. *)
    procedure RecordContestSetUp(aStatesCountries: boolean);
    (* True ONCE after Create or Clear, then False: the caller reports an
      empty list when this answers True. ALWAYS False while the last set-up
      stated no domestic country -- an empty list is then the contest's
      answer, not a missing input -- and the once-only latch is left armed. *)
    function ClaimEmptyReport: boolean;
    property IDs[aIndex: integer]: string read GetID;
  end;

var
  (* Created in this unit's initialization, freed in its finalization. *)
  DomesticCountries                     : TDomesticCountryList;
//  LastLocateCall                        : CallString;
  LastLocateQTH                         : QTHRecord;

procedure AddDomesticCountry(ID: CallString);
procedure ClearDomesticCountryList;
function DomesticCountryCall(Call: CallString): boolean;

function ClubCall(Call: CallString): boolean;

function GetVEInitialExchange(Call: CallString): string;

//procedure LocateCall(Call: VC.CallString; var QTH: VC.QTHRecord; UseStandardCallFormat: boolean);

function GetContinentName(Cont: ContinentType): string;
(* GetContinentFromString MOVED to utils_text -- M11 S6, 2026-10-14: the
  RSGB IOTA class parses a continent too, and a contest class cannot reach
  this unit. Every caller already uses utils_text. *)

implementation
uses
     (* PostUnit and uContestRegistry stood first here from M5b until Q50 was
       ruled (2026-10-15): they served only the contest's initial-exchange
       question below, which is gone. *)
     LogWind,
     MainUnit;   // the logger global

function GetVEInitialExchange(Call: CallString): string;

var
  CountryID                             : Str20;
  QTH                                   : QTHRecord;
begin
  GetVEInitialExchange := '';

  Call := StandardCallFormat(Call, True);
  ctyLocateCall(Call, QTH);
  CountryID := QTH.CountryID;

  (* NO RUSSIAN OBLAST HERE ANY MORE -- Q50, ruled 2026-10-15. D7 tested
    CountryID 'UA' here under RussianDXQSOPointMethod, and M5b moved that to
    the contest's InitialExchangeFromCall; neither ever ran for a shipped
    contest, because the Russian DX and RU3AX rows state NoInitialExchange and
    so never reach this routine. LOGEDIT.InitialExchangeEntry's fallback, the
    rule that did run, now asks the contest's InitialExchangeFromCall once,
    after every initial-exchange arm. *)

  if CountryID <> 'VE' then Exit;
  Call := Copy(Call, 1, 3);

  if StringHas(Call, '3') then
     begin
     GetVEInitialExchange := 'Ont ';
     end;
  if StringHas(Call, '4') then
     begin
     GetVEInitialExchange := 'Man';
     end;
  if StringHas(Call, '5') then
     begin
     GetVEInitialExchange := 'Sask';
     end;
  if StringHas(Call, '6') then
     begin
     GetVEInitialExchange := 'Ab';
     end;
  if StringHas(Call, '7') then
     begin
     GetVEInitialExchange := 'Bc';
     end;
  if StringHas(Call, '8') then
     begin
     GetVEInitialExchange := 'NWT';
     end;

  if Call = 'VE2' then
     begin
     GetVEInitialExchange := 'Que';
     end;
  if Call = 'VY2' then
     begin
     GetVEInitialExchange := 'vy2';
     end;
  if Call = 'VY1' then
     begin
     GetVEInitialExchange := 'Yuk';
     end;
  if Call = 'VO1' then
     begin
     GetVEInitialExchange := 'vo1';
     end;
  if Call = 'VO2' then
     begin
     GetVEInitialExchange := 'vo2';
     end;
  if Call = 'VE1' then
     begin
     GetVEInitialExchange := 've1';
     end;
end;

constructor TDomesticCountryList.Create;
begin
  inherited Create;
  FIDs := TList<AnsiString>.Create;
  FEmptyReported := False;
  FContestStatesNone := False;
end;

destructor TDomesticCountryList.Destroy;
begin
  FIDs.Free;
  inherited Destroy;
end;

procedure TDomesticCountryList.Add(ID: CallString);
var
  StoredID                              : string[6];
begin
  strU(ID);
  (* Truncated to six, as DomesticCountryRecord.CountryID was. *)
  StoredID := ID;
  FIDs.Add(AnsiString(StoredID));
end;

procedure TDomesticCountryList.Clear;
begin
  FIDs.Clear;
  FEmptyReported := False;
  FContestStatesNone := False;
end;

procedure TDomesticCountryList.RecordContestSetUp(aStatesCountries: boolean);
begin
  FContestStatesNone := not aStatesCountries;
end;

function TDomesticCountryList.Count: integer;
begin
  Result := FIDs.Count;
end;

function TDomesticCountryList.GetID(aIndex: integer): string;
begin
  Result := string(FIDs[aIndex]);
end;

function TDomesticCountryList.HoldsCountry(const aCountryID: ShortString): boolean;
var
  wanted                                : AnsiString;
  i                                     : integer;
begin
  wanted := AnsiString(aCountryID);
  for i := 0 to FIDs.Count - 1 do
     begin
     if FIDs[i] = wanted then
        begin
        Result := True;
        Exit;
        end;
     end;
  Result := False;
end;

function TDomesticCountryList.ClaimEmptyReport: boolean;
begin
  if FContestStatesNone then
     begin
     Result := False;
     Exit;
     end;
  Result := not FEmptyReported;
  FEmptyReported := True;
end;

procedure AddDomesticCountry(ID: CallString);
begin
  DomesticCountries.Add(ID);
end;

function DomesticCountryCall(Call: CallString): boolean;

(* Returns TRUE if the callsign is in one of the countries identified as
  domestic countries. *)

var
  ID                                    : CallString;
  QTH                                   : QTHRecord;
begin
  (* AN EMPTY LIST IS NOT AN ANSWER, IT IS A MISSING INPUT -- SAY SO.

    This returned False silently, and False here means "this callsign is DX".
    So when the domestic-country list fails to load, EVERY station in the
    contest becomes DX: a US callsign in ARRL Field Day is asked for a DX
    exchange, scores as DX, and takes no section multiplier.

    That is what NY4I saw on Linux (2026-09-09), and the cause was FIVE steps
    away: SetUpFileNames split the chosen contest path by scanning back for a
    backslash, found none on Unix, and truncated the path to nonsense -- so the
    log database opened as the wrong file, so the contest was never loaded, so
    CONTEST never reached FoundContest, so the domestic countries were never
    added. NOTHING connected the two ends. The program had the information and
    did not report it, which is the silent fallback this codebase treats as a
    defect in its own right.

    THE FIRST VERSION OF THIS MESSAGE BLAMED THE .dom FILE, and that was wrong.
    The .dom supplies the SECTION list; the domestic COUNTRY list is built in
    code by fcontest's AddARRLSectionDomesticCountries. A diagnostic that names
    the wrong file sends the next person to check something that is fine, which
    is worse than saying less -- so it now says what it actually knows.

    ONCE PER SESSION, not once per callsign: this is called for every entry
    and a per-call message would be a flood rather than a diagnosis. The
    condition cannot come and go within a contest -- the list is loaded when
    the contest is set up -- so one line carries the whole story.

    NOT FOR A CONTEST THAT HAS NONE (2026-10-23). CQ WW states no domestic
    country, so this fired on every DX contest the first time anything asked
    -- GetDXQTH, through a spot's need-multiplier hint after File > Clear log
    -- and said "the contest was not set up" of a contest that was.
    ClaimEmptyReport now answers False when the set-up stated none. *)
  if DomesticCountries.Count = 0 then
     begin
     if DomesticCountries.ClaimEmptyReport then
        begin
        logger.Error('[Domestic] The domestic country list is EMPTY, so every '
                     + 'callsign will be treated as DX. The contest was not '
                     + 'set up -- check that a CONTEST value was applied and '
                     + 'that the contest file above is the one you chose.');
        end;
     DomesticCountryCall := False;
     Exit;
     end;

  ctyLocateCall(Call, QTH);
  ID := QTH.CountryID;

  DomesticCountryCall := DomesticCountries.HoldsCountry(ID);
end;

procedure ClearDomesticCountryList;
begin
  DomesticCountries.Clear;
end;

function ClubCall(Call: CallString): boolean;

begin
end;

function GetNumber(Call: CallString): AnsiChar;

{ This function will look at the callsign passed to it and return the
  single number that is in it.  If the call is portable, the number from
  the portable designator will be given if there is one.  If the call
  or prefix has two numbers in it, the last one will be given.         }

var
  CharPtr                               : integer;

begin
  if StringHas(Call, '/') then
     begin
     Call := PrecedingString(Call, '/');
     end;

  for CharPtr := length(Call) downto 1 do
    if (Call[CharPtr] <= '9') and (Call[CharPtr] >= '0') then
       begin
       GetNumber := Call[CharPtr];
       Exit;
       end;
  GetNumber := #0;
end;

function GetContinentName(Cont: ContinentType): string;
begin
  case Cont of
    NorthAmerica: GetContinentName := 'NA';
    SouthAmerica: GetContinentName := 'SA';
    Europe: GetContinentName := 'EU';
    Africa: GetContinentName := 'AF';
    Asia: GetContinentName := 'AS';
    Oceania: GetContinentName := 'OC';
  else GetContinentName := '';
  end;
end;

//begin
  //  LastLocateCall := '';

initialization
  (* BEFORE ANY READER: every add is at run time (FoundContest, the config
    reader), long after every unit's initialization. *)
  DomesticCountries := TDomesticCountryList.Create;

finalization
  DomesticCountries.Free;
  DomesticCountries := nil;

end.

