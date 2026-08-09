program tr4w_status_trace;

{
  STATUS-PIPELINE TRACE -- the A/B oracle for moving radio status off RadioObject.

  WHAT THIS PINS.  uRadioPolling.UpdateStatus: the raw byte-compare of
  CurrentStatus against PreviousStatus, and the ONE-CYCLE-DELAYED adoption of
  FilteredStatus that follows it.  That pair does change-detection and torn-read
  protection at the same time and does neither cleanly, which is why it is the
  thing most likely to break silently when the state moves onto the radio.

  Its failure mode is not a crash.  It is a field that quietly stops being
  updated, or a filtered status that settles one cycle early or late.  Both read
  as perfectly legal values.  Neither the golden corpus (which tests the contest
  engine, not the radio) nor test/unit (which links no transport) can see it.

  HOW IT WORKS.  A scripted sequence writes states directly into
  Radio1.CurrentStatus and calls the REAL UpdateStatus after each one.  Every
  decision UpdateStatus makes is reported through uRadioPolling.RadioStatusTrace
  and written as one JSON object per line.  Diff the JSONL from before and after
  a refactor: identical means the state machine is preserved, and any difference
  names the exact step and field that moved.

  WHY NOT THE SIMULATORS.  tools/radiosim and the hamlib ports drive the DRIVER
  half -- bytes on a wire into a factory radio -- which tr4w_radio_bench.dpr
  already covers and which this refactor does not touch.  They also need a
  virtual COM pair, so they cannot run unattended.  For a refactor the oracle
  has to be DETERMINISTIC: the same input must produce a byte-identical trace
  every run, or the diff is noise.  A script does that; a live serial link,
  with its poll timing and reconnect backoff, does not.

  WHAT IT DELIBERATELY DOES NOT COVER.  The fill of CurrentStatus from the
  factory radio inside pFactoryRadio (a straight field copy, and not separately
  callable -- pFactoryRadio IS the polling thread body), and everything below
  the hook: DisplayCurrentStatus, ProcessFilteredStatus, SendRadioInfoToUDP.
  Those are observed only in that they are reached, not in what they render.

  RUN:  msbuild tr4w_status_trace.dproj /t:Build /p:Config=Debug /p:Platform=Win32
        tr4w_status_trace.exe > before.jsonl
        ...refactor...
        tr4w_status_trace.exe > after.jsonl
        diff before.jsonl after.jsonl
}

{$APPTYPE CONSOLE}

uses
   Windows,
   SysUtils,
   TypInfo,
   Log4D,
   MainUnit,
   VC,
   LogRadio,
   LogStuff,      // UDPBroadcastRadio -- forced off below, see the note in main
   uRadioPolling;

var
   GStep: integer = 0;      // which scripted step produced the event
   GEvents: integer = 0;    // how many events the hook reported in total

// ---------------------------------------------------------------------------
// Serialisation
//
// Enum members are written by NAME, not ordinal.  An ordinal trace would stay
// byte-identical across a change that inserts a member into BandType or
// ModeType -- silently re-labelling every recorded state.
// ---------------------------------------------------------------------------

function EnumName(aTypeInfo: PTypeInfo; aValue: integer): string;
begin
   Result := GetEnumName(aTypeInfo, aValue);
end;

function B(aValue: boolean): string;
begin
   if aValue then
      begin
      Result := 'true';
      end
   else
      begin
      Result := 'false';
      end;
end;

function VFOJson(const v: VFOStatusType): string;
begin
   Result := Format(
      '{"freq":%d,"ritfreq":%d,"band":"%s","mode":"%s","split":%s,"rit":%s,"xit":%s,"xmode":"%s"}',
      [v.Frequency,
       v.RITFreq,
       EnumName(TypeInfo(BandType), Ord(v.Band)),
       EnumName(TypeInfo(ModeType), Ord(v.Mode)),
       B(v.Split),
       B(v.RIT),
       B(v.XIT),
       EnumName(TypeInfo(ExtendedModeType), Ord(v.ExtendedMode))]);
end;

function StatusJson(const s: RadioStatusRecord): string;
begin
   Result := Format(
      '{"freq":%d,"split":%s,"rit":%s,"xit":%s,"ritfreq":%d,"prevritfreq":%d,' +
      '"band":"%s","mode":"%s","xmode":"%s","vfostatus":"%s","prevvfostatus":"%s",' +
      '"txon":%s,"vfoa":%s,"vfob":%s}',
      [s.Freq,
       B(s.Split),
       B(s.RIT),
       B(s.XIT),
       s.RITFreq,
       s.PrevRITFreq,
       EnumName(TypeInfo(BandType), Ord(s.Band)),
       EnumName(TypeInfo(ModeType), Ord(s.Mode)),
       EnumName(TypeInfo(ExtendedModeType), Ord(s.ExtendedMode)),
       EnumName(TypeInfo(ActiveVFOStatusType), Ord(s.VFOStatus)),
       EnumName(TypeInfo(ActiveVFOStatusType), Ord(s.PrevVFOStatus)),
       B(s.TXOn),
       VFOJson(s.VFO[VFOA]),
       VFOJson(s.VFO[VFOB])]);
end;

// ---------------------------------------------------------------------------
// The hook.  One line per decision UpdateStatus makes.
// ---------------------------------------------------------------------------

procedure TraceEvent(rig: RadioPtr; aEvent: TRadioStatusEvent);
begin
   Inc(GEvents);
   WriteLn(Format('{"step":%d,"event":"%s","current":%s,"filtered":%s}',
                  [GStep,
                   EnumName(TypeInfo(TRadioStatusEvent), Ord(aEvent)),
                   StatusJson(rig^.CurrentStatus),
                   StatusJson(rig^.FilteredStatus)]));
end;

// ---------------------------------------------------------------------------
// Script driver
// ---------------------------------------------------------------------------

// One poll cycle with whatever CurrentStatus currently holds.  Steps that call
// this WITHOUT changing anything are not filler: an unchanged cycle is what
// triggers the delayed adoption of FilteredStatus, so the debounce is only
// observable across a change/no-change pair.
procedure Poll(const aWhat: string);
begin
   Inc(GStep);
   WriteLn(Format('{"step":%d,"poll":"%s"}', [GStep, aWhat]));
   UpdateStatus(@Radio1);
end;

procedure RunScript;
begin
   // ---- baseline ---------------------------------------------------------
   // ClearRadioStatus zeroes both records and sets Mode := NoMode, which is how
   // the program starts a radio.  Starting from a zeroed record rather than
   // whatever the globals happened to hold is what makes the trace repeatable.
   ClearRadioStatus(@Radio1);
   // NOTE, established by running this: the first poll DOES report rseChanged.
   // ClearRadioStatus zeroes the record and then sets Mode := NoMode, and NoMode
   // is ordinal 4, not 0 -- so a "cleared" status differs from a zeroed
   // PreviousStatus in exactly one field.  Every radio therefore emits one
   // change event at startup before it has spoken to anything.  That is current
   // behaviour, so the trace pins it; it is not obviously desirable, and it is
   // worth revisiting when the state moves onto the radio.
   Poll('initial -- cleared status vs zeroed previous');
   Poll('settle after the initial change');

   // ---- a plain QSY ------------------------------------------------------
   Radio1.CurrentStatus.Freq := 14025000;
   Radio1.CurrentStatus.VFO[VFOA].Frequency := 14025000;
   Radio1.CurrentStatus.Band := Band20;
   Radio1.CurrentStatus.VFO[VFOA].Band := Band20;
   Poll('QSY to 14.025 -- expect rseChanged');
   Poll('settle -- expect rseFiltered (the one-cycle delay)');
   Poll('idle -- expect no event');

   // ---- mode change only -------------------------------------------------
   Radio1.CurrentStatus.Mode := CW;
   Radio1.CurrentStatus.VFO[VFOA].Mode := CW;
   Poll('mode -> CW');
   Poll('settle');

   // ---- single-byte delta ------------------------------------------------
   // One Hz.  The byte-compare must catch it; a comparison that looked at
   // fewer bytes than SizeOf(RadioStatusRecord), or walked the record two
   // bytes at a time, would miss exactly this.
   Radio1.CurrentStatus.Freq := 14025001;
   Poll('QSY by 1 Hz -- the smallest detectable change');
   Poll('settle');

   // ---- flags ------------------------------------------------------------
   Radio1.CurrentStatus.Split := True;
   Poll('split on');
   Poll('settle');

   Radio1.CurrentStatus.RIT := True;
   Radio1.CurrentStatus.RITFreq := -250;
   Poll('RIT on, -250 Hz');
   Poll('settle');

   Radio1.CurrentStatus.XIT := True;
   Poll('XIT on');
   Poll('settle');

   // ---- transmit ---------------------------------------------------------
   Radio1.CurrentStatus.TXOn := True;
   Poll('TX on');
   Poll('settle');
   Radio1.CurrentStatus.TXOn := False;
   Poll('TX off');
   Poll('settle');

   // ---- VFO B and the active-VFO switch ----------------------------------
   Radio1.CurrentStatus.VFO[VFOB].Frequency := 14200000;
   Radio1.CurrentStatus.VFO[VFOB].Band := Band20;
   // ModeType is TR4W's COARSE mode set -- (CW, Digital, Phone, Both, NoMode,
   // FM).  There is no USB member; sideband lives in ExtendedModeType, which
   // the record carries separately.  Setting both is what the real fill does.
   Radio1.CurrentStatus.VFO[VFOB].Mode := Phone;
   Radio1.CurrentStatus.VFO[VFOB].ExtendedMode := eSSB;
   Poll('VFO B set to 14.200 SSB');
   Poll('settle');

   Radio1.CurrentStatus.PrevVFOStatus := Radio1.CurrentStatus.VFOStatus;
   Radio1.CurrentStatus.VFOStatus := VFOB;
   Radio1.CurrentStatus.Freq := 14200000;
   Poll('active VFO -> B');
   Poll('settle');

   // ---- two changes with NO settle between --------------------------------
   // Back-to-back changes never let FilteredStatus adopt anything.  This is the
   // case that distinguishes the current debounce from a naive "publish every
   // change" implementation, so a refactor that drops the delay shows up here
   // and nowhere else.
   Radio1.CurrentStatus.Freq := 14200100;
   Poll('change 1 of 2 (no settle)');
   Radio1.CurrentStatus.Freq := 14200200;
   Poll('change 2 of 2 (no settle)');
   Poll('settle after the pair');

   // ---- band change ------------------------------------------------------
   Radio1.CurrentStatus.Freq := 7025000;
   Radio1.CurrentStatus.Band := Band40;
   Radio1.CurrentStatus.VFO[VFOA].Frequency := 7025000;
   Radio1.CurrentStatus.VFO[VFOA].Band := Band40;
   Poll('band change to 40m');
   Poll('settle');

   // ---- revert to zero ---------------------------------------------------
   // A disconnect clears the status.  Going back to the zeroed record is itself
   // a change and must be reported like any other.
   ClearRadioStatus(@Radio1);
   Poll('cleared (disconnect)');
   Poll('settle');
   Poll('idle');
end;

begin
   // Every unit below logs through MainUnit's global `logger`, which tr4w.dpr
   // assigns at startup.  A standalone EXE that links app units and skips this
   // faults on the first log call -- same note as the unit-test project and the
   // radio bench.
   logger := TLogLogger.GetLogger('TR4WStatusTrace');

   // DETERMINISM.  UpdateStatus republishes an UNCHANGED status when
   // UDPBroadcastRadio is on and more than 10 seconds have passed, which would
   // inject wall-clock-dependent rsePeriodic events and make two runs of the
   // same script differ.  Off means the trace is a pure function of the script.
   // The rsePeriodic branch is still reachable and still distinguished by the
   // hook -- it is simply not exercised here.
   UDPBroadcastRadio := False;

   Radio1.RadioName := 'TRACE1';

   RadioStatusTrace := TraceEvent;
   try
      RunScript;
   finally
      RadioStatusTrace := nil;
   end;

   // Trailer on stderr, so stdout stays pure JSONL and diffs cleanly.
   WriteLn(ErrOutput, Format('steps=%d events=%d', [GStep, GEvents]));
end.
