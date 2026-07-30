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
unit uRadioFlex6000;

{
  MODEL unit for the FlexRadio 6000 series (FLEX-6300/6400/6600/6700/6800, Aurora).

  This unit declares no class of its own.  It exists to hold the single
  RegisterRadio call for FLEX and to name which protocol driver serves each
  transport:

      Radio Control Port = TCP   -> TFlexAPI (uRadioFlexAPI), SmartSDR Ethernet
                                    API on port 4992
      Radio Control Port = COMn  -> TFlexCAT (uRadioFlexCAT), CAT protocol
                                    (Kenwood 2-char + Flex ZZxx) over the
                                    SmartSDR CAT virtual serial port

  ONE radio type in the radio list ("FlexRadio 6000").  The operator picks the
  transport by setting the control port, exactly as for every other radio that
  offers both -- the difference here is invisible to them.

  WHY TWO CLASSES.  Every other dual-transport radio in TR4W (IC-7610, IC-9700,
  K4, TS-890 ...) speaks ONE protocol over two pipes, so it registers one ctor
  and TFactoryRadioBase.Connect/SendToRadio pick the pipe.  Flex is the one
  exception: 4992 is a genuinely different protocol from the CAT port -- command
  sequence numbers, a client handle and pushed status subscriptions, versus
  ';'-terminated ZZ commands that must be polled.  Rather than make TFlexAPI the
  only driver in the tree that switches protocol on transport, the registry
  takes a constructor per transport.  See uRadioRegistry.RegisterRadio (two-ctor
  overload) and docs/ADDING_A_RADIO.md.

  ADDING A LATER FLEX.  If a future model diverges on only one side, subclass
  just that driver (e.g. TFlex8000CAT = class(TFlexCAT)) and give the model its
  own unit with its own RegisterRadio.  Neither protocol driver learns which
  model it is serving -- same rule as the Yaesu/Icom family bases.
}

interface

implementation

uses
   uRadioRegistry, uRadioFlexAPI, uRadioFlexCAT, VC;

initialization
   RegisterRadio(FLEX,
      function: TFactoryRadioBase begin Result := TFlexAPI.Create end,   // network: 4992 Ethernet API
      function: TFactoryRadioBase begin Result := TFlexCAT.Create end,   // serial:  ZZ CAT
      // discoverable = True, and now backed by a real implementation:
      // uFlexDiscovery listens for the radio's 1 Hz VITA-49 broadcast on UDP
      // 4992, dispatched from uCAT.DiscoverNetworkRadios.  Before that existed
      // this flag was True with nothing behind it, so the dialog offered a
      // Discover button that could only ever report "no Flex radios found".
      'FlexRadio 6000', [rlSerial, rlNetwork], 4992, True,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
