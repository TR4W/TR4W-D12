unit uWSJTXReport;
{$I tr4w.inc}

(* A WSJT-X SNR, AND THE RST THE LOG SHOWS FOR IT (issue 261, split from 173).

  WSJT-X's logged record carries the report as a signed dB SNR ("-12", "+05"),
  and ParseADIFRecord stores it in the QSO's RSTReceived as that small number.
  The Cabrillo export turns a value below 25 back into an RST (postunit); this
  unit is the ONE place that says which modes it does that for, and how.

  WHICH MODES.  A mode whose report is a dB SNR the way FT8's is: FT8, FT4,
  JT65, FST4 and FST4W, plus eMFSK, which is what a WSJT-X record naming MFSK
  with no recognised submode parses to.  History: D7 (C:\TR4W postunit) listed
  eFT8, eMFSK and eJT65, written when those were the modes WSJT-X offered;
  FT4 followed, and FST4 / FST4W arrived with issue 173, and neither was added
  (FT4 is an MFSK submode in ADIF, so it parses to eFT4 and fell through to the
  "not a WSJT-X mode" branch: its received report was exported as "-12").

  WHICH MODES NOT.  Q65, JT9 and MSK144 have no ExtendedModeType value at all
  (their ADIF mode / submode parse to eNoMode), so no ExtMode can name them and
  nothing here can include them.  eJS8 is JS8Call's, a different program with
  its own report convention.  Everything else (CW, SSB, RTTY, PSK) carries a
  real RST, never a dB value.

  A leaf: it uses VC and nothing else. *)

interface

uses
   VC;

const
   (* The ExtMode values whose RSTReceived is a WSJT-X dB SNR. *)
   WSJTX_SNR_MODES = [eFT8, eFT4, eJT65, eFST4, eFST4W, eMFSK];

   (* A stored report below this is an SNR, not an RST (the legacy test). *)
   WSJTX_SNR_RST_LIMIT = 25;

(* True when aExtMode is one of WSJTX_SNR_MODES. *)
function WSJTXModeReportsSNR(aExtMode: ExtendedModeType): Boolean;

(* The RST for a dB SNR: nine bands of 6 dB, 509 (-20 and below) to 599 (+28
  and above). *)
function WSJTXSnrToRST(aSnr: integer): integer;

(* What the Cabrillo exchange prints for a RECEIVED report.  A SNR-mode QSO whose
  stored value is below WSJTX_SNR_RST_LIMIT is converted when WSJT-X is enabled
  and is 599 when it is not; every other combination is the stored value. *)
function WSJTXReceivedReportForExport(aExtMode: ExtendedModeType;
                                      aStored: integer;
                                      aWsjtxEnabled: Boolean): integer;

implementation

function WSJTXModeReportsSNR(aExtMode: ExtendedModeType): Boolean;
begin
   Result := aExtMode in WSJTX_SNR_MODES;
end;

function WSJTXSnrToRST(aSnr: integer): integer;
begin
   if aSnr <= -20 then
      begin
      Result := 509;
      end
   else if aSnr < -14 then
      begin
      Result := 519;
      end
   else if aSnr < -8 then
      begin
      Result := 529;
      end
   else if aSnr < -2 then
      begin
      Result := 539;
      end
   else if aSnr < 4 then
      begin
      Result := 549;
      end
   else if aSnr < 10 then
      begin
      Result := 559;
      end
   else if aSnr < 16 then
      begin
      Result := 569;
      end
   else if aSnr < 22 then
      begin
      Result := 579;
      end
   else if aSnr < 28 then
      begin
      Result := 589;
      end
   else
      begin
      Result := 599;
      end;
end;

function WSJTXReceivedReportForExport(aExtMode: ExtendedModeType;
                                      aStored: integer;
                                      aWsjtxEnabled: Boolean): integer;
begin
   if WSJTXModeReportsSNR(aExtMode) and
      (aStored < WSJTX_SNR_RST_LIMIT) then
      begin
      if aWsjtxEnabled then
         begin
         Result := WSJTXSnrToRST(aStored);
         end
      else
         begin
         Result := 599;
         end;
      end
   else
      begin
      Result := aStored;
      end;
end;

end.
