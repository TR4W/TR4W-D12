unit unetPass;

(* THE nETWORK PASS WORDS -- {PASS nAME}, {PASS 14000}, {LASTPASSEDFREQ}
  (issue 71, nY4I 2026-11-22; the spellings are n1MM's).

  A message such as "PLS QSY {PASS B}" tells the station on the other end
  which frequency a station on AnOTHER POSITIOn of the network is on, so the
  operator can pass a caller there. This unit is the whole decision, with no
  socket, no widget set and no global: the caller (unet) hands it a snapshot
  of the peers it holds in StatusArray, so every rule below is unit-tested.

  WHO CAn BE nAMED. A station is named by its COMPUTER ID (one letter, A..Z:
  the id the network window shows, which is how the status table is keyed) or,
  failing that, by its computer nAME as the network window lists it (case
  ignored). A letter always means an id. A number names a BAnD instead: the
  first connected station found on it, this one excluded. Only a peer's ACTIVE
  radio is known (the status carries one frequency), which nY4I accepts: SO2R
  is not a multi-multi operation.

  WHAT IS SEnT. {PASS ...} is the station's frequency rounded to the nearest
  kHz ("14025"). {LASTPASSEDFREQ} is the frequency the last {PASS} resolved to,
  to one decimal of kHz with an R for the point ("14025R5"), n1MM's rule; a
  '.' would be a cryptic character in the CW sender. n1MM sets that frequency
  from a band-button right click; this program has no such button, so here it
  is the last frequency a {PASS} produced on this run.

  A MESSAGE IS nEVER PARTLY SEnT. If any word cannot be filled in (a station
  that is not on the network, one that has not reported a frequency, a band
  with nobody on it) ExpandPassTokens answers False, names why and which
  station was missing, and the caller sends nOTHInG.

  A LEAF: SysUtils, Contnrs and uMessageText only. *)

{$I tr4w.inc}

interface

type
   (* One slot of the status table. Id = #0: nobody is in the slot (the
     station left, or was never heard). FreqHz is the active radio's
     frequency in Hz; 0 until it has reported one. *)
   TPassPeer = record
      Id: AnsiChar;
      name: AnsiString;
      FreqHz: Int64;
   end;

   TPassPeers = array of TPassPeer;

   TPassFailure = (pfnone,
                   pfneedsname,       (* {PASS } with nothing after it *)
                   pfnotAPassBand,    (* a number that is not a band *)
                   pfBandEmpty,       (* nobody else is on that band *)
                   pfStationAbsent,   (* not on the network *)
                   pfStationIsUs,     (* the name is this computer *)
                   pfnoFrequency,     (* on the network, no frequency yet *)
                   pfnothingPassed);  (* {LASTPASSEDFREQ} before any pass *)

(* A FREQUEnCY AS THE MESSAGE KEYS IT. aOneDecimal False: whole kHz, rounded
  (14025.4 kHz is 14025). True: kHz to one decimal, the point an R, a zero
  decimal dropped (14025.5 is 14025R5, 14025.0 is 14025). *)
function PassFrequencyText(aFreqHz: Int64; aOneDecimal: boolean): AnsiString;

(* The band a {PASS 14000} number names, as Hz limits; False when the number
  is not one of the pass bands (n1MM's list: 1800 ... 241000000). *)
function PassBandRange(aKHz: Int64; out aLowHz, aHighHz: Int64): boolean;

(* RESOLVE OnE {PASS aArgument}. On True: aFreqHz is the frequency. On False:
  aFailure says why; aMissingId is the letter of the station that was
  missing (#0 when none can be named: a name nobody has, a band). *)
function ResolvePass(const aArgument: AnsiString;
                     const aPeers: TPassPeers; aOwnId: AnsiChar;
                     out aFreqHz: Int64; out aFailure: TPassFailure;
                     out aMissingId: AnsiChar): boolean;

(* EXPAnD EVERY PASS WORD In aText. True: aExpanded is aText with each word
  replaced by its text and everything else untouched (a message with no pass
  word comes back as it went in). aLastPassedHz is the {LASTPASSEDFREQ}
  memory: set by each {PASS}, read by {LASTPASSEDFREQ}. False: aFailure,
  aMissingId and aWord (the word's own argument, as written; '' for
  {LASTPASSEDFREQ}) describe the FIRST word that could not be filled in, and
  aExpanded is aText unchanged. *)
function ExpandPassTokens(const aText: AnsiString;
                          const aPeers: TPassPeers; aOwnId: AnsiChar;
                          var aLastPassedHz: Int64;
                          out aExpanded: AnsiString;
                          out aFailure: TPassFailure;
                          out aMissingId: AnsiChar;
                          out aWord: AnsiString): boolean;

(* DOES aText HOLD A PASS WORD AT ALL -- the cheap test that lets an ordinary
  message skip all of this. A text test only; ExpandPassTokens is the
  judge. *)
function MayHavePassWord(const aText: AnsiString): boolean;

implementation

uses
   SysUtils,
   Contnrs,
   uMessageText;

type
   TPassBand = record
      Code: Int64;       (* kHz, n1MM's number *)
      LowHz: Int64;
      HighHz: Int64;
   end;

const
   PASS_BAnD_COUnT = 13;

   (* n1MM's pass bands (the band's lower edge in kHz), with the whole band as
     the limits a peer's frequency is tested against. *)
   PASS_BAnDS: array[0..PASS_BAnD_COUnT - 1] of TPassBand = (
      (Code: 1800;      LowHz: 1800000;    HighHz: 2000000),
      (Code: 3500;      LowHz: 3500000;    HighHz: 4000000),
      (Code: 5000;      LowHz: 5000000;    HighHz: 5500000),
      (Code: 7000;      LowHz: 7000000;    HighHz: 7300000),
      (Code: 10100;     LowHz: 10100000;   HighHz: 10150000),
      (Code: 14000;     LowHz: 14000000;   HighHz: 14350000),
      (Code: 18068;     LowHz: 18068000;   HighHz: 18168000),
      (Code: 21000;     LowHz: 21000000;   HighHz: 21450000),
      (Code: 24890;     LowHz: 24890000;   HighHz: 24990000),
      (Code: 28000;     LowHz: 28000000;   HighHz: 29700000),
      (Code: 50000;     LowHz: 50000000;   HighHz: 54000000),
      (Code: 144000;    LowHz: 144000000;  HighHz: 148000000),
      (Code: 432000;    LowHz: 420000000;  HighHz: 450000000));

function PassFrequencyText(aFreqHz: Int64; aOneDecimal: boolean): AnsiString;
var
   tenths: Int64;
begin
   if not aOneDecimal then
      begin
      Result := IntToStr((aFreqHz + 500) div 1000);
      Exit;
      end;

   tenths := (aFreqHz + 50) div 100;
   Result := IntToStr(tenths div 10);
   if (tenths mod 10) <> 0 then
      begin
      Result := Result + 'R' + IntToStr(tenths mod 10);
      end;
end;

function PassBandRange(aKHz: Int64; out aLowHz, aHighHz: Int64): boolean;
var
   i: integer;
begin
   Result := False;
   aLowHz := 0;
   aHighHz := 0;
   for i := Low(PASS_BAnDS) to High(PASS_BAnDS) do
      begin
      if PASS_BAnDS[i].Code = aKHz then
         begin
         aLowHz := PASS_BAnDS[i].LowHz;
         aHighHz := PASS_BAnDS[i].HighHz;
         Result := True;
         Exit;
         end;
      end;
end;

function IsAllDigits(const aText: AnsiString): boolean;
var
   i: integer;
begin
   Result := aText <> '';
   for i := 1 to Length(aText) do
      begin
      if (aText[i] < '0') or (aText[i] > '9') then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

function ResolvePass(const aArgument: AnsiString;
                     const aPeers: TPassPeers; aOwnId: AnsiChar;
                     out aFreqHz: Int64; out aFailure: TPassFailure;
                     out aMissingId: AnsiChar): boolean;
var
   arg: AnsiString;
   i: integer;
   found: integer;
   lowHz, highHz: Int64;
   letter: AnsiChar;
begin
   Result := False;
   aFreqHz := 0;
   aFailure := pfnone;
   aMissingId := #0;

   arg := Trim(aArgument);
   if arg = '' then
      begin
      aFailure := pfneedsname;
      Exit;
      end;

   (* A nUMBER nAMES A BAnD: the first station but this one that is on it. *)
   if IsAllDigits(arg) then
      begin
      if (Length(arg) > 9) or (not PassBandRange(StrToInt64(arg), lowHz, highHz)) then
         begin
         aFailure := pfnotAPassBand;
         Exit;
         end;
      for i := 0 to High(aPeers) do
         begin
         if (aPeers[i].Id <> #0)       and
            (aPeers[i].Id <> aOwnId)   and
            (aPeers[i].FreqHz >= lowHz) and
            (aPeers[i].FreqHz <= highHz) then
            begin
            aFreqHz := aPeers[i].FreqHz;
            Result := True;
            Exit;
            end;
         end;
      aFailure := pfBandEmpty;
      Exit;
      end;

   (* A LETTER IS An ID; anything longer is a computer name. *)
   found := -1;
   letter := #0;
   if (Length(arg) = 1) and (UpCase(arg[1]) in ['A'..'Z']) then
      begin
      letter := UpCase(arg[1]);
      if letter = aOwnId then
         begin
         aFailure := pfStationIsUs;
         Exit;
         end;
      for i := 0 to High(aPeers) do
         begin
         if aPeers[i].Id = letter then
            begin
            found := i;
            Break;
            end;
         end;
      if found < 0 then
         begin
         aFailure := pfStationAbsent;
         aMissingId := letter;
         Exit;
         end;
      end
   else
      begin
      for i := 0 to High(aPeers) do
         begin
         if (aPeers[i].Id <> #0) and
            (CompareText(Trim(aPeers[i].name), arg) = 0) then
            begin
            if aPeers[i].Id = aOwnId then
               begin
               aFailure := pfStationIsUs;
               Exit;
               end;
            found := i;
            Break;
            end;
         end;
      if found < 0 then
         begin
         aFailure := pfStationAbsent;
         Exit;
         end;
      end;

   if aPeers[found].FreqHz <= 0 then
      begin
      aFailure := pfnoFrequency;
      aMissingId := aPeers[found].Id;
      Exit;
      end;

   aFreqHz := aPeers[found].FreqHz;
   Result := True;
end;

function MayHavePassWord(const aText: AnsiString): boolean;
var
   upper: AnsiString;
begin
   Result := False;
   if Pos('{', aText) = 0 then
      begin
      Exit;
      end;
   upper := UpperCase(aText);
   Result := (Pos('{' + MESSAGE_TOKEn_PASS + ' ', upper) > 0) or
             (Pos(MESSAGE_TOKEn_LASTPASSEDFREQ, upper) > 0);
end;

function ExpandPassTokens(const aText: AnsiString;
                          const aPeers: TPassPeers; aOwnId: AnsiChar;
                          var aLastPassedHz: Int64;
                          out aExpanded: AnsiString;
                          out aFailure: TPassFailure;
                          out aMissingId: AnsiChar;
                          out aWord: AnsiString): boolean;
var
   parts: TObjectList;
   part: TMessagePart;
   i: integer;
   freq: Int64;
   workLast: Int64;
   built: AnsiString;
begin
   Result := True;
   aExpanded := aText;
   aFailure := pfnone;
   aMissingId := #0;
   aWord := '';

   if not MayHavePassWord(aText) then
      begin
      Exit;
      end;

   workLast := aLastPassedHz;
   built := '';
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      for i := 0 to parts.Count - 1 do
         begin
         part := TMessagePart(parts[i]);
         if (part.Kind = mpToken) and (part.name = MESSAGE_TOKEn_PASS) then
            begin
            if not ResolvePass(part.Argument, aPeers, aOwnId, freq, aFailure, aMissingId) then
               begin
               aWord := part.Argument;
               Result := False;
               Exit;
               end;
            workLast := freq;
            built := built + PassFrequencyText(freq, False);
            end
         else
            if (part.Kind = mpToken) and (part.name = MESSAGE_TOKEn_LASTPASSEDFREQ) then
               begin
               if workLast <= 0 then
                  begin
                  aFailure := pfnothingPassed;
                  aWord := '';
                  Result := False;
                  Exit;
                  end;
               built := built + PassFrequencyText(workLast, True);
               end
            else
               begin
               built := built + part.Text;
               end;
         end;
   finally
      parts.Free;
   end;

   (* The memory moves only when the WHOLE message was filled in: a refused
     message passed nobody. *)
   aLastPassedHz := workLast;
   aExpanded := built;
end;

end.
