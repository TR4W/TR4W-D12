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

{ THE MY-EXCHANGE AS ADIF SEES IT -- the twin of uCabrilloExchange, extracted
  for the same reasons and by the same recipe.

  uCabrilloExchange lifted `case ActiveExchange of` out of PostUnit in May,
  deliberately dependency-light, and uTestCabrilloExchange then pinned 39 arms.
  Its ADIF sibling sat nine hundred lines further down the same file and never
  moved.  That asymmetry was pure debt: the Cabrillo half is characterised
  arm-by-arm, the ADIF half was reachable only through a 4,000-line unit that no
  test links.

  WHY THIS ONE IS WORTH DOING BEFORE THE CONTEST FACTORY.  The golden corpus
  byte-diffs `ref.adi` for all thirteen fixture sets -- so for this function the
  corpus is not a proxy for the behaviour, it is a direct byte-level test of the
  code being moved.  No other slice of the contest work has that property, and
  it converts thirteen file-level fixtures into arm-level tests covering the
  exchange shapes of the 172 contests that have no fixture at all.

  THE BODY IS UNCHANGED.  Every global the arms read is declared here as a local
  of the SAME type and assigned once at the top; nothing inside the case was
  touched.  A behaviour-preserving move of 61 arms is only credible if the arms
  are not edited. }
unit uADIFExchange;

{$I tr4w.inc}

interface

uses
  VC,
  SysUtils,
  uCabrilloExchange;   // TMyStationExchange -- ONE record, not a second copy
                       // that drifts from it

{ Builds the ADIF MY-exchange string for one QSO, dispatching on
  ActiveExchange.

  aGoodQSO is the caller's GoodLookingQSO decision, passed rather than
  recomputed: this unit deliberately cannot open the log.

  Returns the exchange.  An ActiveExchange with no arm yields 'None' and an
  Error log line, exactly as it did in PostUnit -- unhandled is REPORTED, not
  silently blank. }
function FormatADIFMyExchange(
    ActiveExchange : ExchangeType;
    Contest        : ContestType;
    const rx       : ContestExchange;
    const my       : TMyStationExchange;
    aGoodQSO       : boolean) : string;

implementation

uses
  Log4D;   // the same single concession uCabrilloExchange makes, and for the
           // same reason: an unhandled arm must say so.

var
  logger: TLogLogger;

{ TWO HELPERS INLINED RATHER THAN A `uses TF`.

  The arms call TF.inttopchar and TF.StringIsAllNumbers.  TF drags in Windows
  and the whole RTL-shim layer, which is exactly what uCabrilloExchange refused
  in order to stay testable.  Both are three lines. }
function inttopchar(i: integer): string;
begin
   Result := IntToStr(i);
end;

function StringIsAllNumbers(const s: ShortString): boolean;
var
   i: integer;
begin
   Result := (s <> '');
   for i := 1 to Length(s) do
      if not (s[i] in ['0'..'9']) then
         begin
         Result := False;
         Exit;
         end;
end;

function FormatADIFMyExchange(
    ActiveExchange : ExchangeType;
    Contest        : ContestType;
    const rx       : ContestExchange;
    const my       : TMyStationExchange;
    aGoodQSO       : boolean) : string;
      var
        // HisCallsign                           : PChar;
        cMyZone: integer;
        cMyState: string;
        cMyPark: string;
        cMyName: PAnsiChar;
        // csName                                : PChar;
        cMyFOCNumber: PAnsiChar;
        cMyCheck: PAnsiChar;
        // csCheck                               : integer {PChar};
        crFOCNr: PAnsiChar;
        cMyGrid: PAnsiChar;
        csPower: PAnsiChar;
        // hisAge                                : Integer;
        csQTHString: PAnsiChar;
        // str1                                  : widestring;
        // nrReceived                            : integer;
        nrSent: integer;
        // tempcategoryoperator                  : tcategoryoperator;

        // T1                                    : PChar;
        // T2                                    : PChar;
        // T3                                    : PChar;
        // T4                                    : PChar;      // 4.73.6
        // cKids                                 : PChar;
        TempGrid: Str20;
        previousqsonr: integer;
        contacts: integer;
        PreviousQTHString: Str10;
        pnr: integer;

        { THE OLD GLOBALS, AS LOCALS.

          Every one of these was a unit-scope global the 61 arms read directly.
          Declaring them here with the SAME TYPES -- they are all ShortStrings,
          not `string` -- lets the whole body move across UNCHANGED, which is
          what makes this a behaviour-preserving extraction rather than a
          rewrite with 61 chances to introduce a difference.

          GoodLookingQSO shadows a FUNCTION for the same reason: the caller has
          already decided, and the body's `if GoodLookingQSO then` still reads
          the same. }
        MyGrid: GridString;
        MyName: Str20;
        MyState: Str20;
        MyPark: Str10;
        MyZone: Str20;
        MyCheck: Str10;
        MyFDClass: Str10;
        MySection: Str10;
        MyPrec: Str10;
        MyFOCNumber: Str10;
        MyPostalCode: Str20;
        TempRXData: ContestExchange;
        GoodLookingQSO: boolean;
      begin
      { ZEROED FIRST, AND THIS IS NOT DEFENSIVE PADDING.

        Three arms take PAnsiChar(@MyName[1]) / @MyCheck[1] / @MyFOCNumber[1] of
        a SHORTSTRING, which has no terminator -- the read runs to the first
        zero byte after the text.  As unit-scope globals these were zero-filled
        once at startup and stayed that way, so it worked.  As LOCALS they would
        start as whatever was on the stack, and the arm would append stale bytes
        to a name.

        That is the exact defect this tree has already paid for once: a radio
        called K3S displayed as "K3Sio 2", because PAnsiChar(@RadioName[1]) read
        past its length into a longer previous value.  Moving these globals to
        locals would have reintroduced it, silently, in an extraction whose
        whole claim is that it changes nothing. }
      FillChar(MyGrid, SizeOf(MyGrid), 0);
      FillChar(MyName, SizeOf(MyName), 0);
      FillChar(MyState, SizeOf(MyState), 0);
      FillChar(MyPark, SizeOf(MyPark), 0);
      FillChar(MyZone, SizeOf(MyZone), 0);
      FillChar(MyCheck, SizeOf(MyCheck), 0);
      FillChar(MyFDClass, SizeOf(MyFDClass), 0);
      FillChar(MySection, SizeOf(MySection), 0);
      FillChar(MyPrec, SizeOf(MyPrec), 0);
      FillChar(MyFOCNumber, SizeOf(MyFOCNumber), 0);
      FillChar(MyPostalCode, SizeOf(MyPostalCode), 0);

      MyGrid       := GridString(my.MyGrid);
      MyName       := Str20(my.MyName);
      MyState      := Str20(my.MyState);
      MyPark       := Str10(my.MyPark);
      MyZone       := Str20(my.MyZone);
      MyCheck      := Str10(my.MyCheck);
      MyFDClass    := Str10(my.MyFDClass);
      MySection    := Str10(my.MySection);
      MyPrec       := Str10(my.MyPrec);
      MyFOCNumber  := Str10(my.MyFOCNumber);
      MyPostalCode := Str20(my.MyPostalCode);
      TempRXData     := rx;
      GoodLookingQSO := aGoodQSO;
      Result := 'Error generating my exchange';
      try
        TempGrid := MyGrid;
        // Issue #902 -- null-terminate after the actual grid length.
        // Old code wrote #0 at byte 5 unconditionally; that silently truncated
        // 6-char grids (e.g. EL88AA -> EL88) in the exported exchange field.
        TempGrid[ length( MyGrid ) + 1 ] := #0;
        cMyGrid                          := @TempGrid[ 1 ];

        cMyName := @MyName[ 1 ];

        cMyZone  := StrToIntDef( MyZone, 0 );
        cMyState := MyState;
        cMyPark  := MyPark;

        previousqsonr := 0;
        nrSent        := TempRXData.NumberSent;


        // Exchanges yet to be added...
        {
          CheckAndChapterOrQTHExchange:
          KidsDayExchange:
          NameQTHAndPossibleTenTenNumber:
          NameAndPossibleGridSquareExchange:
          NZFieldDayExchange:
          RSTAndGrid3Exchange:
          QSONumberNameChapterAndQTHExchange:
          RSTALLJAPrefectureAndPrecedenceExchange:
          RSTAndDOMESTICQTH:       //n4af
          RSTAndFOCNumberExchange: //n4af
          RSTAndGridExchange:
          RSTAndSerialNumberAndGridandPossibleMemberNumber:
          RSTNameAndPossibleFOCNumber:
          RSTPossibleDomesticQTHAndPower:
          RSTQSONumberAndRandomCharactersExchange:
          RSTQSONumberOrDomesticQTHExchange:
          RSTQTHNameAndFistsNumberOrPowerExchange:
          RSTQTHExchange:
          RSTLongJAPrefectureExchange:
          RSTAndGridSquareOrRDAExchange:
        }

        if GoodLookingQSO then
           begin

           { Make Exchanges Strings }
           case ActiveExchange of
             GridExchange, Grid2Exchange:
               begin
               Result := cMyGrid;
               // TF.Format(CABRILLO_MYEX, '%-11s', cMyGrid);
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
                 if cMyState[ 1 ] = '' then
                    begin
                    Result := sysutils.Format( '%-3d  %-6d',
                       [ TempRXData.RSTSent, nrSent ] );
                    end;
               end;

             RSTPrefectureExchange:
               Result := sysutils.Format( '%-3d %-7d',
                  [ TempRXData.RSTSent, cMyZone ] );

             NameAndDomesticOrDXQTHExchange:
               Result := sysutils.Format( '  %-10s %-4s',
                  [ cMyName, cMyState ] );

             QSONumberPrecedenceCheckDomesticQTHExchange:
               begin
               CID_TWO_BYTES[ 0 ] := TempRXData.Precedence;
               // csName := CID_TWO_BYTES;

               cMyName := @MyPrec[ 1 ];
               // csCheck := {inttopchar}(TempRXData.Check);
               cMyCheck := @MyCheck[ 1 ];
               // cMyState := @MySection[1];

               Result := sysutils.Format( '%-4d %s %s %-3s ',
                  [ nrSent, cMyName, cMyCheck, MySection ] );
               end;

             QSONumberNameDomesticOrDXQTHExchange:
               begin
               // csName := @TempRXData.Name[1];
               cMyName := @MyName[ 1 ];
               if MyState = '' then
                  begin
                  cMyState := 'DX';
                  end;
               if TempRXData.QTHString = '' then
                  begin
                  csQTHString := 'DX';
                  end;
               Result        := sysutils.Format( '%-4d %-7s %-8s',
                  [ nrSent, cMyName, cMyState ] );
               end;
             QSONumberAndAgeExchange:
               begin
               Result := sysutils.Format( '%-4d %-8s', [ nrSent, cMyState ] );
               end;

             RSTAgeAndPossibleSK:
               Result := sysutils.Format( '%-3d %-16s',
                  [ TempRXData.RSTSent, cMyState ] );

             RSTAgeExchange:
               Result := sysutils.Format( '%-3d %-7s',
                  [ TempRXData.RSTSent, cMyState ] );

             AgeAndQSONumberExchange: // 4.55.4
               Result := sysutils.Format( '%-3d %-2s %03d      ',
                  [ cMyState, nrSent ] );

             RSTAndPOTAPark:
               Result := cMyPark;

             RSTPowerExchange:
               begin
               csPower := @TempRXData.Power[ 1 ];
               if Contest = FOCMARATHON then
                  begin
                  cMyFOCNumber := @MyFOCNumber[ 1 ];
                  crFOCNr      := @TempRXData.Power[ 1 ];
                  Result       := sysutils.Format( '%-3d %-7s',
                     [ TempRXData.RSTSent, cMyFOCNumber ] );
                  end
               else
                 if Contest <> FOCMARATHON then
                    begin
                    Result := sysutils.Format( '%-3d %-7s',
                       [ TempRXData.RSTSent, cMyState ] );
                    end;
               end;
             RSTAndOrGridExchange:
               begin
               Result := sysutils.Format( '%-3d %-7s',
                  [ TempRXData.RSTSent, cMyGrid ] );
               end;

             QSONumberAndGridSquare:
               Result := sysutils.Format( '%-3s %-7s', [ nrSent, cMyState ] );

             QSONumberDomesticOrDXQTHExchange, QSONumberDomesticQTHExchange:
               Result := sysutils.Format( '%-4s %-6d', [ cMyState, nrSent ] );

             QSONumberAndPossibleDomesticQTHExchange,
                RSTQSONumberAndDomesticQTHExchange,
                RSTQSONumberAndPossibleDomesticQTHExchange:
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

             QSONumberAndCoordinatesSum: { RFASCHAMPIONSHIP }
               Result := sysutils.Format( '%-3s %03d    ',
                  [ cMyState, nrSent ] );
             QSONumberAndGeoCoordinates:
               Result := cMyState;

             ClassDomesticOrDXQTHExchange:
               Result := sysutils.Format( '%-3s %-7s ',
                  [ MyFDClass, MySection ] );

             RSTQSONumberExchange:
               Result := sysutils.Format( '%-3d %03d ',
                  [ TempRXData.RSTSent, nrSent ] ); // issue 177

             RSTAndContinentExchange:
               Result := sysutils.Format( '%-3d %-7s',
                  [ TempRXData.RSTSent, cMyState ] );

             RSTDomesticQTHExchange:
               if Contest in [ CQVHF { , MMAA } ] then
                  begin
                  Result := sysutils.Format( '%-3d %-7s',
                     [ TempRXData.RSTSent, cMyGrid ] );
                  end
               else
                  begin
                  if MyState = '' then
                     begin
                     cMyState := 'DX';
                     end;
                  if Contest in [ SPDX, PACC ] then
                     begin
                     MyState := inttopchar( nrSent );
                     end;
                  Result := sysutils.Format( '%-3d %-7s',
                     [ TempRXData.RSTSent, MyState ] ); // 4.97.5
                  end;

             RSTDomesticOrDXQTHExchange:
               Result := sysutils.Format( '%-3d %-7s',
                  [ TempRXData.RSTSent, cMyState ] );

             QSONumberAndZone:
               Result := sysutils.Format( '  %s    %03d ',
                  [ cMyState, nrSent ] );

             RSTZoneExchange:
               Result := sysutils.Format( '%-3d %-7.2d',
                  [ TempRXData.RSTSent, cMyZone ] );

             QSONumberAndPreviousQSONumber:
               begin
               // hisnr := (nrreceived div 1000);    // 4.53.2
               // rxnr := (nrreceived mod 1000);    // 4.53.2
               Result := sysutils.Format( '%-.3u%-7.3d', [ pnr, nrSent ] );
               end;

             RSTAndQSONumberOrFrenchDepartmentExchange,
                RSTAndQSONumberOrDomesticQTHExchange,
                RSTDomesticQTHOrQSONumberExchange:
               begin
               if ( MyState <> '' ) and ( Contest <> PCC ) then // 4.83.2
                  begin
                  Result := sysutils.Format( '%-3d %-7s',
                     [ TempRXData.RSTSent, cMyState ] );
                  end
               else
                 if StringIsAllNumbers( MyState ) then
                    begin
                    Result := sysutils.Format( '%-4d %03u/M   ',
                       [ TempRXData.RSTSent, nrSent ] );
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
             // n4af
             RSTAndFOCNumberExchange, // n4af
             RSTAndGridExchange,
                RSTAndSerialNumberAndGridandPossibleMemberNumber,
                RSTNameAndPossibleFOCNumber, RSTPossibleDomesticQTHAndPower,
                RSTQSONumberAndRandomCharactersExchange,
             // RSTQSONumberOrDomesticQTHExchange,
             RSTQTHNameAndFistsNumberOrPowerExchange, RSTQTHExchange,
                RSTLongJAPrefectureExchange, RSTAndGridSquareOrRDAExchange:
               begin
               Result := 'None';
               logger.Error
                  ( '[] MyExchange ADIF not yet implemented for exchange %s',
                  [ ActiveExchangeArray[ ActiveExchange ] ] );
               end;

           end; // of case ActiveExchange
           end;
      except
      end;
      end;

initialization
  logger := TLogLogger.GetLogger('TR4WDebugLog.ADIFExchange');

end.
