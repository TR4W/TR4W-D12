unit uRadioPanelState;

(* WHAT A RADIO PANEL SAYS ABOUT WHICH RADIO, AND WHICH VFO -- the UI refresh
  proposal's "Radio display" (docs/TR4W_UI_REFRESH_PROPOSAL.md), 2026-11-22.

  Two separate facts, kept apart on purpose:

    THE ACTIVE RADIO is the station's choice (ActiveRadioPtr; SO2R swaps it).
    It is shown by the panel's cyan tint, unchanged, and by a compact "Active"
    label on the active radio's panel only. RadioPanelShowsActive decides it.

    THE ACTIVE VFO is the RIG's state (VFO A or B, from the polling thread). It
    is shown by the readouts' weight: the VFO the rig names keeps the bold the
    form was designed with, and the other one drops to regular (it was already
    greyed). VFOReadoutIsBold decides it.

  WEIGHT, NOT SIZE. The panel's scaler (uLCLFormHelpers.ApplyLayoutScale)
  rewrites every control's Font.Height on each resize and never touches the
  style, so a style survives a drag where a larger size step would not; and a
  regular face is narrower than the bold one the readout was designed to hold,
  so the change can only make text fit better, never worse.

  NO LCL. uRadioPanelForm asks the controls (Enabled) and the radio pointers
  and hands the answers in; uTestRadioPanelState pins every rule. *)

{$I tr4w.inc}

interface

(* Whether the panel for aPanelSlot (1 or 2) is the active radio's, given
  aActiveSlot (1 or 2, or 0 when neither radio is active). A slot outside 1..2
  is never the active one. *)
function RadioPanelShowsActive(const aPanelSlot, aActiveSlot: integer): boolean;

(* Whether a VFO readout is drawn bold. aThisVFOActive / aOtherVFOActive are
  whether the rig names this readout's VFO and the other one (the panel's
  Enabled state). A readout drops to regular ONLY when the rig names the OTHER
  VFO alone; when the rig names neither or both (vfoUnknown), both stay bold,
  which is the panel as designed. *)
function VFOReadoutIsBold(const aThisVFOActive, aOtherVFOActive: boolean): boolean;

implementation

function RadioPanelShowsActive(const aPanelSlot, aActiveSlot: integer): boolean;
begin
   Result := (aPanelSlot >= 1)          and
             (aPanelSlot <= 2)          and
             (aPanelSlot = aActiveSlot);
end;

function VFOReadoutIsBold(const aThisVFOActive, aOtherVFOActive: boolean): boolean;
begin
   Result := aThisVFOActive or (not aOtherVFOActive);
end;

end.
