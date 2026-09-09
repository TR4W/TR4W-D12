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
      procedure Test_ReadOnlyAndSideEffectsAreVisible;
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
   (* SETTINGS THAT CANNOT ROUND-TRIP THEIR OWN VALUE. THE LIST IS EMPTY.

     A COUNTDOWN, AND IT REACHED ZERO. Ten on 2026-09-09, the day this walk was
     first written; none by the end of the same day. The test fails if a
     setting breaks, if a listed one starts working, AND if a listed one is
     never exercised -- that last guard was added after two entries went stale
     unnoticed when HasSideEffects began skipping the rows they named.

     HOW THE TEN CLEARED, because "we fixed them" would misrepresent it:

       FOUR were the QSO-point rows holding -1 for "this contest sets no fixed
       value". CFGCA's crMin/crMax are Word -- UNSIGNED -- so the table could
       not declare a negative bound at all. They graduated onto TIntSetting,
       whose bounds are signed.

       ONE was MINITOUR DURATION holding 0 for "no minitour" against a range of
       5..60. Widening to 0..60 would have admitted 1..4, which are not
       durations. It graduated too, and named a concept the table had no word
       for: TIntSetting.Sentinel, one value accepted beside the range.

       TWO were access violations, and were never TR4W's fault in the way the
       list implied: appearance.ctrlj.insertMode and
       operating.autoQSONumberDecrement carry a crP redraw handler, and running
       it with no main window is what faulted. They are skipped now, like every
       side-effecting row. Whether they round-trip is still unknown and needs a
       harness with a window.

       THREE were skipped for the same reason once HasSideEffects existed --
       they carry a crA hook -- so their entries were stale rather than fixed,
       and the guard now says so out loud.

     KEEP THE ARRAY AND THE MACHINERY. An empty countdown is the point: the
     next setting that cannot hold its own value fails this test by name on the
     day it is written, instead of reaching an operator. Add the key here only
     with a reason, and only as a step towards removing it again. *)
   KNOWN_NO_ROUND_TRIP: array[0..0] of string = (
      '');

var
   GStore: TRadioConfigStore = nil;

function KnownNoRoundTrip(const aKey: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(KNOWN_NO_ROUND_TRIP) to High(KNOWN_NO_ROUND_TRIP) do
      begin
      (* Pascal has no zero-length constant array, so an empty countdown is one
        empty string. It matches no key and is not a stale entry. *)
      if KNOWN_NO_ROUND_TRIP[i] = '' then
         begin
         Continue;
         end;
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

procedure TAllSettingsTests.Test_ReadOnlyAndSideEffectsAreVisible;
var
   all:        TArray<TSettingBase>;
   i:          integer;
   readOnly:   integer;
   sideEffect: integer;
   s:          TSettingBase;
begin
   (* THE TWO FACTS THE REGISTRY COULD NOT STATE UNTIL 2026-09-09, and both
     were named as blockers to retiring CFGCA.

     ReadOnly lifts crJ's states 2 and 3. Without it a generated panel offers
     an editable control for a value the program will not honour.

     HasSideEffects lifts crP and crA. Without it nothing outside the legacy
     adapter can tell that writing a setting repaints a window or reopens a
     port -- which cost this very suite a run, when two such rows faulted
     headless and killed it.

     Pinned rather than assumed: a floor on each, so a change that stopped
     mapping them would show up here and not as a panel behaving oddly. *)
   BeginTest('read-only and side-effecting settings can be identified');
   Declared;
   all := AllSettings;
   readOnly := 0;
   sideEffect := 0;

   for i := 0 to High(all) do
      begin
      if all[i].ReadOnly then
         begin
         Inc(readOnly);
         end;
      if all[i].HasSideEffects then
         begin
         Inc(sideEffect);
         end;
      end;

   CheckTrue(readOnly > 20,
             'only ' + IntToStr(readOnly) + ' settings are marked read-only; '
             + 'crJ 2 and 3 cover 88 rows');
   CheckTrue(sideEffect > 10,
             'only ' + IntToStr(sideEffect) + ' settings report side effects; '
             + 'about thirty rows carry a crP handler');

   (* A NAMED ONE, so the count above cannot be satisfied by the wrong rows.
     The QSO-point settings are set by a contest's .cfg and never by the
     operator, which is what crJ:2 said on the rows they replaced. *)
   s := FindSetting('contest.qsoPointsDomesticCw');
   CheckTrue(s <> nil, 'contest.qsoPointsDomesticCw is registered');
   if s <> nil then
      begin
      CheckTrue(s.ReadOnly,
                'contest.qsoPointsDomesticCw lost its read-only marking');
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
   seen:    array[Low(KNOWN_NO_ROUND_TRIP)..High(KNOWN_NO_ROUND_TRIP)] of boolean;
   k:       integer;
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
   for k := Low(seen) to High(seen) do
      begin
      seen[k] := False;
      end;

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
         for k := Low(seen) to High(seen) do
            begin
            if SameText(KNOWN_NO_ROUND_TRIP[k], all[i].Key) then
               begin
               seen[k] := True;
               end;
            end;
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

   (* A NAME THAT WAS NEVER TRIED IS A STALE ENTRY, and the ratchet has to say
     so or it rots exactly the way the first version did. A setting can leave
     this loop without being exercised -- it gained a crA or crP hook, or it
     was withdrawn -- and a list that silently tolerates that stops meaning
     anything.

     This is the second time the same lesson has been paid for: two entries had
     already gone stale when HasSideEffects started skipping the rows that
     faulted, and nothing noticed until I read the list by hand. *)
   for k := Low(seen) to High(seen) do
      begin
      if KNOWN_NO_ROUND_TRIP[k] = '' then
         begin
         Continue;
         end;
      CheckTrue(seen[k],
                'KNOWN_NO_ROUND_TRIP names "' + KNOWN_NO_ROUND_TRIP[k]
                + '", which this test never exercised -- it is stale, remove it');
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
   Test_ReadOnlyAndSideEffectsAreVisible;
   Test_ValuesSurviveATextRoundTrip;
   Test_NonsenseIsRefusedAndChangesNothing;

   (* The store belongs to this suite, not to the program: unhook it so a
     later suite cannot write through it by accident. *)
   uSettingsLegacy.ActiveStoreProvider := nil;
   FreeAndNil(GStore);
end;

end.
