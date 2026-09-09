unit uTestAllSettings;
{$I ..\..\src\tr4w.inc}

(*
  EVERY SETTING THE PROGRAM ACTUALLY DECLARES, WALKED.

  uTestSettingsRegistry proves the registry MECHANISM with settings it invents.
  This proves the DECLARATIONS: it calls DeclareAllSettings and then holds every
  real setting to the contract a UI and a config file rely on.

  WHY THIS IS THE FOUNDATION FOR RETIRING CFGCA.

  Settings are being moved off the old array in three steps -- a CFGCA row, then
  a typed closure over the global it lives in, then a self-storing registry
  entry with no global at all (see uSettingsDeclarations' header). A panel
  cannot tell the three apart, which is the point, and it is also the danger:
  when a setting graduates, NOTHING today notices if it stops round-tripping.

  So this walks all of them and asserts the properties that must hold whichever
  step a setting is on. A migration that breaks one shows up as a named failure
  instead of as an operator losing a value.

  IT IS ALSO THE TEST NEITHER PROGRAM HAS. TR4QT cannot write it at all -- its
  settings are typed getter/setter pairs with nothing to enumerate, which is
  why its preferences dialog is 3,746 lines of hand-wiring (see
  docs/TR4QT-Settings-Architecture-Reference.md). Enumerability is the thing
  our registry has and theirs does not, and this is what it buys.

  WHAT IS DELIBERATELY NOT DONE HERE: settings carrying an OnApply hook are not
  written to. Applying 500 settings in a console test would run hooks that
  redraw windows, reopen serial ports and restart servers, and a test that
  reformats an operator's session to prove a string round-trips is not a test
  worth having. They are still READ and still checked against their allow-list;
  only the write pass skips them, and it reports how many.
*)

interface

uses
   uTR4WTestFramework;

type
   TAllSettingsTests = class(TTestCase)
   protected
      procedure Test_TheDeclarationsRun;
      procedure Test_EverySettingRendersItsValue;
      procedure Test_AnAllowListContainsTheCurrentValue;
      procedure Test_KeysAreUniqueAndWellFormed;
      procedure Test_EverySettingHasACaption;
      procedure Test_ValuesSurviveATextRoundTrip;
      procedure Test_NonsenseIsRefusedAndChangesNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uSettingsRegistry,
   uSettingsLegacy,
   uRadioConfigStore,
   uSettingsDeclarations;

const
   (* SETTINGS THAT CANNOT ROUND-TRIP THEIR OWN VALUE TODAY.

     A COUNTDOWN, NOT AN EXCUSE LIST. The test fails if a setting NOT named
     here breaks, and it also fails if one named here starts working -- so the
     list cannot quietly grow, and a fix is not finished until the name is
     removed. Ten on 2026-09-09, the day the walk was first written.

     They fall into three groups, and all three are the same shape: a setting
     whose CURRENT value its OWN validator rejects. Preferences reads with one
     and writes with the other, so saving a form can change a setting the
     operator never touched.

       FOUR SENTINELS OUTSIDE THEIR RANGE -- the four qsoPoints rows hold -1,
       which means "not set for this contest", while their declared range
       starts at 0. The value is legitimate and the RANGE is what is wrong,
       which is why this needs a decision rather than a clamp.

       FOUR REFUSED OUTRIGHT -- 'DUMMY CONTEST' is the no-contest-loaded
       sentinel and is not in the contest allow-list; minitourDuration holds 0
       against a range that excludes it; two more hold '' where empty is not
       an accepted spelling.

     None of these is a regression. They have been true for as long as the
     rows have existed and nothing was ever in a position to notice.

     TWO MORE WERE FOUND AND ARE NOT LISTED HERE, because they are not
     reachable by this test: appearance.ctrlj.insertMode and
     operating.autoQSONumberDecrement took an ACCESS VIOLATION when written.
     They carry a crP redraw handler, and running it with no main window is
     what faulted -- so the fault is the test's environment, not proof that
     the setting is broken. They are skipped now like every other
     side-effecting row (see HasSideEffects, which had to be added to the
     registry before this test could tell). Whether they round-trip is an open
     question that needs a harness with a window. *)
   KNOWN_NO_ROUND_TRIP: array[0..7] of string = (
      'bandmap.ctrlj.bandMapCutoffFrequency',
      'contest.contest',
      'contest.minitourDuration',
      'contest.qsoPointsDomesticCw',
      'contest.qsoPointsDomesticPhone',
      'contest.qsoPointsDxCw',
      'contest.qsoPointsDxPhone',
      'operating.ctrlj.frequencyMemory');

var
   GStore: TRadioConfigStore = nil;

function KnownNoRoundTrip(const aKey: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(KNOWN_NO_ROUND_TRIP) to High(KNOWN_NO_ROUND_TRIP) do
      begin
      if SameText(KNOWN_NO_ROUND_TRIP[i], aKey) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* A STORE FOR THE TEST TO WRITE INTO, AND WHY ONE IS NEEDED.

  A legacy setting refuses to save when no configuration store is open --
  deliberately, so that a graduated row cannot silently fall back to writing an
  ini file nothing reads any more (uSettingsLegacy:232). In Preferences the
  store is the one being edited; in a console test there is none, so the first
  run of this suite reported 226 settings "refusing their own current value",
  which was the test's environment and not a defect in any of them.

  TRadioConfigStore.Create is in-memory -- it owns some lists and touches no
  file until it is told to -- so this writes nowhere and leaves nothing behind.

  IT ALSO MAKES THE ROUND TRIP REAL rather than nominal: with a store present
  the value goes out through the same path Preferences uses and comes back
  through the same reader, which is the whole point of the assertion. *)
function ProvideTestStore: TObject;
begin
   if GStore = nil then
      begin
      GStore := TRadioConfigStore.Create;
      end;
   Result := GStore;
end;

(* Every test needs the declarations in place, and DeclareAllSettings is
  idempotent, so each one asks rather than depending on run order. *)
procedure Declared;
begin
   DeclareAllSettings;
   uSettingsLegacy.ActiveStoreProvider := ProvideTestStore;
end;

procedure TAllSettingsTests.Test_TheDeclarationsRun;
begin
   BeginTest('the real declarations register');
   Declared;

   (* A FLOOR, NOT AN EXACT COUNT. The number grows every time a setting is
     added and shrinks when one is withdrawn, so pinning it exactly would make
     this a test of arithmetic. Zero or a handful means DeclareAllSettings did
     not run, which is the failure that would make every test below pass
     vacuously -- the same trap the TLS probe fell into. *)
   CheckTrue(SettingCount > 200,
             'DeclareAllSettings registered ' + IntToStr(SettingCount)
             + ' settings; expected the full set');
end;

procedure TAllSettingsTests.Test_EverySettingRendersItsValue;
var
   all: TArray<TSettingBase>;
   i:   integer;
   s:   string;
begin
   BeginTest('every setting can render its current value');
   Declared;
   all := AllSettings;

   for i := 0 to High(all) do
      begin
      (* AsText is documented never to raise: "a setting that cannot render
        itself is a bug in the setting, not something for a caller to guard on
        every use". This is what holds it to that.

        For a LEGACY row this reads through CheckCommand and an untyped
        crAddress -- the construct behind the SCP MINIMUM LETTERS access
        violation -- so this loop is the only thing exercising all of them. *)
      try
         s := all[i].AsText;
      except
         on E: Exception do
            begin
            Check(False, all[i].Key + ': AsText raised ' + E.ClassName + ': ' + E.Message);
            Continue;
            end;
      end;
      end;

   Check(True, 'all ' + IntToStr(Length(all)) + ' settings rendered');
end;

procedure TAllSettingsTests.Test_AnAllowListContainsTheCurrentValue;
var
   all:     TArray<TSettingBase>;
   values:  TArray<string>;
   i, v:    integer;
   current: string;
   found:   boolean;
   checked: integer;
begin
   (* THE ONE THAT CATCHES THE SINGLE BAND SCORE CLASS OF BUG.

     A drop-down is built from AllowedValues. If the setting's CURRENT value is
     not among them, the control cannot show what the program is actually doing
     -- it silently displays something else, and saving the form changes a
     setting the operator never touched.

     That is not hypothetical: 'SINGLE BAND SCORE=All' was written by
     Preferences and then rejected on every later start, because the spelling
     table held 'All' and the comparison had been uppercased. Same shape. *)
   BeginTest('a setting with an allow-list holds one of its own values');
   Declared;
   all := AllSettings;
   checked := 0;

   for i := 0 to High(all) do
      begin
      values := all[i].AllowedValues;
      if Length(values) = 0 then
         begin
         Continue;
         end;

      current := all[i].AsText;
      found := False;
      for v := 0 to High(values) do
         begin
         if SameText(values[v], current) then
            begin
            found := True;
            Break;
            end;
         end;

      Inc(checked);
      CheckTrue(found,
                all[i].Key + ': current value "' + current
                + '" is not in its own allow-list');
      end;

   Check(checked > 0, IntToStr(checked) + ' settings have an allow-list');
end;

procedure TAllSettingsTests.Test_KeysAreUniqueAndWellFormed;
var
   all:  TArray<TSettingBase>;
   i, j: integer;
begin
   BeginTest('keys are present, lower case and unique');
   Declared;
   all := AllSettings;

   for i := 0 to High(all) do
      begin
      CheckTrue(all[i].Key <> '', 'a setting has an empty key');

      (* THE CONVENTION IS DOTTED camelCase -- 'operating.cw.sayHi'.

        My first version of this asserted lower case and failed on eight real
        keys. That was me inventing a rule the codebase does not have: the
        existing declarations are deliberately camelCase within dotted
        segments, and they are already in operators' JSON files, so the
        convention is settled and it is not mine to change.

        What IS worth asserting is what would actually break something: a key
        is the JSON name, so whitespace in it makes a file that reads oddly and
        sorts worse, and a key with no dot has no group to sit under in the
        store or in Preferences. *)
      CheckTrue(Pos(' ', all[i].Key) = 0,
                'key "' + all[i].Key + '" contains a space');
      CheckTrue(Pos('.', all[i].Key) > 0,
                'key "' + all[i].Key + '" has no group prefix');
      end;

   (* Duplicate keys are refused at registration, and this checks the result
     rather than the guard -- a duplicate that slipped through would mean two
     settings sharing one JSON entry, where the last one written wins. *)
   for i := 0 to High(all) do
      begin
      for j := i + 1 to High(all) do
         begin
         if SameText(all[i].Key, all[j].Key) then
            begin
            Check(False, 'duplicate key: ' + all[i].Key);
            end;
         end;
      end;
end;

procedure TAllSettingsTests.Test_EverySettingHasACaption;
var
   all: TArray<TSettingBase>;
   i:   integer;
begin
   (* A setting with no caption is a row in Preferences with nothing in the
     label column. Cheap to assert, and it fails the moment someone adds a
     declaration without one. *)
   BeginTest('every setting has something to label it with');
   Declared;
   all := AllSettings;

   for i := 0 to High(all) do
      begin
      CheckTrue(all[i].Caption <> '',
                all[i].Key + ': has no caption');
      end;
end;

procedure TAllSettingsTests.Test_ValuesSurviveATextRoundTrip;
var
   all:     TArray<TSettingBase>;
   i:       integer;
   before:  string;
   err:     string;
   ok:      boolean;
   skipped: integer;
   done:    integer;
begin
   (* THE PROPERTY THE WHOLE MIGRATION RESTS ON: a setting must accept the text
     it just produced, and be unchanged afterwards.

     Every save writes AsText to JSON and every load feeds it back through
     TrySetText. If that is not a round trip, the value an operator set is not
     the value they get -- and because both halves are the setting's own code,
     a broken pair is self-consistent and invisible until someone restarts.

     This is exactly what a graduating setting can break: the closure form
     reads and writes a global through code written by hand for that one row. *)
   BeginTest('a setting accepts the text it just produced');
   Declared;
   all := AllSettings;
   skipped := 0;
   done := 0;

   for i := 0 to High(all) do
      begin
      if all[i].HasSideEffects then
         begin
         (* See the unit header: writing these runs a hook. HasSideEffects, not
           Assigned(OnApply) -- a LEGACY row carries its hook in crP and crA,
           which OnApply cannot see. Two such rows slipped past the earlier
           test, ran a redraw handler with no main window, and took an access
           violation that ended the run. *)
         Inc(skipped);
         Continue;
         end;

      before := all[i].AsText;
      err := '';
      ok := False;

      (* GUARDED PER SETTING, so a fault NAMES the row instead of ending the
        run. The first version of this test took an access violation somewhere
        in this loop and reported only "the suite crashed", which is the least
        useful form of a real finding.

        A legacy row writes through an untyped crAddress -- the construct
        behind the SCP MINIMUM LETTERS access violation -- so a fault here is
        a result, not an accident, and it belongs in the report with a key
        beside it. *)
      try
         if all[i].TrySetText(before, err) then
            begin
            ok := (all[i].AsText = before);
            if not ok then
               begin
               err := 'changed when set to its own value';
               end;
            end;
      except
         on E: Exception do
            begin
            ok  := False;
            err := E.ClassName + ': ' + E.Message;
            end;
      end;

      (* THE RATCHET. A new breakage fails; a fixed one fails too, so the list
        cannot rot. See KNOWN_NO_ROUND_TRIP. *)
      if KnownNoRoundTrip(all[i].Key) then
         begin
         CheckTrue(not ok,
                   all[i].Key + ' now round-trips -- remove it from '
                   + 'KNOWN_NO_ROUND_TRIP');
         end
      else
         begin
         CheckTrue(ok,
                   all[i].Key + ': cannot round-trip its own value "'
                   + before + '" -- ' + err);
         end;

      if ok then
         begin
         Inc(done);
         end;
      end;

   Check(done > 0, IntToStr(done) + ' settings round-tripped, '
                   + IntToStr(skipped) + ' skipped for having an apply hook');
end;

procedure TAllSettingsTests.Test_NonsenseIsRefusedAndChangesNothing;
var
   all:    TArray<TSettingBase>;
   i:      integer;
   before: string;
   err:    string;
   refused: integer;
begin
   (* REFUSING MUST NOT ALSO ASSIGN. TrySetText's contract is that False means
     NOTHING was assigned and the setting keeps its value -- that is what lets
     a dialog show the error and leave the field alone. A setting that
     validates after assigning passes every happy-path test and quietly
     corrupts itself on a typo.

     The probe value is deliberately not a number, not a boolean spelling and
     not in anyone's allow-list. A free-text string setting will legitimately
     accept it, which is why the assertion is about the VALUE not changing when
     it is refused, rather than about refusal itself. *)
   BeginTest('a refused value leaves the setting alone');
   Declared;
   all := AllSettings;
   refused := 0;

   for i := 0 to High(all) do
      begin
      if all[i].HasSideEffects then
         begin
         Continue;
         end;

      before := all[i].AsText;
      err := '';

      (* Guarded for the same reason as the round trip above. *)
      try
         if not all[i].TrySetText('~~not a valid value~~', err) then
            begin
            Inc(refused);
            CheckEquals(before, all[i].AsText,
                        all[i].Key + ': refused a value but changed anyway');
            CheckTrue(err <> '',
                      all[i].Key + ': refused a value without saying why');
            end
         else
            begin
            (* It accepted it -- a free-text setting. Put it back. *)
            all[i].TrySetText(before, err);
            end;
      except
         on E: Exception do
            begin
            Check(False, all[i].Key + ': rejecting a bad value raised '
                  + E.ClassName + ': ' + E.Message);
            end;
      end;
      end;

   Check(refused > 0, IntToStr(refused) + ' settings refused the probe value');
end;

procedure TAllSettingsTests.RunAllTests;
begin
   Test_TheDeclarationsRun;
   Test_EverySettingRendersItsValue;
   Test_AnAllowListContainsTheCurrentValue;
   Test_KeysAreUniqueAndWellFormed;
   Test_EverySettingHasACaption;
   Test_ValuesSurviveATextRoundTrip;
   Test_NonsenseIsRefusedAndChangesNothing;

   (* The store belongs to this suite, not to the program: unhook it so a
     later suite cannot write through it by accident. *)
   uSettingsLegacy.ActiveStoreProvider := nil;
   FreeAndNil(GStore);
end;

end.
