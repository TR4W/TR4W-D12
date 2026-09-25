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
unit uRadioIcom7110;
{$I ..\tr4w.inc}

{
  Icom IC-7110 Radio Implementation

  THIS IS A CLONE OF THE IC-705, NOT A DRIVER WRITTEN FROM A MANUAL.
  Added 2026-08-28 (NY4I). The radio has only just been announced, so its CI-V
  reference guide is not available to check anything against; this is a
  placeholder that lets an operator select the model and talk to it on the one
  fact we do have -- its CI-V address -- rather than a finished driver.

  Only two things about it are asserted:

    CI-V address    0xBA   (given)
    Display name    Icom IC-7110

  EVERYTHING ELSE BELOW IS INHERITED AND UNVERIFIED for this model -- the band
  plan, the transceive menu address, the scope geometry, the capability flags
  and the serial parameters are the IC-705's, because that is what a clone
  means. The HamLib id is deliberately still the IC-705's (3085): NY4I does not
  have one for this radio yet, so HamLib will drive it as an IC-705.

  ADDING_A_RADIO.md step 2 says to read the manufacturer's CAT manual and not
  to assume it matches the model you copied, "even for one command". That step
  has NOT been done here. Do it before this is offered to an operator as a real
  radio, and correct the notes below rather than trusting them.

  Inherited from the IC-705, unconfirmed here:
  Controller address: 0xE0 (standard)
  Network capable: Yes (WiFi or Ethernet via USB)
  VFO B format: Standard ($25)
  Supported bands: 160m-6m (HF), 2m, 70cm; no 4m -- stated once, in
  DeclareCoverage, and no more verified than the rest of this header.
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, uFactoryRadioBase, uRadioBand, VC, uRadioRegistry;

type
  TIcom7110Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  protected
    procedure DeclareCoverage; override;
  end;

implementation

uses
  SysUtils, Log4D;

var
  logger: TLogLogger;

constructor TIcom7110Radio.Create;
begin
  inherited Create;
  RadioAddress := $BA;
  radioModel := 'Icom IC-7110';
  // The IC-705's transceive menu address, inherited unverified. $0131 rather
  // than the default $0150 (IC-7610/IC-7760). If the IC-7110 puts it elsewhere,
  // transceive silently never arms and the radio just looks unresponsive.
  FTransceiveMenuBytes := #$01 + #$31;
  logger.Info('[TIcom7110Radio.Create] Created IC-7110 instance with CI-V address $BA');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     UNVERIFIED FOR THIS MODEL.  475x160 is the IC-705's geometry, and on the
     IC-705 it is Tier 1 -- confirmed against Icom's own CI-V Reference Guide.
     Nobody has checked it against an IC-7110, because this driver is a clone.
     A wrong width here does not fail loudly: the scope simply draws with the
     wrong number of bins, which reads as a rendering bug rather than a data
     one.  Confirm it before believing a waterfall from this radio.

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(475, 160);
end;

(* COVERAGE, INHERITED FROM THE IC-705 UNVERIFIED -- like everything else here.

  This replaces a copy of the IC-705's band ladder, and carries exactly the
  same claim it did: HF through 6 m, 2 m, 70 cm, no 4 m.  It is no better
  grounded than it was, and it is now in one place where correcting it is one
  edit.  If this radio turns out to have a band this omits, the operator loses
  it from band-up/down as well as from stepping -- so check it against the CAT
  manual before this driver is offered to anyone, as the header says. *)
procedure TIcom7110Radio.DeclareCoverage;
begin
   AddCoverageRange(1800000, 54000000);         (* 160 m through 6 m, contiguous *)
   AddCoverageRange(144000000, 148000000);      (* 2 m *)
   AddCoverageRange(430000000, 450000000);      (* 70 cm *)
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7110: TFactoryRadioBase;
begin
   Result := TIcom7110Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7110');

  { REGISTERED BY ID, NOT BY ENUM -- and that is the whole point of this unit.

    RegisterRadio(IC7110, ...) would need an InterfacedRadioType member in
    VC.pas, which is a second file to edit for one radio and, historically, a
    second list to fall out of step with (two of them did; four Kenwoods
    selected the wrong driver for years). RegisterRadioById needs nothing
    outside this file.

    What it costs: the enum-keyed unit tests walk Low(InterfacedRadioType) to
    High and cannot see an id-only radio, so this driver is not covered by the
    exhaustive per-model pins. uTestCWFraming covers it explicitly by id
    instead, because a radio declaring rcCWByCAT with no frame rule has an
    uninitialised maxLen -- the silent zero that shipped the TS-850 as "no
    limit". Any future id-only radio needs the same treatment. }
  RegisterRadioById('IC7110',
     CreateIcom7110,
     'Icom IC-7110', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1),
     3085,        // HamLib: the IC-705's, until this radio has its own
     186);        // CI-V $BA

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials('IC7110');

end.
