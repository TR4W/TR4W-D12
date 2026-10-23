unit uN1MMMode;
{$I tr4w.inc}

(* The MODE NAME TR4W puts on the wire to N1MM-format listeners: the UDP
  contact broadcast (logsubs2.BuildUDPContact) and the RadioInfo packet
  (uRadioPolling).  One answer, so the two cannot drift.

  NEVER VC.ExtendedModeStringArray.  Those are TR4W's own spellings -- DATA,
  CW-R, FM-N, D-STAR, NoMode ... -- and no other program knows them.  N1MM's
  documented RadioInfo vocabulary is CW, USB, LSB, RTTY, PSK31 ..., FSK, GMSK,
  DOMINO, HELL, MT63, THOR, OLIVIA, MFSK8, MFSK16 and so on (n1mmwp.hamdocs.com,
  External UDP Broadcasts).  AM, FM, FT8, FT4 and JT65 are N1MM logging modes
  that list omits; they go as themselves.  Where N1MM has no name the ADIF
  name goes.  Generic data is RTTY, the same ruling as the ADIF export
  (issue 457).

  A leaf: it uses VC and nothing else. *)

interface

uses
   VC;

(* Sideband by frequency in Hz: 5,300,000..5,500,000 inclusive is USB (60 m is
  USB by convention, covering the US 5403.5 kHz channel), below 8,000,000 is
  LSB, everything above is USB. *)
function N1MMSidebandForFreq(aFreqHz: LongInt): string;

(* aMode is the base mode, consulted only when aExtMode is eNoMode (and for
  eSSB's sideband, aFreqHz). *)
function N1MMModeName(aMode: ModeType; aExtMode: ExtendedModeType;
                      aFreqHz: LongInt): string;

implementation

const
   (* '' means "derive it from the base mode / frequency".  An array over the
     enum, so a new ExtendedModeType value fails to compile until it has a
     row. *)
   N1MMExtModeNames: array[ExtendedModeType] of string =
      (
      (* eNoMode  *) '',
      (* eCW      *) 'CW',
      (* eRTTY    *) 'RTTY',
      (* eFT8     *) 'FT8',
      (* eFT4     *) 'FT4',
      (* eJT65    *) 'JT65',
      (* ePSK31   *) 'PSK31',
      (* ePSK63   *) 'PSK63',
      (* eSSB     *) '',
      (* eFM      *) 'FM',
      (* eAM      *) 'AM',
      (* eMFSK    *) 'MFSK',
      (* eJS8     *) 'JS8',
      (* eUSB     *) 'USB',
      (* eLSB     *) 'LSB',
      (* eData    *) 'RTTY',
      (* eCW_R    *) 'CW',
      (* eData_R  *) 'RTTY',
      (* eRTTY_R  *) 'RTTY',
      (* eFM_N    *) 'FM',
      (* eAM_N    *) 'AM',
      (* eData_FM *) 'RTTY',
      (* eC4FM    *) 'C4FM',
      (* eDStar   *) 'DSTAR',
      (* ePSK_R   *) 'PSK',
      (* eWFM     *) 'FM'
      );

function N1MMSidebandForFreq(aFreqHz: LongInt): string;
begin
   if (aFreqHz >= 5300000) and
      (aFreqHz <= 5500000) then
      begin
      Result := 'USB';
      end
   else if aFreqHz < 8000000 then
      begin
      Result := 'LSB';
      end
   else
      begin
      Result := 'USB';
      end;
end;

function N1MMModeName(aMode: ModeType; aExtMode: ExtendedModeType;
                      aFreqHz: LongInt): string;
begin
   Result := N1MMExtModeNames[aExtMode];
   if Result <> '' then
      begin
      Exit;
      end;

   if aExtMode = eSSB then
      begin
      Result := N1MMSidebandForFreq(aFreqHz);
      Exit;
      end;

   (* eNoMode: the base mode decides. *)
   case aMode of
      Phone:   Result := N1MMSidebandForFreq(aFreqHz);
      Digital: Result := 'RTTY';
      FM:      Result := 'FM';
      else     Result := 'CW';
   end;
end;

end.
