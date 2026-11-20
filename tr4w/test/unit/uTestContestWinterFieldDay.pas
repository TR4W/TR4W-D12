(* WINTER FIELD DAY, AGAINST THE SPONSOR'S 2027 RULES (v3) -- reviewed key
   by key 2026-11-19; the text is docs/ContestRules/WinterFieldDay/
   WFD-2027-Rules-v3.md. The final score (QSO points, no band-mode count, no
   power factor) is pinned in uTestContestTotals.Test_FieldDayFormulas; the
   class letters in uTestFieldDaySectionRefusal; the exports in
   uTestContestExport. *)
unit uTestContestWinterFieldDay;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestWinterFieldDayTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_BandsModesAndPoints;
      procedure Test_WSJTModesAndExcludedBandsAreXQSOs;
      procedure Test_Schedule;
   end;

implementation

uses
   SysUtils, DateUtils, VC, uContestBase, uContestRegistry, uContestSchedule,
   uTestContestObjects;

function WFDQSO(aBand: BandType; aMode: ModeType;
                aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := ContestHandleOf(WINTERFIELDDAY);
   Result.Callsign := 'K4FUN';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.ceClass := '1H';
   Result.QTHString := 'WCF';
   Result.DomesticQTH := 'WCF';
end;

(* "All Amateur bands may be used except 12, 17, 30, and 60 meters";
   "Phone contacts count as one point each, and all CW and digital modes
   count as two points each"; "All modes, except WSJT modes ... may be used".
   Every band, every mode and every submode, scored. *)
procedure TContestWinterFieldDayTests.Test_BandsModesAndPoints;
var
   wfd: TContestBase;
   band: BandType;
   mode: ModeType;
   ext: ExtendedModeType;
   qso: ContestExchange;
   expected: integer;
begin
   BeginTest('Test_WinterFieldDayBandsModesAndPoints');
   wfd := Make(WINTERFIELDDAY, NoStation);
   try
      for band := Low(BandType) to High(BandType) do
         begin
         CheckTrue(wfd.UsesBand(band) = (band in
            [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2, Band222,
             Band432, Band902, Band1296, Band2304, Band3456, Band5760, Band10G, Band24G,
             BandLight]),
            BandStringsArray[band] + ': "All Amateur bands ... except 12, 17, 30, and 60 meters"');
         end;

      for mode := Low(ModeType) to High(ModeType) do
         begin
         for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
            begin
            expected := 0;
            if mode = CW then
               begin
               expected := 2;
               end;
            (* "If the result is voice, it's Phone" -- FM, C4FM and D-STAR. *)
            if mode in [Phone, FM] then
               begin
               expected := 1;
               end;
            (* Every digital submode TR4W can name but the WSJT ones; eNoMode
               and the three generic data modes are "some submode". *)
            if (mode = Digital) and
               (ext in [eNoMode, eData, eData_R, eData_FM, eRTTY, eRTTY_R,
                        ePSK31, ePSK63, ePSK_R, eMFSK, eJS8, eJTTY]) then
               begin
               expected := 2;
               end;
            (* A RECORD WITH NO MODE is never judged off-mode
               (uContestBase.QSOIsOffContest), so it reaches the points rule,
               whose "everything but phone" arm gives it 2 -- unchanged by
               the 2027 review, pinned so a change is seen. *)
            if mode = NoMode then
               begin
               expected := 2;
               end;
            qso := WFDQSO(Band20, mode, ext);
            wfd.ScoreQSO(qso);
            CheckEquals(expected, Integer(qso.QSOPoints),
               ExtendedModeStringArray[ext] + ': phone 1, CW and digital 2, WSJT modes none');
            if mode <> NoMode then
               begin
               CheckTrue(wfd.UsesMode(mode, ext) = (expected > 0),
                  ExtendedModeStringArray[ext] + ': credited exactly where it scores');
               end;
            end;
         end;

      (* THE SPONSOR'S WSJT LIST, as far as TR4W can name it. JTTY is not on
         it and passes free text (NY4I, issue 120). *)
      for ext in [eFT8, eFT4, eJT65, eFST4, eFST4W] do
         begin
         CheckFalse(wfd.UsesMode(Digital, ext),
            ExtendedModeStringArray[ext] + ' is a WSJT mode: "not appropriate for Winter Field Day"');
         end;
      for ext in [eJS8, eJTTY, eMFSK, eRTTY, ePSK31] do
         begin
         CheckTrue(wfd.UsesMode(Digital, ext),
            ExtendedModeStringArray[ext] + ' passes the full exchange');
         end;
   finally
      wfd.Free;
   end;
end;

(* AN OFF-BAND OR OFF-MODE QSO IS AN AUTOMATIC X-QSO (Q98 S1), judged on the
   record by its own contest. *)
procedure TContestWinterFieldDayTests.Test_WSJTModesAndExcludedBandsAreXQSOs;
var
   qso: ContestExchange;
   band: BandType;
begin
   BeginTest('Test_WinterFieldDayWSJTModesAndExcludedBandsAreXQSOs');
   qso := WFDQSO(Band20, Digital, eFT8);
   CheckTrue(LoggedQSOIsXQSO(qso), 'FT8 is a WSJT mode: an automatic X-QSO');
   qso := WFDQSO(Band20, Digital, eFT4);
   CheckTrue(LoggedQSOIsXQSO(qso), 'FT4 likewise');
   qso := WFDQSO(Band20, Digital, eJTTY);
   CheckFalse(LoggedQSOIsXQSO(qso), 'JTTY counts (NY4I, issue 120)');
   qso := WFDQSO(Band20, Digital, eJS8);
   CheckFalse(LoggedQSOIsXQSO(qso), 'JS8Call is named by the rules');
   for band in [Band30, Band17, Band12] do
      begin
      qso := WFDQSO(band, CW, eCW);
      CheckTrue(LoggedQSOIsXQSO(qso), BandStringsArray[band] + ' is excluded');
      end;
   qso := WFDQSO(Band222, Phone, eFM);
   CheckFalse(LoggedQSOIsXQSO(qso), '"Don''t forget about 1.25 meters (220)!"');
end;

(* "Winter Field Day is held the 4th full weekend in January. For 2027, it
   will be held on January 23rd and 24th. The 30-hour operational period
   starts at 1600 UTC on Saturday ... and ends at 21:59 UTC on Sunday". *)
procedure TContestWinterFieldDayTests.Test_Schedule;
var
   s: TContestSchedule;
   err: string;
   startUTC, endUTC: TDateTime;
begin
   BeginTest('Test_WinterFieldDaySchedule');
   CheckTrue(TryParseContestSchedule(ContestIdentity(ContestHandleOf(WINTERFIELDDAY)).Schedule,
                                     s, err), 'the schedule parses: ' + err);
   CheckEquals(1, Length(s.Clauses), 'one clause');
   CheckTrue(TryNextSchedulePeriod(s.Clauses[0], EncodeDateTime(2027, 1, 1, 0, 0, 0, 0),
                                   startUTC, endUTC), 'a 2027 period');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDateTime(2027, 1, 23, 16, 0, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', startUTC), '2027: Saturday January 23, 1600 UTC');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDateTime(2027, 1, 24, 22, 0, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', endUTC),
               '30 hours: the last minute is 21:59 UTC Sunday January 24');
end;

procedure TContestWinterFieldDayTests.RunAllTests;
begin
   Test_BandsModesAndPoints;
   Test_WSJTModesAndExcludedBandsAreXQSOs;
   Test_Schedule;
end;

end.
