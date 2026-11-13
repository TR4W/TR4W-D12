(* Real QSO-party engine fixture. Owns isolated multiplier, domestic and
   dupe sheets; restores every session global it changes. Shared by the new
   party tests so parsing/credit setup and cleanup have one implementation. *)
unit uTestQSOPartyEngine;

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes, VC, uContestBase, uMults, uCallsigns, LogDom;

type
   TQSOPartyEngine = class
   private
      FActive: boolean;
      FHandle: TContestHandle;
      savedMults: TMultsObject;
      savedError: string;
      savedContest: TContestHandle;
      savedQsoByBand: boolean;
      savedQsoByMode: boolean;
      savedMultByBand: boolean;
      savedMultByMode: boolean;
      savedDomesticByBand: TAdditionalMultByBand;
      savedInHostState: boolean;
      savedCounties: boolean;
      savedActiveMode: ModeType;
      savedCallWindow: CallString;
      savedTable: TDomQTHTable;
      savedList: TCallsignsList;
      savedQualified: TQualifiedDupeSheet;
      savedCountries: TStringList;
      savedRefusalDomDir: string;
      savedMyCountry: string;
      savedDomesticFilename: string;
   public
      constructor Create(aHandle: TContestHandle);
      destructor Destroy; override;
      procedure Activate(aInHostState: boolean);
      function Enter(const aCall: string; const aExch: string; aBand: BandType;
         aMode: ModeType; aExtMode: ExtendedModeType;
         out aAccepted: boolean; var aRX: ContestExchange): boolean;
   end;

(* Empty means exact agreement with the independently transcribed sponsor
   table: canonical code, display name, count, no repeats or includes. *)
function CountyFileDifference(const aParty, aDomName, aSourceName: string;
   aExpectedCount: integer): string;

implementation

uses
   SysUtils, uSettingsModel, uContestRegistry, uContestFactory, uCTYDAT,
   uTestContestObjects, uTestShippedDom, uTestQSOPartyRules, ZoneCont, LogDupe, LogEdit, LogWind,
   LogStuff, PostUnit, FCONTEST, uPendingCounties, MainUnit, uDomFileKeys;

function CountyFileDifference(const aParty, aDomName, aSourceName: string;
   aExpectedCount: integer): string;
var
   source, lines, seen: TStringList;
   i: integer;
   key, root: string;
begin
   Result := '';
   source := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      root := ShippedDomDir + '..' + PathDelim + '..' + PathDelim + '..' + PathDelim;
      source.LoadFromFile(AnsiString(root + 'docs' + PathDelim + 'ContestRules' +
         PathDelim + 'QSOParties' + PathDelim + aParty + PathDelim + aSourceName));
      lines.LoadFromFile(AnsiString(ShippedDomDir + aDomName));
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE', UpperCase(TrimLeft(string(lines[i])))) = 1 then
            begin
            Result := 'county file includes another table';
            Exit;
            end;
         key := DomFileLineKey(string(lines[i]));
         if key = '' then
            begin
            Continue;
            end;
         if (seen.IndexOf(AnsiString(key)) >= 0) or
            (source.IndexOfName(AnsiString(key)) < 0) then
            begin
            Result := 'duplicate or unknown county: ' + key;
            Exit;
            end;
         seen.Add(AnsiString(key));
         if string(lines[i]) <> key + ' = ' + key + ',^' + string(source.Values[AnsiString(key)]) then
            begin
            Result := 'county code/name differs: ' + key;
            Exit;
            end;
         end;
      if seen.Count <> aExpectedCount then
         begin
         Result := 'county count differs';
         end;
   finally
      seen.Free;
      lines.Free;
      source.Free;
   end;
end;

constructor TQSOPartyEngine.Create(aHandle: TContestHandle);
var
   i: integer;
   ctyPath: string;
begin
   inherited Create;
   FHandle := aHandle;
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
      PathDelim + 'target' + PathDelim + 'cty.dat';
   if not ctyLoadInCountryFile(ctyPath, False, False, True) then
      begin
      raise Exception.Create('QSO-party test cannot load cty.dat');
      end;
   savedError := string(ExchangeErrorMessage);
   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   savedCounties := MultipliersIsCounties;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedRefusalDomDir := DomesticQTHRefusalDomDir;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedMults := mo;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   FActive := True;
   mo := TMultsObject.Create;
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
end;

destructor TQSOPartyEngine.Destroy;
var
   i: integer;
begin
   if FActive then
      begin
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      ClearPendingCounties;
      if mo <> savedMults then
         begin
         mo.Free;
         end;
      mo := savedMults;
      if QualifiedDupes <> savedQualified then
         begin
         QualifiedDupes.Free;
         end;
      QualifiedDupes := savedQualified;
      if CallsignsList <> savedList then
         begin
         CallsignsList.Free;
         end;
      CallsignsList := savedList;
      if DomQTHTable <> savedTable then
         begin
         DomQTHTable.Free;
         end;
      DomQTHTable := savedTable;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      MultipliersIsCounties := savedCounties;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Settings.Contest.DomesticFilename := savedDomesticFilename;
      Settings.My.DeriveCountry(savedMyCountry);
      DomesticQTHRefusalDomDir := savedRefusalDomDir;
      ExchangeErrorMessage := savedError;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
   inherited Destroy;
end;

procedure TQSOPartyEngine.Activate(aInHostState: boolean);
var
   identity: TContestBase;
   filename: string;
begin
   identity := ContestIdentity(FHandle);
   Contest := FHandle;
   StationInHostState := aInHostState;
   MultipliersIsCounties := not aInHostState;
   Settings.Qso.ByBand := identity.QSOByBand;
   Settings.Qso.ByMode := identity.QSOByMode;
   Settings.Mult.ByBand := identity.MultByBand;
   Settings.Mult.ByMode := identity.MultByMode;
   DomesticMultByBand := dmbbDefauld;
   DomesticCountries.Clear;
   Add_KVEKH6KL;
   DomesticQTHRefusalDomDir := ShippedDomDir;
   Settings.My.DeriveCountry('K');
   if aInHostState then
      begin
      filename := identity.InStateDomesticFileName;
      end
   else
      begin
      filename := identity.DomesticFileName;
      end;
   Settings.Contest.DomesticFilename := filename + '.dom';
   LoadShippedDomFollowingIncludes(DomQTHTable, filename + '.dom', True, 0);
   mo.ClearAllMults;
   CallsignsList.Free;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes.Free;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   ClearPendingCounties;
   ReleaseActiveContest;
   ActiveContest(Contest);
end;

function TQSOPartyEngine.Enter(const aCall: string; const aExch: string; aBand: BandType;
               aMode: ModeType; aExtMode: ExtendedModeType;
               out aAccepted: boolean; var aRX: ContestExchange): boolean;
begin
   Result := EnterPartyQSO(aCall, aExch, aBand, aMode, aExtMode, aAccepted, aRX);
end;

end.
