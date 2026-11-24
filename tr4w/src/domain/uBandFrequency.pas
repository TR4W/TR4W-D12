unit uBandFrequency;
{$I ..\tr4w.inc}

(* THE FREQUENCY A BAND DEFAULTS TO, per mode -- one table, for every reader.

  It lived in LogWind (TFreqMemoryType, DefaultFreqMemory) beside the radio
  code that tunes to it. The ADIF writer needs it too (a QSO logged with no
  radio frequency still names a band, and a logger that refuses a record with
  no FREQ -- WRL -- would otherwise refuse the QSO; NY4I, 2026-11-24: a QSO
  with a band and no frequency takes the band's default for its mode), and uADIF does not depend on the TRDOS units. So the table is here,
  a leaf that needs only VC, and LogWind, the Band Plan window, the radio
  profile and the config reader all use THIS one.

  THE TABLE IS EDITABLE: the Band Plan window and the radio profile write
  DefaultFreqMemory[band, mode], so a reader asks at the moment it needs the
  answer and never caches one.

  Columns are the three ModeType values CW, Digital and Phone; the rows are
  every BandType, and a band with no default (the microwave rows, AllBands,
  NoBand) is 0. *)

interface

uses
   VC;

type
   TFreqMemoryType = array[BandType, CW..Phone] of LongInt;

var
   (* Hz, [band, CW | Digital | Phone]. Edited at run time; see above. *)
   DefaultFreqMemory: TFreqMemoryType =
      (
      (0001820000, 1840000, 0001840000),
      (0003525000, 3580000, 0003850000),
      (0007025000, 7040000, 0007070000),
      (0014025000, 14080000, 0014225000),
      (0021025000, 21080000, 0021300000),
      (0028050000, 28080000, 0028400000),

      (0010105000, 10125000, 0010105000),
      (0018068000, 18110000, 0018110000),
      (0024890000, 24920000, 0024930000),
      (0050125000, 50125000, 0050125000),
      (0144100000, 144200000, 0144200000),
      (0222100000, 0, 0222100000),
      (0433100000, 0, 0433200000),
      (0902000000, 0, 0902000000),
      (1296200000, 0, 1296200000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000),
      (0000000000, 0, 0000000000)
      );

(* The default frequency in Hz for aBand and aMode, 0 when the band has none.
  CW and Digital have their own column; every other mode (Phone, FM, Both,
  NoMode) answers the Phone column, the one a radio goes to for a voice QSO. *)
function DefaultBandFrequency(aBand: BandType; aMode: ModeType): LongInt;

implementation

function DefaultBandFrequency(aBand: BandType; aMode: ModeType): LongInt;
begin
   case aMode of
      CW:
         begin
         Result := DefaultFreqMemory[aBand, CW];
         end;
      Digital:
         begin
         Result := DefaultFreqMemory[aBand, Digital];
         end;
   else
      begin
      Result := DefaultFreqMemory[aBand, Phone];
      end;
   end;
end;

end.
