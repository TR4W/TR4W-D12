{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 }
unit uCallsigns;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
//  SysUtils,
  VC,
  TF,
  (* WINDOWS IS GONE FROM THIS UNIT (2026-09-08). It was here for ONE call --
    CompareStringA(LOCALE_SYSTEM_DEFAULT, NORM_IGNORECASE, ...) -- and the
    note that stood here said, correctly, that repointing it as a side effect
    of a portability sweep would be exactly the wrong way round: it is one of
    three drifted copies, and NY4I's standing instruction is that the TESTS
    come before the repoint.

    THE TESTS NOW EXIST. test/unit/uTestStringCompare.pas pins order,
    antisymmetry and transitivity over the callsign alphabet in 416
    assertions, and it was written and passing BEFORE this line changed. See
    CompareStrings for why the swap is safe -- in particular that the sorted
    order is never persisted, so nothing on disk can be left ordered by the
    old comparator. *)
  uStringCompare,
  Tree,
  LogRadio,
  LogSCP,
  uTR4WStrings,
  utils_text,
  Generics.Collections;   (* TObjectList -- the entries, owned; the qualified sheet's dictionaries *)

const
  MAXCALLSIGNSINLIST                    = 100000;           // 4.115.6

type
  (* ONE STATION IN THE LOG: its call as logged, its dupe bits per mode (a
    bit per band), how many QSOs (stops at 255), and the initial exchange
    TRMASTER or the log gave it. *)
  TCallsignEntry = class
  public
    Dupes: TDupesArray;
    Call: CallString;
    QSOs: Byte;
    InExchange: String[14];
  end;

  (* THE WORKED-CALLS LIST -- a CLASS over a TObjectList since 2026-10-17
    (pointer audit P8, docs/POINTER_AUDIT.md 2.3, 6.9).

    IT WAS AN OLD-STYLE `object` WITH A VMT (two virtual methods nothing
    overrode) over a ReallocMem'd array of records reached through a
    pointer, grown and shifted by hand with System.Move and zeroed with
    FillChar. The tests that drove a list of their own had to FillChar the
    object by its TYPE's size before Init, because SizeOf an INSTANCE of
    such an object reads its VMT pointer -- the 0xC0000005 of 2026-10-13/14.
    Now a list is made with Create and released with Free.

    The entries are classes, not records, because FPC 3.2.2's TList<T> gives
    out COPIES of an item and has no in-place access, and this list is
    written in place on every QSO (the dupe bits, the count).

    SEMANTICS KEPT EXACTLY and pinned by uTestCallsignsList against the old
    code first, with three deliberate exceptions, all undefined behaviour:
    AddCallsign indexed the dupe bits with FM, which is past TDupesArray, and
    wrote into the entry's CALL (now DupeSlot, as CallsignIsDupe always read
    it -- and DisplayDupeSheet read past it the same way); FindNumber read
    one entry PAST the end of the list (its loop ran to Count, not Count - 1);
    and AddIniitialExchange returned an unassigned boolean when the list was
    full. An index out of range now raises, where the array read whatever
    lay there. *)
  TCallsignsList = class
  private
    FItems: TObjectList<TCallsignEntry>;
    function CompareStrings(const s1, s2: CallString): integer;
    procedure InsertCallsign(Index: integer; const s: CallString);
    function GetCount: integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(Index: integer): string;
    function GetQSOs(Index: integer): Byte;
    function GetDupesArray(Index: integer; var da: TDupesArray): boolean;

    function GetTotalWorkedStations: integer;
    function AddCallsign(const s: string; Mode: ModeType; Band: BandType; JustAddToList: boolean): integer;
    function AddIniitialExchange(const Call: string; const InitialExchangeString: string): boolean;
    function GetIniitialExchange(const Call: string): string;
    function GetIniitialExchangeByIndex(Index: integer): string;
    function CallsignIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
//    procedure Clear;
//    procedure Delete(Index: integer);
    procedure ClearDupes;
    procedure DisplayDupeSheet(Radio: RadioPtr {dBand: BandType; dMode: ModeType});
    function CreatePartialsList(const Call: string): integer;
    function FindCallsign(const s: string; var Index: integer): boolean;
    function FindNumber(const s: string): boolean;  // n4af 4.42.2

    property Count: integer read GetCount;
  end;

  (* One station's qualifiers and their dupe bits. *)
  TQualifierMarks = TDictionary<string, TDupesArray>;
  (* Qualifiers, as WorkedQualifiers answers them. A string array of THIS
    unit's string, not TStrings/SysUtils.TStringArray, whose elements are the
    RTL's AnsiString -- every crossing would be a narrowing conversion. *)
  TQualifierArray = array of string;

  (* THE CALL + QUALIFIER DUPE SHEET -- Q118; see QualifiedDupes below.

    A CLASS OVER DICTIONARIES, NOT A SECOND TCallsignsList: that list keys
    on a CallString (13 characters), and a call plus a county overruns it --
    'KC2ABC/STE SCH' would be cut to 'KC2ABC/STE SC' and collide with SCO
    and SCU. Here the call (upper-cased: TCallsignsList compares case-blind)
    keys the station, and each station holds its qualifiers, so "which QTHs
    was this call worked from on this band and mode" -- the pre-exchange
    hint, LOGEDIT.EditableLog.CallIsADupeBeforeExchange -- is a lookup, not
    a walk of the log. The bits are the same TDupesArray, read and written
    by the same MarkDupeBits / DupeBitsSay. *)
  TQualifiedDupeSheet = class
  private
    FCalls: TObjectDictionary<string, TQualifierMarks>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddQSO(const aCall: string; const aQualifier: string;
                     Mode: ModeType; Band: BandType);
    function QSOIsDupe(const aCall: string; const aQualifier: string;
                       Band: BandType; Mode: ModeType): boolean;
    (* THE QUALIFIERS aCall WAS WORKED FROM ON THIS BAND AND MODE, as the
      dupe rule reads them (DupeBitsSay), sorted. *)
    function WorkedQualifiers(const aCall: string; Band: BandType;
                              Mode: ModeType): TQualifierArray;
    procedure ClearDupes;
  end;

const
  MaxCallsignsInPossibleCallsList       = 9;
var
  (* Created in this unit's initialization, freed in its finalization. *)
  CallsignsList                         : TCallsignsList;
  (* THE DUPE SHEET FOR A CONTEST WHOSE DUPE KEY IS MORE THAN THE CALL --
    Q118 (TContestBase.DupeKeyQualifier: a state party's received QTH).
    Used ONLY for the dupe question of a logged QSO (LOGEDIT.QSOIsADupe)
    and the pre-exchange hint (EditableLog.CallIsADupeBeforeExchange's
    WorkedQualifiers), never for partials, the dupe-sheet window or the
    worked-station count, which stay on CallsignsList. Written beside
    CallsignsList by LOGEDIT.AddQSOToDupeSheets; cleared with it by
    ClearAllDupeSheets. Empty for every other contest. Created in this
    unit's initialization, freed in its finalization. *)
  QualifiedDupes                        : TQualifiedDupeSheet;

(* THE DUPE BITS OF ONE STATION, AND THE ONE RULE FOR READING AND WRITING
  THEM -- shared by TCallsignsList and TQualifiedDupeSheet so the two sheets
  cannot disagree about band, mode, FM or an off-band QSO. Lifted out of
  TCallsignsList.AddCallsign / CallsignIsDupe unchanged (Q118); FM is
  uSortedStringList.DupeSlot's, the one FM rule (P8).

  MarkDupeBits: an off-band QSO (the contest does not use the band) marks
  nothing; otherwise the band and AllBands bits of the mode's slot and of
  Both. DupeBitsSay: an off-band question (Band <> AllBands) is never a
  dupe; otherwise the QSO-by-band and QSO-by-mode settings choose the bit. *)
procedure MarkDupeBits(var aDupes: TDupesArray; Mode: ModeType; Band: BandType);
function DupeBandIsOffBand(Band: BandType): boolean;
function DupeBitsSay(const aDupes: TDupesArray; Band: BandType; Mode: ModeType): boolean;

(* CLEARS EVERY DUPE SHEET'S MARKS -- CallsignsList and QualifiedDupes,
  which must never disagree about what has been worked. *)
procedure ClearAllDupeSheets;

implementation
uses
  uMainForm,       { the possible-call list, named -- wh[] round 4 }
  uDupeSheetForm,  { the dupe sheet is a form -- see DisplayDupeSheet }
  SysUtils,            // Issue #997 - SysUtils.Format / StrPCopy
  uConfigValues,
  uSettingsModel,   // Settings.PossibleCall.Enable
  LogStuff,
  LogDupe,
  LogWind,
  (* Contest, and the band question an off-band QSO is asked (M8). *)
  PostUnit,
  uContestBase,
  uContestRegistry,
  uSortedStringList;   (* DupeSlot -- FM shares Phone's dupe bits *)

constructor TCallsignsList.Create;
begin
  inherited Create;
  FItems := TObjectList<TCallsignEntry>.Create(True);
end;

destructor TCallsignsList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TCallsignsList.GetCount: integer;
begin
  Result := FItems.Count;
end;

function TCallsignsList.GetIniitialExchangeByIndex(Index: integer): string;
begin
  Result := string(FItems[Index].InExchange);
end;

function TCallsignsList.GetIniitialExchange(const Call: string): string;
var
  Index                                 : integer;
begin
  if FindCallsign(Call, Index) then
     begin
     Result := string(FItems[Index].InExchange);
     end
  else
     begin
     Result := '';
     end;
end;

(* True when the station was new. A FULL list adds nothing and answers False
  -- it returned an unassigned boolean there until P8. *)
function TCallsignsList.AddIniitialExchange(const Call: string; const InitialExchangeString: string): boolean;
var
  Index                                 : integer;
begin
  Result := False;
  if not FindCallsign(Call, Index) then
     begin
     if FItems.Count = MAXCALLSIGNSINLIST then
        begin
        Exit;
        end;
     InsertCallsign(Index, ShortString(Call));
     Result := True;
     end;
  FItems[Index].InExchange := ShortString(InitialExchangeString);
end;

function TCallsignsList.GetTotalWorkedStations: integer;
var
  i                                     : integer;
begin
  Result := 0;
  for i := 0 to FItems.Count - 1 do
     begin
     if FItems[i].QSOs > 0 then
        begin
        inc(Result);
        end;
     end;
end;

(* A FULL list refuses a new station and returns its insertion point, as it
  always did; no caller reads the result then. *)
function TCallsignsList.AddCallsign(const s: string; Mode: ModeType; Band: BandType; JustAddToList: boolean): integer;
var
  entry                                 : TCallsignEntry;
begin
  if not FindCallsign(s, Result) then
     begin
     if FItems.Count = MAXCALLSIGNSINLIST then
        begin
        Exit;
        end;
     InsertCallsign(Result, ShortString(s));
     end;

  entry := FItems[Result];
  if entry.QSOs < 255 then  //n4af 4.35.8
     begin
     inc(entry.QSOs);
     end;

  if JustAddToList then
     begin
     Exit;
     end;

  (* THE BITS, THE OFF-BAND RULE AND THE FM SLOT ARE MarkDupeBits'S --
    shared with TQualifiedDupeSheet since Q118. The QSO still counts as a
    QSO with the station (QSOs above) when it is off-band: it is in the log. *)
  MarkDupeBits(entry.Dupes, Mode, Band);
end;

procedure MarkDupeBits(var aDupes: TDupesArray; Mode: ModeType; Band: BandType);
var
  slot                                  : ModeType;
begin
  (* AN OFF-BAND QSO MARKS NO DUPE BIT -- M8, design 7.4. NY4I, 2026-10-01:
    an off-band QSO "is not a dupe and makes no later on-band QSO a dupe".

    The AllBands bit below is what a contest whose QSOs are NOT counted per
    band checks, so before M8 a 30 m QSO in such a contest made the same
    station a dupe on 20 m. The same question scoring and SetMultFlags ask
    (ContestCreditsBand), of the session's contest; ContestIdentity, which
    carries no station and is safe off the main thread, because the band
    list is what the contest IS. *)
  if not ContestCreditsBand(ContestIdentity(Contest), Band) then
     begin
     Exit;
     end;

  (* FM SHARES PHONE'S SLOT, as DupeBitsSay reads it. Until P8 this
    indexed the bits with Mode itself, and TDupesArray stops at NoMode, so
    an FM QSO wrote four bytes PAST the array -- into the length and first
    characters of the entry's call. The loader and LogContact remap FM
    before calling; the rescore (MainUnit.RecomputeQSOScoring) passes the
    record's mode as stored, and GetModeFromExtendedMode stores FM. *)
  slot := DupeSlot(Mode);
  aDupes[slot] := aDupes[slot] or (1 shl Ord(Band));
  aDupes[Both] := aDupes[Both] or (1 shl Ord(Band));
  aDupes[slot] := aDupes[slot] or (1 shl Ord(AllBands));
  aDupes[Both] := aDupes[Both] or (1 shl Ord(AllBands));
end;

function DupeBandIsOffBand(Band: BandType): boolean;
begin
  (* AllBands from a caller is a key, not a band, and asks nothing -- see
    TCallsignsList.CallsignIsDupe. *)
  Result := (Band <> AllBands) and
            (not ContestCreditsBand(ContestIdentity(Contest), Band));
end;

function DupeBitsSay(const aDupes: TDupesArray; Band: BandType; Mode: ModeType): boolean;
var
  TempMode                              : ModeType;
  TempBand                              : BandType;
begin
  if DupeBandIsOffBand(Band) then
     begin
     Result := False;
     Exit;
     end;

  if Settings.Qso.ByMode then
     begin
     TempMode := Mode;
     end
  else
     begin
     TempMode := Both;
     end;
  if Settings.Qso.ByBand then
     begin
     TempBand := Band;
     end
  else
     begin
     TempBand := AllBands;
     end;

  TempMode := DupeSlot(TempMode);

  Result := (aDupes[TempMode] and (1 shl Ord(TempBand))) <> 0;
end;

function TCallsignsList.CallsignIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
var
  Index                                 : integer;
begin
  Result := False;

  (* AN OFF-BAND QSO IS NOT A DUPE -- M8, design 7.4; the other half of the
    rule in AddCallsign, asked the same way (DupeBandIsOffBand, shared with
    TQualifiedDupeSheet since Q118). Band is the REAL band here:
    EditableLog.CallIsADupe used to turn it into the AllBands key before
    calling, which hid the band this asks about; it passes it through now and
    the key is made in DupeBitsSay, once. AllBands from a caller (the
    QSO-needs strip of a contest not counted per band) is a key, not a band,
    and asks nothing. IndexInList is still reported, so a caller can still
    show the station's history. *)
  if DupeBandIsOffBand(Band) then
     begin
     if not FindCallsign(s, IndexInList) then
        begin
        IndexInList := -1;
        end;
     Exit;
     end;

  if FindCallsign(s, Index) then
     begin
     Result := DupeBitsSay(FItems[Index].Dupes, Band, Mode);
     IndexInList := Index;
     end
  else
     begin
     IndexInList := -1;
     end;
end;

(* THE CALL IS CUT TO CallString WIDTH ONCE, here, where the old code had each
  comparison's CallString parameter cut it -- the same conversion, made once. *)
function TCallsignsList.FindCallsign(const s: string; var Index: integer): boolean;
var
  l, h, i, c                            : integer;
  key                                   : CallString;
begin
  Result := False;
  key := ShortString(s);
  l := 0;
  h := FItems.Count - 1;
  while l <= h do
     begin
     i := (l + h) shr 1;
     c := CompareStrings(FItems[i].Call, key);
     if c < 0 then
        begin
        l := i + 1;
        end
     else
        begin
        h := i - 1;
        if c = 0 then
           begin
           Result := True;
           l := i;
           end;
        end;
     end;
  Index := l;
end;

(* THE MEMBER-NUMBER REVERSE LOOKUP (n4af 4.42.2): the first station whose
  initial exchange ENDS in s, in list order, goes to the call window.

  ITS LOOP RAN ONE PAST THE END until P8 -- `i := -1; while i <= h do inc(i)`
  reads entries 0..Count, and entry Count was whatever the ReallocMem'd
  array held beyond the last station (uninitialised capacity, or past the
  block when the list was exactly full). *)
function TCallsignsList.FindNumber(const s: string): boolean;        // n4af 4.42.2 reverse lookup member #
var
  i                                     : integer;
  key                                   : CallString;
begin
  Result := False;
  key := ShortString(s);
  for i := 0 to FItems.Count - 1 do
     begin
     if CompareStrings(ShortString(LastString(FItems[i].InExchange)), key) = 0 then
        begin
        Result := True;
        CallWindowString := FItems[i].Call;
        Exit;
        end;
     end;
end;

function TCallsignsList.Get(Index: integer): string;
begin
  Result := string(FItems[Index].Call);
end;

function TCallsignsList.GetQSOs(Index: integer): Byte;
begin
  Result := 0;
  if Index = -1 then
     begin
     Exit;
     end;
  Result := FItems[Index].QSOs;
end;

function TCallsignsList.GetDupesArray(Index: integer; var da: TDupesArray): boolean;
begin
  Result := False;
  if Index = -1 then
     begin
     Exit;
     end;
  da := FItems[Index].Dupes;
  Result := True;
end;

(* A NEW ENTRY IS ZERO -- a class instance's fields are, which is what the
  FillChar over the array slot did. *)
procedure TCallsignsList.InsertCallsign(Index: integer; const s: CallString);
var
  entry                                 : TCallsignEntry;
begin
  entry := TCallsignEntry.Create;
  entry.Call := s;
  FItems.Insert(Index, entry);
end;

function TCallsignsList.CompareStrings(const s1 {edx}, s2 {ecx}: CallString): integer {eax};
begin
  (* uStringCompare.CompareKeyIgnoreCase, NOT Win32 CompareStringA.

    THE WIN32 CALL WAS LOCALE-DEPENDENT, and that is a defect rather than
    behaviour worth preserving: LOCALE_SYSTEM_DEFAULT means THE SAME CALLSIGN
    LIST ORDERS DIFFERENTLY ON TWO OPERATORS' MACHINES. Nothing about a
    callsign is linguistic -- they are drawn from A-Z, 0-9 and '/'.

    WHY THIS IS SAFE TO SWAP, checked rather than assumed:

      - The comparator is the ordering key for a BINARY SEARCH, and this class
        uses it for BOTH insertion and lookup, so consistency is preserved by
        construction.
      - THE SORTED ORDER IS NOT PERSISTED. This list is built in memory from
        the log at startup; there is no SaveToFile and no stream anywhere in
        this unit, so no on-disk artifact can be left ordered by the old
        comparator and read back by the new one.
      - For the alphabet actually in use the two orders agree: ordinal puts
        '/' (47) before the digits (48-57) before the letters (65-90), and the
        Windows word sort orders that set the same way.

    The `- 2` was turning Windows' 1/2/3 (LESS/EQUAL/GREATER) into -1/0/1.

    416 assertions in uTestStringCompare pin the replacement's order,
    antisymmetry and transitivity over exactly this alphabet -- written BEFORE
    this repoint, which is what NY4I asked for on 2026-09-07: "ensure we have
    unit tests for every case to check the refactor for when it's done." *)
  Result := CompareKeyIgnoreCase(s1, s2);

{
  Result := 0;
  if s1 <> s2 then
  begin
    asm
    JBE @@L
    JNE @@G
@@L:MOV RESULT,-1
    JMP @@E
@@G:MOV RESULT, 1
@@E:
    end;
  end;
}
{
  if s1 = s2 then result := 0
  else
    if s1 < s2 then result := -1
    else
      result := 1;
}

//  if s1[0] > s2[0] then l := length(s2) else l := length(s1);
{
  asm
  push ebx
  push ecx
  push edi
  push esi

  xor ebx, ebx
  mov bl,byte ptr [edx]
  sub bl,byte ptr [ecx]//>0 length(s1)>length(s2)

  xor eax, eax
  mov al,byte ptr [edx]
  cmp al,byte ptr [ecx]
  jbe  @@1
  mov al,byte ptr [ecx]

@@1:

  MOV ESI,ecx
  MOV EDI,edx
  add esi,1
  add edi,1

  mov ecx,eax//3

  REPE CMPSB
  JZ   @@EQUAL
  JB   @@LESS

@@GREAT:
  MOV EDX,-1
  JMP @@EXIT

@@EQUAL:
//  CMP EBX ,0
//  JL  @@LESS
//  JNZ  @@GREAT
  MOV EDX,EBX
  JMP @@EXIT

@@LESS:
  MOV EDX,1
  JMP @@EXIT

  @@EXIT:

  pop esi
  pop edi
  pop ecx
  pop ebx
  end;
}

//  RESULT := StrComp(@s1[1], @s2[1]);
//  RESULT := Windows.lstrcmp(@s1[1], @s2[1]);

end;

function TCallsignsList.CreatePartialsList(const Call: string): integer;
label
  1;
var
  Index                                 : integer;
  TempIndex                             : integer;
  entry                                 : TCallsignEntry;
begin
  { FIRST, so the two guards below cannot return an uninitialised Result.
    A function that exits before assigning one hands back whatever was in
    the register, and both callers read it as a count. }
  Result := 0;
  if not Settings.PossibleCall.Enable then Exit;
  ClearPossibleCalls;
  if length(Call) < 2 then Exit;
  for Index := 0 to FItems.Count - 1 do
     begin
     entry := FItems[Index];
     if pos(Call, entry.Call) > 0 then
        begin
              PossibleCallList.List[Result].Call := entry.Call;
              PossibleCallList.List[Result].Dupe :=
                CallsignIsDupe(entry.Call, ActiveBand, ActiveMode, TempIndex);
              (* THE CALLSIGN GOES INTO THE CONTROL, not just into the model.
                See uMainForm.lstPossibleCallPrepareCanvas for why a strip that
                held no data cost four separate defects. *)
              AddPossibleCall(string(PossibleCallList.List[Result].Call),
                              PossibleCallList.List[Result].Dupe);
              inc(Result);
              if Result = MaxCallsignsInPossibleCallsList then
                 begin
                 goto 1;
                 end;
        end;
     end;
  1:
  if Result > 0 then
     begin
     SelectPossibleCall(0);
     end;

  // The rows are all empty strings, so the list cannot know the model moved.
  PossibleCallsUpdated;
end;

{ FILLS THE DUPE SHEET FROM THIS LIST -- the model writing to the view, which is
  the direction it always was.  What changed is the other end: the calls go into
  the form's own list and the grid draws from that, instead of being pushed into
  a list box with LB_ADDSTRING and read back out again by an owner-draw handler
  that had no other way to know what it was painting.

  THE COLUMN-PER-DISTRICT LAYOUT IS GONE WITH `COLUMN DUPESHEET ENABLE`
  (retired 2026-08-24, NY4I).  It sent each callsign to one of ten list boxes
  whose control ids happened to equal the ASCII codes of '0'..'9'.

  AND IT CARRIED AN UNINITIALISED READ.  LB_SETITEMDATA sat OUTSIDE the
  if/else -- the indentation hid that -- while `Item` was only assigned in the
  non-column arm, so in column mode the call passed an uninitialised local as an
  item index, to the hidden list box at that.  Win32 answered LB_ERR and nobody
  ever looked. }
procedure TCallsignsList.DisplayDupeSheet(Radio: RadioPtr {dBand: BandType; dMode: ModeType});
var
  frm                                   : TfrmDupeSheet;
  i, Index                              : integer;
  entry                                 : TCallsignEntry;

  Band                                  : BandType;
  Mode                                  : ModeType;
  TempChar                              : AnsiChar;
  rn                                    : AnsiString;   // the radio name, length-correct
begin
//  if not Sheet.DupeSheetEnable then Exit;
  (* THE FORM, DIRECTLY. This read a handle off the radio, checked it against
    zero, and then searched every dupe-sheet form for the one whose .Handle
    matched. nil is the same answer in one step. *)
  frm := TfrmDupeSheet(Radio.tDupeSheetForm);
  if frm = nil then Exit;

  Band := Radio.BandMemory;
  (* FM reads Phone's slot -- see DupeSlot; it read past the array. *)
  Mode := DupeSlot(Radio.ModeMemory);

  frm.Calls.BeginRebuild;

  (* THE CALL AREA IS THE FIRST DIGIT THAT FOLLOWS A LETTER. The loop ran
    from 0 with range checks off, reading Call[-1] -- the byte before the
    string -- and Call[0], its length; neither can be a letter followed by a
    digit (a CallString is at most 13 long), so starting at 2 is the same
    answer without the out-of-range read. The {$RangeChecks ON} that closed
    that block also switched range checking ON for the rest of this unit,
    where it had been off; both went with the read. *)
  for TempChar := '0' to '9' do
     begin
     for Index := 0 to FItems.Count - 1 do
        begin
        entry := FItems[Index];
        if (entry.Dupes[Mode] and (1 shl Ord(Band))) <> 0 then
           begin
           for i := 2 to length(entry.Call) do        // 4.79.3
              begin
              if (entry.Call[i - 1] in ['A'..'Z']) and
                 (entry.Call[i] in ['0'..'9']) then
                 begin
                 if entry.Call[i] = TempChar then
                    begin
                    frm.Calls.AddItem(string(entry.Call), Ord(TempChar));
                    end;
                 Break;
                 end;
              end;
           end;
        end;
     end;

  frm.Calls.EndRebuild;


  // P1/P2 went with the pushes.  They were assigned and never read: the same
  // note below records that the asm which consumed them was already gone.
  // Issue #997: removed orphaned `asm push p2/push p1` -- leftover from the
  // earlier conversion below; the SysUtils.Format call replaced the wsprintf
  // that consumed these pushes, and the matching `add esp,16` was already
  // commented out, so the pushes fed nothing (absorbed by the stack frame).

  // Issue #997 - wsprintf-push formatting converted to ANSI TF.Format
  // (wsprintfA).  TC_DUPESHEET already carries two %s specs (band, mode); the
  // appended ' - %s' adds the radio name -> three PAnsiChar args.  Writing
  // straight into the ANSI wsprintfBuffer avoids the D12 wide StrPCopy /
  // SysUtils.Format round-trip (dest is PAnsiChar).
  // Same defect as LOGWIND's radio-name row, same variable: RadioName is a
  // ShortString and PAnsiChar(@RadioName[1]) reads past its length into stale
  // bytes from a longer previous value, so this caption showed "K3Sio 2".
  // The AnsiString conversion is length-correct, and rn is a LOCAL held across
  // the call -- PAnsiChar of a temporary would dangle under FPC.
  // THE RADIO LEADS.  Was 'Dupesheet - 10m-CW - Radio 1'; NY4I asked for the
  // radio to be identified up front -- "Radio One Dupesheet would be useful" --
  // and with two of these windows open at once that is the first thing to read.
  // Composed from TC_DUPESHEET rather than a new literal, so the only English
  // here is still the one that was already translated.
  rn := AnsiString(Radio.RadioName);
  frm.Caption := SysUtils.Format(AnsiString(LclText('%s ' + TC_DUPESHEET)),
                                 [rn, BandStringsArray[Band],
                                  ModeStringArray[Mode]]);
end;

{ WHAT WM_INITDIALOG DID.  Reached through the form's OnShow -- see the seam in
  uDupeSheetForm.  The window handle is recorded by OpenTR4WWindow; what is left
  is telling the radio which window is its dupe sheet, and filling it. }
procedure DupeSheetWindowShown(const aIndex: WindowsType);
var
   frm: TfrmDupeSheet;
begin
   frm := DupeSheetForm(aIndex);
   if frm = nil then
      begin
      Exit;
      end;

   if aIndex = tw_DUPESHEETWINDOW2_INDEX then
      begin
      Radio2.tDupeSheetForm := frm;
      CallsignsList.DisplayDupeSheet(@Radio2);
      end
   else
      begin
      Radio1.tDupeSheetForm := frm;
      CallsignsList.DisplayDupeSheet(@Radio1);
      end;
end;

{ And what WM_CLOSE did.  CloseTR4WWindow hides the window; the radio has to be
  told its dupe sheet is gone, or DisplayDupeSheet keeps writing to a window
  nobody can see. }
procedure DupeSheetWindowClosed(const aIndex: WindowsType);
begin
   if aIndex = tw_DUPESHEETWINDOW2_INDEX then
      begin
      Radio2.tDupeSheetForm := nil;
      end
   else
      begin
      Radio1.tDupeSheetForm := nil;
      end;
end;

procedure RegisterDupeSheetSeams;
begin
   DupeSheetOnShow  := @DupeSheetWindowShown;
   DupeSheetOnClose := @DupeSheetWindowClosed;
end;

procedure TCallsignsList.ClearDupes;
var
  Index                                 : integer;
  m                                     : ModeType;
  entry                                 : TCallsignEntry;
begin
  for Index := 0 to FItems.Count - 1 do
     begin
     entry := FItems[Index];
     for m := Low(TDupesArray) to High(TDupesArray) do
        begin
        entry.Dupes[m] := 0;
        end;
     entry.QSOs := 0;
     end;
end;

{ TQualifiedDupeSheet }

constructor TQualifiedDupeSheet.Create;
begin
  inherited Create;
  FCalls := TObjectDictionary<string, TQualifierMarks>.Create([doOwnsValues]);
end;

destructor TQualifiedDupeSheet.Destroy;
begin
  FCalls.Free;
  inherited Destroy;
end;

procedure TQualifiedDupeSheet.AddQSO(const aCall: string; const aQualifier: string;
                                     Mode: ModeType; Band: BandType);
var
  marks                                 : TQualifierMarks;
  dupes                                 : TDupesArray;
begin
  if not FCalls.TryGetValue(UpperCase(aCall), marks) then
     begin
     marks := TQualifierMarks.Create;
     FCalls.Add(UpperCase(aCall), marks);
     end;
  if not marks.TryGetValue(aQualifier, dupes) then
     begin
     dupes := Default(TDupesArray);
     end;
  MarkDupeBits(dupes, Mode, Band);
  marks.AddOrSetValue(aQualifier, dupes);
end;

function TQualifiedDupeSheet.QSOIsDupe(const aCall: string; const aQualifier: string;
                                       Band: BandType; Mode: ModeType): boolean;
var
  marks                                 : TQualifierMarks;
  dupes                                 : TDupesArray;
begin
  Result := False;
  if FCalls.TryGetValue(UpperCase(aCall), marks) and
     marks.TryGetValue(aQualifier, dupes) then
     begin
     Result := DupeBitsSay(dupes, Band, Mode);
     end;
end;

function TQualifiedDupeSheet.WorkedQualifiers(const aCall: string; Band: BandType;
                                              Mode: ModeType): TQualifierArray;
var
  marks                                 : TQualifierMarks;
  pair                                  : TPair<string, TDupesArray>;
  count                                 : integer;
  i                                     : integer;
begin
  Result := nil;
  if not FCalls.TryGetValue(UpperCase(aCall), marks) then
     begin
     Exit;
     end;
  count := 0;
  SetLength(Result, marks.Count);
  for pair in marks do
     begin
     if DupeBitsSay(pair.Value, Band, Mode) then
        begin
        (* An insertion into the sorted part: a station has a handful. *)
        i := count;
        while (i > 0) and (Result[i - 1] > pair.Key) do
           begin
           Result[i] := Result[i - 1];
           Dec(i);
           end;
        Result[i] := pair.Key;
        Inc(count);
        end;
     end;
  SetLength(Result, count);
end;

procedure TQualifiedDupeSheet.ClearDupes;
begin
  FCalls.Clear;
end;

procedure ClearAllDupeSheets;
begin
  CallsignsList.ClearDupes;
  QualifiedDupes.ClearDupes;
end;

initialization
  CallsignsList := TCallsignsList.Create;
  QualifiedDupes := TQualifiedDupeSheet.Create;
  RegisterDupeSheetSeams;

finalization
  FreeAndNil(QualifiedDupes);
  FreeAndNil(CallsignsList);

end.



