unit uTestSpotStore;
{$I ..\..\src\tr4w.inc}

(* THE SPOT STORE -- uSpots.SpotsList -- PINNED BEFORE ITS CONVERSION.

  Written against the old-style `object` TDXSpotsList and required to pass
  UNCHANGED against the `class` that replaces it (pointer audit packet P8, part
  B). Everything below goes through the global SpotsList and its public
  methods only, so it does not know which of the two it is talking to.

  WHAT IS PINNED, including the parts that look odd:

    * the store is ordered by FREQUENCY and nothing else;
    * a spot on a frequency the store already holds REPLACES that entry, whatever
      its callsign -- FindSpot keys on frequency alone. The same call on a
      different frequency is a second entry;
    * a spot's age is whole seconds since it ARRIVED (FSysTime), and BAND MAP
      DECAY TIME is in MINUTES compared in SECONDS;
    * Get() of an index outside the store returns an all-zero record;
    * the store grows from a capacity of 4 (Init calls Grow once), so 600 spots
      cross the growth boundary many times.

  WHAT IS NOT: BuildVisibleSpots (it asks VisibleLog about multipliers),
  DisplayCallsignOnThisFreq and TuneDupeCheck (they drive the call window) --
  those need a running program and are on docs/BENCH_QUEUE.md. *)

interface

uses
   SysUtils, DateUtils, uTR4WTestFramework, VC, uSettingsModel, uSpotAge, uSpots;

type
   TSpotStoreTests = class(TTestCase)
   private
      procedure Empty;
      function  Put(aFreq: integer; const aCall: string; aBand: BandType): integer;
      function  PutAged(aFreq: integer; const aCall: string; aAgeSeconds: integer): integer;
   protected
      procedure Test_StartsEmptyAndGetOutsideIsZero;
      procedure Test_AddKeepsFrequencyOrder;
      procedure Test_SameFrequencyReplaces;
      procedure Test_SameCallOnAnotherFrequencyIsASecondEntry;
      procedure Test_FindSpotFoundAndInsertionPoint;
      procedure Test_IndexOfSpotNeedsFrequencyAndCall;
      procedure Test_WarcBandsAreFlagged;
      procedure Test_GetReturnsACopy;
      procedure Test_DeleteMiddleFirstLastAndOutOfRange;
      procedure Test_ClearEmptiesAndStoreIsReusable;
      procedure Test_GrowthAcrossCapacityKeepsEveryRecord;
      procedure Test_AgeIsSecondsSinceArrival;
      procedure Test_DecayIsMinutesComparedInSeconds;
      procedure Test_SpotsInOneClockMinuteExpireSeparately;
      procedure Test_ExpiredRunsAreRemoved;
      procedure Test_EverythingExpiredEmptiesTheStore;
      procedure Test_DecrementOnEmptyStoreIsHarmless;
      procedure Test_ResetTimesAndDupes;
      procedure Test_UpdateDupeStatusMatchesCallBandMode;
      procedure Test_MutatorsRaiseTheRepaintToken;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   BASE_FREQ = 14000000;

procedure TSpotStoreTests.Empty;
begin
   SpotsList.Clear;
end;

function TSpotStoreTests.Put(aFreq: integer; const aCall: string;
                             aBand: BandType): integer;
var
   spot: TSpotRecord;
begin
   spot := Default(TSpotRecord);
   spot.FFrequency := aFreq;
   spot.FCall := ShortString(aCall);
   spot.FBand := aBand;
   spot.FMode := CW;
   spot.FSysTime := UTCNow;
   Result := SpotsList.AddSpot(spot, False);
end;

function TSpotStoreTests.PutAged(aFreq: integer; const aCall: string;
                                 aAgeSeconds: integer): integer;
var
   spot: TSpotRecord;
begin
   spot := Default(TSpotRecord);
   spot.FFrequency := aFreq;
   spot.FCall := ShortString(aCall);
   spot.FBand := Band20;
   spot.FMode := CW;
   spot.FSysTime := IncSecond(UTCNow, -aAgeSeconds);
   Result := SpotsList.AddSpot(spot, False);
end;

procedure TSpotStoreTests.Test_StartsEmptyAndGetOutsideIsZero;
var
   spot: TSpotRecord;
begin
   BeginTest('an emptied store has no spots, and Get outside it is all zero');
   Empty;
   CheckEquals(0, SpotsList.Count, 'count after Clear');
   spot := SpotsList.Get(0);
   CheckEquals(0, spot.FFrequency, 'Get(0) of an empty store: frequency');
   CheckEquals('', string(spot.FCall), 'Get(0) of an empty store: call');
   spot := SpotsList.Get(-1);
   CheckEquals(0, spot.FFrequency, 'Get(-1)');
   Put(BASE_FREQ, 'K1AAA', Band20);
   spot := SpotsList.Get(1);
   CheckEquals(0, spot.FFrequency, 'Get(Count) is outside, so zero');
   Empty;
end;

procedure TSpotStoreTests.Test_AddKeepsFrequencyOrder;
begin
   BeginTest('spots are held in frequency order whatever order they arrive in');
   Empty;
   Put(BASE_FREQ + 250, 'K1CCC', Band20);
   Put(BASE_FREQ + 10,  'K1AAA', Band20);
   Put(BASE_FREQ + 100, 'K1BBB', Band20);
   Put(BASE_FREQ - 7000000, 'K1DDD', Band40);
   CheckEquals(4, SpotsList.Count, 'four distinct frequencies');
   CheckEquals(BASE_FREQ - 7000000, SpotsList.Get(0).FFrequency, 'lowest first');
   CheckEquals('K1DDD', string(SpotsList.Get(0).FCall), 'lowest first: call');
   CheckEquals('K1AAA', string(SpotsList.Get(1).FCall), 'second');
   CheckEquals('K1BBB', string(SpotsList.Get(2).FCall), 'third');
   CheckEquals('K1CCC', string(SpotsList.Get(3).FCall), 'highest last');
   Empty;
end;

procedure TSpotStoreTests.Test_SameFrequencyReplaces;
begin
   BeginTest('a second spot on the same frequency replaces the first');
   Empty;
   Put(BASE_FREQ, 'K1AAA', Band20);
   Put(BASE_FREQ, 'K1BBB', Band20);
   CheckEquals(1, SpotsList.Count, 'one entry, not two');
   CheckEquals('K1BBB', string(SpotsList.Get(0).FCall), 'the later spot wins');
   Put(BASE_FREQ, 'K1BBB', Band20);
   CheckEquals(1, SpotsList.Count, 'the same call again is still one entry');
   Empty;
end;

procedure TSpotStoreTests.Test_SameCallOnAnotherFrequencyIsASecondEntry;
begin
   BeginTest('the same call on two frequencies is two entries');
   Empty;
   Put(BASE_FREQ,       'K1AAA', Band20);
   Put(BASE_FREQ + 500, 'K1AAA', Band20);
   CheckEquals(2, SpotsList.Count, 'frequency, not call, is the key');
   Empty;
end;

procedure TSpotStoreTests.Test_FindSpotFoundAndInsertionPoint;
var
   probe: TSpotRecord;
   idx: integer;
begin
   BeginTest('FindSpot reports a hit, or where the spot would go');
   Empty;
   Put(BASE_FREQ + 100, 'K1AAA', Band20);
   Put(BASE_FREQ + 300, 'K1BBB', Band20);
   Put(BASE_FREQ + 500, 'K1CCC', Band20);
   probe := Default(TSpotRecord);
   probe.FFrequency := BASE_FREQ + 300;
   CheckTrue(SpotsList.FindSpot(probe, idx), 'present frequency is found');
   CheckEquals(1, idx, 'and at its index');
   probe.FFrequency := BASE_FREQ + 400;
   CheckFalse(SpotsList.FindSpot(probe, idx), 'absent frequency is not found');
   CheckEquals(2, idx, 'insertion point is the first higher entry');
   probe.FFrequency := BASE_FREQ;
   CheckFalse(SpotsList.FindSpot(probe, idx), 'below everything');
   CheckEquals(0, idx, 'goes first');
   probe.FFrequency := BASE_FREQ + 900;
   CheckFalse(SpotsList.FindSpot(probe, idx), 'above everything');
   CheckEquals(3, idx, 'goes last');
   Empty;
end;

procedure TSpotStoreTests.Test_IndexOfSpotNeedsFrequencyAndCall;
var
   probe: TSpotRecord;
begin
   BeginTest('IndexOfSpot finds by frequency AND callsign');
   Empty;
   Put(BASE_FREQ + 100, 'K1AAA', Band20);
   Put(BASE_FREQ + 300, 'K1BBB', Band20);
   probe := Default(TSpotRecord);
   probe.FFrequency := BASE_FREQ + 300;
   probe.FCall := 'K1BBB';
   CheckEquals(1, SpotsList.IndexOfSpot(probe), 'both match');
   probe.FCall := 'K1AAA';
   CheckEquals(-1, SpotsList.IndexOfSpot(probe), 'right frequency, wrong call');
   probe.FFrequency := BASE_FREQ + 100;
   CheckEquals(0, SpotsList.IndexOfSpot(probe), 'now the pair matches entry 0');
   probe.FFrequency := BASE_FREQ + 999;
   CheckEquals(-1, SpotsList.IndexOfSpot(probe), 'unknown frequency');
   Empty;
   CheckEquals(-1, SpotsList.IndexOfSpot(probe), 'empty store');
end;

procedure TSpotStoreTests.Test_WarcBandsAreFlagged;
begin
   BeginTest('30, 17 and 12 metre spots are marked WARC on the way in');
   Empty;
   Put(10100000, 'K1WARC', Band30);
   Put(18100000, 'K1SEVT', Band17);
   Put(24900000, 'K1TWLV', Band12);
   Put(14025000, 'K1TWEN', Band20);
   CheckEquals(4, SpotsList.Count, 'all four stored');
   (* frequency order: 10.100 (30m), 14.025 (20m), 18.100 (17m), 24.900 (12m) *)
   CheckTrue(SpotsList.Get(0).FWARCBand,  '30m');
   CheckFalse(SpotsList.Get(1).FWARCBand, '20m is not WARC');
   CheckTrue(SpotsList.Get(2).FWARCBand,  '17m');
   CheckTrue(SpotsList.Get(3).FWARCBand,  '12m');
   Empty;
end;

procedure TSpotStoreTests.Test_GetReturnsACopy;
var
   copy_: TSpotRecord;
begin
   BeginTest('Get hands back a copy; editing it leaves the store alone');
   Empty;
   Put(BASE_FREQ, 'K1AAA', Band20);
   copy_ := SpotsList.Get(0);
   copy_.FCall := 'CHANGED';
   copy_.FDupe := True;
   CheckEquals('K1AAA', string(SpotsList.Get(0).FCall), 'call untouched');
   CheckFalse(SpotsList.Get(0).FDupe, 'dupe flag untouched');
   Empty;
end;

procedure TSpotStoreTests.Test_DeleteMiddleFirstLastAndOutOfRange;
begin
   BeginTest('Delete closes the gap, and ignores an index outside the store');
   Empty;
   Put(BASE_FREQ + 100, 'K1AAA', Band20);
   Put(BASE_FREQ + 200, 'K1BBB', Band20);
   Put(BASE_FREQ + 300, 'K1CCC', Band20);
   Put(BASE_FREQ + 400, 'K1DDD', Band20);
   SpotsList.Delete(1);
   CheckEquals(3, SpotsList.Count, 'after deleting the middle');
   CheckEquals('K1CCC', string(SpotsList.Get(1).FCall), 'later entries moved down');
   SpotsList.Delete(0);
   CheckEquals('K1CCC', string(SpotsList.Get(0).FCall), 'after deleting the first');
   SpotsList.Delete(SpotsList.Count - 1);
   CheckEquals(1, SpotsList.Count, 'after deleting the last');
   CheckEquals('K1CCC', string(SpotsList.Get(0).FCall), 'the survivor');
   SpotsList.Delete(-1);
   SpotsList.Delete(5);
   CheckEquals(1, SpotsList.Count, 'out-of-range deletes change nothing');
   SpotsList.Delete(0);
   CheckEquals(0, SpotsList.Count, 'and the store can be deleted down to empty');
   Empty;
end;

procedure TSpotStoreTests.Test_ClearEmptiesAndStoreIsReusable;
begin
   BeginTest('Clear empties the store and it accepts spots afterwards');
   Empty;
   Put(BASE_FREQ + 100, 'K1AAA', Band20);
   Put(BASE_FREQ + 200, 'K1BBB', Band20);
   SpotsList.Clear;
   CheckEquals(0, SpotsList.Count, 'cleared');
   SpotsList.Clear;
   CheckEquals(0, SpotsList.Count, 'clearing an empty store is harmless');
   Put(BASE_FREQ + 300, 'K1CCC', Band20);
   CheckEquals(1, SpotsList.Count, 'reusable');
   CheckEquals('K1CCC', string(SpotsList.Get(0).FCall), 'and holds the new spot');
   Empty;
end;

procedure TSpotStoreTests.Test_GrowthAcrossCapacityKeepsEveryRecord;
const
   N = 600;
var
   i: integer;
   f: integer;
begin
   BeginTest('600 spots in scrambled order survive every growth step intact');
   Empty;
   (* 7919 is prime and does not divide 600, so i * 7919 mod 600 visits every
     slot once: distinct frequencies, arriving in no useful order. *)
   for i := 0 to N - 1 do
      begin
      f := (i * 7919) mod N;
      Put(BASE_FREQ + f * 10, 'F' + IntToStr(f), Band20);
      end;
   CheckEquals(N, SpotsList.Count, 'all stored');
   for i := 0 to N - 1 do
      begin
      if (SpotsList.Get(i).FFrequency <> BASE_FREQ + i * 10) or
         (string(SpotsList.Get(i).FCall) <> 'F' + IntToStr(i)) then
         begin
         Check(False, 'record ' + IntToStr(i) + ' is out of place or damaged');
         Break;
         end;
      end;
   Empty;
end;

procedure TSpotStoreTests.Test_AgeIsSecondsSinceArrival;
var
   was: integer;
   age: integer;
begin
   BeginTest('DecrementSpotsTimes stamps FAgeSeconds as elapsed seconds');
   was := Settings.BandMap.DecayTime;
   try
      Settings.BandMap.DecayTime := 60;
      Empty;
      PutAged(BASE_FREQ, 'K1AAA', 90);
      SpotsList.DecrementSpotsTimes;
      CheckEquals(1, SpotsList.Count, 'a 90 s old spot survives an hour limit');
      age := SpotsList.Get(0).FAgeSeconds;
      Check((age >= 89) and (age <= 95), 'age is about 90 seconds, got ' + IntToStr(age));
   finally
      Settings.BandMap.DecayTime := was;
      Empty;
   end;
end;

procedure TSpotStoreTests.Test_DecayIsMinutesComparedInSeconds;
var
   was: integer;
begin
   BeginTest('BAND MAP DECAY TIME is minutes: 2 keeps 100 s and drops 140 s');
   was := Settings.BandMap.DecayTime;
   try
      Settings.BandMap.DecayTime := 2;
      Empty;
      PutAged(BASE_FREQ + 100, 'K1OLD', 140);
      PutAged(BASE_FREQ + 200, 'K1NEW', 100);
      SpotsList.DecrementSpotsTimes;
      CheckEquals(1, SpotsList.Count, 'one expired');
      CheckEquals('K1NEW', string(SpotsList.Get(0).FCall), 'the younger one stayed');
   finally
      Settings.BandMap.DecayTime := was;
      Empty;
   end;
end;

procedure TSpotStoreTests.Test_SpotsInOneClockMinuteExpireSeparately;
var
   was: integer;
begin
   BeginTest('two spots seconds apart do not expire on the same tick');
   was := Settings.BandMap.DecayTime;
   try
      (* THE ORIGINAL DEFECT: the cluster line carries HHMM, so every spot in a
        minute shared a stamp and the whole map emptied at once. *)
      Settings.BandMap.DecayTime := 1;
      Empty;
      PutAged(BASE_FREQ + 100, 'K1EARLY', 70);
      PutAged(BASE_FREQ + 200, 'K1LATE', 12);
      SpotsList.DecrementSpotsTimes;
      CheckEquals(1, SpotsList.Count, 'only the older spot is gone');
      CheckEquals('K1LATE', string(SpotsList.Get(0).FCall), 'the newer survives');
   finally
      Settings.BandMap.DecayTime := was;
      Empty;
   end;
end;

procedure TSpotStoreTests.Test_ExpiredRunsAreRemoved;
var
   was: integer;
begin
   BeginTest('expired spots at the head, middle and tail are all removed');
   was := Settings.BandMap.DecayTime;
   try
      Settings.BandMap.DecayTime := 1;
      Empty;
      PutAged(BASE_FREQ + 100, 'OLD1', 600);
      PutAged(BASE_FREQ + 200, 'OLD2', 600);
      PutAged(BASE_FREQ + 300, 'KEEP', 5);
      PutAged(BASE_FREQ + 400, 'OLD3', 600);
      PutAged(BASE_FREQ + 500, 'OLD4', 600);
      SpotsList.DecrementSpotsTimes;
      CheckEquals(1, SpotsList.Count, 'only the fresh spot is left');
      CheckEquals('KEEP', string(SpotsList.Get(0).FCall), 'and it is the right one');
   finally
      Settings.BandMap.DecayTime := was;
      Empty;
   end;
end;

procedure TSpotStoreTests.Test_EverythingExpiredEmptiesTheStore;
var
   was: integer;
begin
   BeginTest('a store of nothing but expired spots ends up empty');
   was := Settings.BandMap.DecayTime;
   try
      Settings.BandMap.DecayTime := 1;
      Empty;
      PutAged(BASE_FREQ + 100, 'OLD1', 600);
      PutAged(BASE_FREQ + 200, 'OLD2', 600);
      PutAged(BASE_FREQ + 300, 'OLD3', 600);
      SpotsList.DecrementSpotsTimes;
      CheckEquals(0, SpotsList.Count, 'all gone');
      SpotsList.DecrementSpotsTimes;
      CheckEquals(0, SpotsList.Count, 'and a second pass is harmless');
   finally
      Settings.BandMap.DecayTime := was;
      Empty;
   end;
end;

procedure TSpotStoreTests.Test_DecrementOnEmptyStoreIsHarmless;
begin
   BeginTest('ageing an empty store does nothing');
   Empty;
   SpotsList.DecrementSpotsTimes;
   CheckEquals(0, SpotsList.Count, 'still empty');
end;

procedure TSpotStoreTests.Test_ResetTimesAndDupes;
var
   spot: TSpotRecord;
begin
   BeginTest('ResetSpotsTimes zeroes every age; ResetSpotsDupes clears every dupe');
   Empty;
   spot := Default(TSpotRecord);
   spot.FFrequency := BASE_FREQ;
   spot.FCall := 'K1AAA';
   spot.FBand := Band20;
   spot.FMode := CW;
   spot.FSysTime := UTCNow;
   spot.FAgeSeconds := 77;
   spot.FDupe := True;
   SpotsList.AddSpot(spot, False);
   CheckEquals(77, SpotsList.Get(0).FAgeSeconds, 'age stored as given');
   SpotsList.ResetSpotsTimes;
   CheckEquals(0, SpotsList.Get(0).FAgeSeconds, 'age reset');
   CheckTrue(SpotsList.Get(0).FDupe, 'dupe still set');
   SpotsList.ResetSpotsDupes;
   CheckFalse(SpotsList.Get(0).FDupe, 'dupe cleared');
   Empty;
end;

procedure TSpotStoreTests.Test_UpdateDupeStatusMatchesCallBandMode;
begin
   BeginTest('a worked QSO marks only the spot with the same call, band and mode');
   Empty;
   Put(BASE_FREQ + 100,  'K1AAA', Band20);
   Put(BASE_FREQ + 200,  'K1BBB', Band20);
   Put(7010000,          'K1AAA', Band40);
   SpotsList.UpdateSpotsDupeStatus('K1AAA', Band20, CW);
   CheckTrue(SpotsList.Get(1).FDupe,  'K1AAA on 20m CW');
   CheckFalse(SpotsList.Get(2).FDupe, 'K1BBB is a different call');
   CheckFalse(SpotsList.Get(0).FDupe, 'K1AAA on 40m is a different band');
   SpotsList.UpdateSpotsDupeStatus('K1BBB', Band20, Phone);
   CheckFalse(SpotsList.Get(2).FDupe, 'a different mode does not match');
   Empty;
end;

procedure TSpotStoreTests.Test_MutatorsRaiseTheRepaintToken;
var
   token: cardinal;
   spot: TSpotRecord;
begin
   BeginTest('every mutator moves the repaint token; MarkPainted settles it');
   Empty;
   SpotsList.MarkPainted;
   CheckFalse(SpotsList.NeedsRepaint, 'settled');
   Put(BASE_FREQ, 'K1AAA', Band20);
   CheckTrue(SpotsList.NeedsRepaint, 'AddSpot');
   SpotsList.MarkPainted;
   CheckFalse(SpotsList.NeedsRepaint, 'painted again');
   token := SpotsList.RepaintToken;
   SpotsList.Delete(0);
   Check(SpotsList.RepaintToken <> token, 'Delete');
   token := SpotsList.RepaintToken;
   SpotsList.Clear;
   Check(SpotsList.RepaintToken <> token, 'Clear');
   token := SpotsList.RepaintToken;
   SpotsList.RequestRepaint;
   Check(SpotsList.RepaintToken <> token, 'RequestRepaint');
   spot := Default(TSpotRecord);
   spot.FFrequency := BASE_FREQ;
   spot.FCall := 'K1AAA';
   spot.FBand := Band20;
   spot.FMode := CW;
   spot.FSysTime := UTCNow;
   SpotsList.AddSpot(spot, False);
   token := SpotsList.RepaintToken;
   SpotsList.ResetSpotsDupes;
   Check(SpotsList.RepaintToken <> token, 'ResetSpotsDupes');
   token := SpotsList.RepaintToken;
   SpotsList.ResetSpotsTimes;
   Check(SpotsList.RepaintToken <> token, 'ResetSpotsTimes');
   token := SpotsList.RepaintToken;
   SpotsList.UpdateSpotsDupeStatus('K1AAA', Band20, CW);
   Check(SpotsList.RepaintToken <> token, 'UpdateSpotsDupeStatus');
   Empty;
end;

procedure TSpotStoreTests.RunAllTests;
var
   so2r: boolean;
   ie: boolean;
begin
   (* AddSpot refuses a spot when SO2R display or the initial-exchange switch
     say so. Both are off by default; make sure, and put them back after. *)
   so2r := Settings.BandMap.So2rDisplay;
   ie := Settings.Operating.IeSwitch;
   try
      if so2r then
         begin
         Settings.BandMap.So2rDisplay := False;
         end;
      if ie then
         begin
         Settings.Operating.IeSwitch := False;
         end;

      Test_StartsEmptyAndGetOutsideIsZero;
      Test_AddKeepsFrequencyOrder;
      Test_SameFrequencyReplaces;
      Test_SameCallOnAnotherFrequencyIsASecondEntry;
      Test_FindSpotFoundAndInsertionPoint;
      Test_IndexOfSpotNeedsFrequencyAndCall;
      Test_WarcBandsAreFlagged;
      Test_GetReturnsACopy;
      Test_DeleteMiddleFirstLastAndOutOfRange;
      Test_ClearEmptiesAndStoreIsReusable;
      Test_GrowthAcrossCapacityKeepsEveryRecord;
      Test_AgeIsSecondsSinceArrival;
      Test_DecayIsMinutesComparedInSeconds;
      Test_SpotsInOneClockMinuteExpireSeparately;
      Test_ExpiredRunsAreRemoved;
      Test_EverythingExpiredEmptiesTheStore;
      Test_DecrementOnEmptyStoreIsHarmless;
      Test_ResetTimesAndDupes;
      Test_UpdateDupeStatusMatchesCallBandMode;
      Test_MutatorsRaiseTheRepaintToken;
   finally
      Empty;
      if so2r then
         begin
         Settings.BandMap.So2rDisplay := True;
         end;
      if ie then
         begin
         Settings.Operating.IeSwitch := True;
         end;
   end;
end;

end.
