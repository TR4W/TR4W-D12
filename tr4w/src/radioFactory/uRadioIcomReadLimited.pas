{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uRadioIcomReadLimited;
{$I ..\tr4w.inc}

{
  Shared base for the CI-V radios that read everything a modern Icom does EXCEPT
  the unselected VFO and the RIT offset.  Registers nothing -- one model per unit.

  THE PROFILE, AND WHY IT IS THIS AND NOT LESS.  It is the modern profile
  (TIcomModernRadio) minus exactly two flags:

      rcReadVFOB   -- absent from LOGRADIO's IcomRadiosThatSupportVFOB
      rcReadRIT    -- absent from IcomRadiosThatSupportRIT

  Stated here as the three flags these radios HAVE (split, TX status, data mode)
  rather than inherit-modern-and-Exclude: since the base class default went
  restrictive, every family base declares its full set explicitly -- no
  subtraction, so what a radio claims is readable in one place.

  Nothing else is removed, and that precision matters: an earlier version of this
  migration attached these radios to TIcomLegacyRadio instead -- the conservative
  profile NY4I's testers bench-proved on the IC-706 family and the IC-7000 -- and
  silently withheld four things D7 does for every Icom but the IC-718:

      $0F split read       IcomRadiosSplitSetOnly       = [IC718]
      $1C TX status        IcomRadiosTXStatusUnreadable = [IC718]
      $06 filter byte      IcomRadiosModeSetNoFilter    = [IC718]
      $1A06 data mode      not list-gated at all -- D7 PROBES it (icomHasDataMode)

  Neither of the first two sets even EXISTS in the D7 tree: D7 polls both for
  every Icom, unconditionally.  The root mistake was reading a one-element
  deny-list as "only this model is proven" when it means "one exception".

  uTestIcomRegistry compares all four sets against every registered CI-V radio,
  so that class of error now fails the build.

  PROMOTION PATH: a model that turns out to differ gets the deviation in its own
  unit -- override DefineCapabilities there.  Nothing here should ever test which
  radio it is.
}

interface

uses uFactoryRadioBase, uRadioIcomBase;   // uFactoryRadioBase for TRadioCapability

type
  TIcomReadLimitedRadio = class(TIcomRadio)
  protected
    procedure DefineCapabilities; override;
  end;

implementation

procedure TIcomReadLimitedRadio.DefineCapabilities;
begin
  // The modern profile minus rcReadVFOB and rcReadRIT -- those two, and ONLY
  // those two, per LOGRADIO's capability sets (see the unit header).
  FCapabilities.Flags := [rcReadSplit, rcReadTXStatus, rcDataMode];
  FCapabilities.CWSpeedMin := 6;
  FCapabilities.CWSpeedMax := 48;
end;

end.
