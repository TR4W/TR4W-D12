unit uSetupWizard;

(* THE SETUP WIZARD'S RULES, WITHOUT ITS WINDOW.

  Two questions the wizard asks, answered here so a unit test can pin them
  without streaming a form -- see docs/SETUP_WIZARD_DESIGN.md:

    WHICH PAGES, IN WHAT ORDER.  One Station page, one checklist, then one
    page per ticked item in CANONICAL order (Radio, CW keyer, DX cluster,
    external logger, rotator, WSJT-X) whatever order the boxes were ticked
    in, then the result page.  A support instruction such as "the third page"
    therefore means one thing.

    WHETHER IT IS OFFERED AT STARTUP.  While the station has no callsign
    stored, and never in a headless run, where there is no operator and a
    window is a hang.  There is no once-only flag: an operator who cancelled
    has configured nothing and is asked again, and the moment a callsign is
    stored (the wizard, or New Contest -- which will not take an empty one)
    the station is configured and the question stops on its own.

    WHAT THE OPTIONAL ITEMS PUT IN THE STORES.  StageSetupItems copies the
    wizard's drafts into the radio, keyer and cluster libraries and points a
    profile at them; StageSetupRotator and StageSetupLogger do the same for
    the rotator library and the external logger definitions (issue 334) --
    through each store's own API, so the wizard declares no field of its own
    (design 3.1).  A test reads the stores back.  WSJT-X is not a store: it
    is three settings, written by the form through ApplyAndStoreCommand.

  NEARLY A LEAF: no LCL, no settings object, no live radio.  The stores it
  stages into are RTL-only units.  The window (uSetupWizardForm) and startup
  (uProgramMain) ask; this unit only answers. *)

{$I tr4w.inc}

interface

uses
   uRadioConfigStore,
   uKeyerConfigStore,
   uExternalLoggerConfig;

const
   (* The profile the wizard creates when the station has none active.  A
     NAME, not a caption: it is data in the operator's file, like any profile
     name they type, and is not translated. *)
   SETUP_PROFILE_NAME = 'Default';

type
   (* THE OPTIONAL ITEMS, in their canonical order.  The ordinal order IS the
     page order, so adding an item means choosing where it goes here. *)
   TSetupItem  = (siRadio, siKeyer, siCluster, siLogger, siRotator, siWSJTX);
   TSetupItems = set of TSetupItem;

   (* Every page the wizard has.  spResult is shown after "Create
     configuration" and says what landed and what did not. *)
   TSetupPage  = (spStation, spChecklist, spRadio, spKeyer, spCluster,
                  spLogger, spRotator, spWSJTX, spResult);

   TSetupPagePlan = array of TSetupPage;

(* [Station, Checklist] + the ticked items' pages in canonical order +
  [Result].  Recomputed whenever the checklist changes; the page control only
  DISPLAYS the plan, it never holds it. *)
function SetupPagePlan(const aTicked: TSetupItems): TSetupPagePlan;

(* Where aPage sits in aPlan, or -1 when the plan does not contain it -- an
  item that was unticked while its page was showing. *)
function IndexOfSetupPage(const aPlan: TSetupPagePlan;
                          const aPage: TSetupPage): integer;

(* The page whose Next button reads "Create configuration": the one just
  before the result page. *)
function IsCommitPage(const aPlan: TSetupPagePlan; const aIndex: integer): boolean;

(* WHETHER STARTUP OFFERS THE WIZARD.

  aHeadless           /EXPORT and the other batch modes -- never.
  aStationHasCallsign whether a callsign is stored (StartupMainCallsign, read
                      from the file; nothing is assigned or saved that early).
                      A settings FILE is not the test: a file can exist with
                      nothing in it, which is what a cancelled first run and
                      the programs that write flags leave behind. *)
function SetupWizardDueAtStartup(const aHeadless: boolean;
                                 const aStationHasCallsign: boolean): boolean;

(* COPY THE DRAFTS INTO THE STORES.

  aRadio, aKeyer, aCluster: the wizard's drafts, nil for an item that was not
  ticked.  NEVER CONSUMED -- each is copied, so the caller frees its own
  drafts whatever happens here.

  Each item is staged INDEPENDENTLY: one that the store refuses is reported
  and the others still land (design section 5).  A name already in use is
  made unique the store's own way rather than refused.

  A radio goes into slot 1 and a keyer becomes slot 1's CW output, of the
  ACTIVE profile -- or of profile SETUP_PROFILE_NAME, created when the station
  has no active profile -- and that profile is made the active one.  A
  cluster becomes the active cluster.

  One line per item is added to aReport (operator-facing, uAppStrings).
  Returns the items that landed.  Nothing is written to disk here and nothing
  is applied to a running radio: that is the caller's, after it has
  validated and saved the stores. *)
function StageSetupItems(const aStore: TRadioConfigStore;
                         const aKeyers: TKeyerConfigStore;
                         const aRadio: TRadioDefinition;
                         const aKeyer: TKeyerDefinition;
                         const aCluster: TClusterDefinition;
                         var aReport: string): TSetupItems;

(* COPY THE ROTATOR DRAFT INTO THE ROTATOR LIBRARY (issue 334).

  aRotator is copied, never consumed.  Its name is made unique the store's
  way (a blank name starts from SDefaultRotatorName, as Preferences' Add
  does), and it is made THE ACTIVE ROTATOR -- by id, with the name as the
  readable mirror, which is what Preferences' "Use this" writes -- because
  only the active rotator turns, and an operator who set up one rotator
  means that one.  Its band claim is left as drafted: blank is every band.

  True when it landed.  One line is added to aReport either way. *)
function StageSetupRotator(const aStore: TRadioConfigStore;
                           const aRotator: TRotatorDefinition;
                           var aReport: string): boolean;

(* COPY THE EXTERNAL LOGGER DRAFT INTO THE DEFINITIONS (issue 334).

  aDefinition is the hosted editor's accepted definition, copied with its id
  and never consumed.  aActive puts it LAST in the delivery order, the rule
  of the editor's own Active box.

  THE CALLER SEEDS aConfig FIRST, the way startup does
  (uExternalLoggerMigration.SeedExternalLoggers): on a file that predates
  the definitions, that is what carries an upgrader's single legacy logger
  across, and adding to an unseeded library would mark it Present with that
  logger missing.  So a library that is not Present is refused here rather
  than silently made so.  Refused, too, when it could not be read
  (aConfig.Error) -- its file section is preserved, never written over --
  and when it does not validate with the definition added, which is then
  taken back out.  A name already in use is made unique the way the store
  makes a rotator's or a cluster's: "Logger 1 2".

  Secrets stay in the definition; SaveConfig hands them to the OS keychain
  (TExternalLoggerDefinition.ToJSON).  Nothing is written here. *)
function StageSetupLogger(const aConfig: TExternalLoggerConfig;
                          const aDefinition: TExternalLoggerDefinition;
                          const aActive: boolean;
                          var aReport: string): boolean;

(* Appends one line to a result-page report. *)
procedure AddReportLine(var aReport: string; const aLine: string);

(* The name a new cluster is stored under when the operator gave none: the
  host part of 'host:port', or SDefaultClusterName. *)
function SetupClusterBaseName(const aCluster: TClusterDefinition): string;

(* A MAIDENHEAD LOCATOR IN ITS STANDARD CASE.  The field letters are capitals
  and the subsquare letters lower case: EL88pa, and EL88 when only four
  characters are given.  Digits and anything else are left as typed.  Applied
  to what the operator typed, never to what the program derived. *)
function NormalizeGridSquare(const aGrid: string): string;

(* A CLUSTER SERVER AS THE OPERATOR MAY WRITE IT -- 'host', 'host:port', an IP
  address with or without a port, or a TRCLUSTER.DAT line with a description
  after the address -- split into the host and the port text.  aPort is ''
  when none was given.  JoinClusterServer is the spelling the cluster store
  keeps. *)
procedure SplitClusterServer(const aText: string; out aHost, aPort: string);
function JoinClusterServer(const aHost, aPort: string): string;

(* '' (the standard port) or a whole number from 1 to 65535. *)
function IsValidClusterPort(const aPort: string): boolean;

(* THE LINES THE RESULT PAGE SHOWS ON REQUEST: what the brief lines leave out
  of the radio, the keyer and the cluster just staged.  Never a password, only
  whether one was set.  aCluster and the others may each be nil. *)
function SetupDetailLines(const aRadio: TRadioDefinition;
                          const aKeyer: TKeyerDefinition;
                          const aCluster: TClusterDefinition): string;

implementation

uses
   SysUtils,
   uPortAddress,        // DeviceNameFromStoredPort
   uRadioRegistry,      // DisplayNameId
   uRotatorRegistry,    // RotatorDisplayName, RotatorUsesSerialPort
   uExternalLoggerRegistry,   // FindExternalLoggerRegistration -- the display name
   uAppStrings;

function SetupPagePlan(const aTicked: TSetupItems): TSetupPagePlan;
const
   (* The item's page.  A case would do as well; a table keeps the canonical
     order in ONE place -- the enum's own. *)
   PAGE_OF_ITEM: array[TSetupItem] of TSetupPage =
      (spRadio, spKeyer, spCluster, spLogger, spRotator, spWSJTX);
var
   item: TSetupItem;
   n: integer;
begin
   Result := nil;
   SetLength(Result, 2 + Ord(High(TSetupItem)) + 1 + 1);
   n := 0;

   Result[n] := spStation;
   Inc(n);
   Result[n] := spChecklist;
   Inc(n);

   for item := Low(TSetupItem) to High(TSetupItem) do
      begin
      if item in aTicked then
         begin
         Result[n] := PAGE_OF_ITEM[item];
         Inc(n);
         end;
      end;

   Result[n] := spResult;
   Inc(n);

   SetLength(Result, n);
end;

function IndexOfSetupPage(const aPlan: TSetupPagePlan;
                          const aPage: TSetupPage): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(aPlan) do
      begin
      if aPlan[i] = aPage then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function IsCommitPage(const aPlan: TSetupPagePlan; const aIndex: integer): boolean;
begin
   Result := (aIndex >= 0)                  and
             (aIndex + 1 <= High(aPlan))    and
             (aPlan[aIndex + 1] = spResult);
end;

function SetupWizardDueAtStartup(const aHeadless: boolean;
                                 const aStationHasCallsign: boolean): boolean;
begin
   Result := (not aHeadless) and (not aStationHasCallsign);
end;

function SetupClusterBaseName(const aCluster: TClusterDefinition): string;
var
   colon: integer;
begin
   Result := '';
   if aCluster = nil then
      begin
      Exit;
      end;

   Result := Trim(aCluster.Name);
   if Result <> '' then
      begin
      Exit;
      end;

   Result := Trim(aCluster.Server);
   colon := Pos(':', Result);
   if colon > 0 then
      begin
      Result := Trim(Copy(Result, 1, colon - 1));
      end;

   if Result = '' then
      begin
      Result := SDefaultClusterName;
      end;
end;

(* A string rather than a TStrings: the RTL's
  TStrings holds the 8-bit string, and every Add of this program's text would
  be a narrowing the build counts. *)
procedure AddReportLine(var aReport: string; const aLine: string);
begin
   if aReport <> '' then
      begin
      aReport := aReport + sLineBreak;
      end;
   aReport := aReport + aLine;
end;

(* "on COM3" or "at 192.168.1.5:9200": how the radio is reached, for the result
  page.  A serial name stored the old way ('SERIAL 3') is shown as the port. *)
function RadioConnectionPhrase(const aRadio: TRadioDefinition): string;
var
   addr: string;
   portName: string;
begin
   if aRadio.Transport = rtNetwork then
      begin
      addr := Trim(aRadio.IPAddress);
      if aRadio.TCPPort > 0 then
         begin
         addr := addr + ':' + IntToStr(aRadio.TCPPort);
         end;
      Result := UnicodeFormat(SWizResAtAddress, [addr]);
      Exit;
      end;

   portName := DeviceNameFromStoredPort(Trim(aRadio.ControlPort));
   if (portName = '') or UnicodeSameText(portName, PORT_NONE) then
      begin
      Result := SWizResNoPort;
      end
   else
      begin
      Result := UnicodeFormat(SWizResOnPort, [portName]);
      end;
end;

(* Blank means "log in as my station callsign", which the wizard cannot name
  here -- the callsign may change later and the cluster follows it. *)
function ClusterLoginShown(const aCluster: TClusterDefinition): string;
begin
   Result := Trim(aCluster.LoginCall);
   if Result = '' then
      begin
      Result := SWizResLoginAsStation;
      end;
end;

function OnOff(const aValue: boolean): string;
begin
   if aValue then
      begin
      Result := SWizDetOn;
      end
   else
      begin
      Result := SWizDetOff;
      end;
end;

(* The profile the radio and keyer go into: the active one, else the setup
  profile, created when it does not exist.  nil only when the store refuses
  to add it, and that reason is reported. *)
function ProfileForSetup(const aStore: TRadioConfigStore;
                         var aReport: string): TStationProfile;
var
   err: string;
begin
   Result := aStore.ActiveProfile;
   if Result <> nil then
      begin
      Exit;
      end;

   Result := aStore.FindProfile(SETUP_PROFILE_NAME);
   if Result <> nil then
      begin
      Exit;
      end;

   Result := TStationProfile.Create;
   Result.Name := SETUP_PROFILE_NAME;
   if not aStore.AddProfile(Result, err) then
      begin
      Result.Free;
      Result := nil;
      AddReportLine(aReport, UnicodeFormat(SWizResRadioFailed, [err]));
      end;
end;

function StageSetupItems(const aStore: TRadioConfigStore;
                         const aKeyers: TKeyerConfigStore;
                         const aRadio: TRadioDefinition;
                         const aKeyer: TKeyerDefinition;
                         const aCluster: TClusterDefinition;
                         var aReport: string): TSetupItems;
var
   radio: TRadioDefinition;
   keyer: TKeyerDefinition;
   keyerName: string;
   cluster: TClusterDefinition;
   profile: TStationProfile;
   err: string;
   wantCAT, wantSpeedSync: boolean;
begin
   Result := [];
   radio := nil;
   keyer := nil;
   wantCAT := False;
   wantSpeedSync := False;

   if (aStore = nil) or (aKeyers = nil) then
      begin
      Exit;
      end;

   (* THE RADIO.  A clone, renamed only if the name is taken, so a second run
     from the Tools menu adds "IC-7300 (2)" rather than failing on the first
     run's radio. *)
   if aRadio <> nil then
      begin
      radio := aRadio.Clone;
      radio.Name := aStore.UniqueRadioName(radio.Name);
      (* THE DRAFT CARRIES THE TWO CW CHOICES in the radio's own CW fields,
        which are where the wizard's checkboxes write; they belong to the
        PROFILE, so they are read here and not stored on the radio. *)
      wantCAT       := radio.CWByCAT;
      wantSpeedSync := radio.CWSpeedSync;
      radio.CWByCAT     := False;
      radio.CWSpeedSync := False;
      if aStore.AddRadio(radio, err) then
         begin
         Include(Result, siRadio);
         AddReportLine(aReport, UnicodeFormat(SWizResRadio,
                                              [DisplayNameId(radio.RegistryId),
                                               RadioConnectionPhrase(radio),
                                               radio.Name]));
         end
      else
         begin
         radio.Free;
         radio := nil;
         AddReportLine(aReport, UnicodeFormat(SWizResRadioFailed, [err]));
         end;
      end;

   (* THE KEYER.  AddKeyer cannot refuse; the name is made unique first and
     kept across the Assign, which copies the draft's name too. *)
   if aKeyer <> nil then
      begin
      keyerName := aKeyers.UniqueKeyerName(aKeyer.Name);
      keyer := aKeyers.AddKeyer(keyerName, aKeyer.Kind);
      keyer.Assign(aKeyer);
      keyer.Name := keyerName;
      Include(Result, siKeyer);
      AddReportLine(aReport, UnicodeFormat(SWizResKeyer,
                                           [keyer.Name,
                                            DeviceNameFromStoredPort(keyer.Port)]));
      end;

   (* THE PROFILE that puts them on the air, only when one of them landed. *)
   if (radio <> nil) or (keyer <> nil) then
      begin
      profile := ProfileForSetup(aStore, aReport);
      if profile <> nil then
         begin
         if radio <> nil then
            begin
            aStore.SetProfileRadioByName(profile, 1, radio.Name);
            end;
         if keyer <> nil then
            begin
            profile.CWOutput1   := keyer.Name;
            profile.CWOutput1Id := keyer.Id;
            end
         else if (radio <> nil) and wantCAT then
            begin
            (* ONE CW OUTPUT PER SLOT: a WinKeyer chosen on its own page wins
              over CW by CAT. *)
            profile.CWOutput1   := CWOUTPUT_CAT;
            profile.CWOutput1Id := '';
            AddReportLine(aReport, SWizResCWByCAT);
            end;
         if (radio <> nil) and wantSpeedSync then
            begin
            profile.SpeedSync1 := True;
            AddReportLine(aReport, SWizResSpeedSync);
            end;
         aStore.ActiveProfileName := profile.Name;
         (* SAY WHERE THEY WENT.  The operator never chose a profile; naming it
           and the page that edits it is what makes "Default" a thing they can
           find rather than a name that appears later. *)
         AddReportLine(aReport, UnicodeFormat(SWizResProfile, [profile.Name]));
         end;
      end;

   (* THE CLUSTER, made the active one -- an operator who set up exactly one
     cluster means that one, the rule Preferences' Add button follows. *)
   if aCluster <> nil then
      begin
      cluster := TClusterDefinition.Create;
      cluster.Assign(aCluster);
      cluster.Name := aStore.UniqueClusterName(SetupClusterBaseName(aCluster));
      if aStore.AddCluster(cluster) then
         begin
         aStore.ActiveClusterName := cluster.Name;
         Include(Result, siCluster);
         AddReportLine(aReport, UnicodeFormat(SWizResCluster,
                                              [cluster.Name,
                                               cluster.Server,
                                               ClusterLoginShown(cluster)]));
         end
      else
         begin
         // AddCluster frees nothing on refusal -- this still owns it.
         cluster.Free;
         AddReportLine(aReport, SWizResClusterFailed);
         end;
      end;
end;

(* "on COM3" or "at 127.0.0.1:12000": how the rotator is reached, asked of the
  DRIVER (serial or not), never of a list of type names here.  A network
  rotator left blank uses the program's defaults (uRotatorControl), so blank
  says nothing rather than a wrong address. *)
function RotatorConnectionPhrase(const aRotator: TRotatorDefinition): string;
var
   addr, portName: string;
   baud: integer;
begin
   if not RotatorUsesSerialPort(aRotator.RotatorId, baud) then
      begin
      addr := Trim(aRotator.IPAddress);
      if aRotator.UDPPort > 0 then
         begin
         addr := addr + ':' + IntToStr(aRotator.UDPPort);
         end;
      if addr = '' then
         begin
         Result := SWizResDefaultAddress;
         end
      else
         begin
         Result := UnicodeFormat(SWizResAtAddress, [addr]);
         end;
      Exit;
      end;

   portName := DeviceNameFromStoredPort(Trim(aRotator.ControlPort));
   if (portName = '') or UnicodeSameText(portName, PORT_NONE) then
      begin
      Result := SWizResNoPort;
      end
   else
      begin
      Result := UnicodeFormat(SWizResOnPort, [portName]);
      end;
end;

function StageSetupRotator(const aStore: TRadioConfigStore;
                           const aRotator: TRotatorDefinition;
                           var aReport: string): boolean;
var
   rotator: TRotatorDefinition;
   base: string;
begin
   Result := False;
   if (aStore = nil) or (aRotator = nil) then
      begin
      Exit;
      end;

   rotator := TRotatorDefinition.Create;   // its own id, born with it
   rotator.Assign(aRotator);
   base := Trim(aRotator.Name);
   if base = '' then
      begin
      base := SDefaultRotatorName;
      end;
   rotator.Name := aStore.UniqueRotatorName(base);

   if not aStore.AddRotator(rotator) then
      begin
      // AddRotator frees nothing on refusal -- this still owns it.
      rotator.Free;
      AddReportLine(aReport, SWizResRotatorFailed);
      Exit;
      end;

   aStore.ActiveRotatorId   := rotator.Id;
   aStore.ActiveRotatorName := rotator.Name;
   Result := True;
   AddReportLine(aReport, UnicodeFormat(SWizResRotator,
                                        [rotator.Name,
                                         RotatorDisplayName(rotator.RotatorId),
                                         RotatorConnectionPhrase(rotator)]));
end;

(* aBase, or aBase 2, aBase 3 ... -- the store's own spelling of a second name
  (TRadioConfigStore.UniqueRotatorName and its siblings), compared without
  case as the definitions' Validate compares them. *)
function UniqueLoggerName(const aConfig: TExternalLoggerConfig;
                          const aBase: string): string;

   function Taken(const aName: string): boolean;
   var
      d: TExternalLoggerDefinition;
   begin
      Result := False;
      for d in aConfig.Definitions do
         begin
         if UnicodeSameText(d.Name, aName) then
            begin
            Result := True;
            Exit;
            end;
         end;
   end;

var
   n: integer;
begin
   Result := aBase;
   n := 2;
   while Taken(Result) do
      begin
      Result := aBase + ' ' + IntToStr(n);
      Inc(n);
      end;
end;

function StageSetupLogger(const aConfig: TExternalLoggerConfig;
                          const aDefinition: TExternalLoggerDefinition;
                          const aActive: boolean;
                          var aReport: string): boolean;
var
   definition: TExternalLoggerDefinition;
   registration: TExternalLoggerRegistration;
   provider, err: string;
begin
   Result := False;
   if (aConfig = nil) or (aDefinition = nil) then
      begin
      Exit;
      end;

   if aConfig.Error <> '' then
      begin
      AddReportLine(aReport, UnicodeFormat(SWizResLoggerFailed, [aConfig.Error]));
      Exit;
      end;
   if not aConfig.Present then
      begin
      (* The caller's mistake, not the operator's: say so in the same words. *)
      AddReportLine(aReport, UnicodeFormat(SWizResLoggerFailed,
                                           ['the external logger library was not loaded']));
      Exit;
      end;

   definition := TExternalLoggerDefinition.Create;
   definition.Assign(aDefinition);
   definition.Name := UniqueLoggerName(aConfig, Trim(definition.Name));
   aConfig.Definitions.Add(definition);   // owned by the list from here
   aConfig.SetActive(definition.Id, aActive);

   if not aConfig.Validate(err) then
      begin
      aConfig.SetActive(definition.Id, False);
      aConfig.Definitions.Remove(definition);   // frees it
      AddReportLine(aReport, UnicodeFormat(SWizResLoggerFailed, [err]));
      Exit;
      end;

   Result := True;
   provider := definition.ProviderId;
   if FindExternalLoggerRegistration(definition.ProviderId, registration) then
      begin
      provider := registration.DisplayName;
      end;
   if aActive then
      begin
      AddReportLine(aReport, UnicodeFormat(SWizResLoggerActive, [definition.Name, provider]));
      end
   else
      begin
      AddReportLine(aReport, UnicodeFormat(SWizResLoggerInactive, [definition.Name, provider]));
      end;
end;

function NormalizeGridSquare(const aGrid: string): string;
var
   i: integer;
   c: WideChar;
begin
   Result := Trim(aGrid);
   for i := 1 to Length(Result) do
      begin
      c := Result[i];
      (* ASCII letters only: a locator has no others, and a plain subtraction
        cannot be wrong for them. *)
      case i of
         1, 2:
            begin
            if (c >= 'a') and (c <= 'z') then
               begin
               Result[i] := WideChar(Ord(c) - 32);
               end;
            end;
         5, 6, 9, 10:
            begin
            if (c >= 'A') and (c <= 'Z') then
               begin
               Result[i] := WideChar(Ord(c) + 32);
               end;
            end;
      end;
      end;
end;

procedure SplitClusterServer(const aText: string; out aHost, aPort: string);
var
   text: string;
   i, colon: integer;
begin
   text := Trim(aText);
   (* A TRCLUSTER.DAT line carries a description after the address. *)
   i := 1;
   while (i <= Length(text)) and (text[i] > ' ') do
      begin
      Inc(i);
      end;
   text := Copy(text, 1, i - 1);

   colon := Pos(':', text);
   if colon > 0 then
      begin
      aHost := Copy(text, 1, colon - 1);
      aPort := Copy(text, colon + 1, MaxInt);
      end
   else
      begin
      aHost := text;
      aPort := '';
      end;
end;

function JoinClusterServer(const aHost, aPort: string): string;
begin
   Result := Trim(aHost);
   if (Result <> '') and (Trim(aPort) <> '') then
      begin
      Result := Result + ':' + Trim(aPort);
      end;
end;

function IsValidClusterPort(const aPort: string): boolean;
var
   text: string;
   i, value: integer;
begin
   text := Trim(aPort);
   Result := text = '';
   if Result then
      begin
      Exit;
      end;

   (* DIGITS AND AT MOST FIVE OF THEM, summed by hand: no RTL converter is
     needed, and none is range-checked on Win64 for a long digit string. *)
   if Length(text) > 5 then
      begin
      Exit;
      end;
   value := 0;
   for i := 1 to Length(text) do
      begin
      if (text[i] < '0') or (text[i] > '9') then
         begin
         Exit;
         end;
      value := value * 10 + (Ord(text[i]) - Ord('0'));
      end;
   Result := (value >= 1) and (value <= 65535);
end;

function SetupDetailLines(const aRadio: TRadioDefinition;
                          const aKeyer: TKeyerDefinition;
                          const aCluster: TClusterDefinition): string;
begin
   Result := '';

   if aRadio <> nil then
      begin
      if aRadio.Transport = rtNetwork then
         begin
         if Trim(aRadio.NetworkUsername) <> '' then
            begin
            AddReportLine(Result, UnicodeFormat(SWizDetNetworkUser,
                                                [Trim(aRadio.NetworkUsername)]));
            end;
         if aRadio.NetworkPassword <> '' then
            begin
            AddReportLine(Result, SWizDetNetworkPassword);
            end;
         end
      else
         begin
         AddReportLine(Result, UnicodeFormat(SWizDetSerial,
                                             [IntToStr(aRadio.BaudRate),
                                              aRadio.SerialFormat,
                                              aRadio.CatRTS,
                                              aRadio.CatDTR]));
         end;
      AddReportLine(Result, UnicodeFormat(SWizDetPolling,
                                          [OnOff(aRadio.PollingEnable),
                                           IntToStr(aRadio.FrequencyPollRate)]));
      if (Trim(aRadio.KeyerOutputPort) <> '') and
         (not UnicodeSameText(Trim(aRadio.KeyerOutputPort), PORT_NONE)) then
         begin
         AddReportLine(Result, UnicodeFormat(SWizDetKeyerPort,
                                             [DeviceNameFromStoredPort(Trim(aRadio.KeyerOutputPort))]));
         end;
      if Trim(aRadio.StartupCommand) <> '' then
         begin
         AddReportLine(Result, UnicodeFormat(SWizDetStartup, [Trim(aRadio.StartupCommand)]));
         end;
      end;

   if aKeyer <> nil then
      begin
      AddReportLine(Result, UnicodeFormat(SWizDetKeyerMode,
                                          [aKeyer.WKKeyerMode,
                                           aKeyer.WKSidetoneFrequency]));
      end;

   if aCluster <> nil then
      begin
      if aCluster.Password <> '' then
         begin
         AddReportLine(Result, SWizDetClusterPassword);
         end;
      if Trim(aCluster.ConnectCommand) <> '' then
         begin
         AddReportLine(Result, UnicodeFormat(SWizDetClusterCommand,
                                             [Trim(aCluster.ConnectCommand)]));
         end;
      end;
end;

end.
