unit uTestSetupWizard;

(* THE SETUP WIZARD'S RULES -- docs/SETUP_WIZARD_DESIGN.md, section 10.

  Written with the wizard, because most of what it promises is about paths
  nobody walks by hand:

    * the page plan is canonical whatever was ticked, and the page before
      the result page is the one that commits (criteria 6, 9);
    * it opens by itself only on a brand-new install, once, and never in a
      headless run (criteria 1, 2, 4, 5);
    * what the optional items put in the stores is asserted by READING THE
      STORES BACK, not the form (criterion 8), a second run does not collide
      with the first, and the drafts are copied, never consumed. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSetupWizardTests = class(TTestCase)
   protected
      procedure TestPlanWithNothingTicked;
      procedure TestPlanIsCanonicalOrder;
      procedure TestCommitPageIsBeforeResult;
      procedure TestIndexOfMissingPage;
      procedure TestDueOnlyOnBrandNewInstall;
      procedure TestStageNothing;
      procedure TestStageAllThree;
      procedure TestStageTwiceMakesNamesUnique;
      procedure TestStageUsesTheActiveProfile;
      procedure TestClusterBaseName;
      procedure TestGridSquareCase;
      procedure TestClusterServerSplit;
      procedure TestStageCarriesTheCWChoices;
      procedure TestDetailLinesNeverShowAPassword;
      (* Issue 334: the external logger, rotator and WSJT-X items. *)
      procedure TestPlanWithEveryItem;
      procedure TestStageRotatorIsActiveAndUnique;
      procedure TestStageNetworkRotatorSaysDefaultAddress;
      procedure TestStageLoggerAddsAndActivates;
      procedure TestStageLoggerRefusesAnUnseededLibrary;
      procedure TestStageLoggerTakesBackAnInvalidDefinition;
      procedure TestStageLoggerKeepsTheSecretOutOfTheFile;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uJSON,          (* TJSONObject -- what SaveConfig writes the definitions into *)
   uKeychain,      (* InstallTestKeychain, KEYCHAIN_REF_SUFFIX *)
   uRadioConfigStore,
   uKeyerConfigStore,
   uExternalLoggerConfig,
   uAppStrings,    (* SDefaultClusterName -- the default is translatable *)
   uSetupWizard;

function PlanText(const aPlan: TSetupPagePlan): string;
const
   NAMES: array[TSetupPage] of string =
      ('Station', 'Checklist', 'Radio', 'Keyer', 'Cluster',
       'Logger', 'Rotator', 'WSJTX', 'Result');
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aPlan) do
      begin
      if Result <> '' then
         begin
         Result := Result + ',';
         end;
      Result := Result + NAMES[aPlan[i]];
      end;
end;

procedure TSetupWizardTests.TestPlanWithNothingTicked;
begin
   BeginTest('TestPlanWithNothingTicked');
   (* Criterion 6: Station, Checklist, Commit -- no empty pages between. *)
   CheckEquals('Station,Checklist,Result', PlanText(SetupPagePlan([])),
               'nothing ticked is two pages and the result');
end;

procedure TSetupWizardTests.TestPlanIsCanonicalOrder;
begin
   BeginTest('TestPlanIsCanonicalOrder');
   CheckEquals('Station,Checklist,Radio,Keyer,Cluster,Result',
               PlanText(SetupPagePlan([siCluster, siKeyer, siRadio])),
               'everything ticked, canonical order');
   CheckEquals('Station,Checklist,Radio,Cluster,Result',
               PlanText(SetupPagePlan([siCluster, siRadio])),
               'radio before cluster whatever the click order');
   CheckEquals('Station,Checklist,Keyer,Result',
               PlanText(SetupPagePlan([siKeyer])),
               'one item, its own page only');
end;

procedure TSetupWizardTests.TestCommitPageIsBeforeResult;
var
   plan: TSetupPagePlan;
begin
   BeginTest('TestCommitPageIsBeforeResult');
   plan := SetupPagePlan([]);
   CheckFalse(IsCommitPage(plan, 0), 'Station is not the commit page');
   CheckTrue(IsCommitPage(plan, 1), 'with nothing ticked the checklist commits');
   CheckFalse(IsCommitPage(plan, 2), 'the result page does not commit');

   plan := SetupPagePlan([siRadio, siCluster]);
   CheckFalse(IsCommitPage(plan, 1), 'the checklist is not last any more');
   CheckFalse(IsCommitPage(plan, 2), 'radio is not last');
   CheckTrue(IsCommitPage(plan, 3), 'the last ticked page commits');
   CheckFalse(IsCommitPage(plan, -1), 'out of range is not a commit page');
end;

procedure TSetupWizardTests.TestIndexOfMissingPage;
var
   plan: TSetupPagePlan;
begin
   BeginTest('TestIndexOfMissingPage');
   plan := SetupPagePlan([siKeyer]);
   CheckEquals(2, IndexOfSetupPage(plan, spKeyer), 'keyer is third');
   CheckEquals(3, IndexOfSetupPage(plan, spResult), 'result is last');
   CheckEquals(-1, IndexOfSetupPage(plan, spRadio), 'an unticked page is absent');
end;

procedure TSetupWizardTests.TestDueOnlyOnBrandNewInstall;
begin
   BeginTest('TestDueOnlyOnBrandNewInstall');
   CheckTrue(SetupWizardDueAtStartup(False, False),
             'no callsign stored, an operator: offer it -- whether or not a '
             + 'settings file exists, and however many times it was cancelled');
   CheckFalse(SetupWizardDueAtStartup(True, False),
              'headless: never -- a window there is a hang');
   CheckFalse(SetupWizardDueAtStartup(False, True),
              'a callsign is stored: a configured station');
end;

procedure TSetupWizardTests.TestStageNothing;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   report: string;
begin
   BeginTest('TestStageNothing');
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      report := '';
      CheckTrue(StageSetupItems(store, keyers, nil, nil, nil, report) = [],
                'nothing ticked stages nothing');
      CheckEquals(0, store.RadioCount, 'no radio');
      CheckEquals(0, store.ProfileCount, 'no profile invented');
      CheckEquals(0, keyers.KeyerCount, 'no keyer');
      CheckEquals(0, store.ClusterCount, 'no cluster');
      CheckEquals('', report, 'nothing to report');
   finally
      keyers.Free;
      store.Free;
   end;
end;

procedure TSetupWizardTests.TestStageAllThree;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   cluster: TClusterDefinition;
   staged: TSetupItems;
   profile: TStationProfile;
   report: string;
   err: string;
begin
   BeginTest('TestStageAllThree');
   store   := TRadioConfigStore.Create;
   keyers  := TKeyerConfigStore.Create;
   radio   := TRadioDefinition.Create;
   keyer   := TKeyerDefinition.Create;
   cluster := TClusterDefinition.Create;
   try
      radio.Name := 'IC-7300';
      keyer.Name := 'WinKeyer';
      keyer.Port := 'SERIAL 5';
      cluster.Server := 'dxc.example.net:7373';
      report := '';

      staged := StageSetupItems(store, keyers, radio, keyer, cluster, report);
      CheckTrue(staged = [siRadio, siKeyer, siCluster], 'all three landed');

      (* READ THE STORES BACK. *)
      CheckEquals(1, store.RadioCount, 'one radio');
      CheckEquals('IC-7300', store.Radio(0).Name, 'the radio kept its name');
      CheckEquals(1, keyers.KeyerCount, 'one keyer');
      CheckEquals('SERIAL 5', keyers.Keyer(0).Port, 'the keyer kept its port');

      profile := store.ActiveProfile;
      Check(profile <> nil, 'a profile is active');
      if profile <> nil then
         begin
         CheckEquals(SETUP_PROFILE_NAME, profile.Name, 'the setup profile');
         CheckEquals(store.Radio(0).Id, profile.Radio1Id, 'radio 1 is the new radio');
         CheckEquals('', profile.Radio2Id, 'slot 2 left empty');
         CheckEquals(keyers.Keyer(0).Id, profile.CWOutput1Id, 'CW 1 is the keyer, by id');
         CheckEquals('WinKeyer', profile.CWOutput1, 'and by its readable name');
         end;

      CheckEquals(1, store.ClusterCount, 'one cluster');
      Check(store.ActiveCluster <> nil, 'the cluster is active');
      CheckEquals('dxc.example.net', store.Cluster(0).Name, 'named from its host');
      CheckEquals('dxc.example.net:7373', store.Cluster(0).Server, 'server kept whole');

      CheckTrue(store.Validate(err), 'the store the wizard leaves is valid: ' + err);
      CheckTrue(keyers.Validate(err), 'the keyer store is valid: ' + err);

      (* COPIED, NEVER CONSUMED: the drafts are still the caller's. *)
      Check(store.Radio(0) <> radio, 'the store holds a copy of the radio');
      Check(keyers.Keyer(0) <> keyer, 'the store holds a copy of the keyer');
      Check(store.Cluster(0) <> cluster, 'the store holds a copy of the cluster');
      Check(report <> '', 'each item is reported');
   finally
      cluster.Free;
      keyer.Free;
      radio.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure TSetupWizardTests.TestStageTwiceMakesNamesUnique;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   cluster: TClusterDefinition;
   staged: TSetupItems;
   report: string;
begin
   BeginTest('TestStageTwiceMakesNamesUnique');
   (* A SECOND RUN FROM THE TOOLS MENU with the same names must add, not fail. *)
   store   := TRadioConfigStore.Create;
   keyers  := TKeyerConfigStore.Create;
   radio   := TRadioDefinition.Create;
   keyer   := TKeyerDefinition.Create;
   cluster := TClusterDefinition.Create;
   try
      radio.Name := 'Radio';
      keyer.Name := 'WinKeyer';
      keyer.Port := 'SERIAL 5';
      cluster.Server := 'dxc.example.net';
      report := '';
      StageSetupItems(store, keyers, radio, keyer, cluster, report);

      (* A fresh draft, as a second run of the wizard would hold. *)
      radio.Free;
      radio := TRadioDefinition.Create;
      radio.Name := 'Radio';
      staged := StageSetupItems(store, keyers, radio, keyer, cluster, report);

      CheckTrue(staged = [siRadio, siKeyer, siCluster], 'the second run landed too');
      CheckEquals(2, store.RadioCount, 'two radios');
      Check(not SameText(store.Radio(0).Name, store.Radio(1).Name), 'radio names differ');
      CheckEquals(2, keyers.KeyerCount, 'two keyers');
      Check(not SameText(keyers.Keyer(0).Name, keyers.Keyer(1).Name), 'keyer names differ');
      CheckEquals(2, store.ClusterCount, 'two clusters');
      CheckEquals(store.Cluster(1).Name, store.ActiveClusterName,
                  'the newest cluster is the active one');
      CheckEquals(1, store.ProfileCount, 'one profile, reused');
      CheckEquals(store.Radio(1).Id, store.ActiveProfile.Radio1Id,
                  'radio 1 is the newest radio');
   finally
      cluster.Free;
      keyer.Free;
      radio.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure TSetupWizardTests.TestStageUsesTheActiveProfile;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   existing: TStationProfile;
   radio: TRadioDefinition;
   report, err: string;
begin
   BeginTest('TestStageUsesTheActiveProfile');
   (* An existing station's active profile gets the radio -- no "Default"
     is invented beside it. *)
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   radio  := TRadioDefinition.Create;
   try
      existing := TStationProfile.Create;
      existing.Name := 'Contest';
      CheckTrue(store.AddProfile(existing, err), 'set-up profile added: ' + err);
      store.ActiveProfileName := 'Contest';

      radio.Name := 'K3';
      report := '';
      StageSetupItems(store, keyers, radio, nil, nil, report);

      CheckEquals(1, store.ProfileCount, 'no second profile');
      CheckEquals('Contest', store.ActiveProfileName, 'still the operator''s profile');
      CheckEquals(store.Radio(0).Id, store.ActiveProfile.Radio1Id,
                  'the radio went into its slot 1');
   finally
      radio.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure TSetupWizardTests.TestClusterBaseName;
var
   c: TClusterDefinition;
begin
   BeginTest('TestClusterBaseName');
   c := TClusterDefinition.Create;
   try
      c.Server := 'dxc.example.net:7373';
      CheckEquals('dxc.example.net', SetupClusterBaseName(c), 'host part');
      c.Server := 'node.example.org';
      CheckEquals('node.example.org', SetupClusterBaseName(c), 'no port');
      c.Server := '';
      CheckEquals(string(SDefaultClusterName), SetupClusterBaseName(c), 'nothing to go on');
      c.Name := 'Club node';
      CheckEquals('Club node', SetupClusterBaseName(c), 'a given name wins');
   finally
      c.Free;
   end;
   CheckEquals('', SetupClusterBaseName(nil), 'nil is empty');
end;

procedure TSetupWizardTests.TestGridSquareCase;
begin
   BeginTest('TestGridSquareCase');
   CheckEquals('EL88', NormalizeGridSquare('el88'), 'four characters are capitals and digits');
   CheckEquals('EL88pa', NormalizeGridSquare('EL88PA'), 'the subsquare is lower case');
   CheckEquals('EL88pa', NormalizeGridSquare(' el88pa '), 'trimmed, standard case');
   CheckEquals('EL88pa55xx', NormalizeGridSquare('el88pa55XX'), 'extended locator');
   CheckEquals('', NormalizeGridSquare(''), 'empty stays empty');
end;

procedure TSetupWizardTests.TestClusterServerSplit;
var
   host, port: string;
begin
   BeginTest('TestClusterServerSplit');
   SplitClusterServer('dxc.nc7j.com:7373', host, port);
   CheckEquals('dxc.nc7j.com', host, 'host:port host');
   CheckEquals('7373', port, 'host:port port');
   SplitClusterServer('192.168.1.5', host, port);
   CheckEquals('192.168.1.5', host, 'bare IP');
   CheckEquals('', port, 'no port given');
   SplitClusterServer('  dxc.example.net:23  Some Node', host, port);
   CheckEquals('dxc.example.net', host, 'a directory line drops the description');
   CheckEquals('23', port, 'its port');
   CheckEquals('host:99', JoinClusterServer(' host ', '99'), 'joined');
   CheckEquals('host', JoinClusterServer('host', ''), 'no port, no colon');
   CheckTrue(IsValidClusterPort(''), 'blank is the standard port');
   CheckTrue(IsValidClusterPort('7373'), 'a port');
   CheckFalse(IsValidClusterPort('0'), 'zero');
   CheckFalse(IsValidClusterPort('65536'), 'too big');
   CheckFalse(IsValidClusterPort('12a'), 'not a number');
   CheckFalse(IsValidClusterPort('99999999999'), 'too long to convert');
end;

procedure TSetupWizardTests.TestStageCarriesTheCWChoices;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   report: string;
begin
   BeginTest('TestStageCarriesTheCWChoices');
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   radio  := TRadioDefinition.Create;
   keyer  := TKeyerDefinition.Create;
   try
      radio.Name := 'K4';
      radio.CWByCAT := True;
      radio.CWSpeedSync := True;
      report := '';
      StageSetupItems(store, keyers, radio, nil, nil, report);
      CheckEquals(CWOUTPUT_CAT, store.ActiveProfile.CWOutput1, 'CW by CAT is the slot 1 output');
      CheckTrue(store.ActiveProfile.SpeedSync1, 'speed sync is on');
      CheckFalse(store.Radio(0).CWByCAT, 'the radio itself does not carry the flag');

      (* A WinKeyer on its own page takes the slot's CW output. *)
      keyer.Name := 'WinKeyer';
      keyer.Port := 'COM3';
      report := '';
      StageSetupItems(store, keyers, radio, keyer, nil, report);
      CheckEquals('WinKeyer', store.ActiveProfile.CWOutput1, 'the keyer wins over CAT');
   finally
      keyer.Free;
      radio.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure TSetupWizardTests.TestDetailLinesNeverShowAPassword;
var
   radio: TRadioDefinition;
   cluster: TClusterDefinition;
   text: string;
begin
   BeginTest('TestDetailLinesNeverShowAPassword');
   radio := TRadioDefinition.Create;
   cluster := TClusterDefinition.Create;
   try
      radio.Transport := rtNetwork;
      radio.NetworkUsername := 'op';
      radio.NetworkPassword := 'sekret-radio';
      cluster.Password := 'sekret-cluster';
      text := SetupDetailLines(radio, nil, cluster);
      CheckTrue(Pos('op', text) > 0, 'the user name is shown');
      CheckEquals(0, Pos('sekret', text), 'no password is ever shown');
   finally
      cluster.Free;
      radio.Free;
   end;
end;

procedure TSetupWizardTests.TestPlanWithEveryItem;
begin
   BeginTest('TestPlanWithEveryItem');
   CheckEquals('Station,Checklist,Radio,Keyer,Cluster,Logger,Rotator,WSJTX,Result',
               PlanText(SetupPagePlan([siWSJTX, siRotator, siLogger,
                                       siCluster, siKeyer, siRadio])),
               'the canonical order: radio, keyer, cluster, logger, rotator, WSJT-X');
   CheckEquals('Station,Checklist,Logger,WSJTX,Result',
               PlanText(SetupPagePlan([siWSJTX, siLogger])),
               'only the ticked pages, still in order');
   CheckTrue(IsCommitPage(SetupPagePlan([siRotator]), 2),
             'a lone rotator page is the commit page');
end;

function NewRotatorDraft(const aId, aPort: string): TRotatorDefinition;
begin
   Result := TRotatorDefinition.Create;
   Result.RotatorId := aId;
   Result.ControlPort := aPort;
end;

procedure TSetupWizardTests.TestStageRotatorIsActiveAndUnique;
var
   store: TRadioConfigStore;
   draft: TRotatorDefinition;
   report: string;
begin
   BeginTest('TestStageRotatorIsActiveAndUnique');
   store := TRadioConfigStore.Create;
   draft := NewRotatorDraft('YAESU', 'SERIAL 4');
   try
      report := '';
      CheckTrue(StageSetupRotator(store, draft, report), 'the rotator landed');
      CheckEquals(1, store.RotatorCount, 'one rotator in the library');
      CheckEquals(string(SDefaultRotatorName), store.Rotator(0).Name,
                  'named as Preferences'' Add names one');
      CheckEquals('YAESU', store.Rotator(0).RotatorId, 'the type, by registry id');
      CheckEquals('SERIAL 4', store.Rotator(0).ControlPort, 'the port as drafted');
      CheckEquals('', store.Rotator(0).Bands, 'every band');
      CheckEquals(store.Rotator(0).Id, store.ActiveRotatorId, 'made the active rotator, by id');
      CheckEquals(store.Rotator(0).Name, store.ActiveRotatorName, 'and the readable mirror');
      CheckTrue(store.Rotator(0) <> draft, 'a copy, not the draft');
      CheckTrue(Pos('Yaesu', report) > 0, 'the report names the type');

      (* A second run, from the Tools menu: a second rotator, and it turns. *)
      CheckTrue(StageSetupRotator(store, draft, report), 'the second landed too');
      CheckEquals(2, store.RotatorCount, 'two rotators');
      CheckEquals(string(SDefaultRotatorName) + ' 2', store.Rotator(1).Name,
                  'the store''s own unique name');
      CheckEquals(store.Rotator(1).Id, store.ActiveRotatorId, 'the newest is the one that turns');
      CheckTrue(store.Rotator(0).Id <> store.Rotator(1).Id, 'each its own id');
   finally
      draft.Free;
      store.Free;
   end;
end;

procedure TSetupWizardTests.TestStageNetworkRotatorSaysDefaultAddress;
var
   store: TRadioConfigStore;
   draft: TRotatorDefinition;
   report: string;
begin
   BeginTest('TestStageNetworkRotatorSaysDefaultAddress');
   store := TRadioConfigStore.Create;
   draft := NewRotatorDraft('PSTROTATOR', 'NONE');
   try
      report := '';
      CheckTrue(StageSetupRotator(store, draft, report), 'a UDP rotator with no address lands');
      CheckTrue(Pos(string(SWizResDefaultAddress), report) > 0,
                'blank address and port: the program''s defaults, and the report says so: '
                + report);

      draft.IPAddress := '192.168.1.9';
      draft.UDPPort := 12000;
      report := '';
      CheckTrue(StageSetupRotator(store, draft, report), 'with an address');
      CheckTrue(Pos('192.168.1.9:12000', report) > 0, 'the address is reported: ' + report);
   finally
      draft.Free;
      store.Free;
   end;
end;

function NewLoggerDraft(const aName, aProvider: string): TExternalLoggerDefinition;
begin
   Result := TExternalLoggerDefinition.Create;
   Result.Name := aName;
   Result.ProviderId := aProvider;
   Result.Address := '127.0.0.1';
   Result.Port := DXKEEPER_DEFAULT_PORT;
end;

procedure TSetupWizardTests.TestStageLoggerAddsAndActivates;
var
   config: TExternalLoggerConfig;
   draft: TExternalLoggerDefinition;
   report: string;
begin
   BeginTest('TestStageLoggerAddsAndActivates');
   config := TExternalLoggerConfig.Create;
   draft := NewLoggerDraft('Logger 1', 'DXKEEPER');
   try
      config.Present := True;   // as SeedExternalLoggers leaves it
      report := '';
      CheckTrue(StageSetupLogger(config, draft, True, report), 'the logger landed');
      CheckEquals(1, config.Definitions.Count, 'one definition');
      CheckEquals(draft.Id, config.Definitions[0].Id, 'with the editor''s id');
      CheckTrue(config.Definitions[0] <> draft, 'a copy, not the draft');
      CheckEquals(1, config.ActivePosition(draft.Id), 'switched on, first to deliver');
      CheckTrue(Pos('DXKeeper', report) > 0, 'the report names the provider: ' + report);

      (* A second one with the same name, not switched on. *)
      draft.Id := 'second-id';
      report := '';
      CheckTrue(StageSetupLogger(config, draft, False, report), 'the second landed');
      CheckEquals('Logger 1 2', config.Definitions[1].Name, 'a unique name, the store''s way');
      CheckEquals(0, config.ActivePosition('second-id'), 'not switched on');
      CheckTrue(Pos('Logger 1 2', report) > 0, 'the report names it: ' + report);
   finally
      draft.Free;
      config.Free;
   end;
end;

procedure TSetupWizardTests.TestStageLoggerRefusesAnUnseededLibrary;
var
   config: TExternalLoggerConfig;
   draft: TExternalLoggerDefinition;
   report: string;
begin
   BeginTest('TestStageLoggerRefusesAnUnseededLibrary');
   config := TExternalLoggerConfig.Create;
   draft := NewLoggerDraft('Logger 1', 'DXKEEPER');
   try
      report := '';
      CheckFalse(StageSetupLogger(config, draft, True, report),
                 'a library nobody seeded would hide a legacy logger: refused');
      CheckEquals(0, config.Definitions.Count, 'nothing added');
      CheckFalse(config.Present, 'and not marked present behind the seed''s back');
      CheckTrue(report <> '', 'the refusal is reported');
   finally
      draft.Free;
      config.Free;
   end;
end;

procedure TSetupWizardTests.TestStageLoggerTakesBackAnInvalidDefinition;
var
   config: TExternalLoggerConfig;
   draft: TExternalLoggerDefinition;
   report: string;
begin
   BeginTest('TestStageLoggerTakesBackAnInvalidDefinition');
   config := TExternalLoggerConfig.Create;
   draft := NewLoggerDraft('Logger 1', '');   // no provider: Validate refuses
   try
      config.Present := True;
      report := '';
      CheckFalse(StageSetupLogger(config, draft, True, report), 'refused');
      CheckEquals(0, config.Definitions.Count, 'taken back out');
      CheckEquals(0, config.ActiveIds.Count, 'and out of the delivery order');
      CheckTrue(Pos('not saved', report) > 0, 'the reason is reported: ' + report);
   finally
      draft.Free;
      config.Free;
   end;
end;

(* WHAT CREATE WRITES: the key goes to the keychain and the file holds only a
  reference to it -- through the definitions' own SaveJSON, which is what
  SaveConfig calls.  The in-memory keychain stands in for the OS one. *)
procedure TSetupWizardTests.TestStageLoggerKeepsTheSecretOutOfTheFile;
var
   config: TExternalLoggerConfig;
   draft: TExternalLoggerDefinition;
   root: TJSONObject;
   report, json: string;
begin
   BeginTest('TestStageLoggerKeepsTheSecretOutOfTheFile');
   InstallTestKeychain;
   config := TExternalLoggerConfig.Create;
   draft := NewLoggerDraft('Club Log', 'CLUBLOG');
   root := TJSONObject.Create;
   try
      draft.ApiKey := 'wizard-fixture-secret';
      config.Present := True;
      report := '';
      CheckTrue(StageSetupLogger(config, draft, False, report), 'staged');
      CheckEquals('wizard-fixture-secret', config.Definitions[0].ApiKey,
                  'held in memory until the save');
      config.SaveJSON(root);
      json := root.ToJSON;
      CheckEquals(0, Pos('wizard-fixture-secret', json), 'the key is not in the file');
      CheckTrue(Pos('apiKey' + KEYCHAIN_REF_SUFFIX, json) > 0,
                'the file holds a keychain reference: ' + json);
   finally
      root.Free;
      draft.Free;
      config.Free;
   end;
end;

procedure TSetupWizardTests.RunAllTests;
begin
   TestPlanWithEveryItem;
   TestStageRotatorIsActiveAndUnique;
   TestStageNetworkRotatorSaysDefaultAddress;
   TestStageLoggerAddsAndActivates;
   TestStageLoggerRefusesAnUnseededLibrary;
   TestStageLoggerTakesBackAnInvalidDefinition;
   TestStageLoggerKeepsTheSecretOutOfTheFile;
   TestGridSquareCase;
   TestClusterServerSplit;
   TestStageCarriesTheCWChoices;
   TestDetailLinesNeverShowAPassword;
   TestPlanWithNothingTicked;
   TestPlanIsCanonicalOrder;
   TestCommitPageIsBeforeResult;
   TestIndexOfMissingPage;
   TestDueOnlyOnBrandNewInstall;
   TestStageNothing;
   TestStageAllThree;
   TestStageTwiceMakesNamesUnique;
   TestStageUsesTheActiveProfile;
   TestClusterBaseName;
end;

end.
