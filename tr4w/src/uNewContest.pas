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
  ;
type
  InitialCommands =
    (icmyCheck, icmyFDClass, icmyGrid, icmyFOC, icmyIOTA, icmyName, icmyPark, icmyPrec, icmyQTH, icmySection, icmyState, icmyZone, icmyPostalCode);

function NewContestDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
procedure BeginNewContest(h: HWND);
procedure ClearFields;
procedure SaveNewContest(h: HWND);
procedure DisplayCheckBox(Text: PAnsiChar);
procedure SetCommentAndEnableEditControl(comment: PAnsiChar; EditControl: InitialCommands);
procedure EnterCountyOrState(State: PAnsiChar);
procedure StartContestFromListbox();
function NewSelectContestListBoxProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): integer; stdcall;
procedure ChangeDir;
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
  InitialCommandsHWNDArray              : array[1..CSAS, 1..2] of HWND;
  NewContestDisplayedCommands           : integer;
  NewContestCheckBox                    : HWND;
  NewContestDlgWndHandle                : HWND;
  NewContestListBoxHandle               : HWND;
  NewContestCommentWndHandle            : HWND;
//  NewContestAllowReturn                 : boolean;
  SelectedContest                       : ContestType;
  OldSelectContestListBoxProc           : Pointer;

const

{(*}
  NC_CALL_EDIT                               = 221;
  NC_CONTEST_COMBOBOX                        = 233;
  NC_BUTTON_OK                               = 101;
  NC_BUTTON_CANCEL                           = 102;
  NC_BUTTON_LATEST_CONFIG                    = 73;
  NC_CHECKBOX_IAMIN                          = 107;
  NC_LISTBOX                                 = 444;
  {*)}

  sfFLAG                                = DDL_ARCHIVE or DDL_READWRITE or DDL_DIRECTORY;

function NewContestDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1, ExitAndClose;
var
  TempCardinal                          : Cardinal;
  ct                                    : ContestType;
  Top                                   : integer;

  TempCategoryAssisted                  : tCategoryAssisted;
  TempCategoryBand                      : tCategoryBand;
  TempCategoryMode                      : tCategoryMode;
  TempCategoryOperator                  : tCategoryOperator;
  TempCategoryPower                     : tCategoryPower;
  TempCategoryTransmitter               : tCategoryTransmitter;
  

//  TempActiveExchange                    : ExchangeType;
//  TempExchangeInformation               : ExchangeInformationRecord;
const
  h                                     = 18;
  BS_COMMANDLINK                        = $0000000E;

begin
  Result := False;
  case Msg of
    WM_INITDIALOG:
      begin
        NewContestDlgWndHandle := hwnddlg;

        // Issue #915: shrink left column by 30 px to give the right-side
        // CATEGORY-* labels room.  CATEGORY-TRANSMITTER (the longest label)
        // was being clipped on the left because the label area was too
        // narrow for right-aligned text.  Listbox entries are typically
        // ~25-30 chars (e.g. "[2025 FLORIDA QSO PARTY NY4I]") which still
        // fit comfortably at width 250.
        CreateStatic(RC_CAPTION, 5, 5, 250, hwnddlg, 445);
         {LISTBOX}
        CreateListBox(5, 35, 250, 370, hwnddlg, NC_LISTBOX);

        // FROM settings\tr4w.json, not tr4w.ini (NY4I, 2026-08-16). This is the
        // read half of the move; the write is in tr4w.dpr. An empty result is
        // the ordinary first-run state and simply hides the button below.
        Windows.ZeroMemory(@TR4W_LATESTCFG_FILENAME, SizeOf(FileNameType));
        Windows.lstrcpynA(TR4W_LATESTCFG_FILENAME,
                          PAnsiChar(AnsiString(GetLatestConfigFile)),
                          SizeOf(FileNameType));
        if TR4W_LATESTCFG_FILENAME[0] <> #0 then
           begin

           if FileExists(TR4W_LATESTCFG_FILENAME) then

              begin

              {BUTTON LATEST CONFIG}
                  TempCardinal := tWM_SETFONT(
                    CreateWindowExW(0, ButtonPChar, nil, BS_MULTILINE or WS_CHILD or BS_TEXT or WS_VISIBLE {or WS_TABSTOP}, 5, 415, 250, 50 {nHeight}, hwnddlg, NC_BUTTON_LATEST_CONFIG, hInstance, nil),
                    MSSansSerifFont);

                  Windows.CopyMemory(@TempBuffer1, @TR4W_LATESTCFG_FILENAME, SizeOf(FileNameType));
                  Windows.CharLowerA(TempBuffer1);
                  TF.Format(wsprintfBuffer, TC_LATEST_CONFIG_FILE + ' (Alt+&A):'#13#10'%s', TempBuffer1);
                  //i := GetDlgItem(hwnddlg, NC_BUTTON_LATEST_CONFIG);

                  Windows.SetWindowTextA(TempCardinal, wsprintfBuffer);
                  EnableWindow(TempCardinal, True);
                  Windows.ShowWindow(TempCardinal, SW_SHOW);
              end;
           end;

        // Issue #915: labels shifted left + widened to fit CATEGORY-TRANSMITTER
        // at right-align.  x was 300, w was 125+20 (=145).  Now x=270, w=155+20.
        tCreateStaticWindow('MY CALL', WS_CHILD or SS_NOTIFY or SS_RIGHT or SS_NOPREFIX or WS_VISIBLE, 270, 5, 155 + 20, h, hwnddlg, 0);

        tCreateStaticWindow('CONTEST', WS_CHILD or SS_NOTIFY or SS_RIGHT or SS_NOPREFIX or WS_VISIBLE, 270, 33, 155 + 20, h, hwnddlg, 0);
        tWM_SETFONT(CreateWindowW(StaticPChar, nil, SS_SUNKEN or SS_center or WS_CHILD or WS_VISIBLE, 305, 95, 300, 40, hwnddlg, 106, hInstance, nil), MSSansSerifFont);

        {MY CALL}
        CreateEdit(ES_UPPERCASE, 455, 5, 150, 23, hwnddlg, NC_CALL_EDIT);
        {CONTEST}
        tCreateComboBoxWindow(WS_VSCROLL + CBS_SORT + CBS_UPPERCASE + CBS_DROPDOWNLIST or CBS_AUTOHSCROLL or WS_CHILD or WS_VISIBLE or WS_TABSTOP, 455, 30, 150, hwnddlg, NC_CONTEST_COMBOBOX);
        {I AM IN}
         Windows.ShowWindow(CreateButton(BS_AUTOCHECKBOX or BS_LEFT or BS_TOP or BS_MULTILINE or WS_CHILD or WS_TABSTOP, nil, 420, 60, 430, hwnddlg, NC_CHECKBOX_IAMIN), SW_HIDE); // 4.76.3

        Windows.SetWindowTextA(hwnddlg, TR4W_CURRENTVERSION + TC_OPENCONFIGURATIONFILE);

        NewContestListBoxHandle := GetDlgItem(hwnddlg, NC_LISTBOX);

        TF.Format(wsprintfBuffer, '%s*.CFG', TR4W_PATH_NAME);

        Windows.DlgDirListA(hwnddlg, wsprintfBuffer, NC_LISTBOX, 445, sfFLAG + DDL_DRIVES);
        SelectParentDir(NewContestListBoxHandle);
        OldSelectContestListBoxProc := Pointer(Windows.SetWindowLong(NewContestListBoxHandle, GWL_WNDPROC, integer(@NewSelectContestListBoxProc)));
        tWM_SETFONT(NewContestListBoxHandle, MainFixedFont);

        for ct := Succ(DUMMYCONTEST) to High(ContestType) do
           begin
           tCB_ADDSTRING_PCHAR(hwnddlg, NC_CONTEST_COMBOBOX, ContestTypeSA[ct]);
           end;

        NewContestCheckBox := GetDlgItem(hwnddlg, NC_CHECKBOX_IAMIN);


        NewContestCommentWndHandle := GetDlgItem(hwnddlg, 106);
        tLoadKeyboardLayout;

        for TempCardinal := 1 to CSAS do
           begin
           Top := 120 + TempCardinal * (h + 6);
           // Issue #915: CATEGORY-* labels shifted left + widened so the
           // longest one (CATEGORY-TRANSMITTER) fits at right-align without
           // clipping.  Was: x=300, w=128+20 (=148).  Now: x=270, w=158+20.
           InitialCommandsHWNDArray[TempCardinal, 1] := tCreateStaticWindow(InitialCommandsSA2[TempCardinal], WS_CHILD or SS_NOTIFY or SS_RIGHT or SS_NOPREFIX or WS_VISIBLE, 270, Top, 158 + 20, h, hwnddlg, 0);
           if TempCardinal < 4 then
              begin
              InitialCommandsHWNDArray[TempCardinal, 2] := tCreateEditWindow(WS_EX_STATICEDGE, '', WS_TABSTOP or WS_CHILD or ES_UPPERCASE, 435 + 20, Top, 173 - 20, h, hwnddlg, 0)
              end
           else
              begin
              InitialCommandsHWNDArray[TempCardinal, 2] := tCreateComboBoxWindow({CBS_SORT + }CBS_UPPERCASE + CBS_DROPDOWNLIST or WS_CHILD or {WS_VSCROLL or } WS_VISIBLE or WS_TABSTOP, 435 + 20, Top, 173 - 20, hwnddlg, 0);
              end;
           end;

        for TempCategoryAssisted := Low(tCategoryAssisted) to High(tCategoryAssisted) do
           begin
           SendMessageA(InitialCommandsHWNDArray[4, 2], CB_ADDSTRING, 0, integer(tCategoryAssistedSA[TempCategoryAssisted]));
           end;

        for TempCategoryBand := Low(tCategoryBand) to High(tCategoryBand) do
           begin
           SendMessageA(InitialCommandsHWNDArray[5, 2], CB_ADDSTRING, 0, integer(tCategoryBandSA[TempCategoryBand]));
           end;

        for TempCategoryMode := Low(tCategoryMode) to High(tCategoryMode) do
           begin
           SendMessageA(InitialCommandsHWNDArray[6, 2], CB_ADDSTRING, 0, integer(tCategoryModeSA[TempCategoryMode]));
           end;

        for TempCategoryOperator := Low(tCategoryOperator) to High(tCategoryOperator) do
           begin
           SendMessageA(InitialCommandsHWNDArray[7, 2], CB_ADDSTRING, 0, integer(tCategoryOperatorSA[TempCategoryOperator]));
           end;

        for TempCategoryPower := Low(tCategoryPower) to High(tCategoryPower) do
           begin
           SendMessageA(InitialCommandsHWNDArray[8, 2], CB_ADDSTRING, 0, integer(tCategoryPowerSA[TempCategoryPower]));
           end;

        for TempCategoryTransmitter := Low(tCategoryTransmitter) to High(tCategoryTransmitter) do
           begin
           SendMessageA(InitialCommandsHWNDArray[9, 2], CB_ADDSTRING, 0, integer(tCategoryTransmitterSA[TempCategoryTransmitter]));
           end;

        for TempCardinal := 4 to CSAS do
           begin
           SendMessage(InitialCommandsHWNDArray[TempCardinal, 2], CB_SETCURSEL, 0, 0);
           end;

        MainCallsign[0] := AnsiChar(GetPrivateProfileStringA(_COMMANDS, MAIN_CALLSIGN, nil, @MainCallsign[1], SizeOf(MainCallsign), TR4W_INI_FILENAME));
        if MainCallsign <> '' then
           begin
           Windows.SetDlgItemTextA(hwnddlg, NC_CALL_EDIT, @MainCallsign[1]);
           end;

        {OK}
        CreateButton(BS_DEFPUSHBUTTON, OK_WORD, 350, 430, 80, hwnddlg, NC_BUTTON_OK);
        SendMessage(hwnddlg, DM_SETDEFID, NC_BUTTON_OK, 0);
        {CANCEL}
        CreateButton(0, CANCEL_WORD, 350 + 90, 430, 80, hwnddlg, NC_BUTTON_CANCEL);

      end;

    WM_CLOSE:
      begin
        ExitAndClose:
        TR4W_CFG_FILENAME[0] := '_';
        EndDialog(hwnddlg, 0);
      end;

    WM_COMMAND:
      begin
        if HiWord(wParam) = LBN_DBLCLK then
           begin
           ChangeDir;
           end;

        if HiWord(wParam) = BN_CLICKED then
           begin
           if LoWord(wParam) = NC_BUTTON_LATEST_CONFIG then
              begin
              Windows.CopyMemory(@TR4W_CFG_FILENAME, @TR4W_LATESTCFG_FILENAME, SizeOf(FileNameType));
              DestroyWindow(NewContestDlgWndHandle);
              end;

           if LoWord(wParam) = NC_CHECKBOX_IAMIN then
              begin
              ClearFields;

              Windows.SetWindowTextA(NewContestCommentWndHandle, nil);
               if Windows.SendMessage(NewContestCheckBox, BM_GETCHECK, 0, 0) = BST_UNCHECKED then


                  begin
                  {
              if SelectedContest = NYQP then
              begin
                SetCommentAndEnableEditControl(TC_ENTERSTATEFORUSPROVINCEFORCANADA, nc_MyState);
                EnableWindow(GetDlgItem(hwnddlg, 101), False);
              end;
}
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
                     Windows.SendMessage(107, BM_SETCHECK, BST_CHECKED, 0);
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
                  SetCommentAndEnableEditControl(nil, icmyState);

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
              end;

           end;

        if HiWord(wParam) = CBN_SELCHANGE then
          if LoWord(wParam) = NC_CONTEST_COMBOBOX then
             begin
             SelectedContest := GetContestFromString(GetDialogItemText(hwnddlg, NC_CONTEST_COMBOBOX));
             ClearFields;
             Windows.SetWindowTextA(NewContestCommentWndHandle, nil);
             Windows.ShowWindow(NewContestCheckBox, SW_HIDE);
             Windows.SendMessage(NewContestCheckBox, BM_SETCHECK, BST_UNCHECKED, 0);

             if (ContestsArray[SelectedContest].p <> 0) and (SelectedContest <> BCQP)  then
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
                   Windows.SetWindowTextA(NewContestCheckBox, TC_ISLANDSTATION);
                   Windows.ShowWindow(NewContestCheckBox, SW_SHOW);
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
                  Windows.SetWindowTextA(NewContestCheckBox, 'Activator');
                  Windows.ShowWindow(NewContestCheckBox, SW_SHOW);
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

             end;
        BeginNewContest(hwnddlg);

        case wParam of
{$IFDEF LANG_RUS}
//          104: ShowHelp('ru_selectingacontest');
{$ENDIF}
          NC_BUTTON_CANCEL, 2: goto ExitAndClose;
          NC_BUTTON_OK: SaveNewContest(hwnddlg);
        end;
      end;
  end;
end;

procedure ClearFields;
var
  i                                     : integer;
begin
  NewContestDisplayedCommands := 0;
  for i := 1 to 3 do
     begin
     ShowWindow(InitialCommandsHWNDArray[i, 1], SW_HIDE);
     ShowWindow(InitialCommandsHWNDArray[i, 2], SW_HIDE);
     Windows.SetWindowTextA(InitialCommandsHWNDArray[i, 2], nil);
     end;
end;

procedure BeginNewContest(h: HWND);
var
  res                                   : LongBool;
  i                                     : Cardinal;
  Call                                  : CallString;
begin
  res := True;
  if tCB_GETCURSEL(h, NC_CONTEST_COMBOBOX) = -1 then
     begin
     res := False;
     end;
  i := GetDlgItemTextA(h, NC_CALL_EDIT, @Call[1], SizeOf(CallString));
  if i < 3 then
     begin
     res := False;
     end;
  Call[0] := AnsiChar(i);
  if not IsAGoodCall(Call) then
     begin
     res := False;
     end;

  for i := 1 to NewContestDisplayedCommands do
    if Windows.GetWindowTextLength(InitialCommandsHWNDArray[i, 2]) = 0 then
       begin
       res := False;
       end;
  EnableWindow(GetDlgItem(h, NC_BUTTON_OK), res);

end;

procedure SaveNewContest(h: HWND);
var
  f                                     : HWND;
  i                                     : Cardinal;
  BytesToWrite                          : Cardinal;
begin
  begin
      {callsign}
    i := Windows.GetDlgItemTextA(h, NC_CALL_EDIT, TempBuffer1, SizeOf(TempBuffer1));
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
    Windows.GetDlgItemTextA(h, NC_CONTEST_COMBOBOX, TempBuffer2, SizeOf(TempBuffer2));

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
  Windows.GetDlgItemTextA(h, NC_CONTEST_COMBOBOX, TempBuffer1, SizeOf(TempBuffer1));
  TF.Format(TR4W_CFG_FILENAME, '%s%s.CFG', wsprintfBuffer, TempBuffer1);

  if FileExists(TR4W_CFG_FILENAME) then
     begin
     TF.Format(SYSERRORBUFFER, TC_FOLDERALREADYEXISTSOVERWRITE, TR4W_CFG_FILENAME);
     if YesOrNo(h, SYSERRORBUFFER) = IDno then Exit;
     end;

  f := CreateFileA(TR4W_CFG_FILENAME, GENERIC_WRITE, FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_ARCHIVE, 0);
  if f <> INVALID_HANDLE_VALUE then
     begin

     Windows.GetDlgItemTextA(h, NC_CALL_EDIT, TempBuffer1, SizeOf(TempBuffer1));
     BytesToWrite := TF.Format(wsprintfBuffer, ';Created by ' + TR4W_CURRENTVERSION + #13#10#13#10'[COMMANDS]'#13#10'MY CALL=%s'#13#10, TempBuffer1);
     sWriteFile(f, wsprintfBuffer, BytesToWrite);

     for i := 1 to CSAS do
        begin
        GetWindowTextA(InitialCommandsHWNDArray[i, 1], TempBuffer1, SizeOf(TempBuffer1));
        if GetWindowTextA(InitialCommandsHWNDArray[i, 2], TempBuffer2, SizeOf(TempBuffer2)) = 0 then Continue;
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
     Windows.GetDlgItemTextA(h, NC_CONTEST_COMBOBOX, TempBuffer1, SizeOf(TempBuffer1));
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

     DestroyWindow(h);
     end
  else
     begin
     ShowSysErrorMessage('CFG FILE');
     end;

end;

procedure DisplayCheckBox(Text: PAnsiChar);
begin
  // Issue #997: asm-push wsprintf -> Format (TC_IAMIN = '&I am in %s').
  TF.Format(wsprintfBuffer, TC_IAMIN, Text);
  Windows.SetWindowTextA(NewContestCheckBox, wsprintfBuffer);
  Windows.ShowWindow(NewContestCheckBox, SW_SHOW);
end;

procedure SetCommentAndEnableEditControl(comment: PAnsiChar; EditControl: InitialCommands);
begin
  DisplayInitialCommand(EditControl);
  Windows.SetWindowTextA(NewContestCommentWndHandle, comment);
end;


procedure EnterCountyOrState(State: PAnsiChar);
begin
  DisplayInitialCommand(icmyState);
  // Issue #997: asm-push wsprintf -> Format. TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX
  // has two %s, both = State.
  TF.Format(wsprintfBuffer, TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX, State, State);
  Windows.SetWindowTextA(NewContestCommentWndHandle, wsprintfBuffer);
end;

procedure StartContestFromListbox();
var
  p                                     : PAnsiChar;
begin
  p := TR4W_CFG_FILENAME;
  GetDlgItemTextA(NewContestDlgWndHandle, 445, TR4W_CFG_FILENAME, SizeOf(TR4W_CFG_FILENAME));
  Windows.GetFullPathNameA(@TempBuffer1, 256, @TR4W_CFG_FILENAME, p);
  DestroyWindow(NewContestDlgWndHandle);
end;

function NewSelectContestListBoxProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): integer; stdcall;
begin
  if Msg = WM_KEYUP then
    if wParam = VK_RETURN then
       begin
       ChangeDir;
       end;
  Result := CallWindowProc(OldSelectContestListBoxProc, hwnddlg, Msg, wParam, lParam);
end;

procedure ChangeDir;
begin
  if Windows.DlgDirSelectExA(NewContestDlgWndHandle, TempBuffer1, SizeOf(TempBuffer1), NC_LISTBOX) = False then
     begin
     StartContestFromListbox;
     Exit;
     end;
  Windows.lstrcatA(TempBuffer1, '*.CFG');
  Windows.DlgDirListA(NewContestDlgWndHandle, TempBuffer1, NC_LISTBOX, 445, sfFLAG);

  SelectParentDir(NewContestListBoxHandle);
end;

procedure DisplayInitialCommand(Command: InitialCommands);
begin
  inc(NewContestDisplayedCommands);
  ShowWindow(InitialCommandsHWNDArray[NewContestDisplayedCommands, 1], SW_SHOWNORMAL);
  ShowWindow(InitialCommandsHWNDArray[NewContestDisplayedCommands, 2], SW_SHOWNORMAL);
  Windows.SetWindowTextA(InitialCommandsHWNDArray[NewContestDisplayedCommands, 1], InitialCommandsSA[Command]);
end;


procedure ShowNewContest;
begin
   CreateModalDialog(305, 235, tr4whandle, @NewContestDlgProc, 0);
end;
end.

