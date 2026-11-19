(* A SECOND DOMESTIC MULTIPLIER KEY PER QSO -- issue #317 (NY4I approved the
   work 2026-11-13).

   An in-state entrant's host-county QSO earns the county AND the host state
   in Alabama, West Virginia, Kentucky, Iowa (issue 120), South Carolina
   (issue 111), Illinois (issue 119) and Vermont. The state is a second
   key on the DOMESTIC sheet (TContestBase.AdditionalDomesticMultiplierKey,
   asked by LOGDUPE.AddQSOToSheets through
   AdditionalDomesticMultiplierCredited). Nothing is stored, so what this
   file pins is what the sheet re-derives:

     - every other registered contest answers False (Florida, Arkansas and
       New Jersey named), so their sheets cannot move;
     - the in-state lists: KY 184, AL 130, WV 118, VT 77 (VT's key is the
       Vt S50.DOM already gives the file);
     - the table rule the helper relies on: every in-state key longer than
       two characters is a county of the party's county file;
     - THE EQUAL-SCOPE INVARIANT: the host key is worked in a scope exactly
       when a county is (Vermont: a county implies the state, since a
       station may also send VT itself);
     - a load that trusts the stored flags (a MODEL of LoadinLog: the stored
       records walked through AddQSOToSheets, which is all LoadinLog does to
       the sheet) and a rescore (RecomputeQSOScoring then AddQSOToSheets),
       run twice, give the live sheet's totals. The unit binary boots no log,
       so the real LoadinLog / tUpdateLog are the matrix's and corpus's.

   ISSUE #318 (NY4I: option 2) -- ONE QSO'S COUNT. The per-QSO readers (UDP
   <ismultiplierN>, the hourly report's Mults column) add LOGDUPE's answer for
   the second key to StoredMultiplierFlagCount: live, asked of `mo` before the
   QSO is added (AdditionalDomesticMultipliersBeforeSheet); over the log, a
   TAdditionalDomesticMultiplierReplay. Pinned here: the per-QSO counts of
   a session add up to the sheet's totals, the live answer equals the replay
   for every QSO, each state's own scope QSO by QSO, the UDP XML, and a
   party with no second key (Arkansas) unchanged. *)
unit uTestAdditionalDomesticMultiplier;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework,
   VC;   (* ContestExchange -- CheckPerQSOCounts' parameter *)

type
   TAdditionalDomesticMultiplierTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryOtherContestAnswersFalse;
      procedure Test_InStateListsHoldTheHostKey;
      procedure Test_LongKeysAreCounties;
      procedure Test_KentuckyCountyEarnsKY;
      procedure Test_VermontCountyEarnsTheExistingVT;
      procedure Test_EqualScopeInvariant;
      procedure Test_LoadAndRescoreAgreeWithLive;
      procedure Test_PerQSOCountsAddUpToTheSheet;
      procedure Test_PerQSOCountsFollowEachStatesScope;
      procedure Test_UDPShowsTheSecondKey;
      procedure Test_NoSecondKeyPartyIsUnchanged;
      procedure CheckPerQSOCounts(const aWhat: string;
                                  const aLogged: TArray<ContestExchange>;
                                  const aExpected: array of integer);
   end;

implementation

uses
   Classes, SysUtils, uContestBase, uContestRegistry,
   uContestAlabamaQP, uContestWestVirginiaQP, uContestKentuckyQP,
   uContestVermontQP, uContestArkansasQP, uContestNewJerseyQP, uContestIowaQP,
   uContestSouthCarolinaQP, uContestIllinoisQP,
   uTestContestObjects, uTestRegisteredContests, uTestQSOPartyEngine,
   uDomFileKeys, uMults, LogDupe, LogStuff, MainUnit,
   uContestFactory,   (* ActiveContest -- the live question's contest (#318) *)
   PostUnit,          (* Contest, the session's contest *)
   logsubs2;          (* BuildUDPContact (#318) *)

type
   (* One party the rule applies to, and two counties of it. *)
   TPartyCase = record
      Id: string;
      Host: string;
      CountyFile: string;
      CountyA: string;
      CountyB: string;
   end;

const
   PARTY_COUNT = 7;

function PartyCase(aIndex: integer): TPartyCase;
begin
   Result := Default(TPartyCase);
   case aIndex of
      0:
         begin
         Result.Id := AL_QSO_PARTY_CONTEST_ID;
         Result.Host := 'AL';
         Result.CountyFile := 'alabama_cty.dom';
         Result.CountyA := 'AUTA';
         Result.CountyB := 'BALD';
         end;
      1:
         begin
         Result.Id := WV_QSO_PARTY_CONTEST_ID;
         Result.Host := 'WV';
         Result.CountyFile := 'westvirginia_cty.dom';
         Result.CountyA := 'BAR';
         Result.CountyB := 'MIN';
         end;
      2:
         begin
         Result.Id := KY_QSO_PARTY_CONTEST_ID;
         Result.Host := 'KY';
         Result.CountyFile := 'kentucky_cty.dom';
         Result.CountyA := 'FAY';
         Result.CountyB := 'SCO';
         end;
      3:
         begin
         (* Issue 120: "each state (including Iowa)", once overall. *)
         Result.Id := IA_QSO_PARTY_CONTEST_ID;
         Result.Host := 'IA';
         Result.CountyFile := 'iowa_cty.dom';
         Result.CountyA := 'STR';
         Result.CountyB := 'POL';
         end;
      4:
         begin
         (* Issue 111, rules 9.2.1: "Each USA state including South
            Carolina", once per band per mode. *)
         Result.Id := SC_QSO_PARTY_CONTEST_ID;
         Result.Host := 'SC';
         Result.CountyFile := 'southcarolina_cty.dom';
         Result.CountyA := 'CHAR';
         Result.CountyB := 'RICH';
         end;
      5:
         begin
         (* Issue 119, NY4I: an Illinois entrant's QSO with an Illinois
            county also earns IL as a state, once overall. *)
         Result.Id := IL_QSO_PARTY_CONTEST_ID;
         Result.Host := 'IL';
         Result.CountyFile := 'illinois_cty.dom';
         Result.CountyA := 'COOK';
         Result.CountyB := 'PEOR';
         end;
      else
         begin
         Result.Id := VT_QSO_PARTY_CONTEST_ID;
         Result.Host := 'VT';
         Result.CountyFile := 'vermont_cty.dom';
         Result.CountyA := 'ADD';
         Result.CountyB := 'CHI';
         end;
      end;
end;

function HandleOfId(const aId: string): TContestHandle;
begin
   if not FindContestById(aId, Result) then
      begin
      raise Exception.Create(aId + ' is not registered');
      end;
end;

function IsAHostStateParty(const aId: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to PARTY_COUNT - 1 do
      begin
      if SameText(PartyCase(i).Id, aId) then
         begin
         Result := True;
         end;
      end;
end;

(* Every non-zero total cell, and the host key's worked counts -- one text,
   so two sheets compare in one assertion and a failure shows the cells. *)
function SheetText(const aHost: string): string;
var
   band: BandType;
   mode: ModeType;
   kind: RemainingMultiplierType;
begin
   Result := '';
   for band := Low(BandType) to High(BandType) do
      begin
      for mode := CW to Both do
         begin
         for kind := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
            begin
            if mo.MTotals[band, mode, kind] <> 0 then
               begin
               Result := Result + Format('[%d,%d,%d]=%d ',
                  [Ord(band), Ord(mode), Ord(kind), mo.MTotals[band, mode, kind]]);
               end;
            end;
         if mo.WorkedCount(rmDomestic, aHost, band, mode) <> 0 then
            begin
            Result := Result + Format('w[%d,%d]=%d ',
               [Ord(band), Ord(mode), mo.WorkedCount(rmDomestic, aHost, band, mode)]);
            end;
         end;
      end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_EveryOtherContestAnswersFalse;
var
   contests: TContestIdentityList;
   i: integer;
   inHost: boolean;
   station: TStationContext;
   obj: TContestBase;
   qso: ContestExchange;
   key: string;
   id: string;
   named: array[0..2] of TContestHandle;
   n: integer;
begin
   BeginTest('Test_EveryOtherContestAnswersFalse');
   qso := Default(ContestExchange);
   qso.ceRecordKind := rkQSO;
   qso.Band := Band20;
   qso.Mode := CW;
   qso.DomesticQTH := 'AUTA';
   qso.DomMultQTH := 'AUTA';
   qso.QTHString := 'AUTA';

   contests := ContestsToWalk;
   CheckTrue(WalkIncludes(contests, AR_QSO_PARTY_CONTEST_ID), 'the walk reaches Arkansas');
   CheckTrue(WalkIncludes(contests, NJ_QSO_PARTY_CONTEST_ID), 'and New Jersey');
   for inHost := False to True do
      begin
      station := WithHostAreaTable(NoStation);
      station.InHostState := inHost;
      for i := 0 to High(contests) do
         begin
         id := ContestId(HandleOf(contests[i]));
         obj := NewContestLike(contests[i], station);
         try
            key := 'stale';
            if inHost and IsAHostStateParty(id) then
               begin
               CheckTrue(obj.AdditionalDomesticMultiplierKey(qso, key), id + ': a county earns the state');
               CheckEquals(obj.HostState, key, id + ': the key is the host state');
               end
            else
               begin
               CheckFalse(obj.AdditionalDomesticMultiplierKey(qso, key),
                  ContestWho(obj) + ' answers False');
               CheckEquals('', key, ContestWho(obj) + ' writes no key');
               end;
         finally
            obj.Free;
         end;
         end;
      end;

   (* NAMED: the three parties whose sponsors do NOT give the host state. *)
   named[0] := ContestHandleOf(FLORIDAQSOPARTY);
   named[1] := HandleOfId(AR_QSO_PARTY_CONTEST_ID);
   named[2] := HandleOfId(NJ_QSO_PARTY_CONTEST_ID);
   station := WithHostAreaTable(NoStation);
   station.InHostState := True;
   for n := 0 to High(named) do
      begin
      obj := Make(named[n], station);
      try
         CheckFalse(obj.AdditionalDomesticMultiplierKey(qso, key),
            ContestId(named[n]) + ' gives no second domestic key in state');
      finally
         obj.Free;
      end;
      end;
   CheckFalse(ContestAdditionalDomesticMultiplierKey(nil, qso, key), 'nil (no contest) answers False');
   CheckEquals('', key, 'nil writes no key');
end;

procedure TAdditionalDomesticMultiplierTests.Test_InStateListsHoldTheHostKey;
const
   EXPECTED: array[0..PARTY_COUNT - 1] of integer = (130, 118, 184, 162, 110, 165, 77);
var
   i: integer;
   party: TPartyCase;
   engine: TQSOPartyEngine;
   index: integer;
begin
   BeginTest('Test_InStateListsHoldTheHostKey');
   for i := 0 to PARTY_COUNT - 1 do
      begin
      party := PartyCase(i);
      engine := TQSOPartyEngine.Create(HandleOfId(party.Id));
      try
         engine.Activate(True);
         CheckEquals(EXPECTED[i], mo.DomList.Count, party.Id + ': in-state list size');
         CheckTrue(mo.DomList.FindMult(party.Host, index), party.Id + ': the host key is on the list');
      finally
         engine.Free;
      end;
      end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_LongKeysAreCounties;
var
   i, k: integer;
   party: TPartyCase;
   engine: TQSOPartyEngine;
   lines, counties: TStringList;
   key: string;
begin
   BeginTest('Test_LongKeysAreCounties');
   for i := 0 to PARTY_COUNT - 1 do
      begin
      party := PartyCase(i);
      lines := TStringList.Create;
      counties := TStringList.Create;
      engine := TQSOPartyEngine.Create(HandleOfId(party.Id));
      try
         lines.LoadFromFile(AnsiString(ShippedDomDir + party.CountyFile));
         for k := 0 to lines.Count - 1 do
            begin
            key := DomFileLineKey(string(lines[k]));
            if key <> '' then
               begin
               counties.Add(AnsiString(UpperCase(key)));
               end;
            end;
         CheckTrue(counties.Count > 10, party.Id + ': the county file was read');
         engine.Activate(True);
         for k := 0 to mo.DomList.Count - 1 do
            begin
            key := UpperCase(mo.DomList.Get(k));
            if Length(key) > 2 then
               begin
               CheckTrue(counties.IndexOf(AnsiString(key)) >= 0,
                  party.Id + ': in-state key ' + key + ' longer than two is a county');
               end;
            end;
      finally
         engine.Free;
         counties.Free;
         lines.Free;
      end;
      end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_KentuckyCountyEarnsKY;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_KentuckyCountyEarnsKY');
   engine := TQSOPartyEngine.Create(HandleOfId(KY_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      engine.Enter('W1AW', '599 CT', Band20, CW, eCW, accepted, rx);
      CheckEquals(1, mo.MTotals[AllBands, Both, rmDomestic], 'a state alone earns no KY');
      engine.Enter('K4AAA', '599 FAY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'county credited');
      CheckEquals(3, mo.MTotals[AllBands, Both, rmDomestic], 'NY4I 6862605577: county AND KY');
      engine.Enter('K4BBB', '59 SCO', Band40, Phone, eLSB, accepted, rx);
      CheckEquals(4, mo.MTotals[AllBands, Both, rmDomestic], 'KY once overall');
      engine.Enter('K4BAD', '599 KY', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'KY is never received instead of a county');

      engine.Activate(False);
      engine.Enter('K4AAA', '599 FAY', Band20, CW, eCW, accepted, rx);
      CheckEquals(1, mo.MTotals[AllBands, Both, rmDomestic], 'outside entrant: the county only');
   finally
      engine.Free;
   end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_VermontCountyEarnsTheExistingVT;
var
   engine: TQSOPartyEngine;
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_VermontCountyEarnsTheExistingVT');
   engine := TQSOPartyEngine.Create(HandleOfId(VT_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      engine.Enter('W1VT', '599 VT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted and rx.DomesticMult, 'a station sending VT itself is the VT multiplier');
      CheckEquals(1, mo.MTotals[AllBands, CW, rmDomestic], 'VT');
      engine.Enter('W1ADD', '599 ADD', Band20, CW, eCW, accepted, rx);
      CheckEquals(2, mo.MTotals[AllBands, CW, rmDomestic], 'the county; VT is already worked in CW');
      engine.Enter('W1ADD', '59 ADD', Band20, Phone, eUSB, accepted, rx);
      CheckEquals(2, mo.MTotals[AllBands, Phone, rmDomestic], 'phone: the county AND VT');
      engine.Enter('W1CHI', '599 CHI', Band20, Digital, eFT8, accepted, rx);
      CheckEquals(0, mo.MTotals[AllBands, Digital, rmDomestic],
         '7B(f): a WSJT-X QSO earns no county, so no VT');
      engine.Enter('W1RTY', '599 CHI', Band20, Digital, eRTTY, accepted, rx);
      CheckEquals(2, mo.MTotals[AllBands, Digital, rmDomestic], 'RTTY: the county AND VT');
      CheckEquals(77, mo.DomList.Count, 'no key was added to the list');

      (* THE DUPE THAT EARNS A COUNTY: the same call, band, mode and county
         as a WSJT-X QSO (which earned none) is a dupe, and SetMultFlags --
         which does not ask ceDupe, pre-existing -- credits its county. The
         state rides on that county exactly. *)
      engine.Activate(True);
      engine.Enter('W1FT', '599 ORL', Band40, Digital, eFT8, accepted, rx);
      CheckEquals(0, mo.MTotals[AllBands, Digital, rmDomestic], 'WSJT-X: nothing');
      CheckTrue(engine.Enter('W1FT', '599 ORL', Band40, Digital, eRTTY, accepted, rx),
         'RTTY after FT8, same county, is a dupe');
      CheckEquals(2, mo.MTotals[AllBands, Digital, rmDomestic],
         'its county is credited (pre-existing), and VT with it');
   finally
      engine.Free;
   end;
end;

(* ENTERS ONE QSO and appends the record, as logged (stored flags included),
   when it is accepted. Answers whether it was. *)
function TakeQSO(engine: TQSOPartyEngine; const aCall, aExch: string; aBand: BandType;
                 aMode: ModeType; aExt: ExtendedModeType;
                 var aRecords: TArray<ContestExchange>): boolean;
var
   rx: ContestExchange;
begin
   (* The dupe answer is in the record (ceDupe); the result is not needed. *)
   engine.Enter(aCall, aExch, aBand, aMode, aExt, Result, rx);
   if Result then
      begin
      SetLength(aRecords, Length(aRecords) + 1);
      aRecords[High(aRecords)] := rx;
      end;
end;

(* A mixed in-state session for one party: two counties, a state, CW and
   phone on two bands, a dupe and an off-band QSO. Answers the accepted
   records, as logged (stored flags included). *)
function RunSession(engine: TQSOPartyEngine; const aParty: TPartyCase): TArray<ContestExchange>;
var
   records: TArray<ContestExchange>;

   procedure Take(const aCall, aExch: string; aBand: BandType; aMode: ModeType;
                  aExt: ExtendedModeType);
   begin
      TakeQSO(engine, aCall, aExch, aBand, aMode, aExt, records);
   end;

begin
   records := nil;
   engine.Activate(True);
   Take('W3AAA', '599 PA', Band20, CW, eCW);
   Take('K0AAA', '599 ' + aParty.CountyA, Band20, CW, eCW);
   Take('K0AAA', '599 ' + aParty.CountyA, Band20, CW, eCW);
   Take('K0BBB', '599 ' + aParty.CountyB, Band40, CW, eCW);
   Take('K0BBB', '59 ' + aParty.CountyB, Band40, Phone, eUSB);
   Take('K0CCC', '59 PA', Band80, Phone, eLSB);
   Take('K0WRC', '599 ' + aParty.CountyA, Band30, CW, eCW);
   Take('K0DDD', '59 ' + aParty.CountyA, Band15, Phone, eUSB);
   Result := records;
end;

procedure TAdditionalDomesticMultiplierTests.Test_EqualScopeInvariant;
const
   BANDS: array[0..5] of BandType = (Band80, Band40, Band20, Band15, Band10, AllBands);
   MODES: array[0..2] of ModeType = (CW, Phone, Both);
var
   i, b, m, k: integer;
   party: TPartyCase;
   engine: TQSOPartyEngine;
   sb: BandType;
   sm: ModeType;
   hostWorked, countyWorked: boolean;
begin
   BeginTest('Test_EqualScopeInvariant');
   for i := 0 to PARTY_COUNT - 1 do
      begin
      party := PartyCase(i);
      engine := TQSOPartyEngine.Create(HandleOfId(party.Id));
      try
         RunSession(engine, party);
         CheckTrue(not mo.IsDmMult(party.Host, MultiplierSheetBand(rmDomestic, Band20),
                                   MultiplierSheetMode(CW), False),
            party.Id + ': the session worked the host state');
         for b := 0 to High(BANDS) do
            begin
            for m := 0 to High(MODES) do
               begin
               sb := MultiplierSheetBand(rmDomestic, BANDS[b]);
               sm := MultiplierSheetMode(MODES[m]);
               hostWorked := not mo.IsDmMult(party.Host, sb, sm, False);
               countyWorked := False;
               for k := 0 to mo.DomList.Count - 1 do
                  begin
                  if (Length(mo.DomList.Get(k)) > 2) and
                     mo.DomList.StringIsDupeByIndex(k, sb, sm) then
                     begin
                     countyWorked := True;
                     end;
                  end;
               if countyWorked then
                  begin
                  CheckTrue(hostWorked, Format('%s: a county worked in scope %d/%d earns the state',
                     [party.Id, Ord(sb), Ord(sm)]));
                  end;
               if party.Id <> VT_QSO_PARTY_CONTEST_ID then
                  begin
                  (* No alias: the host key is reached ONLY through a county.
                     Illinois accepts IL sent itself too, but RunSession never
                     sends it, so the equality holds for its session. *)
                  CheckTrue(hostWorked = countyWorked, Format('%s: the state is worked in scope %d/%d ' +
                     'exactly when a county is', [party.Id, Ord(sb), Ord(sm)]));
                  end;
               end;
            end;
      finally
         engine.Free;
      end;
      end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_LoadAndRescoreAgreeWithLive;
var
   i, k, pass: integer;
   party: TPartyCase;
   engine: TQSOPartyEngine;
   logged: TArray<ContestExchange>;
   rx: ContestExchange;
   live, loaded, rescored: string;
begin
   BeginTest('Test_LoadAndRescoreAgreeWithLive');
   for i := 0 to PARTY_COUNT - 1 do
      begin
      party := PartyCase(i);
      engine := TQSOPartyEngine.Create(HandleOfId(party.Id));
      try
         logged := RunSession(engine, party);
         live := SheetText(party.Host);
         CheckTrue(live <> '', party.Id + ': the live session totalled something');

         (* THE LOAD, MODELLED: the stored records, stored flags trusted. *)
         mo.ClearAllMults;
         for k := 0 to High(logged) do
            begin
            rx := logged[k];
            Sheet.AddQSOToSheets(@rx, False);
            end;
         loaded := SheetText(party.Host);
         CheckEquals(live, loaded, party.Id + ': a load re-derives the state exactly as live');

         (* THE RESCORE, twice: flags re-derived against the sheet so far. *)
         for pass := 1 to 2 do
            begin
            mo.ClearAllMults;
            for k := 0 to High(logged) do
               begin
               rx := logged[k];
               RecomputeQSOScoring(rx);
               Sheet.AddQSOToSheets(@rx, False);
               end;
            rescored := SheetText(party.Host);
            CheckEquals(live, rescored, Format('%s: rescore pass %d equals live', [party.Id, pass]));
            end;
      finally
         engine.Free;
      end;
      end;
end;

(* THE REPLAY'S ANSWER FOR EACH RECORD, in log order -- what the hourly
   report and the full-log UDP resend add (#318). Asks the session's
   ActiveContest, as the program does. *)
function ReplayedSecondKeys(const aLogged: TArray<ContestExchange>): TArray<integer>;
var
   replay: TAdditionalDomesticMultiplierReplay;
   k: integer;
begin
   SetLength(Result, Length(aLogged));
   replay := TAdditionalDomesticMultiplierReplay.Create;
   try
      for k := 0 to High(aLogged) do
         begin
         Result[k] := replay.Feed(aLogged[k]);
         end;
   finally
      replay.Free;
   end;
end;

(* Every total cell of the sheet's AllBands/Both column, every kind: each
   mark on the sheet adds one there. *)
function SheetMarkCount: integer;
var
   kind: RemainingMultiplierType;
begin
   Result := 0;
   for kind := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
      begin
      Result := Result + mo.MTotals[AllBands, Both, kind];
      end;
end;

procedure TAdditionalDomesticMultiplierTests.CheckPerQSOCounts(const aWhat: string;
   const aLogged: TArray<ContestExchange>; const aExpected: array of integer);
var
   second: TArray<integer>;
   k: integer;
begin
   CheckEquals(Length(aExpected), Length(aLogged), aWhat + ': every QSO was accepted');
   if Length(aExpected) <> Length(aLogged) then
      begin
      Exit;
      end;
   second := ReplayedSecondKeys(aLogged);
   for k := 0 to High(aLogged) do
      begin
      CheckEquals(aExpected[k], StoredMultiplierFlagCount(aLogged[k]) + second[k],
         Format('%s: QSO %d (%s) multiplier count', [aWhat, k + 1, string(aLogged[k].Callsign)]));
      end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_PerQSOCountsAddUpToTheSheet;
var
   i, k, sum, seconds, live: integer;
   party: TPartyCase;
   engine: TQSOPartyEngine;
   logged: TArray<ContestExchange>;
   second: TArray<integer>;
   rx: ContestExchange;
begin
   BeginTest('Test_PerQSOCountsAddUpToTheSheet');
   for i := 0 to PARTY_COUNT - 1 do
      begin
      party := PartyCase(i);
      engine := TQSOPartyEngine.Create(HandleOfId(party.Id));
      try
         logged := RunSession(engine, party);
         second := ReplayedSecondKeys(logged);
         sum := 0;
         seconds := 0;
         for k := 0 to High(logged) do
            begin
            sum := sum + StoredMultiplierFlagCount(logged[k]) + second[k];
            seconds := seconds + second[k];
            end;
         CheckTrue(seconds > 0, party.Id + ': the in-state session earned the host state on some QSO');
         CheckEquals(SheetMarkCount, sum,
            party.Id + ': the per-QSO counts add up to the sheet (the hourly Mults column)');

         (* THE LIVE QUESTION, asked of `mo` before each QSO is added (the
            load modelled, as Test_LoadAndRescoreAgreeWithLive does), equals
            the replay QSO by QSO. *)
         mo.ClearAllMults;
         for k := 0 to High(logged) do
            begin
            rx := logged[k];
            live := AdditionalDomesticMultipliersBeforeSheet(ActiveContest(Contest), rx);
            Sheet.AddQSOToSheets(@rx, False);
            CheckEquals(second[k], live,
               Format('%s: QSO %d live answer equals the replay', [party.Id, k + 1]));
            end;
      finally
         engine.Free;
      end;
      end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_PerQSOCountsFollowEachStatesScope;
var
   engine: TQSOPartyEngine;
   logged: TArray<ContestExchange>;
begin
   BeginTest('Test_PerQSOCountsFollowEachStatesScope');

   (* KENTUCKY, ONCE OVERALL: a state alone 1; the first county 2 (county
      and KY); a county on another band and mode 1. *)
   engine := TQSOPartyEngine.Create(HandleOfId(KY_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      logged := nil;
      TakeQSO(engine, 'W1AW', '599 CT', Band20, CW, eCW, logged);
      TakeQSO(engine, 'K4AAA', '599 FAY', Band20, CW, eCW, logged);
      TakeQSO(engine, 'K4BBB', '59 SCO', Band40, Phone, eLSB, logged);
      CheckPerQSOCounts('KY', logged, [1, 2, 1]);
   finally
      engine.Free;
   end;

   (* WEST VIRGINIA, ONCE OVERALL. *)
   engine := TQSOPartyEngine.Create(HandleOfId(WV_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      logged := nil;
      TakeQSO(engine, 'K8AAA', '599 BAR', Band20, CW, eCW, logged);
      TakeQSO(engine, 'K8BBB', '59 MIN', Band40, Phone, eLSB, logged);
      CheckPerQSOCounts('WV', logged, [2, 1]);
   finally
      engine.Free;
   end;

   (* ALABAMA, PER MODE: AL again on the first phone county, not on a second
      CW county. *)
   engine := TQSOPartyEngine.Create(HandleOfId(AL_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      logged := nil;
      TakeQSO(engine, 'K4AAA', '599 AUTA', Band20, CW, eCW, logged);
      TakeQSO(engine, 'K4BBB', '59 BALD', Band40, Phone, eLSB, logged);
      TakeQSO(engine, 'K4CCC', '599 BALD', Band40, CW, eCW, logged);
      CheckPerQSOCounts('AL', logged, [2, 2, 1]);
   finally
      engine.Free;
   end;

   (* VERMONT, PER MODE, WITH VT RECEIVED AS ITSELF: a station sending VT is
      the VT multiplier (1), so the CW county earns only itself (1); the
      phone county earns VT too (2); FT8 earns nothing (0, 7B(f)); RTTY's
      county earns VT in DIGITAL (2). *)
   engine := TQSOPartyEngine.Create(HandleOfId(VT_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      logged := nil;
      TakeQSO(engine, 'W1VT', '599 VT', Band20, CW, eCW, logged);
      TakeQSO(engine, 'W1ADD', '599 ADD', Band20, CW, eCW, logged);
      TakeQSO(engine, 'W1ADD', '59 ADD', Band20, Phone, eUSB, logged);
      TakeQSO(engine, 'W1CHI', '599 CHI', Band20, Digital, eFT8, logged);
      TakeQSO(engine, 'W1RTY', '599 CHI', Band20, Digital, eRTTY, logged);
      CheckPerQSOCounts('VT', logged, [1, 1, 2, 0, 2]);

      (* AN OUTSIDE ENTRANT earns no second key: the county alone. *)
      engine.Activate(False);
      logged := nil;
      TakeQSO(engine, 'W1ADD', '599 ADD', Band20, CW, eCW, logged);
      CheckPerQSOCounts('VT outside', logged, [1]);
   finally
      engine.Free;
   end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_UDPShowsTheSecondKey;
var
   engine: TQSOPartyEngine;
   logged: TArray<ContestExchange>;
   second: TArray<integer>;
   xml: string;
begin
   BeginTest('Test_UDPShowsTheSecondKey');
   engine := TQSOPartyEngine.Create(HandleOfId(KY_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      logged := nil;
      TakeQSO(engine, 'K4AAA', '599 FAY', Band20, CW, eCW, logged);
      TakeQSO(engine, 'K4BBB', '59 SCO', Band40, Phone, eLSB, logged);
      CheckEquals(2, Length(logged), 'both QSOs accepted');
      if Length(logged) <> 2 then
         begin
         Exit;
         end;
      second := ReplayedSecondKeys(logged);

      xml := BuildUDPContact(logged[0], udpContactInfo, second[0]);
      CheckTrue(Pos('<ismultiplier1>1</ismultiplier1>', xml) > 0, 'FAY: the county');
      CheckTrue(Pos('<ismultiplier2>1</ismultiplier2>', xml) > 0, 'FAY: and KY (#318)');
      CheckTrue(Pos('<ismultiplier3>0</ismultiplier3>', xml) > 0, 'FAY: nothing more');

      xml := BuildUDPContact(logged[1], udpContactReplace, second[1]);
      CheckTrue(Pos('<ismultiplier1>1</ismultiplier1>', xml) > 0, 'SCO: the county');
      CheckTrue(Pos('<ismultiplier2>0</ismultiplier2>', xml) > 0, 'SCO: KY is not new again');
   finally
      engine.Free;
   end;
end;

procedure TAdditionalDomesticMultiplierTests.Test_NoSecondKeyPartyIsUnchanged;
var
   engine: TQSOPartyEngine;
   logged: TArray<ContestExchange>;
   second: TArray<integer>;
   k, sum: integer;
   rx: ContestExchange;
begin
   BeginTest('Test_NoSecondKeyPartyIsUnchanged');
   (* ARKANSAS, IN STATE: its sponsor gives no host state, so every QSO's
      count is its stored flags, exactly as before #318. *)
   engine := TQSOPartyEngine.Create(HandleOfId(AR_QSO_PARTY_CONTEST_ID));
   try
      engine.Activate(True);
      logged := nil;
      TakeQSO(engine, 'K5AAA', '599 BEN', Band20, CW, eCW, logged);
      TakeQSO(engine, 'K5BBB', '59 ARK', Band40, Phone, eLSB, logged);
      TakeQSO(engine, 'K5CCC', '599 BEN', Band40, CW, eCW, logged);
      CheckTrue(Length(logged) >= 2, 'Arkansas in state: counties accepted');
      second := ReplayedSecondKeys(logged);
      sum := 0;
      for k := 0 to High(logged) do
         begin
         CheckEquals(0, second[k], Format('Arkansas QSO %d: no second key', [k + 1]));
         sum := sum + StoredMultiplierFlagCount(logged[k]);
         end;
      CheckEquals(SheetMarkCount, sum, 'Arkansas: the stored flags alone add up to the sheet');

      mo.ClearAllMults;
      for k := 0 to High(logged) do
         begin
         rx := logged[k];
         CheckEquals(0, AdditionalDomesticMultipliersBeforeSheet(ActiveContest(Contest), rx),
            Format('Arkansas QSO %d: the live answer is 0', [k + 1]));
         Sheet.AddQSOToSheets(@rx, False);
         end;
   finally
      engine.Free;
   end;
end;

procedure TAdditionalDomesticMultiplierTests.RunAllTests;
begin
   Test_EveryOtherContestAnswersFalse;
   Test_InStateListsHoldTheHostKey;
   Test_LongKeysAreCounties;
   Test_KentuckyCountyEarnsKY;
   Test_VermontCountyEarnsTheExistingVT;
   Test_EqualScopeInvariant;
   Test_LoadAndRescoreAgreeWithLive;
   Test_PerQSOCountsAddUpToTheSheet;
   Test_PerQSOCountsFollowEachStatesScope;
   Test_UDPShowsTheSecondKey;
   Test_NoSecondKeyPartyIsUnchanged;
end;

end.
