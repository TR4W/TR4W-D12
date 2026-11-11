unit uTestMults;
{$I ..\..\src\tr4w.inc}

{
  Tests for uMults multiplier add / check / count (Issue #1034,
  pre-migration roadmap item 3).

  Scope: the zone-multiplier path of TMultsObject, which is fully
  self-contained (fixed-size arrays inside the object, no cty.dat and no
  file backing). DX mults are deliberately NOT covered here because
  SetDXMult gates on CTY.ctyNumberCountries, i.e. it needs a loaded
  country database -- that belongs with the uCTYDAT lookup tests (#1033).

  IMPORTANT semantics (verified against uMults.pas): IsZnMult returns
  TRUE while the zone is still a NEEDED multiplier (its per-band bit is
  clear) and FALSE once SetZnMult has marked it worked. Bits are tracked
  per band and per mode, so working a zone on one band/mode leaves it
  still needed on the others.

  Counting: SetZnMult calls IncrementTotals, which bumps
  MTotals[Band,Mode,rmZone] plus the Both-mode and AllBands roll-ups.
  Tests read MTotals directly (a public field of the object).

  Conventions (docs/tr4w-migration-strategy.md): cast Word/enum to
  Integer before CheckEquals.

  Note: uMults + uSortedStringList were decoupled from MainUnit/TF as part of this
  issue so the multiplier logic links into the dependency-light test EXE.
  This suite also depends on the uCTYDAT/uCallSignRoutines decouple (#1033).
}

interface

uses
   uTR4WTestFramework;

type
   TMultsTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure FreshMults;   // init once + ClearAllMults for a clean slate

      procedure Test_FreshZoneIsNeeded;
      procedure Test_SetMarksZoneWorked;
      procedure Test_WorkedZoneStillNeededOnOtherBand;
      procedure Test_WorkedZoneStillNeededOnOtherMode;
      procedure Test_OtherZoneStillNeeded;
      procedure Test_OutOfRangeZone;
      procedure Test_ZoneCount;
      procedure Test_RemainingYearsEraseTheWorkedYearItself;
      procedure Test_RemainingYearsHiLightListsEveryYear;
      procedure Test_RemainingCQZonesEraseTheWorkedZone;
   end;

implementation

uses
   VC, uMults;

// Module-level instance, the suite's own (it shadows uMults.mo): created once,
// freed at finalization; ClearAllMults gives each test a clean slate (and is
// itself under test). A class since pointer audit P8 (2026-10-17) -- it was an
// old-style object held by value, its sorted lists Init'd here.
var
   mo: TMultsObject;

procedure TMultsTests.FreshMults;
begin
   if mo = nil then
      begin
      mo := TMultsObject.Create;
      end;
   mo.ClearAllMults;
end;

// ---------------------------------------------------------------------------
// A freshly-cleared zone reads as a NEEDED multiplier (True).
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_FreshZoneIsNeeded;
begin
   BeginTest('Test_FreshZoneIsNeeded');
   FreshMults;
   CheckTrue(mo.IsZnMult(5, Band20, CW), 'zone 5 needed on 20m CW after clear');
end;

// ---------------------------------------------------------------------------
// SetZnMult marks the zone worked on that band/mode -> IsZnMult now False.
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_SetMarksZoneWorked;
begin
   BeginTest('Test_SetMarksZoneWorked');
   FreshMults;
   mo.SetZnMult(5, Band20, CW);
   CheckFalse(mo.IsZnMult(5, Band20, CW), 'zone 5 no longer needed on 20m CW after SetZnMult');
end;

// ---------------------------------------------------------------------------
// Per-band tracking: working a zone on 20m leaves it needed on 40m.
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_WorkedZoneStillNeededOnOtherBand;
begin
   BeginTest('Test_WorkedZoneStillNeededOnOtherBand');
   FreshMults;
   mo.SetZnMult(5, Band20, CW);
   CheckTrue(mo.IsZnMult(5, Band40, CW), 'zone 5 still needed on 40m CW');
end;

// ---------------------------------------------------------------------------
// Per-mode tracking: working a zone on CW leaves it needed on Phone.
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_WorkedZoneStillNeededOnOtherMode;
begin
   BeginTest('Test_WorkedZoneStillNeededOnOtherMode');
   FreshMults;
   mo.SetZnMult(5, Band20, CW);
   CheckTrue(mo.IsZnMult(5, Band20, Phone), 'zone 5 still needed on 20m Phone');
end;

// ---------------------------------------------------------------------------
// A different zone is unaffected by working zone 5.
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_OtherZoneStillNeeded;
begin
   BeginTest('Test_OtherZoneStillNeeded');
   FreshMults;
   mo.SetZnMult(5, Band20, CW);
   CheckTrue(mo.IsZnMult(6, Band20, CW), 'zone 6 still needed on 20m CW');
end;

// ---------------------------------------------------------------------------
// Out-of-range zone (> ZoneMultArraySize): IsZnMult False, SetZnMult a no-op.
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_OutOfRangeZone;
begin
   BeginTest('Test_OutOfRangeZone');
   FreshMults;
   CheckFalse(mo.IsZnMult(9999, Band20, CW), 'out-of-range zone is not a mult');
   mo.SetZnMult(9999, Band20, CW);   // must not touch state / raise
   CheckTrue(mo.IsZnMult(5, Band20, CW), 'in-range zone unaffected by out-of-range set');
end;

// ---------------------------------------------------------------------------
// Count: three distinct zones worked on 20m CW -> MTotals reflects 3, with
// the Both-mode and AllBands roll-ups also at 3.
// ---------------------------------------------------------------------------
procedure TMultsTests.Test_ZoneCount;
begin
   BeginTest('Test_ZoneCount');
   FreshMults;
   mo.SetZnMult(3, Band20, CW);
   mo.SetZnMult(5, Band20, CW);
   mo.SetZnMult(7, Band20, CW);
   CheckEquals(3, Integer(mo.MTotals[Band20, CW, rmZone]),   '20m CW zone count');
   CheckEquals(3, Integer(mo.MTotals[Band20, Both, rmZone]), '20m Both-mode roll-up');
   CheckEquals(3, Integer(mo.MTotals[AllBands, CW, rmZone]), 'AllBands CW roll-up');
end;

function ListHas(const aList: TArray<integer>; aValue: integer): boolean;
var
   v: integer;
begin
   Result := False;
   for v in aList do
      begin
      if v = aValue then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* ISSUE 267: THE REMAINING-MULTS WINDOW, ZERO-BASED (European HF Championship,
   KVP -- the year licensed, 00..99, count 100). The window asked zone i and
   listed zone i - 1, so in erase mode a worked year 85 hid 84 and kept 85. *)
procedure TMultsTests.Test_RemainingYearsEraseTheWorkedYearItself;
var
   years: TArray<integer>;
begin
   BeginTest('Test_RemainingYearsEraseTheWorkedYearItself');
   FreshMults;
   mo.SetZnMult(85, Band20, CW);
   mo.SetZnMult(0, Band20, CW);
   years := mo.RemainingZoneIndices(100, True, False, Band20, CW);
   CheckFalse(ListHas(years, 85), 'worked year 85 is not remaining');
   CheckTrue(ListHas(years, 84), 'year 84 is still remaining');
   CheckTrue(ListHas(years, 86), 'year 86 is still remaining');
   CheckFalse(ListHas(years, 0), 'worked year 00 is not remaining');
   CheckTrue(ListHas(years, 1), 'year 01 is still remaining');
   CheckFalse(ListHas(years, 100), 'there is no year 100');
   CheckEquals(98, Length(years), 'one hundred years less the two worked');
   CheckEquals(99, years[High(years)], 'the last year is 99');
   years := mo.RemainingZoneIndices(100, True, False, Band40, CW);
   CheckTrue(ListHas(years, 85), 'year 85 is still needed on 40 m');
end;

(* HiLight mode lists every year, 00..99, worked or not -- the set the old
   walk produced too, so only erase mode moves. *)
procedure TMultsTests.Test_RemainingYearsHiLightListsEveryYear;
var
   years: TArray<integer>;
   i: integer;
begin
   BeginTest('Test_RemainingYearsHiLightListsEveryYear');
   FreshMults;
   mo.SetZnMult(85, Band20, CW);
   years := mo.RemainingZoneIndices(100, True, True, Band20, CW);
   CheckEquals(100, Length(years), 'one hundred years');
   for i := 0 to 99 do
      begin
      CheckEquals(i, years[i], 'year in order');
      end;
end;

(* A one-based count (CQ zones, 40): 1..40, the worked zone erased. *)
procedure TMultsTests.Test_RemainingCQZonesEraseTheWorkedZone;
var
   zones: TArray<integer>;
begin
   BeginTest('Test_RemainingCQZonesEraseTheWorkedZone');
   FreshMults;
   mo.SetZnMult(5, Band20, CW);
   zones := mo.RemainingZoneIndices(40, False, False, Band20, CW);
   CheckEquals(39, Length(zones), 'forty zones less the one worked');
   CheckEquals(1, zones[0], 'the first zone is 1');
   CheckEquals(40, zones[High(zones)], 'the last zone is 40');
   CheckFalse(ListHas(zones, 5), 'worked zone 5 is not remaining');
   CheckTrue(ListHas(zones, 4), 'zone 4 is still remaining');
   CheckFalse(ListHas(zones, 0), 'there is no CQ zone 0');
   zones := mo.RemainingZoneIndices(40, False, True, Band20, CW);
   CheckEquals(40, Length(zones), 'HiLight lists all forty');
   CheckEquals(0, Length(mo.RemainingZoneIndices(0, False, True, Band20, CW)),
               'no zone multiplier lists nothing');
end;

// ---------------------------------------------------------------------------
// Suite entry point
// ---------------------------------------------------------------------------
procedure TMultsTests.RunAllTests;
begin
   Test_FreshZoneIsNeeded;
   Test_SetMarksZoneWorked;
   Test_WorkedZoneStillNeededOnOtherBand;
   Test_WorkedZoneStillNeededOnOtherMode;
   Test_OtherZoneStillNeeded;
   Test_OutOfRangeZone;
   Test_ZoneCount;
   Test_RemainingYearsEraseTheWorkedYearItself;
   Test_RemainingYearsHiLightListsEveryYear;
   Test_RemainingCQZonesEraseTheWorkedZone;
end;

finalization
   mo.Free;
   mo := nil;

end.
