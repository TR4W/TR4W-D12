unit uTestNewContestHome;
{$I ..\..\src\tr4w.inc}

(* MY CALL AGAINST THE "I AM IN ..." BOX -- issue 167.

  At OK on a new contest, the New Contest dialog locates MY CALL and asks the
  operator once when the call and the box disagree. What is pinned:

    the region      a call is in it by whole CTY country ID, or by continent
                    when the contest names one -- never by a prefix of an ID;
    the verdict     ticked outside the region is asked; cleared inside it is
                    asked only when every call of the region is inside the box
                    (Canada), never for a box that is part of one (New
                    England); an unlocated call is never asked about;
    the classes     a box reads its contest's own domestic list -- the North
                    American boxes too since review M16 (they were the
                    continent) -- New England is a one-way K, and a box DXCC
                    cannot decide (IARU's HQ or member) states nothing;
    the walk        every contest that states a region offers the box, so the
                    check never fires for a box the operator cannot see; and
                    every box states a region or is exempt with its reason;
    the real file   the shipped cty.dat puts real calls where the lists say,
                    so a list spelled differently from CTY cannot pass. *)

interface

uses
   uTR4WTestFramework;

type
   TNewContestHomeTests = class(TTestCase)
   protected
      procedure Test_ARegionHoldsAWholeCountryIDOrAContinent;
      procedure Test_TheVerdictAsksOnlyWhereTheBoxIsWrong;
      procedure Test_TheClassesStateTheirRegions;
      procedure Test_EveryStatedRegionHasABox;
      procedure Test_RealCallsAgainstTheShippedCountryFile;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,                  (* ContinentType, QTHRecord, ContestType *)
   uCTYDAT,             (* ctyLoadInCountryFile, ctyLocateCall *)
   uCallSignRoutines,   (* UKEIStation *)
   uContestBase,        (* TNewContestHome, TNewContestPrompts *)
   uContestRegistry,    (* ContestIdentity, ContestHandleOf *)
   uTestRegisteredContests, (* ContestsToWalk, ContestWho *)
   uNewContestHome;

procedure TNewContestHomeTests.Test_ARegionHoldsAWholeCountryIDOrAContinent;
begin
   BeginTest('Test_ARegionHoldsAWholeCountryIDOrAContinent');

   CheckTrue(HomeHoldsCall('VE CY0 CY9', UnknownContinent, 'VE', NorthAmerica),
             'VE is in Canada''s list');
   CheckTrue(HomeHoldsCall('VE CY0 CY9', UnknownContinent, 'CY9', NorthAmerica),
             'the last ID of the list');
   CheckFalse(HomeHoldsCall('VE CY0 CY9', UnknownContinent, 'V', NorthAmerica),
              'a prefix of an ID is not the ID');
   CheckFalse(HomeHoldsCall('VE CY0 CY9', UnknownContinent, 'K', NorthAmerica),
              'K is not in Canada''s list, whatever its continent');
   CheckFalse(HomeHoldsCall('VE CY0 CY9', UnknownContinent, '', NorthAmerica),
              'no ID is in no list');
   CheckTrue(HomeHoldsCall('I IS *IT9', UnknownContinent, '*IT9', Europe),
             'an ID spelled with CTY''s star');

   CheckTrue(HomeHoldsCall('', NorthAmerica, 'KP4', NorthAmerica),
             'by continent: any North American call');
   CheckFalse(HomeHoldsCall('', NorthAmerica, 'DL', Europe),
              'by continent: a European call is not in North America');
   CheckFalse(HomeHoldsCall('', UnknownContinent, 'K', NorthAmerica),
              'a region of neither holds no call');
end;

procedure TNewContestHomeTests.Test_TheVerdictAsksOnlyWhereTheBoxIsWrong;
begin
   BeginTest('Test_TheVerdictAsksOnlyWhereTheBoxIsWrong');

   (* IAmInVerdict(ticked, located, callIsHome, homeIsInside) *)
   CheckTrue(IAmInVerdict(True, True, True, True) = iavAgree,
             'ticked, a home call: agree');
   CheckTrue(IAmInVerdict(True, True, False, True) = iavTickedOutside,
             'ticked, a call outside the region: asked');
   CheckTrue(IAmInVerdict(True, True, False, False) = iavTickedOutside,
             'ticked outside a part-of-a-country box (New England): asked');
   CheckTrue(IAmInVerdict(False, True, True, True) = iavClearedInside,
             'cleared, a home call of a whole-country box (Canada): asked');
   CheckTrue(IAmInVerdict(False, True, True, False) = iavAgree,
             'cleared, a K call and the New England box: an out-of-area station');
   CheckTrue(IAmInVerdict(False, True, False, True) = iavAgree,
             'cleared, a call outside the region: agree');
   CheckTrue(IAmInVerdict(True, False, False, True) = iavAgree,
             'an unlocated call is never asked about, ticked');
   CheckTrue(IAmInVerdict(False, False, True, True) = iavAgree,
             'an unlocated call is never asked about, cleared');
end;

procedure TNewContestHomeTests.Test_TheClassesStateTheirRegions;
var
   home: TNewContestHome;
begin
   BeginTest('Test_TheClassesStateTheirRegions');

   (* THE NORTH AMERICAN BOXES ARE EACH CONTEST'S OWN DOMESTIC LIST, not the
      continent (review M16, 2026-11-16). *)
   CheckTrue(ContestIdentity(ContestHandleOf(ARRL10)).DescribeNewContestHome(home),
             'ARRL 10 states its box''s region');
   CheckEquals('K VE KH6 KL XE', home.Countries,
               'ARRL 10: the stations that send a state or province, from DescribeSession');
   CheckTrue(home.Continent = UnknownContinent, 'ARRL 10: not the continent');
   CheckTrue(home.HomeIsInside, 'ARRL 10: every listed call is inside');
   CheckTrue(ContestIdentity(ContestHandleOf(CQ160CW)).DescribeNewContestHome(home),
             'CQ 160 CW states its box''s region');
   CheckEquals('K VE', home.Countries, 'CQ 160 CW: W/VE');
   CheckTrue(ContestIdentity(ContestHandleOf(CQ160SSB)).DescribeNewContestHome(home),
             'CQ 160 SSB states its box''s region');
   CheckEquals('K VE', home.Countries, 'CQ 160 SSB: W/VE');
   CheckTrue(ContestIdentity(ContestHandleOf(ARRL_RTTY_ROUNDUP)).DescribeNewContestHome(home),
             'RTTY Roundup states its box''s region');
   CheckEquals('K VE', home.Countries, 'RTTY Roundup: W/VE');
   CheckTrue(ContestIdentity(ContestHandleOf(CQWWRTTY)).DescribeNewContestHome(home),
             'CQ WW RTTY states its box''s region');
   CheckEquals('K VE', home.Countries, 'CQ WW RTTY: W/VE, stated (its set-up lists none)');
   CheckTrue(ContestIdentity(ContestHandleOf(ARRL160)).DescribeNewContestHome(home),
             'ARRL 160 states its box''s region');
   CheckTrue(Pos(' KH6 ', ' ' + home.Countries + ' ') > 0, 'ARRL 160: an ARRL-section country (KH6)');
   CheckTrue(Pos(' XE ', ' ' + home.Countries + ' ') = 0, 'ARRL 160: XE is no ARRL-section country');
   CheckTrue(ContestIdentity(ContestHandleOf(JIDXCW)).DescribeNewContestHome(home),
             'JIDX CW states its box''s region');
   CheckEquals('JA', home.Countries, 'JIDX CW: Japan');
   CheckTrue(ContestIdentity(ContestHandleOf(JIDXSSB)).DescribeNewContestHome(home),
             'JIDX SSB states its box''s region');
   CheckEquals('JA', home.Countries, 'JIDX SSB: Japan');
   CheckTrue(ContestIdentity(ContestHandleOf(UBACW)).DescribeNewContestHome(home),
             'UBA CW states its box''s region');
   CheckEquals('ON', home.Countries, 'UBA CW: Belgium');
   CheckTrue(ContestIdentity(ContestHandleOf(UBASSB)).DescribeNewContestHome(home),
             'UBA SSB states its box''s region');
   CheckEquals('ON', home.Countries, 'UBA SSB: Belgium');

   CheckTrue(ContestIdentity(ContestHandleOf(CANADA_DAY)).DescribeNewContestHome(home),
             'Canada Day states its box''s region');
   CheckEquals('VE CY0 CY9', home.Countries,
               'Canada Day: its own domestic list, read from DescribeSession');
   CheckTrue(home.HomeIsInside, 'Canada Day: every Canadian call is inside');

   CheckTrue(ContestIdentity(ContestHandleOf(KINGOFSPAINCW)).DescribeNewContestHome(home),
             'King of Spain CW states its box''s region');
   CheckEquals('EA EA6 EA8 EA9', home.Countries, 'King of Spain: Spain and its islands');

   CheckTrue(ContestIdentity(ContestHandleOf(PACC)).DescribeNewContestHome(home),
             'PACC states its box''s region');
   CheckEquals('PA', home.Countries,
               'PACC: PA, stated -- its session adds PA only for a Dutch station');

   CheckTrue(ContestIdentity(ContestHandleOf(NEWENGLANDQSO)).DescribeNewContestHome(home),
             'New England states its box''s region');
   CheckEquals('K', home.Countries, 'New England is in K');
   CheckFalse(home.HomeIsInside, 'but not every K call is in New England');

   CheckFalse(ContestIdentity(ContestHandleOf(IARU)).DescribeNewContestHome(home),
              'IARU''s box is HQ or member: DXCC cannot decide it');
   CheckFalse(ContestIdentity(ContestHandleOf(POTA)).DescribeNewContestHome(home),
              'POTA''s box is Activator, not a place');
end;

(* Does aContest's prompt list offer the "I am in <region>" box? *)
function OffersIAmInBox(aContest: TContestBase): boolean;
var
   prompts: TNewContestPrompts;
   i: integer;
begin
   Result := False;
   prompts := TNewContestPrompts.Create;
   try
      aContest.DescribeNewContestPrompts(prompts);
      for i := 0 to prompts.ChoiceCount - 1 do
         begin
         if prompts.Choice(i).Kind = npkIAmIn then
            begin
            Result := True;
            end;
         end;
   finally
      prompts.Free;
   end;
end;

(* THE CONTESTS THAT OFFER THE "I AM IN" BOX AND STATE NO REGION, ON PURPOSE
   (review M16, 2026-11-16). A ratchet: Test_EveryStatedRegionHasABox fails
   a box with no region that is not here, and an entry here that now states
   one. Each with its reason:
     IARU, BSCI           "HQ or member" -- a society station, which DXCC
                          cannot decide;
     ARKTIKA_SPRING, PCC  a club member;
     GAGARINCUP           a station with a special designator, not a place;
     WWPMC                a PMC city, which DXCC cannot decide;
     REFCW, REFSSB        France: REF's own test is FrenchID (any ID starting
                          F, TM, TK), a rule over IDs that a whole-ID list
                          would copy and let drift;
     RSGB18               "UK": no station test in its class names the UK
                          countries, and no sponsor text is in the tree;
     IRTS, EUDX           the entrant is decided by the four-character code
                          sent (MY STATE), not by a country -- EUDX's box is
                          any EU country. *)
function OffersABoxWithNoRegionOnPurpose(aContest: TContestBase): boolean;
const
   EXEMPT: array[0..10] of ContestType = (IARU, BSCI, ARKTIKA_SPRING, PCC, GAGARINCUP,
                                          WWPMC, REFCW, REFSSB, RSGB18, IRTS, EUDX);
var
   i: integer;
begin
   Result := False;
   for i := Low(EXEMPT) to High(EXEMPT) do
      begin
      if IsLegacyContest(aContest, EXEMPT[i]) then
         begin
         Result := True;
         end;
      end;
end;

procedure TNewContestHomeTests.Test_EveryStatedRegionHasABox;
var
   contests: TContestIdentityList;
   home: TNewContestHome;
   stating: integer;
   i: integer;
begin
   BeginTest('Test_EveryStatedRegionHasABox');

   (* A country box reads its contest's DescribeSession on a station with no
     country yet, and UK/EI's asked UKEIStation(''), which read past the end
     of the empty ID. *)
   CheckFalse(UKEIStation(''), 'an empty ID is no UK/EI station');
   CheckTrue(UKEIStation('G'), 'G is');
   CheckTrue(UKEIStation('EI'), 'EI is');
   CheckFalse(UKEIStation('E'), 'E alone is not');

   contests := ContestsToWalk;
   stating := 0;
   for i := 0 to High(contests) do
      begin
      (* THE OTHER DIRECTION (review M16, 2026-11-16): a contest that offers
         the box states its region, or is on the exemption list below with
         its reason -- so a new contest with a box and no region fails here.
         An exempt contest that states one fails too: the list only
         shrinks. *)
      if contests[i].DescribeNewContestHome(home) then
         begin
         CheckFalse(OffersABoxWithNoRegionOnPurpose(contests[i]), ContestWho(contests[i]) +
                    ': states a region, so take it off the exemption list');
         end
      else
         begin
         CheckTrue(not OffersIAmInBox(contests[i]) or
                   OffersABoxWithNoRegionOnPurpose(contests[i]),
                   ContestWho(contests[i]) + ': offers the "I am in" box and states ' +
                   'no region -- state one (DescribeNewContestHome) or exempt it ' +
                   'with its reason');
         CheckTrue(OffersIAmInBox(contests[i]) or
                   not OffersABoxWithNoRegionOnPurpose(contests[i]),
                   ContestWho(contests[i]) + ': exempt, but offers no box');
         Continue;
         end;
      inc(stating);
      CheckTrue(OffersIAmInBox(contests[i]), ContestWho(contests[i]) +
                ': states a region for a box it does not offer');
      CheckTrue((Trim(home.Countries) <> '') or (home.Continent <> UnknownContinent),
                ContestWho(contests[i]) + ': states a region of neither countries ' +
                'nor a continent');
      end;
   CheckTrue(stating > 0, 'some contest states a region -- the walk is not empty');
end;

procedure TNewContestHomeTests.Test_RealCallsAgainstTheShippedCountryFile;
var
   ctyPath: string;
   home: TNewContestHome;
   qth: QTHRecord;

   function IsHome(const aCall: string): boolean;
   begin
      CheckTrue(ctyLocateCall(CallString(aCall), qth), aCall + ' is located');
      Result := HomeHoldsCall(home.Countries, home.Continent,
                              string(qth.CountryID), qth.Continent);
   end;

begin
   BeginTest('Test_RealCallsAgainstTheShippedCountryFile');

   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   ContestIdentity(ContestHandleOf(ARRL10)).DescribeNewContestHome(home);
   CheckTrue(IsHome('W1AW'), 'ARRL 10: W1AW is in North America');
   CheckTrue(IsHome('VE3EJ'), 'ARRL 10: VE3EJ is in North America');
   CheckFalse(IsHome('DL1ABC'), 'ARRL 10: DL1ABC is not');
   CheckTrue(IsHome('KH6ABC'), 'ARRL 10: KH6ABC sends a state, though in Oceania (review M16)');
   CheckFalse(IsHome('KP4ABC'), 'ARRL 10: KP4ABC is in North America but sends a serial');

   ContestIdentity(ContestHandleOf(CQ160CW)).DescribeNewContestHome(home);
   CheckTrue(IsHome('VE3EJ'), 'CQ 160: VE3EJ sends a province');
   CheckFalse(IsHome('XE1ABC'), 'CQ 160: XE1ABC is in North America but is DX (review M16)');

   ContestIdentity(ContestHandleOf(CANADA_DAY)).DescribeNewContestHome(home);
   CheckTrue(IsHome('VE3EJ'), 'Canada Day: VE3EJ is in Canada');
   CheckFalse(IsHome('W1AW'), 'Canada Day: W1AW is not');
   CheckTrue(IAmInVerdict(False, True, IsHome('VE3EJ'), home.HomeIsInside) =
             iavClearedInside,
             'Canada Day: VE3EJ with the box cleared is asked about');

   ContestIdentity(ContestHandleOf(NEWENGLANDQSO)).DescribeNewContestHome(home);
   CheckTrue(IsHome('W1AW'), 'New England: W1AW is in K');
   CheckTrue(IAmInVerdict(False, True, IsHome('W4ABC'), home.HomeIsInside) = iavAgree,
             'New England: a K call with the box cleared is not asked about');
   CheckTrue(IAmInVerdict(True, True, IsHome('VE3EJ'), home.HomeIsInside) =
             iavTickedOutside,
             'New England: VE3EJ with the box ticked is asked about');

   ContestIdentity(ContestHandleOf(KINGOFSPAINCW)).DescribeNewContestHome(home);
   CheckTrue(IsHome('EA4ABC'), 'King of Spain: EA4ABC is in Spain');
   CheckTrue(IsHome('EA8ABC'), 'King of Spain: EA8ABC, the Canaries, is in Spain');
   CheckFalse(IsHome('CT1ABC'), 'King of Spain: CT1ABC is not');

   (* The dialog loads the table before set-up replaces it: the locate cache,
     which holds an index into the old table, must not survive the reload. *)
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat reloads');
   CheckEquals('', string(CTY.ctyLastLocatedCall),
               'a replacing load forgets the last located call');
end;

procedure TNewContestHomeTests.RunAllTests;
begin
   Test_ARegionHoldsAWholeCountryIDOrAContinent;
   Test_TheVerdictAsksOnlyWhereTheBoxIsWrong;
   Test_TheClassesStateTheirRegions;
   Test_EveryStatedRegionHasABox;
   Test_RealCallsAgainstTheShippedCountryFile;
end;

end.
