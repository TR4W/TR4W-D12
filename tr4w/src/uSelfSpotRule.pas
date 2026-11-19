unit uSelfSpotRule;

(* WHETHER THE STATION MAY SPOT ITSELF RIGHT NOW (issue 188).

  A LEAF, deliberately: arithmetic and answers, no MainUnit, no radio, no
  cluster, so every refusal is pinned by uTestSelfSpot rather than judged on a
  bench against a live cluster -- which bans a station that spots itself too
  often.

  NY4I's six points (2026-11-19) as they land here:
    1. a function-key macro SPOTME           -- trigger sstMacro
    2. an automatic trigger, 10 min default  -- trigger sstAuto; the interval
       is a setting, and the contest's own minimum is a floor under it
    3. never in S&P mode                     -- ssvSearchAndPounce
    4. the macro does not spot again unless the VFO moved 300 Hz
    5. a Control menu item                   -- trigger sstMenu
    6. the contest states whether it allows it and its minimum interval

  THE TWO GATES AND WHO THEY APPLY TO (a reading, stated rather than buried):
    - THE INTERVAL applies to EVERY trigger, so no route spots more often than
      the contest's stated minimum. The interval in force is the LARGER of the
      operator's setting and the contest's minimum (SelfSpotEffectiveMinutes).
    - THE 300 Hz MOVE applies to the two MANUAL triggers, the macro and the
      menu item, which are the same hot key by another route. It is NOT asked
      of the automatic trigger: a station running on one frequency for an hour
      is exactly what the periodic spot is for, and with the move required it
      could never repeat.
  Every refusal is checked in the order of the enumeration below, so the
  operator is told the most basic reason first. *)

{$I tr4w.inc}

interface

uses
   SysUtils, DateUtils;

type
   TSelfSpotTrigger = (
      sstMacro,   (* the SPOTME command in a function-key memory *)
      sstMenu,    (* Control -> Self-spot *)
      sstAuto     (* the timer, CLUSTER AUTO SELF SPOT *)
   );

   TSelfSpotVerdict = (
      ssvSend,                 (* go ahead *)
      ssvContestDoesNotAllow,  (* the contest class says no, or there is none *)
      ssvSearchAndPounce,      (* S&P mode: the station is not running *)
      ssvNoCall,               (* the station has no call to spot *)
      ssvNoFrequency,          (* the radio has not reported a frequency *)
      ssvNoLink,               (* neither the cluster nor the network is up *)
      ssvTooSoon,              (* inside the interval in force *)
      ssvNotMoved              (* manual trigger, VFO within 300 Hz of the last spot *)
   );

const
   (* NY4I, 2026-11-19: the VFO must have moved at least this far since the
     last self-spot before a MANUAL trigger may spot again. *)
   SELF_SPOT_MIN_MOVE_HZ = 300;

   (* The auto trigger's default interval, in minutes. NY4I: 10 minutes is the
     established minimum, so the default sits on it. *)
   SELF_SPOT_DEFAULT_MINUTES = 10;

(* A SPOT'S FREQUENCY, in Hz: ROUNDED to the nearest 100 Hz, not truncated -- a
  spot is posted in whole hundreds and the Send Spot dialog has always rounded
  up at 50. The dialog and the self-spot both ask this one routine, so the
  two can never post different frequencies for the same VFO. *)
function SpotFrequencyRoundedHz(aFreqHz: integer): integer;

(* THE INTERVAL IN FORCE, in minutes: the operator's setting, never below the
  contest's stated minimum. A setting below 1 reads as 1 -- there is no
  "every zero minutes". *)
function SelfSpotEffectiveMinutes(aSettingMinutes,
                                  aContestMinimumMinutes: integer): integer;

(* MAY THE STATION SPOT ITSELF NOW? Pure: every input is a parameter.

    aContestAllows, aContestMinimumMinutes  the contest class's two answers
    aSettingMinutes                         CLUSTER SELF SPOT INTERVAL
    aSearchAndPounce                        the operating mode is S&P
    aHaveCall                               the station has a call
    aFreqHz                                 the radio's frequency, raw Hz, 0 = none
    aLinkUp                                 the cluster or the network is up
    aHaveLast, aLastStamp, aLastFreqHz      the last self-spot SENT, if any
    aNow                                    both stamps are UTC *)
function SelfSpotVerdictFor(aTrigger: TSelfSpotTrigger;
                            aContestAllows: boolean;
                            aContestMinimumMinutes, aSettingMinutes: integer;
                            aSearchAndPounce, aHaveCall: boolean;
                            aFreqHz: integer;
                            aLinkUp: boolean;
                            aHaveLast: boolean;
                            const aLastStamp, aNow: TDateTime;
                            aLastFreqHz: integer): TSelfSpotVerdict;

implementation

uses
   uSpotAge;   (* AgeSeconds -- one definition of "how long ago", clock-step safe *)

function SpotFrequencyRoundedHz(aFreqHz: integer): integer;
var
   hz100: integer;
begin
   hz100  := aFreqHz mod 100;
   Result := aFreqHz - hz100;
   if hz100 >= 50 then
      begin
      Result := Result + 100;
      end;
end;

function SelfSpotEffectiveMinutes(aSettingMinutes,
                                  aContestMinimumMinutes: integer): integer;
begin
   Result := aSettingMinutes;
   if Result < aContestMinimumMinutes then
      begin
      Result := aContestMinimumMinutes;
      end;
   if Result < 1 then
      begin
      Result := 1;
      end;
end;

function SelfSpotVerdictFor(aTrigger: TSelfSpotTrigger;
                            aContestAllows: boolean;
                            aContestMinimumMinutes, aSettingMinutes: integer;
                            aSearchAndPounce, aHaveCall: boolean;
                            aFreqHz: integer;
                            aLinkUp: boolean;
                            aHaveLast: boolean;
                            const aLastStamp, aNow: TDateTime;
                            aLastFreqHz: integer): TSelfSpotVerdict;
var
   moved: integer;
begin
   if not aContestAllows then
      begin
      Result := ssvContestDoesNotAllow;
      Exit;
      end;
   if aSearchAndPounce then
      begin
      Result := ssvSearchAndPounce;
      Exit;
      end;
   if not aHaveCall then
      begin
      Result := ssvNoCall;
      Exit;
      end;
   if aFreqHz <= 0 then
      begin
      Result := ssvNoFrequency;
      Exit;
      end;
   if not aLinkUp then
      begin
      Result := ssvNoLink;
      Exit;
      end;

   if aHaveLast then
      begin
      if AgeSeconds(aLastStamp, aNow) <
         SelfSpotEffectiveMinutes(aSettingMinutes, aContestMinimumMinutes) * 60 then
         begin
         Result := ssvTooSoon;
         Exit;
         end;

      if aTrigger in [sstMacro, sstMenu] then
         begin
         moved := aFreqHz - aLastFreqHz;
         if moved < 0 then
            begin
            moved := -moved;
            end;
         if moved < SELF_SPOT_MIN_MOVE_HZ then
            begin
            Result := ssvNotMoved;
            Exit;
            end;
         end;
      end;

   Result := ssvSend;
end;

end.
