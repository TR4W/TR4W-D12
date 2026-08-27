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
  Windows,
  Messages,
  Tree,
  LogRadio,
  LogSCP,
  uTR4WStrings,
  uAnsiStr;

const
  MAXCALLSIGNSINLIST                    = 100000;           // 4.115.6

type
  PCallsignItem = ^TCallsignItem;

  TPossibleCalls = record
    FCall: CallString;
    FDupe: boolean;
  end;

  TCallsignItem = record
    {16}FDupesArray: TDupesArray;

    {14}FCall: CallString;
    {01}FQSOs: Byte;
    {01}res1: Byte;

    {14}FInExchange: String[14];
    {01}res2: Byte;
//    {01}res3: Byte;
  end;

  TCallsignItemList = array[0..MAXCALLSIGNSINLIST - 1] of TCallsignItem;
  PCallsignItemList = ^TCallsignItemList;

  TCallsignsList = object {class}
  private
    FList: PCallsignItemList;
    FCount: integer;
    FCapacity: integer;
    //    FPartialList: array[0..9] of TPossibleCalls;
    procedure Grow;
  protected
    function GetCapacity: integer;
    procedure SetCapacity(NewCapacity: integer);
    function CompareStrings(const s1, s2: CallString): integer;
    procedure InsertCallsign(Index: integer; const s: CallString); virtual;
  public
//  destructor Destroy; override;
    constructor Init;
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
    function FindCallsign(const s: string; var Index: integer): boolean; virtual;
    function FindNumber(const s: string): boolean; virtual;  // n4af 4.42.2

    property Count: integer read FCount;
  end;

const
  MaxCallsignsInPossibleCallsList       = 9;
var
  CallsignsList                         : TCallsignsList;
//  PossibleCallsList                     : array[0..MaxCallsignsInPossibleCallsList - 1] of TPossibleCalls;

implementation
uses
  uMainForm,       { the possible-call list, named -- wh[] round 4 }
  uDupeSheetForm,  { the dupe sheet is a form -- see DisplayDupeSheet }
  SysUtils,            // Issue #997 - SysUtils.Format / StrPCopy
  uConfigValues,
  LogStuff,
  LogDupe,
  LogWind;

{ TStringList }

constructor TCallsignsList.Init;
begin
  Grow;
end;
{
destructor TCallsignsList.Destroy;
begin
  inherited Destroy;
  if FCount <> 0 then Finalize(FList^[0], FCount);
  FCount := 0;
  SetCapacity(0);
end;
}

function TCallsignsList.GetIniitialExchangeByIndex(Index: integer): string;
begin
  Result := FList^[Index].FInExchange
end;

function TCallsignsList.GetIniitialExchange(const Call: string): string;
var
  Index                                 : integer;
begin
  if FindCallsign(Call, Index) then
     begin
     Result := FList^[Index].FInExchange
     end
     else
        begin
        Result := '';
        end;
end;

function TCallsignsList.AddIniitialExchange(const Call: string; const InitialExchangeString: string): boolean;
label
  Add;
var
  Index                                 : integer;
begin
  if FindCallsign(Call, Index) then
     begin
     Result := False;
     goto Add;
     end;
  if Count = MAXCALLSIGNSINLIST then Exit;
  InsertCallsign(Index, Call);
  Result := True;
  Add:
  FList^[Index].FInExchange := InitialExchangeString;
end;

function TCallsignsList.GetTotalWorkedStations: integer;
var
  i                                     : integer;
begin
  Result := 0;
  for i := 0 to Count - 1 do
    if FList^[i].FQSOs > 0 then
       begin
       inc(Result);
       end;
end;

function TCallsignsList.AddCallsign(const s: string; Mode: ModeType; Band: BandType; JustAddToList: boolean): integer;
label
  Add;
var
  Value                                 : integer;

begin

  if FindCallsign(s, Result) then
     begin
     goto Add;
     end;
  if Count = MAXCALLSIGNSINLIST then Exit;
  InsertCallsign(Result, s);
  Add:
 if   FList^[Result].FQSOs < 255 then  //n4af 4.35.8
    begin
    inc(FList^[Result].FQSOs);
    end;

  if JustAddToList then Exit;

  Value := FList^[Result].FDupesArray[Mode];
  FList^[Result].FDupesArray[Mode] := Value or (1 shl Ord(Band));

  Value := FList^[Result].FDupesArray[Both];
  FList^[Result].FDupesArray[Both] := Value or (1 shl Ord(Band));

  Value := FList^[Result].FDupesArray[Mode];
  FList^[Result].FDupesArray[Mode] := Value or (1 shl Ord(AllBands));

  Value := FList^[Result].FDupesArray[Both];
  FList^[Result].FDupesArray[Both] := Value or (1 shl Ord(AllBands));

end;

function TCallsignsList.CallsignIsDupe(const s: string; Band: BandType; Mode: ModeType; var IndexInList: integer): boolean;
var
  Index                                 : integer;
  TempMode                              : ModeType;
  TempBand                              : BandType;
begin
  Result := False;
  if FindCallsign(s, Index) then
     begin
     //    TempMode := Mode;
         if QSOByMode then TempMode := Mode else TempMode := Both;
         if QSOByBand then TempBand := Band else TempBand := AllBands;

         if TempMode = FM then
            begin
            TempMode := Phone;
            end;

         Result := (FList^[Index].FDupesArray[TempMode {Mode}] and (1 shl Ord(TempBand))) <> 0;
         IndexInList := Index;
     end
  else
     begin
     IndexInList := -1;
     end;
end;

function TCallsignsList.FindCallsign(const s: string; var Index: integer): boolean;
var
  l, h, i, c                            : integer;

  begin
  Result := False;
  l := 0;
  h := FCount - 1;
  while l <= h do
     begin
     i := (l + h) shr 1;
     c := CompareStrings(FList^[i].FCall, s);
     if c < 0 then
        begin
        l := i + 1
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


function TCallsignsList.FindNumber(const s: string): boolean;        // n4af 4.42.2 reverse lookup member #
var
 i, {l,} h, c                             : integer;
 lstr                                    : string;
begin
  Result := False;
  i := -1; //4.67.3
  h := FCount - 1;
  while i <= h do
     begin
     i := (i + 1);
   lstr := laststring(Flist[i].Finexchange);
    c := CompareStrings(lstr, s);
     if c = 0 then
        begin
        Result := True;
        CallWindowString :=  flist^[i].FCall;
    
        exit; 
        end;
     end;
  end;


function TCallsignsList.Get(Index: integer): string;
begin
  //  if (Index < 0) or (Index >= FCount) then Exit; //ERROR(@SListIndexError, Index);
  Result := FList^[Index].FCall;
end;

function TCallsignsList.GetQSOs(Index: integer): Byte;
begin
  Result := 0;
  if Index = -1 then Exit;

  Result := FList^[Index].FQSOs;
end;

function TCallsignsList.GetDupesArray(Index: integer; var da: TDupesArray): boolean;
begin
  Result := False;
  if Index = -1 then Exit;
  da := FList^[Index].FDupesArray;
  Result := True;
end;

function TCallsignsList.GetCapacity: integer;
begin
  Result := FCapacity;
end;

procedure TCallsignsList.Grow;
var
  delta                                 : integer;
begin
  if FCapacity > 64 then delta := FCapacity div 4 else
    if FCapacity > 8 then delta := 16 else
                                         begin
                                         delta := 4;
                                         end;
  SetCapacity(FCapacity + delta);
end;

procedure TCallsignsList.InsertCallsign(Index: integer; const s: CallString);
begin

  if FCount = FCapacity then
     begin
     Grow;
     end;
  if Index < FCount then
     begin
     System.Move(FList^[Index], FList^[Index + 1],
       (FCount - Index) * SizeOf(TCallsignItem));
     end;

  Windows.ZeroMemory(@FList^[Index], SizeOf(FList^[Index]));
  FList^[Index].FCall := s;
//  with FList^[Index] do
//  begin
//    Windows.ZeroMemory(@FDupesArray, SizeOf(TDupesArray));
//    FQSOs := 0;
//    FCall := s;
//    FInExchange := '';
//  end;
  inc(FCount);

end;

procedure TCallsignsList.SetCapacity(NewCapacity: integer);
begin
  ReallocMem(FList, NewCapacity * SizeOf(TCallsignItem));
  FCapacity := NewCapacity;
end;

function TCallsignsList.CompareStrings(const s1 {edx}, s2 {ecx}: CallString): integer {eax};
begin
  Result := CompareStringA(LOCALE_SYSTEM_DEFAULT, NORM_IGNORECASE, @s1[1], length(s1), @s2[1], length(s2)) - 2;

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
//  TempMode                              : ModeType;
begin
  if not Config.PossibleCallEnable then Exit;
  ClearPossibleCalls;
  if length(Call) < 2 then Exit;
  Result := 0;
  for Index := 0 to FCount - 1 do
     begin
     if pos(Call, FList^[Index].FCall) > 0 then
        begin
        //      if QSOByMode then TempMode := ActiveMode else TempMode := Both;
        //      if TempMode = FM then TempMode := Phone;
              PossibleCallList.List[Result].Call := FList^[Index].FCall;
              PossibleCallList.List[Result].Dupe :=
                CallsignIsDupe(FList^[Index].FCall, ActiveBand, ActiveMode, TempIndex);
        //      (FList^[Index].FDupesArray[TempMode] and (1 shl Ord(ActiveBand))) <> 0;
              AddPossibleCall;   // the row's DATA is PossibleCallList[Result]
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
  TempDSHandle                          : HWND;
  frm                                   : TfrmDupeSheet;
  i, Index                              : integer;

  Band                                  : BandType;
  Mode                                  : ModeType;
  TempChar                              : AnsiChar;
  rn                                    : AnsiString;   // the radio name, length-correct
begin
//  if not Sheet.DupeSheetEnable then Exit;
  TempDSHandle := Radio.tDupeSheetWnd;
  if TempDSHandle = 0 then Exit;

  frm := DupeSheetFormForHandle(TempDSHandle);
  if frm = nil then Exit;

  Band := Radio.BandMemory;
  Mode := Radio.ModeMemory;

  frm.Calls.BeginRebuild;

  for TempChar := '0' to '9' do
     begin
     for Index := 0 to FCount - 1 do
        begin
        if (FList^[Index].FDupesArray[Mode] and (1 shl Ord(Band))) <> 0 then
           begin
           {$RangeChecks OFF}
           for i := 0 to length(FList^[Index].FCall) do        // 4.79.3
             if FList^[Index].FCall[i - 1] in ['A'..'Z'] then
               if FList^[Index].FCall[i] in ['0'..'9'] then
                  begin
                  if FList^[Index].FCall[i] = TempChar then
                     begin
                     frm.Calls.AddItem(string(FList^[Index].FCall), Ord(TempChar));
                     end;
                  Break;
                  end;
           {$RangeChecks ON}
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
  TF.Format(wsprintfBuffer, PAnsiChar(WinAnsi('%s ' + TC_DUPESHEET)),
    PAnsiChar(rn), BandStringsArray[Band], ModeStringArray[Mode]);
//  asm add esp,16  end;
  frm.Caption := string(PAnsiChar(@wsprintfBuffer));
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
      Radio2.tDupeSheetWnd := frm.Handle;
      CallsignsList.DisplayDupeSheet(@Radio2);
      end
   else
      begin
      Radio1.tDupeSheetWnd := frm.Handle;
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
      Radio2.tDupeSheetWnd := 0;
      end
   else
      begin
      Radio1.tDupeSheetWnd := 0;
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
begin
  for Index := 0 to FCount - 1 do
     begin
     Windows.ZeroMemory(@FList^[Index].FDupesArray, SizeOf(TDupesArray));
     FList^[Index].FQSOs := 0;
       {
            for Band := Band160 to AllBands do
              for Mode := CW to Both do
                FList^[Index].FDupesArray[Mode, Band] := 0;
      }
     end;
end;

begin
//  CallsignsList := TCallsignsList.Create;
  CallsignsList.Init;
  RegisterDupeSheetSeams;
end.



