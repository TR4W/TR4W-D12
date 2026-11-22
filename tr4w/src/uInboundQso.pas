unit uInboundQso;
{$I tr4w.inc}

(* A QSO that ANOTHER PROGRAM logged becomes a QSO in this log -- the one place
  that does it (issue 45, 2026-11-22).

  Three things hand TR4W an ADIF record from outside: WSJT-X's logged-ADIF
  message (uWSJTX), the N1MM "Log" envelope that JTDX and JTAlert send
  (uN1MMLogListener), and -- not built yet -- a REST POST of a QSO.  NY4I: the
  parser is data-source agnostic, ONE code path, whatever carried the text.  The
  file import is the same reader at the front (MainUnit.ReadADIFRecord); only
  its tail differs, because an import is a batch and this is one live QSO.

  TWO STEPS, so a source can do its own work between them (WSJT-X reads the
  record's grid for a state in between, and warns about an operator mismatch):

    ParseInboundADIF       the record, the call's country, the DX QTH / prefix
    LogParsedInboundQso    the checks, the band / frequency / mode, the log
                           write, and the entry-field reset a typed QSO does

  THE OPEN CONTEST'S RECORD: the record's CONTEST_ID is NOT read
  (ParseSessionADIFRecord).  An overlay program writes its own -- the Delaware
  QSO Party's FT8 arrives as ARRL-FIELD-DAY -- and honouring it rewrote the log's
  contest (uTestContestDelawareQP.Test_DelawareWSJTXFieldDayRecordStaysDelaware).

  MAIN THREAD ONLY: LogContact writes the log store and the dupe sheet,
  ParametersOkay reads the entry state.  The callers hand a record over with
  Application.QueueAsyncCall; this unit does not check, they do.

  A DUPE IS LOGGED AND FLAGGED, NOT REFUSED (NY4I, issue 45): a resend over UDP
  would be hidden by a refusal.  The normal dupe sheet decides, as for WSJT-X.

  THE ENTRY FIELDS ARE CLEARED, as they are for a WSJT-X QSO: a QSO logged by
  another program wipes whatever the operator was typing.  That is the existing
  WSJT-X behaviour, now shared. *)

interface

uses
   VC;

type
   TInboundQsoResult = (
      iqNotRead,     (* the text held no record *)
      iqNoCall,      (* a record with no callsign: nothing to log *)
      iqRefused,     (* ParametersOkay said no (it has told the operator why) *)
      iqNotStored,   (* LogContact could not write the log (it has said why) *)
      iqLogged);

(* The scoring mode a record is logged under.  The parsed mode when the record
  named one TR4W knows; Digital when it did not (aFellBack True), because a
  program that sends us a QSO this way is a digital-mode program.  Pure. *)
function InboundQsoMode(aParsed: ModeType; out aFellBack: boolean): ModeType;

(* Step 1: aExch is cleared, then filled from the record and the call located.
  False when the text held no record. *)
function ParseInboundADIF(const aAdif: string; var aExch: ContestExchange): boolean;

(* Step 2: check and log what step 1 produced.  aSource names the sender for the
  log ('WSJT-X', 'N1MM listener').  aExch is cleared after a logged QSO. *)
function LogParsedInboundQso(var aExch: ContestExchange;
                             const aSource: string): TInboundQsoResult;

implementation

uses
   LCLIntf,            // GetTickCount64
   SysUtils,
   uSettingsModel,     // Settings
   MainUnit,           // ParseSessionADIFRecord, ParametersOkay, UpdateWindows
   LogDupe,            // ClearContestExchange
   uCTYDAT,            // ctyLocateCall
   LOGSUBS2,           // LogContact
   LogStuff,           // the entry flags
   LogEdit,            // SetDXQTHAndPrefix, CleanUpDisplay
   LOGRADIO,           // ActiveRadioPtr
   LOGWIND,            // OpMode
   LogK1EA,            // tElapsedTimeFromLastQSO
   uMainForm,          // QueueClearCallAndFocus
   uCabrilloFormat;    // tCabrilloFreqString

function InboundQsoMode(aParsed: ModeType; out aFellBack: boolean): ModeType;
begin
   aFellBack := (aParsed = NoMode);
   if aFellBack then
      begin
      Result := Digital;
      end
   else
      begin
      Result := aParsed;
      end;
end;

function ParseInboundADIF(const aAdif: string; var aExch: ContestExchange): boolean;
begin
   ClearContestExchange(aExch);
   Result := ParseSessionADIFRecord(aAdif, aExch);
   if not Result then
      begin
      Exit;
      end;

   ctyLocateCall(aExch.Callsign, aExch.QTH);

   (* The DX QTH, then the prefix, from one contest lookup -- M11 S4
     (LOGEDIT.SetDXQTHAndPrefix). *)
   SetDXQTHAndPrefix(aExch);
end;

function LogParsedInboundQso(var aExch: ContestExchange;
                             const aSource: string): TInboundQsoResult;
var
   tempBand: BandType;
   tempFreq: integer;
   tempMode: ModeType;
   fellBack: boolean;
begin
   if aExch.Callsign = '' then
      begin
      logger.Warn('[Inbound] %s: a record with no callsign was not logged',
                  [aSource]);
      Result := iqNoCall;
      Exit;
      end;

   // ParseADIFRecord populates QTHString (state/grid/zone) for most
   // contests but does not always copy it into ExchString.
   // ParametersOkay requires a non-empty ExchString to call
   // ProcessExchange -- fall back to QTHString when ExchString is empty.
   if aExch.ExchString = '' then
      begin
      aExch.ExchString := aExch.QTHString;
      end;

   if aExch.Band <> NoBand then
      begin
      tempBand := aExch.Band;
      end
   else
      begin
      tempBand := ActiveBand;
      end;

   if aExch.Frequency <> 0 then
      begin
      tempFreq := aExch.Frequency;
      end
   else
      begin
      if ActiveRadioPtr.LastDisplayedFreq = 0 then // No connected radio so use default for band
         begin
         (* AnsiString: SysUtils' StrToIntDef takes 8-bit strings, and the band
           default is an ASCII token, so the conversion is lossless. *)
         tempFreq := StrToIntDef(AnsiString(tCabrilloFreqString[aExch.Band]), 0) * 1000; //14000 in array but needs to be 14000000
         end
      else
         begin
         tempFreq := ActiveRadioPtr.LastDisplayedFreq;
         end;
      end;

   tempMode := InboundQsoMode(aExch.Mode, fellBack);
   if fellBack then
      begin
      logger.Warn('[Inbound] %s: %s sent a mode TR4W does not know; logged as ' +
                  'Digital', [aSource, string(aExch.Callsign)]);
      aExch.Mode := tempMode;
      aExch.ExtMode := eData;
      end;

   if not ParametersOkay(aExch.Callsign, aExch.ExchString, tempBand,
                         tempMode, tempFreq, aExch) then
      begin
      Result := iqRefused;
      Exit;
      end;

   aExch.DomesticQTH := aExch.QTHString;
   // Set these on the record actually being logged, not ReceivedData --
   // otherwise the QSO logs with a blank Computer ID and an unset S&P flag.
   aExch.ceSearchAndPounce := OpMode = SearchAndPounceOpMode;
   aExch.ceComputerID := Settings.Computer.Id;

   (* NOT IN THE LOG (2026-11-18: a full disk, or a read-only log): LogContact
     has said why on the status line, with a beep.  Nothing below runs -- no
     post-QSO window work that would wipe that line, and no "ready for the next
     QSO".  The sending program keeps its own record. *)
   if not LogContact(aExch, True) then
      begin
      logger.Error('[Inbound] %s QSO with %s was NOT logged -- the log would ' +
                   'not take it', [aSource, string(aExch.Callsign)]);
      Result := iqNotStored;
      Exit;
      end;

   (* GetTickCount64: MainUnit writes the same variable with it, and one 32-bit
     writer is what makes a shared stamp disagree with itself. *)
   tElapsedTimeFromLastQSO := GetTickCount64;
   UpdateWindows;
   ClearContestExchange(aExch);
   CallAlreadySent := False;
   ExchangeHasBeenSent := False;
   EditingCallsignSent := False;
   SeventyThreeMessageSent := False;
   EscapeDeletedCallEntry := CallWindowString;
   QueueClearCallAndFocus;
   CleanUpDisplay;
   Result := iqLogged;
end;

end.
