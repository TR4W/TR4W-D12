unit uTestZoneEntryRefusal;
{$I ..\..\src\tr4w.inc}

(* ISSUE 267: A REFUSED RST-AND-ZONE ENTRY LEAVES THE ZONE AS IT FOUND IT.

   LOGSTUFF.ProcessRSTAndZoneExchange wrote RXData.Zone from the two digits
   typed and only then refused a CQ zone above 40, so a refused '599 85' still
   carried zone 85 (D7 did the same). The European HF Championship and KVP send
   the year licensed there, 00..99, and are accepted only because FoundContest
   sets ITU zone mode for them.

   Driven directly, with the CTY zone mode and the active mode set and restored
   here: the zone is pre-set to a sentinel, so "untouched" is visible. RST is
   not asserted -- it is written before a refusal too, which is not this
   issue. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TZoneEntryRefusalTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Entry(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                      aExpectAccepted: boolean; aExpectZone: integer);
      procedure Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone;
      procedure Test_CQZoneModeAcceptsAZoneAndSetsIt;
      procedure Test_ITUZoneModeAcceptsAYearAndSetsIt;
      procedure Test_CQZoneModeRefusesEveryZoneAboveForty;
      procedure Test_CQZoneModeAcceptsOneToForty;
      procedure Test_ITUZoneModeAcceptsFiftyToFiftyNine;
   end;

implementation

uses
   SysUtils,
   uCTYDAT,
   LogWind,
   LOGSTUFF;

const
   SENTINEL_ZONE = 7;

procedure TZoneEntryRefusalTests.Entry(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; aExpectAccepted: boolean; aExpectZone: integer);
var
   rx: ContestExchange;
   savedMode: ModeType;
   savedZoneMode: ZoneModeType;
   accepted: boolean;
   what: string;
begin
   what := '"' + aText + '" ' + IntToStr(Ord(aMode)) + '/' + IntToStr(Ord(aZoneMode));
   savedMode := ActiveMode;
   savedZoneMode := CTY.ctyZoneMode;
   try
      ActiveMode := aMode;
      CTY.ctyZoneMode := aZoneMode;
      rx := Default(ContestExchange);
      rx.Zone := SENTINEL_ZONE;
      accepted := ProcessRSTAndZoneExchange(ShortString(aText), rx);
      if aExpectAccepted then
         begin
         CheckTrue(accepted, what + ' is accepted');
         end
      else
         begin
         CheckFalse(accepted, what + ' is refused');
         end;
      CheckEquals(aExpectZone, Integer(rx.Zone), what + ' zone');
   finally
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      end;
end;

procedure TZoneEntryRefusalTests.Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone;
begin
   BeginTest('Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone');
   Entry('85', CW, CQZoneMode, False, SENTINEL_ZONE);
   Entry('599 85', CW, CQZoneMode, False, SENTINEL_ZONE);
   Entry('599 41', CW, CQZoneMode, False, SENTINEL_ZONE);
   Entry('59 85', Phone, CQZoneMode, False, SENTINEL_ZONE);
   Entry('59 41', Phone, CQZoneMode, False, SENTINEL_ZONE);
end;

(* THERE ARE 40 CQ ZONES (NY4I, issue 267, 2026-11-10): 41..99 is refused,
   50..59 included -- the check compared the first digit with '5' and let them
   through (D7 did the same). Bare, after a CW RST and after a Phone RS. *)
procedure TZoneEntryRefusalTests.Test_CQZoneModeRefusesEveryZoneAboveForty;
const
   ABOVE: array[0..6] of string = ('41', '45', '50', '55', '59', '60', '99');
var
   z: string;
begin
   BeginTest('Test_CQZoneModeRefusesEveryZoneAboveForty');
   for z in ABOVE do
      begin
      Entry(z, CW, CQZoneMode, False, SENTINEL_ZONE);
      Entry('599 ' + z, CW, CQZoneMode, False, SENTINEL_ZONE);
      Entry('59 ' + z, Phone, CQZoneMode, False, SENTINEL_ZONE);
      Entry(z, Phone, CQZoneMode, False, SENTINEL_ZONE);
      end;
end;

(* 01..40 is accepted in CQ mode, every one of them. *)
procedure TZoneEntryRefusalTests.Test_CQZoneModeAcceptsOneToForty;
var
   zone: integer;
   z: string;
begin
   BeginTest('Test_CQZoneModeAcceptsOneToForty');
   for zone := 1 to 40 do
      begin
      z := IntToStr(zone);
      if zone < 10 then
         begin
         z := '0' + z;
         end;
      Entry(z, CW, CQZoneMode, True, zone);
      Entry('599 ' + z, CW, CQZoneMode, True, zone);
      Entry('59 ' + z, Phone, CQZoneMode, True, zone);
      end;
end;

(* ITU zone mode is unchanged: 50..59 and 99 are accepted. *)
procedure TZoneEntryRefusalTests.Test_ITUZoneModeAcceptsFiftyToFiftyNine;
begin
   BeginTest('Test_ITUZoneModeAcceptsFiftyToFiftyNine');
   Entry('50', CW, ITUZoneMode, True, 50);
   Entry('599 55', CW, ITUZoneMode, True, 55);
   Entry('59 59', Phone, ITUZoneMode, True, 59);
   Entry('75', CW, ITUZoneMode, True, 75);
end;

procedure TZoneEntryRefusalTests.Test_CQZoneModeAcceptsAZoneAndSetsIt;
begin
   BeginTest('Test_CQZoneModeAcceptsAZoneAndSetsIt');
   Entry('40', CW, CQZoneMode, True, 40);
   Entry('599 05', CW, CQZoneMode, True, 5);
   Entry('5', CW, CQZoneMode, True, 5);
   Entry('59 14', Phone, CQZoneMode, True, 14);
end;

procedure TZoneEntryRefusalTests.Test_ITUZoneModeAcceptsAYearAndSetsIt;
begin
   BeginTest('Test_ITUZoneModeAcceptsAYearAndSetsIt');
   Entry('85', CW, ITUZoneMode, True, 85);
   Entry('599 85', CW, ITUZoneMode, True, 85);
   Entry('59 85', Phone, ITUZoneMode, True, 85);
   Entry('00', CW, ITUZoneMode, True, 0);
   Entry('599 99', CW, ITUZoneMode, True, 99);
end;

procedure TZoneEntryRefusalTests.RunAllTests;
begin
   Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone;
   Test_CQZoneModeAcceptsAZoneAndSetsIt;
   Test_ITUZoneModeAcceptsAYearAndSetsIt;
   Test_CQZoneModeRefusesEveryZoneAboveForty;
   Test_CQZoneModeAcceptsOneToForty;
   Test_ITUZoneModeAcceptsFiftyToFiftyNine;
end;

end.
