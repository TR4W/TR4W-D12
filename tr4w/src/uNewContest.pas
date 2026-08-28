{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uNewContest;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  Version,
  VC,
  Windows,
  Tree,
  LogDupe,
  LogGrid,
  PostUnit,
  uGradient,
  uCallSignRoutines,
  utils_file,
  Messages
  ,
  uTR4WStrings,
  uAnsiStr,
  LCLStrConsts;
type
  InitialCommands =
    (icmyCheck, icmyFDClass, icmyGrid, icmyFOC, icmyIOTA, icmyName, icmyPark, icmyPrec, icmyQTH, icmySection, icmyState, icmyZone, icmyPostalCode);

{ GONE WITH THE DIALOG PROCEDURE (2026-08-28): NewContestDlgProc itself,
  NewSelectContestListBoxProc -- a list box SUBCLASSED to catch Enter -- and
  ChangeDir and StartContestFromListbox, which existed to drive DlgDirListA
  and DlgDirSelectExA around a filesystem the brief says this dialog should
  not be browsing. See TfrmNewContest.PopulateFiles. }
procedure BeginNewContest;
procedure ClearFields;
procedure SaveNewContest;
procedure DisplayCheckBox(Text: string);
procedure SetCommentAndEnableEditControl(comment: string; EditControl: InitialCommands);
procedure EnterCountyOrState(State: string);
procedure DisplayInitialCommand(Command: InitialCommands);
//procedure FillMyStateComboBox;


// the open-configuration / new-contest dialog shown at startup.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowNewContest;

implementation
uses
  SysUtils,            // Format, Trim, FreeAndNil -- the RTL, not TF shims
  Controls,            // mrOk -- the modal results
  uNewContestForm,     // the designed form this unit now drives
  MainUnit,
  uRadioConfigApply,   // GetLatestConfigFile -- the last contest, from tr4w.json
  uCFG;                // SetCFGCommandValue -- the one route to a [COMMANDS] value

const

  CSAS                                  = 9;
  InitialCommandsSA2                    : array[1..CSAS] of PAnsiChar = (
    nil,
    nil,
    // Issue #976: CATEGORY-OVERLAY removed -- it was only a dangling label
    // (no control was ever created for it).  Restore it as a real drop-down
    // when the New Contest dialog is rebuilt in modern Delphi.
    nil,
    'CATEGORY-ASSISTED',
    'CATEGORY-BAND',
    'CATEGORY-MODE',
    'CATEGORY-OPERATOR',
    'CATEGORY-POWER',
    'CATEGORY-TRANSMITTER');

  InitialCommandsSA                     : array[InitialCommands] of PAnsiChar =
    (
    'MY CHECK',
    'MY FD CLASS',
    'MY GRID',
    'My FOC NUMBER',
    'MY IOTA',
    'MY NAME',
    'MY PARK',
    'MY PREC',
    'MY QTH',
    'MY SECTION',
    'MY STATE',
    'MY ZONE',
    'MY POSTAL CODE'
    );

var
  NewContestDisplayedCommands           : integer;
//  NewContestAllowReturn                 : boolean;
  SelectedContest                       : ContestType;

const

{(*}
  {*)}

  sfFLAG                                = DDL_ARCHIVE or DDL_READWRITE or DDL_DIRECTORY;

{ THE CONTEST-SPECIFIC PROMPTS, MOVED VERBATIM.

  These two case statements are ~240 lines of contest knowledge -- which
  contest wants a district code, which wants a DOK, which wants an oblast --
  built up one contest at a time over years. NOTHING here was retyped or
  reformatted during the LCL conversion: they were lifted out of
  NewContestDlgProc's WM_COMMAND arms as they stood, because the risk in a
  conversion is not the code you rewrite carefully, it is the line you retype
  slightly differently and nobody notices until that contest weekend.

  They reach the screen through five presentation helpers, and it is only
  those helpers that changed: SetWindowTextA on a control handle became a
  method on the form. }

{ The 'I am in <state>' box was ticked or cleared. }
procedure ApplyIAmIn;
begin
   ClearFields;
   frmNewContest.SetComment('');

   { Unticked: the prompts below are what ticking it ASKS FOR, so there is
     nothing to put up. Was an Exit out of the dialog procedure. }
   if not frmNewContest.IAmIn then
      begin
      Exit;
      end;

              case SelectedContest of
              MWC:
              ;
              VAQP:
              ;

                ALRS_UA1DZ_CUP:
                  SetCommentAndEnableEditControl(TC_ENTERYOURRDAIDORGRID, icmyState);

                NEWENGLANDQSO:
                  SetCommentAndEnableEditControl(TC_NEWENGLANDSTATEABREVIATION, icmyState);

                ARRL10, ARRL160, ARRLDXCW, ARRL_RTTY_ROUNDUP:
                  begin
                     { WAS: SendMessage(107, BM_SETCHECK, ...). 107 is a control
                       ID, not an HWND, so this addressed whatever window
                       happened to have handle 107 -- almost certainly nothing.
                       Pre-existing, and present in the D7 tree too; it is
                       dropped rather than carried across, because there is no
                       LCL control it could mean. If these four contests are
                       supposed to pre-tick something, that is a new decision
                       and needs saying out loud. }
                    SetCommentAndEnableEditControl(TC_ENTERTHEQTHTHATYOUWANTTOSEND, icmyState);
                  end;

                CQWWRTTY, CQ160CW, CQ160SSB:
                  SetCommentAndEnableEditControl(TC_ENTERSTATEFORUSPROVINCEFORCANADA, icmyState);

                    IRTS:
                     SetCommentAndEnableEditControl(TC_EnterYourCountyCode,icmyState);

                CANADA_DAY, CANADA_WINTER:
                  SetCommentAndEnableEditControl(TC_ENTERYOURPROVINCEID, icmyState);


                REFSSB, REFCW:
                  SetCommentAndEnableEditControl(TC_DEPARTMENT, icmyState);

                UKRAINIAN, RUSSIANDX, UNDX, CIS, RU3AXMEMORIAL:
                  SetCommentAndEnableEditControl(TC_ENTERYOUROBLASTID, icmyState);

                KINGOFSPAINCW, KINGOFSPAINSSB, UBACW, UBASSB, PACC, ARI_DX, HELVETIA:
                  SetCommentAndEnableEditControl(TC_ENTERYOURPROVINCEID, icmyState);

                CQIR, HADX, YUDX: SetCommentAndEnableEditControl(TC_ENTERYOURCOUNTYCODE, icmyState);

                GagarinCup: SetCommentAndEnableEditControl(TC_Gagarin, icmystate);

                UKEI: SetCommentAndEnableEditControl(TC_EnterYourDistrictCode, icmyState);

                DARC10M, WAG, DARCXMAS: SetCommentAndEnableEditControl(TC_ENTERYOURDOK, icmyState);

                SPDX, OKDX, OKOMSSB, YODX, RSGB18, LZDX, EUDX:                // 4.80.1
                  SetCommentAndEnableEditControl(TC_ENTERYOURDISTRICTABBREVIATION, icmyState);

                RDA: SetCommentAndEnableEditControl(TC_ENTERYOURRDAID, icmyState);

                BSCI, IARU:
                  SetCommentAndEnableEditControl('', icmyState);

                IOTA:
                  SetCommentAndEnableEditControl(TC_ENTERYOURIOTAREFERENCEDESIGNATOR, icmyState);

                WWPMC:
                  SetCommentAndEnableEditControl(TC_ENTERYOURCITYIDENTIFIER, icmyState);
                POTA:
                   SetCommentAndEnableEditControl(TC_ENTERYOURPARKREFERENCEDESIGNATOR, icmyPark);
                PCC, ARKTIKA_SPRING:
                  SetCommentAndEnableEditControl(TC_ENTERYOURMEMBERSHIPNUMBER, icmyState);

                JIDXCW, JIDXSSB:
                  SetCommentAndEnableEditControl(TC_PREFECTURE, icmyState);

              end;

   BeginNewContest;
end;

{ A contest was chosen in the combo. }
procedure ApplyContestChoice;
begin
   SelectedContest := GetContestFromString(frmNewContest.ContestName);
   ClearFields;
   frmNewContest.SetComment('');
   frmNewContest.ResetIAmIn;

   if (ContestsArray[SelectedContest].p <> 0) and (SelectedContest <> BCQP) then
      begin
      EnterCountyOrState(QSOParties[ContestsArray[SelectedContest].p].StateName);
      end;

             case SelectedContest of
              LABRE:
                   SetCommentAndEnableEditControl(TC_LABRE,icmyState);
            
                BCQP:            // 4.97.7
                  SetCommentAndEnableEditControl(TC_ENTERYOURISTRICTIFINVE7,icmyState);


               COLORADOQSOPARTY, MINNQSOPARTY :
                 begin
                    DisplayInitialCommand(icmyName);
                 end;

               ALRS_UA1DZ_CUP:
                 SetCommentAndEnableEditControl(TC_ENTERYOURRDAIDORGRID, icmyState);

               EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW: SetCommentAndEnableEditControl(TC_ENTERYOURNAME, icMyName);

               NZFIELDDAY: SetCommentAndEnableEditControl(TC_ENTERYOURBRANCHNUMBER, icmyZone);

               EUROPEANHFC: SetCommentAndEnableEditControl(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, icmyZone);

               KVP: SetCommentAndEnableEditControl(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, icmyZone);      // 4.65.3

               RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB: SetCommentAndEnableEditControl(TC_ENTERYOURZONE, icmyState);
               RAEM: SetCommentAndEnableEditControl(TC_ENTERYOURGEOGRAPHICALCOORDINATES, icmyQTH);

               OLDNEWYEAR: SetCommentAndEnableEditControl(TC_ENTERSUMOFYOURAGEANDAMOUNT, icmyQTH);
               RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB: SetCommentAndEnableEditControl(TC_ENTERYOURPOSTCODE, icmyPostalCode);

             
               RADIOMEMORY: SetCommentAndEnableEditControl(TC_AGECALLSIGNAGE, icmyQTH);
               CQMM: SetCommentAndEnableEditControl(TC_ENTERYOURCONTINENT, icmyState);

               NRAUBALTICCW, NRAUBALTICSSB: SetCommentAndEnableEditControl(TC_ENTERYOURPROVINCEID, icmyState);
               OZCR_O: SetCommentAndEnableEditControl(TC_OZCR, icmyState);

               //RUSSIAN160: SetCommentAndEnableEditControl(TC_ENTERYOURSQUAREID, icmyState);
               R9W_UW9WK_MEMORIAL: SetCommentAndEnableEditControl(TC_STATIONCLASS, icmyState);

               CUPRFCW, CUPRFSSB, CUPRFDIG: SetCommentAndEnableEditControl(TC_ENTERYOURFOURDIGITGRIDSQUARE, icmyGrid);
               RFASCHAMPIONSHIPCW: SetCommentAndEnableEditControl(TC_RFAS, icMyQTH);
                CQVHF,ARRLVHFJAN,ARRLVHFJUN, ARRLVHFSEP,ARRLDIGI, STEWPERRY, BATAVIA_FT8, WWDIGI, MAKROTHEN, RTC: SetCommentAndEnableEditControl(TC_ENTERYOURFOURDIGITGRIDSQUARE, icmyGrid);

               OZHCRVHF, EUROPEANVHF, RADIOVHFFD: SetCommentAndEnableEditControl(TC_ENTERYOURSIXDIGITGRIDSQUARE, icmyGrid);

               TESLA:
                SetCommentandEnableEditControl(TC_ENTERYOURFOURDIGITGRIDSQUARE,icmyGrid);
              
               NEWENGLANDQSO: DisplayCheckBox(TC_NEWENGLAND);

               CQWWRTTY, CQ160CW, CQ160SSB, ARRL10, ARRL160, ARRL_RTTY_ROUNDUP: DisplayCheckBox(TC_NORTHAMERICA);

               RDA, RUSSIANDX, RU3AXMEMORIAL: DisplayCheckBox(TC_RUSSIA);
               CQIR: DisplayCheckBox(TC_IRELAND);
               CANADA_DAY, CANADA_WINTER: DisplayCheckBox(TC_CANADA);
               REFSSB, REFCW: DisplayCheckBox(TC_FRANCE);
               IRTS: DisplayCheckBox(TC_IRTS);   // 4.93.2
              EUDX:
                DisplayCheckBox(TC_EUDX);  // 4.95.6
               KINGOFSPAINCW, KINGOFSPAINSSB: DisplayCheckBox(TC_SPAIN);
               JIDXCW, JIDXSSB: DisplayCheckBox(TC_JAPAN);
               HELVETIA: DisplayCheckBox(TC_SWITZERLAND);
               ARI_DX: DisplayCheckBox(TC_ITALY);
               UNDX: DisplayCheckBox(TC_KAZAKHSTAN);
               UKRAINIAN: DisplayCheckBox(TC_UKRAINE);
               OKDX, OKOMSSB: DisplayCheckBox(TC_CZECHREPUBLICORINSLOVAKIA);
      //         LABRE: DisplayCheckBox(TC_LABRE);
               LZDX: DisplayCheckBox(TC_BULGARIA);
               YODX: DisplayCheckBox(TC_ROMANIA);
               HADX: DisplayCheckBox(TC_HUNGARY);
               YUDX: DisplayCheckBox(TC_YUGOSLAVIA);
               UKEI: DisplayCheckBox(TC_UKEI);
               GagarinCup: DisplayCheckBox(TC_GC);
             //  UKEI: SetCommentAndEnableEditControl(TC_EnterYourDistrictCode, icmyState);
               UBACW, UBASSB: DisplayCheckBox(TC_BELGIUM);
               PACC: DisplayCheckBox(TC_NETHERLANDS);
               DARC10M, WAG, DARCXMAS: DisplayCheckBox(TC_GERMANY);
               RSGB18: DisplayCheckBox(TC_UK);
               CIS: DisplayCheckBox(TC_CIS);
               SPDX: DisplayCheckBox(TC_POLAND);
               BSCI, IARU: DisplayCheckBox(TC_HQ_OR_MEMBER);
               IOTA:
                 begin
                   frmNewContest.ShowIAmIn(TC_ISLANDSTATION);
                 end;

               WWPMC: DisplayCheckBox('PMC');
               PCC,ARKTIKA_SPRING: DisplayCheckBox(TC_ARKTIKACLUB);

               NAQSOCW, NAQSOSSB, NAQSORTTY, SST:
                 begin
                   SetCommentAndEnableEditControl(TC_ENTERYOURNAMEANDSTATE, icmyState);
                   DisplayInitialCommand(icmyName);
                 end;

               CWOPEN, MST:
                 begin
                   SetCommentAndEnableEditControl(TC_ENTERYOURNAME, icmyName);
                 end;

               CWOPS, LQP, NCCCSPRINT:
                 begin
                   DisplayInitialCommand(icmyName);
                   SetCommentAndEnableEditControl(TC_ENTERYOURNAMEANDQTH, icmyState);
                 end;

              FOCMarathon:
              begin
           //    DisplayInitialCommand(icmyFOC);
              SetCommentAndEnableEditControl(TC_ENTERYOURFOCNUMBER,icmyFOC);
              end;

              KCJ:
              begin
              SetCommentAndEnableEditControl(TC_PREF_OR_CQZONE,icMyState);    // 4.114.1
              end;

              POTA:
                 begin
                  frmNewContest.ShowIAmIn('Activator');
                 end;
              WINTERFIELDDAY:
                 begin
                   DisplayInitialCommand(icmyFDClass);
                   DisplayInitialCommand(icmySection);
                 end;

               ARRLFIELDDAY:
                 begin
                   DisplayInitialCommand(icmyFDClass);
                   DisplayInitialCommand(icmySection);
                 end;

               ARRLSSCW, ARRLSSSSB:
                 begin
                   SetCommentAndEnableEditControl(TC_ENTERYOURPRECEDENCECHECKSECTION, icMyPrec);
                   DisplayInitialCommand(icmyCheck);
                   DisplayInitialCommand(icmySection);
                 end;

               NASPRINTCW, SPRINTSSB, NASPRINTRTTY:
                 begin
                   SetCommentAndEnableEditControl(TC_ENTERYOURQTHANDTHENAME, icmyState);
                   DisplayInitialCommand(icmyName);
                 end;

           //    RSGBDX:
           //    DisplayCheckBox(TC_UKRSGB);

               UA4WCHAMPIONSHIP:
                 SetCommentAndEnableEditControl('Enter your RDA (for Russian stations) or four digit grid square:', icMyQTH);

               ALLASIANCW, ALLASIANSSB, YOUTHCHAMPIONSHIPRF, YOTA:
                 SetCommentAndEnableEditControl(TC_ENTERYOURAGEINMYSTATEFIELD, icmyState);

                UKRAINECHAMPIONSHIP:
                 SetCommentAndEnableEditControl(TC_ENTERYOUROBLASTID, icmyState);

               ARRLDXCW,
                 ARRLDXSSB:
                 SetCommentAndEnableEditControl(TC_ENTERYOURQTHORPOWER, icmyState);

               CUPURAL:
                 SetCommentAndEnableEditControl(TC_ENTERFIRSTTWOLETTERSOFYOURGRID, icmyState);


        //        IN7QPNE:
        //'/}         SetCommentAndEnableEditControl(TC_IN7QPNE, icmyState);

             end;

   BeginNewContest;
end;

{ Anything typed that can change whether OK is legal. In the dialog procedure
  this was BeginNewContest called at the bottom of EVERY WM_COMMAND, which is
  the same rule said once. }
procedure FieldsChanged;
begin
   BeginNewContest;
end;

procedure ClearFields;
begin
  NewContestDisplayedCommands := 0;
  frmNewContest.ClearRows;
end;

{ WHETHER OK IS LEGAL YET. Same four rules, asked of the form instead of of
  control handles: a contest is chosen, the callsign is at least three
  characters and passes IsAGoodCall, and every row this contest asked for has
  been filled in. }
procedure BeginNewContest;
var
  res  : boolean;
  i    : integer;
  Call : string;
begin
  res  := frmNewContest.ContestChosen;
  Call := frmNewContest.MyCall;

  if Length(Call) < 3 then
     begin
     res := False;
     end;

  { IsAGoodCall takes the ShortString the contest engine uses. }
  if res and (not IsAGoodCall(CallString(Call))) then
     begin
     res := False;
     end;

  for i := 1 to NewContestDisplayedCommands do
     begin
     if Trim(frmNewContest.RowText(i)) = '' then
        begin
        res := False;
        end;
     end;

  frmNewContest.EnableOK(res);
end;

procedure SaveNewContest;
var
  f                                     : HWND;
  i                                     : Cardinal;
  BytesToWrite                          : Cardinal;
begin
  begin
      {callsign}
    { The .cfg is written as bytes, so the two working buffers stay ANSI; what
      changed is where the text comes from -- the form, not a control id. }
    Windows.lstrcpynA(TempBuffer1, PAnsiChar(WinAnsi(frmNewContest.MyCall)),
                      SizeOf(TempBuffer1));
    if MainCallsign = '' then
       begin
       // THROUGH THE REGISTRY, NOT STRAIGHT AT THE INI.  'MAIN CALLSIGN' is a
       // CFGCA row (uCFG.pas:635) with a crMax of 13, and this assigned the
       // global by hand and then wrote the file, so the length bound and the
       // row's crA hook never ran at all.
       //
       // SetCFGCommandValue assigns MainCallsign itself via CheckCommand, so
       // the two lines that did it here are gone rather than duplicated.
       SetCFGCommandValue(string(MAIN_CALLSIGN),
                          string(PAnsiChar(@TempBuffer1[0])));
       end;
    DeleteSlashes(TempBuffer1);

      {Contest Name}
    Windows.lstrcpynA(TempBuffer2, PAnsiChar(WinAnsi(frmNewContest.ContestName)),
                      SizeOf(TempBuffer2));

    if TempBuffer2 = 'POTA' then
       begin
       TF.Format(wsprintfBuffer, '%s%s %s %s %s\', TR4W_PATH_NAME, GetYearString, TempBuffer2, GetDateString, TempBuffer1);
       end
    else
       begin
       TF.Format(wsprintfBuffer, '%s%s %s %s\', TR4W_PATH_NAME, GetYearString, TempBuffer2, TempBuffer1);
       end;

    Windows.CreateDirectoryA(wsprintfBuffer, nil);
  end;

  {CFGFileName}
  Windows.lstrcpynA(TempBuffer1, PAnsiChar(WinAnsi(frmNewContest.ContestName)),
                    SizeOf(TempBuffer1));
  TF.Format(TR4W_CFG_FILENAME, '%s%s.CFG', wsprintfBuffer, TempBuffer1);

  if FileExists(TR4W_CFG_FILENAME) then
     begin
     TF.Format(SYSERRORBUFFER, PAnsiChar(WinAnsi(TC_FOLDERALREADYEXISTSOVERWRITE)), TR4W_CFG_FILENAME);
     if YesOrNo(string(PAnsiChar(@SYSERRORBUFFER[0]))) = IDno then Exit;
     end;

  f := CreateFileA(TR4W_CFG_FILENAME, GENERIC_WRITE, FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_ARCHIVE, 0);
  if f <> INVALID_HANDLE_VALUE then
     begin

     Windows.lstrcpynA(TempBuffer1, PAnsiChar(WinAnsi(frmNewContest.MyCall)),
                       SizeOf(TempBuffer1));
     BytesToWrite := TF.Format(wsprintfBuffer, ';Created by ' + TR4W_CURRENTVERSION + #13#10#13#10'[COMMANDS]'#13#10'MY CALL=%s'#13#10, TempBuffer1);
     sWriteFile(f, wsprintfBuffer, BytesToWrite);

     { The row's LABEL is the command name and its field is the value, which is
       why the label is read back rather than held in a parallel array. A row
       the contest never asked for is empty and is skipped, exactly as the
       zero-length GetWindowTextA did. }
     for i := 1 to CSAS do
        begin
        if Trim(frmNewContest.RowText(i)) = '' then
           begin
           Continue;
           end;
        Windows.lstrcpynA(TempBuffer1, PAnsiChar(WinAnsi(frmNewContest.RowCaption(i))),
                          SizeOf(TempBuffer1));
        Windows.lstrcpynA(TempBuffer2, PAnsiChar(WinAnsi(frmNewContest.RowText(i))),
                          SizeOf(TempBuffer2));
        BytesToWrite := TF.Format(wsprintfBuffer, '%s=%s'#13#10, TempBuffer1, TempBuffer2);
        sWriteFile(f, wsprintfBuffer, BytesToWrite);
        end;

     // TERMINATE THE LAST LINE (2026-08-16). Every other line this routine
     // writes ends #13#10; this one did not, so every .cfg TR4W creates ended
     // mid-line -- 8 of the 13 golden-corpus fixtures still do.
     //
     // A file whose last line has no terminator is a trap for anything that
     // APPENDS to it: the new text welds onto the CONTEST= line and TR4W then
     // reports "Invalid statement in config file" for a line nobody typed.
     // This same file is written again later through
     // WritePrivateProfileStringA (MainUnit, uEditMessage), and hand-editing
     // is normal for .cfg files, so the append case is not hypothetical.
     //
     // Pre-existing in D7 (uNewContest.pas:660 there), not a port regression.
     // Existing .cfg files are unaffected -- this only changes what is newly
     // written, and TR4W already reads an unterminated last line correctly.
     Windows.lstrcpynA(TempBuffer1, PAnsiChar(WinAnsi(frmNewContest.ContestName)),
                       SizeOf(TempBuffer1));
     BytesToWrite := TF.Format(wsprintfBuffer, 'CONTEST=%s'#13#10, TempBuffer1);
     sWriteFile(f, wsprintfBuffer, BytesToWrite);

     CloseHandle(f);

     // If the user confirmed overwriting an existing contest, delete any
     // existing .TRW log file.  LoadinLog fatally halts if the file size
     // is not an exact multiple of SizeOf(ContestExchange), which will be
     // true of any .TRW from a previous (different) contest.
     Windows.lstrcpyA(TempBuffer1, TR4W_CFG_FILENAME);
     TempBuffer1[lstrlenA(TempBuffer1) - 3] := 'T';
     TempBuffer1[lstrlenA(TempBuffer1) - 2] := 'R';
     TempBuffer1[lstrlenA(TempBuffer1) - 1] := 'W';
     Windows.DeleteFileA(TempBuffer1); // no-op (returns False) if no .TRW exists

     { The modal form closes itself -- ShowNewContest reads Choice. }
     end
  else
     begin
     ShowSysErrorMessage('CFG FILE');
     end;

end;

{ The formatting is Format, not TF.Format through a shared PAnsiChar buffer:
  these strings go to an LCL caption, so there is no byte boundary to cross and
  no reason to route them via wsprintfBuffer. }
procedure DisplayCheckBox(Text: string);
begin
  frmNewContest.ShowIAmIn(Format(TC_IAMIN, [Text]));
end;

procedure SetCommentAndEnableEditControl(comment: string; EditControl: InitialCommands);
begin
  DisplayInitialCommand(EditControl);
  frmNewContest.SetComment(comment);
end;

procedure EnterCountyOrState(State: string);
begin
  DisplayInitialCommand(icmyState);
  { TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX has two %s, both the state. }
  frmNewContest.SetComment(Format(TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX,
                                  [State, State]));
end;

{ Rows are handed out IN ORDER as contests ask for them -- the counter is the
  next free row, not the command's identity. Two contests wanting two fields
  get rows 1 and 2 whichever fields those are. }
procedure DisplayInitialCommand(Command: InitialCommands);
begin
  inc(NewContestDisplayedCommands);
  frmNewContest.EnableRow(NewContestDisplayedCommands,
                          string(InitialCommandsSA[Command]));
end;


{ WHAT WM_INITDIALOG DID, minus creating thirty controls by hand. }
procedure PrepareForm;
var
   latest: string;
   i     : integer;
begin
   frmNewContest.Caption := TR4W_CURRENTVERSION + TC_OPENCONFIGURATIONFILE;
   frmNewContest.PopulateFiles(string(TR4W_PATH_NAME));

   // THE LIVE VALUE, NOT THE INI.  This used to read MAIN CALLSIGN out of
   // tr4w.ini straight into the MainCallsign global -- but that row is
   // csJSON, so settings\tr4w.json owns it and ApplyStoredCommands has
   // already put the right value in that global at startup.  Reading the
   // ini here did not merely show a stale callsign in the box: it
   // OVERWROTE the live global with it, so opening New Contest on a
   // station whose ini disagreed silently changed the operator's callsign.
   // On a station with no ini at all it blanked it.
   if MainCallsign <> '' then
      begin
      frmNewContest.SetMyCall(string(MainCallsign));
      end;

   // FROM settings\tr4w.json, not tr4w.ini (NY4I, 2026-08-16). An empty
   // result is the ordinary first-run state and simply hides the button.
   latest := GetLatestConfigFile;
   Windows.ZeroMemory(@TR4W_LATESTCFG_FILENAME, SizeOf(FileNameType));
   Windows.lstrcpynA(TR4W_LATESTCFG_FILENAME, PAnsiChar(WinAnsi(latest)),
                     SizeOf(FileNameType));

   if (latest <> '') and FileExists(latest) then
      begin
      frmNewContest.ShowLatest(Format(TC_LATEST_CONFIG_FILE + ' (Alt+&A):'#13#10'%s',
                                      [LowerCase(latest)]));
      end
   else
      begin
      frmNewContest.ShowLatest('');
      end;

   { The six CATEGORY-* rows are labelled once and stay labelled. Rows 1..3 are
     nil in this table because they are named per contest by DisplayInitialCommand. }
   for i := 1 to CSAS do
      begin
      if InitialCommandsSA2[i] <> nil then
         begin
         frmNewContest.SetRowLabel(i, string(InitialCommandsSA2[i]));
         end;
      end;

   BeginNewContest;   { OK starts disabled unless the form is already valid }
end;

{ The operator picked an existing .cfg from the list.

  StartContestFromListbox read the file name back out of the static that
  DlgDirListA wrote the current directory into, then expanded it with
  GetFullPathNameA because the list could be showing any directory. With a flat
  list of one directory there is nothing to expand: the name joins the path it
  was listed from. }
procedure OpenSelectedConfig;
begin
   { A FULL path already -- the grid can be showing any directory, which is why
     SelectedFile answers with the path and not just the name. }
   Windows.lstrcpynA(TR4W_CFG_FILENAME,
                     PAnsiChar(WinAnsi(frmNewContest.SelectedFile)),
                     SizeOf(FileNameType));
end;

procedure ShowNewContest;
begin
   frmNewContest := TfrmNewContest.Create(nil);
   try
      OnContestChanged := ApplyContestChoice;
      OnIAmInChanged   := ApplyIAmIn;
      OnFieldsChanged  := FieldsChanged;

      PrepareForm;

      if frmNewContest.ShowModal = mrOk then
         begin
         case frmNewContest.Choice of
            nccOpenSelected: OpenSelectedConfig;
            nccLatest:       Windows.CopyMemory(@TR4W_CFG_FILENAME,
                                                @TR4W_LATESTCFG_FILENAME,
                                                SizeOf(FileNameType));
            nccCreate:       SaveNewContest;
         end;
         end
      else
         begin
         { WM_CLOSE set this sentinel and uProgramMain tests it to mean
           "the operator did not choose a contest" -- see the caller. }
         TR4W_CFG_FILENAME[0] := '_';
         end;
   finally
      OnContestChanged := nil;
      OnIAmInChanged   := nil;
      OnFieldsChanged  := nil;
      FreeAndNil(frmNewContest);
   end;
end;
end.

