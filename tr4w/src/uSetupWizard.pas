unit uSetupWizard;

(* THE SETUP WIZARD'S RULES, WITHOUT ITS WINDOW.

  Two questions the wizard asks, answered here so a unit test can pin them
  without streaming a form -- see docs/SETUP_WIZARD_DESIGN.md:

    WHICH PAGES, IN WHAT ORDER.  One Station page, one checklist, then one
    page per ticked item in CANONICAL order (Radio, CW keyer, DX cluster)
    whatever order the boxes were ticked in, then the result page.  A support
    instruction such as "the third page" therefore means one thing.

    WHETHER IT OPENS BY ITSELF AT STARTUP.  Only on a brand-new install (no
    settings file when the program started), only once, and never in a
    headless run, where there is no operator and a window is a hang.

    WHAT THE OPTIONAL ITEMS PUT IN THE STORES.  StageSetupItems copies the
    wizard's drafts into the radio, keyer and cluster libraries and points a
    profile at them -- through each store's own API, so the wizard declares
    no field of its own (design 3.1).  A test reads the stores back.

  NEARLY A LEAF: no LCL, no settings object, no live radio.  The stores it
  stages into are RTL-only units.  The window (uSetupWizardForm) and startup
  (uProgramMain) ask; this unit only answers. *)

{$I tr4w.inc}

interface

uses
   uRadioConfigStore,
   uKeyerConfigStore;

const
   (* The profile the wizard creates when the station has none active.  A
     NAME, not a caption: it is data in the operator's file, like any profile
     name they type, and is not translated. *)
   SETUP_PROFILE_NAME = 'Default';

type
   (* THE OPTIONAL ITEMS, in their canonical order.  The ordinal order IS the
     page order, so adding an item means choosing where it goes here. *)
   TSetupItem  = (siRadio, siKeyer, siCluster);
   TSetupItems = set of TSetupItem;

   (* Every page the wizard has.  spResult is shown after "Create
     configuration" and says what landed and what did not. *)
   TSetupPage  = (spStation, spChecklist, spRadio, spKeyer, spCluster, spResult);

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

(* WHETHER STARTUP OPENS THE WIZARD.

  aHeadless           /EXPORT and the other batch modes -- never.
  aSettingsFileExisted whether settings\tr4w.json was on disk when startup
                      began (captured BEFORE anything writes it -- the load
                      saves the file on a first run, so asking later always
                      answers yes).  An existing file is an existing station.
  aAlreadyShown       the durable once-only flag.  Set BEFORE the window is
                      shown, so a crash or a Cancel does not re-arm it; the
                      operator can always run it again from the Tools menu. *)
function SetupWizardDueAtStartup(const aHeadless: boolean;
                                 const aSettingsFileExisted: boolean;
                                 const aAlreadyShown: boolean): boolean;

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

(* Appends one line to a result-page report. *)
procedure AddReportLine(var aReport: string; const aLine: string);

(* The name a new cluster is stored under when the operator gave none: the
  host part of 'host:port', or 'Cluster'. *)
function SetupClusterBaseName(const aCluster: TClusterDefinition): string;

implementation

uses
   SysUtils,
   uAppStrings;

function SetupPagePlan(const aTicked: TSetupItems): TSetupPagePlan;
const
   (* The item's page.  A case would do as well; a table keeps the canonical
     order in ONE place -- the enum's own. *)
   PAGE_OF_ITEM: array[TSetupItem] of TSetupPage = (spRadio, spKeyer, spCluster);
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
                                 const aSettingsFileExisted: boolean;
                                 const aAlreadyShown: boolean): boolean;
begin
   Result := (not aHeadless)            and
             (not aSettingsFileExisted) and
             (not aAlreadyShown);
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
      Result := 'Cluster';
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
begin
   Result := [];
   radio := nil;
   keyer := nil;

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
      if aStore.AddRadio(radio, err) then
         begin
         Include(Result, siRadio);
         AddReportLine(aReport, UnicodeFormat(SWizResRadio, [radio.Name]));
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
      AddReportLine(aReport, UnicodeFormat(SWizResKeyer, [keyer.Name]));
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
            end;
         aStore.ActiveProfileName := profile.Name;
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
         AddReportLine(aReport, UnicodeFormat(SWizResCluster, [cluster.Name]));
         end
      else
         begin
         // AddCluster frees nothing on refusal -- this still owns it.
         cluster.Free;
         AddReportLine(aReport, SWizResClusterFailed);
         end;
      end;
end;

end.
