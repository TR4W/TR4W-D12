unit uSelfSpot;

(* THE STATION SPOTS ITSELF (issue 188): Control -> Self-spot, the SPOTME
  command in a function-key memory, and the automatic trigger.

  WHAT LIVES WHERE. The decision -- may it go, and if not why -- is the leaf
  uSelfSpotRule and is pinned by uTestSelfSpot. The contest's two answers are
  TContestBase.AllowsSelfSpotting and SelfSpotMinimumMinutes. The spot itself
  leaves by uSendSpot.SendDXSpot, the ONE door the Send Spot dialog uses, with
  the station's own call, the run frequency (the radio's, rounded as the dialog
  rounds it) and the contest's name as the comment. This unit only gathers the
  inputs, remembers the last spot SENT, and says the result on the status line.

  THE LAST SPOT IS REMEMBERED ONLY WHEN ONE WAS SENT, and by every route
  together: a menu click, a macro and the timer share one interval and one
  "where was I last". It is session state, main thread only (the menu, the
  command dispatch and OneSecondTick all run there), and is not saved: a
  restart is a fresh station as far as a cluster is concerned. *)

{$I tr4w.inc}

interface

uses
   uSelfSpotRule;

(* ASK TO SPOT NOW. True when a spot was sent; otherwise nothing went out and
  aMessage says why (a refusal) -- the same text the operator is shown. On True
  aMessage names what was spotted. *)
function SelfSpotNow(aTrigger: TSelfSpotTrigger; out aMessage: string): boolean;

(* Control -> Self-spot: asks as sstMenu and shows the answer on the quick
  display line either way. *)
procedure SelfSpotFromMenu;

(* Once a second, from OneSecondTick. Does nothing at all unless CLUSTER AUTO
  SELF SPOT is on. A refusal is silent (it would repeat every second) and is
  logged once each time the reason changes; a spot sent is announced. *)
procedure SelfSpotTick;

implementation

uses
   SysUtils,
   VC,
   PostUnit,            (* Contest *)
   uContestBase,        (* ContestAllowsSelfSpotting, ContestSelfSpotMinimumMinutes *)
   uContestRegistry,    (* ContestIdentity, ContestId *)
   uSettingsModel,      (* Settings *)
   uSpotAge,            (* UTCNow *)
   uAppStrings,
   uSendSpot,           (* SendDXSpot *)
   uTelnet,             (* TelnetIsConnected *)
   uNet,                (* NetIsConnected *)
   LogRadio,            (* ActiveRadioPtr *)
   LogWind,             (* OpMode, QuickDisplay, QuickDisplayError *)
   TF,                  (* FreqToPChar *)
   MainUnit;            (* logger *)

var
   GHaveLast: boolean = False;
   GLastStamp: TDateTime = 0;
   GLastFreqHz: integer = 0;
   (* The reason the automatic trigger was last held back, so a changed reason is
     logged and a repeated one is not. Starts at "sent" -- nothing to report. *)
   GLastAutoVerdict: TSelfSpotVerdict = ssvSend;

function VerdictText(aVerdict: TSelfSpotVerdict; aMinutes: integer): string;
begin
   case aVerdict of
      ssvContestDoesNotAllow:
         begin
         Result := SSelfSpotNotAllowed;
         end;
      ssvSearchAndPounce:
         begin
         Result := SSelfSpotSearchAndPounce;
         end;
      ssvNoCall:
         begin
         Result := SSelfSpotNoCall;
         end;
      ssvNoFrequency:
         begin
         Result := SSelfSpotNoFrequency;
         end;
      ssvNoLink:
         begin
         Result := SSelfSpotNoLink;
         end;
      ssvTooSoon:
         begin
         Result := UnicodeFormat(SSelfSpotTooSoon, [aMinutes]);
         end;
      ssvNotMoved:
         begin
         Result := UnicodeFormat(SSelfSpotNotMoved, [SELF_SPOT_MIN_MOVE_HZ]);
         end;
   else
      begin
      Result := '';
      end;
   end;
end;

function CurrentFrequencyHz: integer;
begin
   if ActiveRadioPtr = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := ActiveRadioPtr.LastDisplayedFreq;
      end;
end;

(* THE VERDICT FOR THE STATION AS IT IS RIGHT NOW. aMinutes returns the
  interval in force, for the refusal text. *)
function CurrentVerdict(aTrigger: TSelfSpotTrigger; out aMinutes: integer): TSelfSpotVerdict;
var
   rules: TContestBase;
   minimum: integer;
begin
   rules   := ContestIdentity(Contest);
   minimum := ContestSelfSpotMinimumMinutes(rules);
   aMinutes := SelfSpotEffectiveMinutes(Settings.Cluster.SelfSpotInterval, minimum);
   Result := SelfSpotVerdictFor(aTrigger,
                                ContestAllowsSelfSpotting(rules),
                                minimum,
                                Settings.Cluster.SelfSpotInterval,
                                OpMode = SearchAndPounceOpMode,
                                string(Settings.My.Call) <> '',
                                CurrentFrequencyHz,
                                TelnetIsConnected or NetIsConnected,
                                GHaveLast, GLastStamp, UTCNow, GLastFreqHz);
end;

function SelfSpotNow(aTrigger: TSelfSpotTrigger; out aMessage: string): boolean;
var
   verdict: TSelfSpotVerdict;
   minutes: integer;
   freqHz: integer;
   freqText: string;
begin
   Result := False;
   verdict := CurrentVerdict(aTrigger, minutes);
   if verdict <> ssvSend then
      begin
      aMessage := VerdictText(verdict, minutes);
      Exit;
      end;

   freqHz   := CurrentFrequencyHz;
   freqText := FreqToPChar(SpotFrequencyRoundedHz(freqHz));
   if SendDXSpot(string(Settings.My.Call), freqText,
                 ContestId(Contest)) then
      begin
      GHaveLast   := True;
      GLastStamp  := UTCNow;
      GLastFreqHz := freqHz;
      Result := True;
      aMessage := UnicodeFormat(SSelfSpotSent, [string(Settings.My.Call), freqText]);
      end
   else
      begin
      (* The link dropped between the verdict and the send. *)
      aMessage := SSelfSpotNoLink;
      end;
end;

procedure SelfSpotFromMenu;
var
   msg: string;
begin
   if SelfSpotNow(sstMenu, msg) then
      begin
      QuickDisplay(msg);
      end
   else
      begin
      QuickDisplayError(msg);
      end;
end;

procedure SelfSpotTick;
var
   verdict: TSelfSpotVerdict;
   minutes: integer;
   msg: string;
begin
   if not Settings.Cluster.AutoSelfSpot then
      begin
      Exit;
      end;

   verdict := CurrentVerdict(sstAuto, minutes);
   if verdict = ssvSend then
      begin
      if SelfSpotNow(sstAuto, msg) then
         begin
         QuickDisplay(msg);
         GLastAutoVerdict := ssvSend;
         end;
      Exit;
      end;

   (* Held back. "Too soon" is the normal state between two spots -- never
     worth a line. Anything else is logged once per change of reason. *)
   if (verdict <> ssvTooSoon) and (verdict <> GLastAutoVerdict) then
      begin
      if logger <> nil then
         begin
         logger.Debug('[SelfSpot] automatic self-spot held back: ' + VerdictText(verdict, minutes));
         end;
      end;
   GLastAutoVerdict := verdict;
end;

end.
