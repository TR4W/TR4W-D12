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
unit uMults;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses

  VC,
  uSortedStringList,
  uCallSignRoutines,
  uCTYDAT,
  //Country9,
  Log4D,
  (* TContestBase -- FillVisibleBytes' parameter (M11 S4). A leaf over VC
    and uSettingsModel, already linked by the unit tests. *)
  uContestBase;   // Issue #1034: dropped uCallsigns (unused here)


const
  ZoneMultArraySize                     = 100;

type
  DXMultsArray = record
    dxmaArray: TDupesArray;
    dxmaVisible: boolean;
  end;

  MultsObject = object
    DXMultsArray: array[0..MaxCountries - 1] of TDupesArray;
    ZoneMultsArray: array[0..ZoneMultArraySize] of TDupesArray;
    PrfList: TSortedStringList;
    DomList: TSortedStringList;

    MTotals: array[BandType, CW..Both, RemainingMultiplierType] of Word;

    procedure IncrementTotals(Band: BandType; Mode: ModeType; m: RemainingMultiplierType);
    procedure ClearAllMults;
    procedure FillRemMultsBytes(rm: RemainingMultiplierType);

    procedure SetZnMult(Zone: Word; Band: BandType; Mode: ModeType);
    procedure SetDXMult(Cntr: Word; Band: BandType; Mode: ModeType);
    procedure SetPxMult(const Prfx: string; Band: BandType; Mode: ModeType);
    procedure SetDmMult(const Dom: string; Band: BandType; Mode: ModeType);

    function IsZnMult(Zone: Word; Band: BandType; Mode: ModeType): boolean;
    function IsDXMult(Country: Word; Band: BandType; Mode: ModeType): boolean;
    function IsPxMult(const Prfx: string; Band: BandType; Mode: ModeType): boolean;
    (* aKeyedOnGridField: the contest's domestic multiplier is the grid FIELD
      (TContestBase.HasGridFieldMultiplier) -- the caller asks the contest,
      M11 S6 part 1. It was the session's DomesticMultType, of which this
      tested one member. *)
    function IsDmMult(const Dom: string; Band: BandType; Mode: ModeType; aKeyedOnGridField: boolean): boolean;
    (* WHICH CTY COUNTRIES THE REMAINING-MULTS WINDOW LISTS. aContest is the
      active contest (ActiveContest(Contest)), asked which countries its
      filter keeps -- TContestBase.ListsRemainingDXCountry, M11 S4; nil, the
      classless DUMMYCONTEST, keeps them all. *)
    procedure FillVisibleBytes(aContest: TContestBase);
  end;

var
  mo                                    : MultsObject;
  
implementation

(* uContestSession WAS USED HERE for ContestSession.DoingDXMults (M10 S9d /
  M11 S2). Since M11 S4 part 2 the contest answers whether it has a DX
  multiplier (HasDXMultiplier) and its filter (ListsRemainingDXCountry), both
  through uContestBase, so this unit reads no session kind at all. *)

// Issue #1034: own Log4D logger (initialized below), replacing the former
// MainUnit.logger borrow. MainUnit + LogDupe were otherwise unused here, so
// dropping them removes uMults's direct MainUnit -> LogStuff coupling and lets
// the multiplier logic be linked into the dependency-light unit-test EXE.
var
  logger: TLogLogger;

procedure MultsObject.IncrementTotals(Band: BandType; Mode: ModeType; m: RemainingMultiplierType);
begin
  // MTotals mode dim is CW..Both; FM (ordinal 5) is outside it -> remap to
  // Phone (FM counts as Phone) so MTotals[Band, FM, m] is not out of bounds.
  if Mode = FM then
     begin
     Mode := Phone;
     end;
  inc(MTotals[Band, Mode, m]);

  if Mode <> Both then
     begin
     inc(MTotals[Band, Both, m]);
     end;

  if Band <> AllBands then
     begin
     inc(MTotals[AllBands, Mode, m]);
     end;

   if ((Mode <> Both) and (Band <> AllBands)) then
      begin
      inc(MTotals[AllBands, Both, m]);
      end;
end;

procedure MultsObject.ClearAllMults;
begin
  FillChar(ZoneMultsArray, SizeOf(ZoneMultsArray), 0);
  FillChar(DXMultsArray, SizeOf(DXMultsArray), 0);
  FillChar(MTotals, SizeOf(MTotals), 0);
  PrfList.ClearDupes;
  DomList.ClearDupes;
end;

procedure MultsObject.SetZnMult(Zone: Word; Band: BandType; Mode: ModeType);
begin
  if Mode = FM then Mode := Phone;   // FM shares the Phone slot (TDupesArray is CW..NoMode)
  if not (Zone in [0..ZoneMultArraySize]) then Exit;
  ZoneMultsArray[Zone][Mode] := ZoneMultsArray[Zone][Mode] or (1 shl Ord(Band));
  ZoneMultsArray[Zone][Both] := ZoneMultsArray[Zone][Both] or (1 shl Ord(Band));
  ZoneMultsArray[Zone][Mode] := ZoneMultsArray[Zone][Mode] or (1 shl Ord(AllBands));
  ZoneMultsArray[Zone][Both] := ZoneMultsArray[Zone][Both] or (1 shl Ord(AllBands));
  IncrementTotals(Band, Mode, rmZone);
end;

procedure MultsObject.SetDXMult(Cntr: Word; Band: BandType; Mode: ModeType);
begin
  if Mode = FM then Mode := Phone;   // FM shares the Phone slot (TDupesArray is CW..NoMode)
  if Cntr >= CTY.ctyNumberCountries then Exit;

  DXMultsArray[Cntr][Mode] := DXMultsArray[Cntr][Mode] or (1 shl Ord(Band));
  DXMultsArray[Cntr][Both] := DXMultsArray[Cntr][Both] or (1 shl Ord(Band));
  DXMultsArray[Cntr][Mode] := DXMultsArray[Cntr][Mode] or (1 shl Ord(AllBands));
  DXMultsArray[Cntr][Both] := DXMultsArray[Cntr][Both] or (1 shl Ord(AllBands));
  IncrementTotals(Band, Mode, rmDX);
end;

procedure MultsObject.SetPxMult(const Prfx: string; Band: BandType; Mode: ModeType);
begin
  // (dropped the ShortString null-terminator Prfx[Ord(Prfx[0])+1]:=#0 -- a native
  //  string carries its own length, and uSortedStringList.AddString now takes a string.)
  PrfList.AddString(Prfx, Band, Mode, False);
  IncrementTotals(Band, Mode, rmPrefix);
end;

procedure MultsObject.SetDmMult(const Dom: string; Band: BandType; Mode: ModeType);
begin
  // (dropped the ShortString null-terminator; native string + uSortedStringList.AddString(string).)
  DomList.AddString(Dom, Band, Mode, False);
  IncrementTotals(Band, Mode, rmDomestic);
end;

function MultsObject.IsZnMult(Zone: Word; Band: BandType; Mode: ModeType): boolean;
begin
  if Mode = FM then Mode := Phone;   // FM shares the Phone slot (TDupesArray is CW..NoMode)
  if Zone in [0..ZoneMultArraySize] then
     begin
     Result := (ZoneMultsArray[Zone][Mode] and (1 shl Ord(Band))) = 0
     end
  else
     begin
     Result := False;
     end;
end;

function MultsObject.IsDXMult(Country: Word; Band: BandType; Mode: ModeType): boolean;
begin
  if Mode = FM then Mode := Phone;   // FM shares the Phone slot (TDupesArray is CW..NoMode)
  if Country < MaxCountries then
     begin
     Result := (DXMultsArray[Country][Mode] and (1 shl Ord(Band))) = 0
     end
    else
       begin
       Result := False;
       end;
end;

function MultsObject.IsPxMult(const Prfx: string; Band: BandType; Mode: ModeType): boolean;
var
  Index                                 : integer;
begin
  Result := not PrfList.StringIsDupe(Prfx, Band, Mode, Index);
  if Index = -1 then
     begin
     logger.debug('In MultsObject.IsPxMult, for Prfx of ' + Prfx + ', Result = true');
     Result := True;
     end;
end;

function MultsObject.IsDmMult(const Dom: string; Band: BandType; Mode: ModeType; aKeyedOnGridField: boolean): boolean;
var
  Index                                 : integer;
  InsertPos                             : integer;
  StoredKey                             : string;
  FieldKey                              : string;
begin

  // For GridFields the mult unit is the 2-char field ("FN"), not the full
  // 4-char grid square ("FN20" or "FN25"). Truncate the query to 2 chars so
  // that any FN-prefixed grid in the store matches, regardless of whether the
  // stored key is the field ("FN", new format) or the full grid ("FN20", old
  // log records). GridSquares uses the full 4-char key and is unaffected.
  if aKeyedOnGridField then
     begin
     FieldKey := Copy(Dom, 1, 2);
     Result := not DomList.StringIsDupe(FieldKey, Band, Mode, Index);
     if Index = -1 then
        begin
        // Exact 2-char field not found — store may have full-grid keys.
        // FindMult returns the insertion point, which lands at the first
        // stored entry whose prefix matches FieldKey (e.g. "FN20").
        DomList.FindMult(FieldKey, InsertPos);
        if InsertPos < DomList.Count then
           begin
           StoredKey := DomList.Get(InsertPos);
           if Copy(StoredKey, 1, 2) = FieldKey then
              begin
              Result := not DomList.StringIsDupeByIndex(InsertPos, Band, Mode);
              Exit;
              end;
           end;
        Result := True;
        end;
     Exit;
     end;

  Result := not DomList.StringIsDupe(Dom, Band, Mode, Index);
  if Index = -1 then
     begin
     Result := True;
     end;

end;

procedure MultsObject.FillRemMultsBytes(rm: RemainingMultiplierType);
begin

end;

procedure MultsObject.FillVisibleBytes(aContest: TContestBase);
label
  1;
var
  i                                     : integer;
  (* Asked once, not per country: a station test can allocate. *)
  countsDX                              : boolean;
begin
  countsDX := ContestHasDXMultiplier(aContest);
  for i := 0 to MaxCountries - 1 do
     begin
     if CTY.ctyCountryMode = ARRLCountryMode then
       if CTY.ctyTable[i].ID[1] = '*' then
          begin
          1:
          CTY.ctyTable[i].VisibleInRM := 0;
          Continue;
          end;

     if not countsDX then
        begin
        goto 1;
        end;

     (* THE CONTEST'S FILTER -- M11 S4, 2026-10-14. Three tests on the
       session's DX kind stood here: CQNonEuropeanCountries (no contest ran
       it since M11 S2), CQEuropeanCountries (WAE, for an entrant outside
       Europe) and CQUBAEuropeanCountries (UBA, outside Belgium). The contest
       answers now, reproducing exactly those -- not its whole DX rule, which
       this window never knew (plan F7). *)
     if not ContestListsRemainingDXCountry(aContest, CTY.ctyTable[i].ID,
                                           CTY.ctyTable[i].DefaultContinent) then
        begin
        Continue;
        end;

     if CTY.ctyCustomRemainingCountryListFound then Continue;

     if CTY.ctyTable[i].VisibleInRM <> 1 then
        begin
        CTY.ctyTable[i].VisibleInRM := 2;
        end;

     end;
end;

begin
  logger := TLogLogger.GetLogger('uMults');   // Issue #1034: own logger (was MainUnit.logger)
  mo.PrfList.Init;
  mo.DomList.Init;
//  mo.PrfList := TSortedStringList.Create;
//  mo.DomList := TSortedStringList.Create;
end.

