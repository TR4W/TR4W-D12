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
unit uTCIProtocol;

{
  THE TCI GRAMMAR.  Pure: no sockets, no radio, no logging.

  TCI (the ExpertSDR3 Transceiver Control Interface) is a text protocol over
  WebSocket.  One command is

      name[:arg1,arg2,...];

  and one WebSocket frame may carry several of them, or half of one.  This
  unit tokenizes that and formats replies.  Everything that decides WHAT to
  answer lives in uTCIServer; everything about the radio lives further down
  still.

  WHY A SHARED UNIT AND NOT THE CLIENT'S PARSER.  uRadioTCI (the TCI client)
  has its own dispatch, and that stays where it is: a client consumes
  notifications, a server answers requests, and merging those two would be a
  merge of two different jobs that happen to share a lexer.  What IS shared
  is exactly the lexer and the formatters, which is what lives here.

  ------------------------------------------------------------------------
  ARITY IS PER COMMAND.  THIS IS THE ONE DELIBERATE DIVERGENCE FROM THE
  REFERENCE SERVER, AND IT IS A BUG FIX.

  AetherSDR decides GET vs SET with a single global rule
  (TciProtocol.cpp:455):

      bool isSet = (args.size() >= 2);

  That is wrong for every command whose SET carries ONE argument.  Live
  consequence: `cw_macros_speed:20;` -- the natural way to set the keyer
  speed -- is one argument, so it is treated as a GET and answered with the
  CURRENT speed.  The command is unreachable, and the reference has three
  commands special-cased at the dispatch site precisely because the global
  rule does not fit them.

  So here every command declares its own arity, and the classifier is a
  table lookup.  A command with a one-argument SET simply says so.
  ------------------------------------------------------------------------

  SANITIZING IS NOT OPTIONAL.  ';' and ',' are the framing.  A value carrying
  either one corrupts the stream for EVERY client on the socket, not just the
  one that asked.  TCIMsg scrubs every argument it formats, so the escape is
  impossible to forget at a call site.
}

interface

uses
   SysUtils, Classes;

type
   TTCICommandKind = (
      tckNormal,            // dispatched normally
      tckNotificationOnly   // recognised, but server-to-client ONLY: an
                            // inbound one mutates nothing and answers nothing
      );

   TTCIRequestKind = (
      tcrUnknown,     // not a command we know -- answer with silence
      tcrGet,         // a read
      tcrSet,         // a write
      tcrMalformed,   // known name, argument count fits neither form
      tcrIgnored      // known, but notification-only
      );

   TTCICommand = record
      Name: string;            // lowercased
      Args: TArray<string>;    // trimmed, NOT lowercased (cw_msg keeps case)
      Raw:  string;
      function ArgCount: integer;
      // Safe accessors: an absent argument reads as empty/default rather
      // than raising.  Every caller would otherwise need the same guard.
      function Arg(Index: integer): string;
      function ArgInt(Index: integer; Default: integer): integer;
      function ArgIsTrue(Index: integer): boolean;
      // True only for a literal 'true'/'false' (case-insensitive).  The
      // reference treats any non-'true' as false, which silently accepts
      // `split_enable:0,yes` as an OFF command.
      function ArgBool(Index: integer; out Value: boolean): boolean;
   end;

   TTCICommandSpec = record
      Name:   string;
      GetMin: integer;   // inclusive arg-count range meaning GET; -1 = no GET
      GetMax: integer;
      SetMin: integer;   // at least this many args means SET; -1 = not settable
      Kind:   TTCICommandKind;
      // Accepts the GLOBAL one-argument form, e.g. 'split_enable:false'
      // instead of 'split_enable:0,false'.  WSJT-X really sends that -- it
      // was observed on the wire being read as a GET for receiver -1 and
      // answered with silence.  See TCIExpandGlobalForm.
      GlobalForm: boolean;
   end;

   { Splits an inbound text stream into commands.

     Frames do NOT align with commands: one frame may carry several `...;`
     commands or half of one, so the remainder has to be kept.  This is the
     same rule uRadioTCI.WSText follows on the client side. }
   TTCIFramer = class(TObject)
   private
      FBuffer: string;
      FMaxBuffer: integer;
      FOverflowed: boolean;
   public
      constructor Create(AMaxBuffer: integer = 8192);
      procedure Reset;
      procedure Append(const Text: string);
      // Pops the next complete command, without its ';'.  False when the
      // buffer holds no terminator yet.
      function  NextCommand(out Cmd: string): boolean;
      // True once a peer has sent MaxBuffer characters with no ';' at all.
      // A peer that never terminates must not make us grow without bound.
      property Overflowed: boolean read FOverflowed;
   end;

{ -------------------------------------------------------------- parsing -- }

function TCIParse(const Cmd: string): TTCICommand;

// Rewrites the GLOBAL one-argument form into the explicit per-receiver one:
// 'split_enable:false' becomes 'split_enable:0,false'.  Call this BEFORE
// TCIClassify so there is one shape downstream.
//
// The test is "argument 0 is not a receiver index".  'split_enable:0' stays a
// GET for receiver 0; 'split_enable:false' is a global SET.  That is the same
// distinction the reference server draws by hand in cmdDrive and cmdVolume,
// made once here instead of per command.
function TCIExpandGlobalForm(const Cmd: TTCICommand): TTCICommand;

// Looks up Cmd.Name and decides what was asked.  This is the ONLY place
// GET/SET is decided.
function TCIClassify(const Cmd: TTCICommand): TTCIRequestKind;

// The spec for a name, or a Name='' record when unknown.
function TCIFindSpec(const Name: string): TTCICommandSpec;

{ ------------------------------------------------------------ formatting -- }

// ';' and ',' are the framing; anything carrying one is scrubbed to '_'.
function TCISanitize(const S: string): string;

function TCIInt(Value: integer): string;
function TCIBool(Value: boolean): string;

function TCIMsg(const Name: string): string; overload;
function TCIMsg(const Name, A1: string): string; overload;
function TCIMsg(const Name, A1, A2: string): string; overload;
function TCIMsg(const Name, A1, A2, A3: string): string; overload;
function TCIMsg(const Name, A1, A2, A3, A4: string): string; overload;

// For cw_msg and friends, whose payload legitimately contains commas: the
// text is joined back and only ';' is scrubbed.
function TCIMsgFreeText(const Name, Text: string): string;

const
   // The identity block.  These are compatibility values, not descriptions
   // of our hardware, and each one is load-bearing:
   //
   //   protocol -- WSJT-X's TCITransceiver HALVES transmit sample amplitude
   //   (~ -6 dB) when the device names a SunSDR AND the protocol does not
   //   start with 'ExpertSDR3'.  Announcing ExpertSDR3 keeps the
   //   full-amplitude path and selects the command formats we implement.
   //
   //   device -- a literal name, not a SunSDR one, for the same reason and
   //   to avoid the leading-space bug in the '<name> <model>' form when a
   //   radio's nickname is empty.
   TCI_PROTOCOL_ID   = 'ExpertSDR3,1.5';
   TCI_DEVICE_NAME   = 'TR4W';

   // channels_count is PLURAL.  The published TCI PDF spells it
   // CHANNEL_COUNT, but the reference client parser (eesdr-tci, the basis of
   // many clients including the RF2K-S amplifier firmware) recognises only
   // the plural form and raises on the singular, aborting the handshake.
   // Implementation wins over the PDF.
   TCI_CHANNELS_COUNT = 2;

   // What TR4W can actually be told to do.  Deliberately short: a mode we
   // advertise and then cannot set is worse than one we never offered.
   TCI_MODULATIONS = 'usb,lsb,cw,cwr,am,fm,digu,digl,rtty';

   // Advisory only -- clients use these to sanity-check a tune.  The SAME
   // values must answer a request as appear in the init burst; the reference
   // server drifted into answering different ones, which is a defect, not a
   // convention to copy.
   TCI_VFO_LIMIT_LOW  = 1000;
   TCI_VFO_LIMIT_HIGH = 75000000;
   TCI_IF_LIMIT_LOW   = -48000;
   TCI_IF_LIMIT_HIGH  = 48000;

implementation

// TStringHelper.Split is a Delphi RTL string helper.  FPC 3.2.2 has no string
// helpers at all, so the member call is an "Illegal qualifier" there.  Splitting
// explicitly keeps ONE tokenizer that both compilers agree on -- which matters
// more here than elsewhere, because this is the wire grammar: a difference in
// how arguments split is a difference in what every TCI client is told.
function SplitOnChar(const S: string; Sep: Char): TArray<string>;
var
   i, start, n: integer;
begin
   SetLength(Result, 0);
   if S = '' then
      begin
      Exit;
      end;

   // One pass to count, one to fill -- no repeated reallocation.
   n := 1;
   for i := 1 to Length(S) do
      begin
      if S[i] = Sep then
         begin
         Inc(n);
         end;
      end;

   SetLength(Result, n);
   n := 0;
   start := 1;
   for i := 1 to Length(S) do
      begin
      if S[i] = Sep then
         begin
         Result[n] := Copy(S, start, i - start);
         Inc(n);
         start := i + 1;
         end;
      end;
   Result[n] := Copy(S, start, Length(S) - start + 1);
end;

const
   // The commands TR4W's server understands.  A rig bridge, so the SDR-only
   // surface of TCI (panadapter, noise blanker, IQ) is absent by design --
   // an unknown command is answered with silence, which is exactly what the
   // protocol says to do and what clients expect.
   //
   //                       name                 get       set  kind
   //                                          min  max    min
   TCI_SPECS: array[0..27] of TTCICommandSpec = (
      (Name: 'vfo';               GetMin: 2; GetMax: 2; SetMin: 3; Kind: tckNormal; GlobalForm: False),
      (Name: 'modulation';        GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),
      (Name: 'trx';               GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: True),
      (Name: 'tune';              GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),

      // drive/tune_drive accept a bare global GET and a per-trx GET.  Their
      // REPLY always carries <trx>,<power>: ESDR3-mode WSJT-X and JTDX index
      // args[1] unconditionally, and a one-field 'drive:0;' crashes them.
      (Name: 'drive';             GetMin: 0; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),
      (Name: 'tune_drive';        GetMin: 0; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),

      (Name: 'split_enable';      GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: True),
      (Name: 'rx_filter_band';    GetMin: 1; GetMax: 1; SetMin: 3; Kind: tckNormal; GlobalForm: False),
      (Name: 'rit_enable';        GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),
      (Name: 'xit_enable';        GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),
      (Name: 'rit_offset';        GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),
      (Name: 'xit_offset';        GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),
      (Name: 'dds';               GetMin: 1; GetMax: 1; SetMin: 2; Kind: tckNormal; GlobalForm: False),

      // One-argument SETs.  These are the commands the reference server's
      // global 'two or more args means SET' rule makes unreachable.
      (Name: 'cw_macros_speed';   GetMin: 0; GetMax: 0; SetMin: 1; Kind: tckNormal; GlobalForm: False),
      (Name: 'cw_msg';            GetMin: -1; GetMax: -1; SetMin: 1; Kind: tckNormal; GlobalForm: False),

      // Read-only identity.  The other identity commands (device, protocol,
      // trx_count...) have no inbound form at all and fall through to
      // silence, which is what the reference does and what clients expect --
      // but the LIMITS are genuinely asked for, because a client checks a
      // tune against them.
      (Name: 'vfo_limits';        GetMin: 0; GetMax: 1; SetMin: -1; Kind: tckNormal; GlobalForm: False),
      (Name: 'if_limits';         GetMin: 0; GetMax: 1; SetMin: -1; Kind: tckNormal; GlobalForm: False),

      (Name: 'start';             GetMin: 0; GetMax: 0; SetMin: -1; Kind: tckNormal; GlobalForm: False),
      (Name: 'stop';              GetMin: 0; GetMax: 0; SetMin: -1; Kind: tckNormal; GlobalForm: False),

      (Name: 'rx_sensors_enable'; GetMin: 0; GetMax: 0; SetMin: 1; Kind: tckNormal; GlobalForm: False),
      (Name: 'tx_sensors_enable'; GetMin: 0; GetMax: 0; SetMin: 1; Kind: tckNormal; GlobalForm: False),

      // Streams.  We have no audio to offer -- TR4W bridges a rig and the
      // client keeps its own soundcard -- but the commands are acknowledged
      // because a client that gets silence here concludes the server is
      // broken.  No binary frame is ever emitted.
      (Name: 'audio_start';       GetMin: 0; GetMax: 4; SetMin: -1; Kind: tckNormal; GlobalForm: False),
      (Name: 'audio_stop';        GetMin: 0; GetMax: 4; SetMin: -1; Kind: tckNormal; GlobalForm: False),
      (Name: 'iq_start';          GetMin: 0; GetMax: 4; SetMin: -1; Kind: tckNormal; GlobalForm: False),
      (Name: 'iq_stop';           GetMin: 0; GetMax: 4; SetMin: -1; Kind: tckNormal; GlobalForm: False),

      // Server-to-client state.  TCI 2.0 and Thetis both define TX_ENABLE
      // that way, so an inbound one must mutate nothing and answer nothing.
      // Recognised rather than unknown so the distinction is testable.
      (Name: 'tx_enable';         GetMin: -1; GetMax: -1; SetMin: -1; Kind: tckNotificationOnly; GlobalForm: False),
      (Name: 'rx_enable';         GetMin: -1; GetMax: -1; SetMin: -1; Kind: tckNotificationOnly; GlobalForm: False),
      (Name: 'rx_smeter';         GetMin: -1; GetMax: -1; SetMin: -1; Kind: tckNotificationOnly; GlobalForm: False)
      );

{ ---------------------------------------------------------- TTCICommand -- }

function TTCICommand.ArgCount: integer;
begin
   Result := Length(Args);
end;

function TTCICommand.Arg(Index: integer): string;
begin
   if (Index >= 0) and (Index < Length(Args)) then
      begin
      Result := Args[Index];
      end
   else
      begin
      Result := '';
      end;
end;

function TTCICommand.ArgInt(Index: integer; Default: integer): integer;
begin
   Result := StrToIntDef(Trim(Arg(Index)), Default);
end;

function TTCICommand.ArgBool(Index: integer; out Value: boolean): boolean;
var
   s: string;
begin
   s := LowerCase(Trim(Arg(Index)));
   if s = 'true' then
      begin
      Value := True;
      Result := True;
      end
   else if s = 'false' then
      begin
      Value := False;
      Result := True;
      end
   else
      begin
      // Not a boolean at all.  The reference reads "anything but true" as
      // false, which turns a typo into a working OFF command; we refuse and
      // let the caller answer with silence.
      Value := False;
      Result := False;
      end;
end;

function TTCICommand.ArgIsTrue(Index: integer): boolean;
begin
   if not ArgBool(Index, Result) then
      begin
      Result := False;
      end;
end;

{ ------------------------------------------------------------ TTCIFramer -- }

constructor TTCIFramer.Create(AMaxBuffer: integer);
begin
   inherited Create;
   FMaxBuffer := AMaxBuffer;
   Reset;
end;

procedure TTCIFramer.Reset;
begin
   FBuffer := '';
   FOverflowed := False;
end;

procedure TTCIFramer.Append(const Text: string);
begin
   FBuffer := FBuffer + Text;
   if Length(FBuffer) > FMaxBuffer then
      begin
      // A peer that never sends ';' is either broken or hostile.  Drop what
      // we have rather than grow, and say so, so the caller can close.
      FBuffer := '';
      FOverflowed := True;
      end;
end;

function TTCIFramer.NextCommand(out Cmd: string): boolean;
var
   p: integer;
begin
   Cmd := '';
   p := Pos(';', FBuffer);
   if p = 0 then
      begin
      Result := False;
      Exit;
      end;
   Cmd := Trim(Copy(FBuffer, 1, p - 1));
   Delete(FBuffer, 1, p);
   Result := True;
end;

{ -------------------------------------------------------------- parsing -- }

function TCIParse(const Cmd: string): TTCICommand;
var
   p:        integer;
   argsPart: string;
   i:        integer;
begin
   Result.Raw := Cmd;
   Result.Name := '';
   SetLength(Result.Args, 0);

   p := Pos(':', Cmd);
   if p = 0 then
      begin
      Result.Name := LowerCase(Trim(Cmd));
      Exit;
      end;

   Result.Name := LowerCase(Trim(Copy(Cmd, 1, p - 1)));
   argsPart := Copy(Cmd, p + 1, Length(Cmd));

   // An empty argument list ('trx:;') is no arguments, not one empty one --
   // otherwise a stray colon would turn a GET into a malformed SET.
   if Trim(argsPart) = '' then
      begin
      Exit;
      end;

   Result.Args := SplitOnChar(argsPart, ',');
   for i := 0 to High(Result.Args) do
      begin
      // Trimmed but NOT lowercased: cw_msg and spot text keep their case,
      // and the handlers that need a lowercase value ask for one.
      Result.Args[i] := Trim(Result.Args[i]);
      end;
end;

function TCIFindSpec(const Name: string): TTCICommandSpec;
var
   i: integer;
begin
   for i := Low(TCI_SPECS) to High(TCI_SPECS) do
      begin
      if TCI_SPECS[i].Name = Name then
         begin
         Result := TCI_SPECS[i];
         Exit;
         end;
      end;
   Result.Name := '';
   Result.GetMin := -1;
   Result.GetMax := -1;
   Result.SetMin := -1;
   Result.Kind := tckNormal;
end;

function TCIExpandGlobalForm(const Cmd: TTCICommand): TTCICommand;
var
   spec: TTCICommandSpec;
begin
   Result := Cmd;
   spec := TCIFindSpec(Cmd.Name);
   if (spec.Name = '') or (not spec.GlobalForm) then
      begin
      Exit;
      end;
   if Cmd.ArgCount <> 1 then
      begin
      Exit;
      end;
   // A receiver index is an integer.  Anything else in that position is the
   // VALUE, and the receiver was left implicit -- which by convention means
   // receiver 0, the one every WSJT-X instance addresses.
   if StrToIntDef(Cmd.Arg(0), MaxInt) <> MaxInt then
      begin
      Exit;
      end;
   SetLength(Result.Args, 2);
   Result.Args[0] := '0';
   Result.Args[1] := Cmd.Arg(0);
end;

function TCIClassify(const Cmd: TTCICommand): TTCIRequestKind;
var
   spec: TTCICommandSpec;
   n:    integer;
begin
   spec := TCIFindSpec(Cmd.Name);
   if spec.Name = '' then
      begin
      Result := tcrUnknown;
      Exit;
      end;

   if spec.Kind = tckNotificationOnly then
      begin
      Result := tcrIgnored;
      Exit;
      end;

   n := Cmd.ArgCount;

   // SET is tested FIRST because the forms overlap at the boundary: for
   // 'drive' a GET is 0 or 1 arguments and a SET is 2 or more, and for
   // 'vfo' a GET is exactly 2 while a SET is 3.  Testing GET first would
   // classify every SET whose count happened to fall in the GET range as a
   // read, which is the reference server's bug in a different disguise.
   if (spec.SetMin >= 0) and (n >= spec.SetMin) then
      begin
      Result := tcrSet;
      Exit;
      end;

   if (spec.GetMin >= 0) and (n >= spec.GetMin) and (n <= spec.GetMax) then
      begin
      Result := tcrGet;
      Exit;
      end;

   Result := tcrMalformed;
end;

{ ------------------------------------------------------------ formatting -- }

function TCISanitize(const S: string): string;
var
   i: integer;
begin
   Result := S;
   for i := 1 to Length(Result) do
      begin
      // ';' ends a command and ',' separates arguments.  Either one inside a
      // value re-frames the stream for every client on the socket, so this
      // is a correctness guard, not politeness.  CR/LF go too: they survive
      // a WebSocket TEXT frame and confuse line-oriented client parsers.
      if CharInSet(Result[i], [';', ',', #13, #10]) then
         begin
         Result[i] := '_';
         end;
      end;
end;

function TCIInt(Value: integer): string;
begin
   Result := IntToStr(Value);
end;

function TCIBool(Value: boolean): string;
begin
   // Lowercase literals: TCI values on the wire are always lowercase, and
   // some client parsers compare without folding case.
   if Value then
      begin
      Result := 'true';
      end
   else
      begin
      Result := 'false';
      end;
end;

function TCIMsg(const Name: string): string;
begin
   Result := LowerCase(Name) + ';';
end;

function TCIMsg(const Name, A1: string): string;
begin
   Result := LowerCase(Name) + ':' + TCISanitize(A1) + ';';
end;

function TCIMsg(const Name, A1, A2: string): string;
begin
   Result := LowerCase(Name) + ':' + TCISanitize(A1) + ',' + TCISanitize(A2) + ';';
end;

function TCIMsg(const Name, A1, A2, A3: string): string;
begin
   Result := LowerCase(Name) + ':' + TCISanitize(A1) + ',' + TCISanitize(A2) + ','
           + TCISanitize(A3) + ';';
end;

function TCIMsg(const Name, A1, A2, A3, A4: string): string;
begin
   Result := LowerCase(Name) + ':' + TCISanitize(A1) + ',' + TCISanitize(A2) + ','
           + TCISanitize(A3) + ',' + TCISanitize(A4) + ';';
end;

function TCIMsgFreeText(const Name, Text: string): string;
var
   body: string;
   i:    integer;
begin
   body := Text;
   for i := 1 to Length(body) do
      begin
      // Commas survive here -- they are part of the message, not framing --
      // but a ';' would still end the command early.
      if CharInSet(body[i], [';', #13, #10]) then
         begin
         body[i] := '_';
         end;
      end;
   Result := LowerCase(Name) + ':' + body + ';';
end;

end.
