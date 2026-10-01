(*
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
 *)

(* THE MY-EXCHANGE AS ADIF SEES IT, ONE ARM PER EXCHANGE SHAPE -- the twin of
  uCabrilloExchange, extracted for the same reasons and by the same recipe,
  and pinned arm by arm in uTestADIFExchange.

  SINCE M4 (2026-10-01) IT IS THE BASE'S DEFAULT. PostUnit asks the contest
  (uContestRegistry.ContestIdentity) for its STX_STRING, and
  TContestBase.FormatADIFSentExchange calls this with the session's exchange.
  Nothing here names a contest any more: FOC Marathon's membership number,
  PACC's serial and the PCC's sent branches are those classes' overrides, and
  CQ VHF's and SP DX's branches were dead (uCabrilloExchange's header has the
  measurement). The two arms inventory D4 listed -- Sweepstakes' and the Field
  Days' exchanges, owned by their classes since phase F -- are deleted.

  THE BODY IS OTHERWISE THE ONE THAT MOVED OUT OF PostUnit. Every global the
  arms read is a local of the SAME type, assigned once at the top, so the arms
  could come across unedited. *)
unit uADIFExchange;

{$I tr4w.inc}

interface

uses
  VC,
  SysUtils,
  uCabrilloExchange,   // TMyStationExchange -- ONE record, not a second copy
  uContestBase;

const
  (* WHAT STX_STRING CARRIES WHEN THE EXCHANGE COULD NOT BE BUILT -- a QSO
     that is not a good one, or a format that raised. One spelling, because
     PostUnit writes it too, for a contest's own formatter that raises. *)
  ADIFMyExchangeErrorMarker = 'Error generating my exchange';

(* Builds the ADIF MY-exchange string for one QSO from the shared arm for
  aKind. The caller has decided the QSO is a good one.

  An exchange with no arm returns ADIFMyExchangeErrorMarker and logs an Error;
  one on the not-yet-implemented list returns 'None', also logged; a format
  that raises returns the marker. Unhandled is REPORTED, not silently blank. *)
function FormatADIFExchangeOfKind(
    aKind          : ExchangeType;
    const rx       : ContestExchange;
    const my       : TMyStationExchange) : string;

implementation

uses
  Log4D;   // the same single concession uCabrilloExchange makes, and for the
           // same reason: an unhandled arm must say so.

var
  logger: TLogLogger;

function FormatADIFExchangeOfKind(
    aKind          : ExchangeType;
    const rx       : ContestExchange;
    const my       : TMyStationExchange) : string;
      var
        cMyZone: integer;
        cMyState: string;
        cMyPark: string;
        cMyName: string;
        cMyGrid: string;
        nrSent: integer;
        contacts: integer;
        PreviousQTHString: Str10;
        pnr: integer;

        (* THE OLD GLOBALS, AS LOCALS.

          Every one of these was a unit-scope global the arms read directly.
          Declaring them here with the SAME TYPES -- they are all ShortStrings,
          not `string` -- let the whole body move across UNCHANGED. *)
        MyGrid: GridString;
        MyName: Str20;
        MyState: Str20;
        MyPark: Str10;
        MyZone: Str20;
        MyPostalCode: Str20;
        TempRXData: ContestExchange;
      begin
      MyGrid       := GridString(my.MyGrid);
      MyName       := Str20(my.MyName);
      MyState      := Str20(my.MyState);
      MyPark       := Str10(my.MyPark);
      MyZone       := Str20(my.MyZone);
      MyPostalCode := Str20(my.MyPostalCode);
      TempRXData   := rx;

      (* THE OLD GLOBALS WERE ZERO.  THESE LOCALS ARE NOT.

        A global IS zero-initialised and a local is NOT, so moving them in
        silently changed what the arms read before anything assigns them --
        and nothing ever assigns these three here. Zero and empty are what
        they held as globals, so this restores the behaviour rather than
        choosing new values. *)
      contacts          := 0;
      pnr               := 0;
      PreviousQTHString := '';

      Result := ADIFMyExchangeErrorMarker;
      try
        cMyGrid := string( MyGrid );

        cMyName := string(MyName);

        cMyZone  := StrToIntDef( MyZone, 0 );
        cMyState := MyState;
        cMyPark  := MyPark;

        nrSent        := TempRXData.NumberSent;

        case aKind of
          GridExchange, Grid2Exchange:
            begin
            Result := cMyGrid;
            end;

          RSTNameAndQTHExchange:
            begin
            Result := sysutils.Format( '%-3d %-5s %-7s',
               [ TempRXData.RSTSent, cMyName, cMyState ] );
            end;

          QSONumberAndNameExchange:
            begin
            Result := sysutils.Format( '%-3d %-7s', [ nrSent, cMyName ] );
            end;

          RSTAndPostalCodeExchange:
            begin
            if contacts = 1 then
               begin
               Result := sysutils.Format( '%-3d %-10s',
                  [ TempRXData.RSTSent, MyPostalCode ] );
               end
            else
               begin
               Result := sysutils.Format( '%-3d %-10s',
                  [ TempRXData.RSTSent, PreviousQTHString ] );
               end;
            end;

          RSTQSONumberAndGridSquareExchange:
            begin
            Result := sysutils.Format( '%-3d %-4d %-7s',
               [ TempRXData.RSTSent, nrSent, cMyGrid ] );
            end;

          RSTQSONumberOrDomesticQTHExchange: // n4af 4.40.6
            begin
            if cMyState[ 1 ] <> '' then
               begin
               Result := sysutils.Format( '%-3d  %-5s',
                  [ TempRXData.RSTSent, cMyState ] );
               end
            else
               begin
               if cMyState[ 1 ] = '' then
                  begin
                  Result := sysutils.Format( '%-3d  %-6d',
                     [ TempRXData.RSTSent, nrSent ] );
                  end;
               end;
            end;

          RSTPrefectureExchange:
            begin
            Result := sysutils.Format( '%-3d %-7d',
               [ TempRXData.RSTSent, cMyZone ] );
            end;

          NameAndDomesticOrDXQTHExchange:
            begin
            Result := sysutils.Format( '  %-10s %-4s',
               [ cMyName, cMyState ] );
            end;

          QSONumberNameDomesticOrDXQTHExchange:
            begin
            cMyName := string(MyName);
            if MyState = '' then
               begin
               cMyState := 'DX';
               end;
            Result        := sysutils.Format( '%-4d %-7s %-8s',
               [ nrSent, cMyName, cMyState ] );
            end;

          QSONumberAndAgeExchange:
            begin
            Result := sysutils.Format( '%-4d %-8s', [ nrSent, cMyState ] );
            end;

          RSTAgeAndPossibleSK:
            begin
            Result := sysutils.Format( '%-3d %-16s',
               [ TempRXData.RSTSent, cMyState ] );
            end;

          RSTAgeExchange:
            begin
            Result := sysutils.Format( '%-3d %-7s',
               [ TempRXData.RSTSent, cMyState ] );
            end;

          AgeAndQSONumberExchange: // 4.55.4
            begin
            (* THREE FORMAT SPECIFIERS AND TWO ARGUMENTS, so this raises and
               the marker stands -- a DEFECT, pinned as such by
               uTestADIFExchange, and left for the class that owns this
               exchange to correct. *)
            Result := sysutils.Format( '%-3d %-2s %03d      ',
               [ cMyState, nrSent ] );
            end;

          RSTAndPOTAPark:
            begin
            Result := cMyPark;
            end;

          RSTPowerExchange:
            begin
            (* FOC Marathon's membership number is TContestFOCMarathon's. *)
            Result := sysutils.Format( '%-3d %-7s',
               [ TempRXData.RSTSent, cMyState ] );
            end;

          RSTAndOrGridExchange:
            begin
            Result := sysutils.Format( '%-3d %-7s',
               [ TempRXData.RSTSent, cMyGrid ] );
            end;

          QSONumberAndGridSquare:
            begin
            Result := sysutils.Format( '%-3s %-7s', [ nrSent, cMyState ] );
            end;

          QSONumberDomesticOrDXQTHExchange, QSONumberDomesticQTHExchange:
            begin
            Result := sysutils.Format( '%-4s %-6d', [ cMyState, nrSent ] );
            end;

          QSONumberAndPossibleDomesticQTHExchange,
             RSTQSONumberAndDomesticQTHExchange,
             RSTQSONumberAndPossibleDomesticQTHExchange:
            begin
            if cMyState = 'TRC' then
               begin
               Result := sysutils.Format( '%-3d %d%-6s',
                  [ TempRXData.RSTSent, nrSent, cMyState ] );
               end
            else
               begin
               Result := sysutils.Format( '%-3d %-4d %-6s ',
                  [ TempRXData.RSTSent, nrSent, cMyState ] );
               end;
            end;

          RSTZoneAndPossibleDomesticQTHExchange:
            begin
            if MyState = '' then
               begin
               cMyState := 'DX';
               end;
            Result := sysutils.Format( '%-3d %02u %-4s',
               [ TempRXData.RSTSent, MyZone, cMyState ] );
            end;

          RSTZoneOrDomesticQTH, RSTZoneOrSocietyExchange:
            begin
            if MyState <> '' then
               begin
               Result := sysutils.Format( '%-3d %-7s',
                  [ TempRXData.RSTSent, cMyState ] );
               end
            else
               begin
               Result := sysutils.Format( '%-3d %-7d',
                  [ TempRXData.RSTSent, cMyZone ] );
               end;
            end;

          QSONumberAndCoordinatesSum: (* RFASCHAMPIONSHIP *)
            begin
            Result := sysutils.Format( '%-3s %03d    ',
               [ cMyState, nrSent ] );
            end;

          QSONumberAndGeoCoordinates:
            begin
            Result := cMyState;
            end;

          RSTQSONumberExchange:
            begin
            Result := sysutils.Format( '%-3d %03d ',
               [ TempRXData.RSTSent, nrSent ] ); // issue 177
            end;

          RSTAndContinentExchange:
            begin
            Result := sysutils.Format( '%-3d %-7s',
               [ TempRXData.RSTSent, cMyState ] );
            end;

          RSTDomesticQTHExchange:
            begin
            (* PACC's serial is TContestPACC's; CQ VHF's and SP DX's branches
               were dead. THE 'DX' BELOW REACHES NOTHING: it is written to
               cMyState and the format reads MyState (4.97.5). Kept, as the
               arm always had it -- what it should print for a station with
               no state is the owning contest's question. *)
            if MyState = '' then
               begin
               cMyState := 'DX';
               end;
            Result := sysutils.Format( '%-3d %-7s',
               [ TempRXData.RSTSent, MyState ] ); // 4.97.5
            end;

          RSTDomesticOrDXQTHExchange:
            begin
            Result := sysutils.Format( '%-3d %-7s',
               [ TempRXData.RSTSent, cMyState ] );
            end;

          QSONumberAndZone:
            begin
            Result := sysutils.Format( '  %s    %03d ',
               [ cMyState, nrSent ] );
            end;

          RSTZoneExchange:
            begin
            Result := sysutils.Format( '%-3d %-7.2d',
               [ TempRXData.RSTSent, cMyZone ] );
            end;

          QSONumberAndPreviousQSONumber:
            begin
            Result := sysutils.Format( '%-.3u%-7.3d', [ pnr, nrSent ] );
            end;

          RSTAndQSONumberOrFrenchDepartmentExchange,
             RSTAndQSONumberOrDomesticQTHExchange,
             RSTDomesticQTHOrQSONumberExchange:
            begin
            (* The '/M' branch was the PCC's alone -- uCabrilloExchange's arm
               says why -- and is TContestPCC's now. *)
            if MyState <> '' then // 4.83.2
               begin
               Result := sysutils.Format( '%-3d %-7s',
                  [ TempRXData.RSTSent, cMyState ] );
               end
            else
               begin
               Result := sysutils.Format( '%-4d %03u   ',
                  [ TempRXData.RSTSent, nrSent ] );
               end;
            end;

          // Exchanges not yet implemented
          CheckAndChapterOrQTHExchange, KidsDayExchange,
             NameQTHAndPossibleTenTenNumber,
             NameAndPossibleGridSquareExchange, NZFieldDayExchange,
             RSTAndGrid3Exchange, QSONumberNameChapterAndQTHExchange,
             RSTALLJAPrefectureAndPrecedenceExchange, RSTAndDOMESTICQTH,
             RSTAndFOCNumberExchange,
             RSTAndGridExchange,
             RSTAndSerialNumberAndGridandPossibleMemberNumber,
             RSTNameAndPossibleFOCNumber, RSTPossibleDomesticQTHAndPower,
             RSTQSONumberAndRandomCharactersExchange,
             RSTQTHNameAndFistsNumberOrPowerExchange, RSTQTHExchange,
             RSTLongJAPrefectureExchange, RSTAndGridSquareOrRDAExchange:
            begin
            Result := 'None';
            logger.Error
               ( '[] MyExchange ADIF not yet implemented for exchange %s',
               [ ActiveExchangeArray[ aKind ] ] );
            end;
          else
            begin
            (* NO ARM -- which includes Sweepstakes' and the Field Days'
               exchanges, whose classes format their own. The marker stands,
               as it always did for an exchange with no arm; what is new is
               that it is reported. *)
            logger.Error
               ( '[] MyExchange ADIF has no arm for exchange %s',
               [ ActiveExchangeArray[ aKind ] ] );
            end;
        end; // of case aKind
      except
      end;
      end;

initialization
  logger := TLogLogger.GetLogger('TR4WDebugLog.ADIFExchange');

end.
