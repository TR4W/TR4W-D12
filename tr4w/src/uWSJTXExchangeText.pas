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
 *)
unit uWSJTXExchangeText;

{$I tr4w.inc}

(* WHAT THE STATION WSJT-X IS WORKING HAS SENT, AS THE TEXT THE EXCHANGE WINDOW
  TAKES (2026-11-25).

  A decode addressed to us ('NY4I F6HUK -15', 'NY4I F6HUK R-18', 'NY4I F6HUK
  JN06', Field Day's 'NY4I F6HUK R 3A ENY') carries the other station's
  report, grid, or class and section. This unit reads one such message and
  says what text, in the contest's own fields, the operator would have typed.

  A LEAF: pure text and the contest's field list. It touches no window, no
  setting and no thread, so the UDP listener can call it and a test can feed
  it a string.

  THE REPORT IS AN RST, NOT THE dB. The typed-entry path (tree.ValidRST) reads
  digits only -- a leading '-' stays 0 -- so '-15' cannot be typed. The
  conversion is uWSJTXReport.WSJTXSnrToRST, the one the Cabrillo export uses,
  and what the operator would key for that signal. The logged QSO still comes
  from WSJT-X's ADIF record (-15 as is); this text is for the operator to see
  and correct beforehand.

  ONLY WHAT THE CLASS LISTS, AND ONLY WHAT PARSES BACK. The field list is the
  contest class's (ExchangeInformationRecord). A class that lists a field
  WSJT-X cannot supply (a serial, a name, a county ...) gets NO text, because
  the typed parsers are positional: a lone '519' for an RST-and-serial class is
  read as the serial. The one exception is the RST, name and QTH shape (General
  QSO), whose typed form accepts a lone leading RST: it gets the report alone,
  and the grid arrives with the logged record.

  ... EXCEPT ON A DIGITAL QSO (NY4I, 2026-11-25: "put the grid in the exchange
  window; optimally the actual received signal report, -18"). General QSO's
  typed parser reads WSJT-X's signed dB report and a grid there, so the text is
  '-08 FN41' (WSJTXExchangeForMode) and the logged QSO equals WSJT-X's own. *)

interface

uses
   VC;

type
   (* What the messages of one QSO have said so far. Messages accumulate: the
     grid comes in the first reply, the report in the next. *)
   TWSJTXReceivedParts = class(TObject)
   public
      HasReport: boolean;
      Snr: integer;
      Grid: string;
      ExchClass: string;
      Section: string;
      (* The last message parsed carried an acknowledgement ('R-18', 'R 3A
        ENY'): the other station is answering OUR message, so it is not the
        opening of a new QSO. *)
      Roger: boolean;
      procedure Clear;
      function  Any: boolean;
   end;

(* The call without its hash brackets and without a prefix or suffix
  (F6HUK/P, DL/F6HUK, <F6HUK> all give F6HUK), upper case. *)
function WSJTXBaseCall(const aCall: string): string;

(* Is aDecodedText addressed to aMyCall FROM aDXCall (word 1 and word 2, base
  calls compared)? Whatever the tail carries is added to aParts; a part the
  message does not carry is left as it was. True only when the message is
  addressed to us from that station AND carries at least one part. *)
function WSJTXParseAddressedMessage(const aDecodedText, aMyCall,
                                    aDXCall: string;
                                    aParts: TWSJTXReceivedParts): boolean;

(* The exchange text for the parts so far. False (aText '') when the class lists
  a field that cannot be supplied or no listed field can be. *)
function WSJTXExchangeFromParts(const aFields: ExchangeInformationRecord;
                                aParts: TWSJTXReceivedParts;
                                out aText: string): boolean;

(* The same, told whether the QSO is on a digital mode. For the RST, name and QTH
  shape (General QSO) a digital QSO gets the REPORT AS WSJT-X SENT IT and the
  grid ('-08 FN41'), which that class's typed parser reads on a digital QSO;
  every other shape is as above. *)
function WSJTXExchangeForMode(const aFields: ExchangeInformationRecord;
                              aParts: TWSJTXReceivedParts;
                              aDigitalMode: boolean;
                              out aText: string): boolean;

(* THE CALL WSJT-X LOGGED IS NOT PUT BACK (2026-11-25). After WSJT-X logs a QSO
  its STATUS keeps naming that DX call (for minutes, while it sends CQ), so a
  put on the next STATUS brought the logged call back, flagged a dupe. True
  when aStatusDXCall is the call that was logged (base calls compared); the
  suppression ends when the STATUS names another call or none. *)
function WSJTXIsTheLoggedCall(const aStatusDXCall, aLoggedCall: string): boolean;

(* PUT A CALL BACK that something cleared while WSJT-X still transmits to it:
  the window is empty, the call is not the one the operator escaped, and it is
  not the call WSJT-X logged. *)
function WSJTXShouldRestoreCall(const aDXCall, aEscapedCall, aLoggedCall: string;
                                aCallWindowEmpty: boolean): boolean;

(* A MESSAGE THAT OPENS A NEW QSO WITH THE LOGGED CALL (the escape from the
  suppression above): addressed to us from aDXCall, carrying a grid, a plain
  report or a class -- and NOT an acknowledgement ('R-18', 'R 3A ENY'), which
  a station repeats when it did not hear our RR73. *)
function WSJTXOpensANewQso(const aDecodedText, aMyCall, aDXCall: string): boolean;

(* One message at a time: parse and compose. *)
function WSJTXDecodeToExchangeText(const aFields: ExchangeInformationRecord;
                                   const aDecodedText, aMyCall,
                                   aDXCall: string;
                                   out aText: string): boolean;

implementation

uses
   SysUtils,
   uWSJTXReport;   // WSJTXSnrToRST

procedure TWSJTXReceivedParts.Clear;
begin
   HasReport := False;
   Snr := 0;
   Grid := '';
   ExchClass := '';
   Section := '';
   Roger := False;
end;

function TWSJTXReceivedParts.Any: boolean;
begin
   Result := HasReport or (Grid <> '') or (ExchClass <> '') or (Section <> '');
end;

function WSJTXBaseCall(const aCall: string): string;
var
   work: string;
   part: string;
   slash: integer;
begin
   work := UpperCase(Trim(aCall));
   if (Length(work) > 1) and (work[1] = '<') and (work[Length(work)] = '>') then
      begin
      work := Copy(work, 2, Length(work) - 2);
      end;

   Result := '';
   while work <> '' do
      begin
      slash := Pos('/', work);
      if slash = 0 then
         begin
         part := work;
         work := '';
         end
      else
         begin
         part := Copy(work, 1, slash - 1);
         work := Copy(work, slash + 1, Length(work));
         end;
      (* The longest piece is the call; a prefix (DL) or suffix (P, QRP) is
        shorter. *)
      if Length(part) > Length(Result) then
         begin
         Result := part;
         end;
      end;
end;

(* The words of a message, trailing blanks gone. *)
procedure SplitWords(const aText: string; var aWords: array of string;
                     out aCount: integer);
var
   i: integer;
   current: string;
begin
   aCount := 0;
   current := '';
   for i := 1 to Length(aText) + 1 do
      begin
      if (i > Length(aText)) or (aText[i] = ' ') then
         begin
         if (current <> '') and (aCount <= High(aWords)) then
            begin
            aWords[aCount] := current;
            Inc(aCount);
            end;
         current := '';
         end
      else
         begin
         current := current + aText[i];
         end;
      end;
end;

function IsDigit(aChar: char): boolean;
begin
   Result := (aChar >= '0') and (aChar <= '9');
end;

(* A WSJT-X dB report: [+-]nn. *)
function IsSignedReport(const aWord: string; out aSnr: integer): boolean;
begin
   Result := (Length(aWord) = 3) and
             ((aWord[1] = '+') or (aWord[1] = '-')) and
             IsDigit(aWord[2]) and IsDigit(aWord[3]);
   if Result then
      begin
      aSnr := (Ord(aWord[2]) - Ord('0')) * 10 + (Ord(aWord[3]) - Ord('0'));
      if aWord[1] = '-' then
         begin
         aSnr := -aSnr;
         end;
      end;
end;

(* A four-character grid. RR73 has the shape and is the sign-off. *)
function IsGrid4(const aWord: string): boolean;
begin
   Result := (Length(aWord) = 4) and (aWord <> 'RR73') and
             (aWord[1] >= 'A') and (aWord[1] <= 'R') and
             (aWord[2] >= 'A') and (aWord[2] <= 'R') and
             IsDigit(aWord[3]) and IsDigit(aWord[4]);
end;

(* Field Day's class: one or two digits and a letter A-F. *)
function IsFieldDayClass(const aWord: string): boolean;
begin
   Result := ((Length(aWord) = 2) or (Length(aWord) = 3)) and
             IsDigit(aWord[1]) and
             ((Length(aWord) = 2) or IsDigit(aWord[2])) and
             (aWord[Length(aWord)] >= 'A') and (aWord[Length(aWord)] <= 'F');
end;

function IsSectionWord(const aWord: string): boolean;
var
   i: integer;
begin
   Result := (Length(aWord) >= 2) and (Length(aWord) <= 4);
   if Result then
      begin
      for i := 1 to Length(aWord) do
         begin
         if (aWord[i] < 'A') or (aWord[i] > 'Z') then
            begin
            Result := False;
            end;
         end;
      end;
end;

function WSJTXParseAddressedMessage(const aDecodedText, aMyCall,
                                    aDXCall: string;
                                    aParts: TWSJTXReceivedParts): boolean;
var
   words: array[0..9] of string;
   count: integer;
   next: integer;
   snr: integer;
   found: boolean;
begin
   Result := False;
   found := False;
   if (aParts = nil) or (WSJTXBaseCall(aMyCall) = '') or
      (WSJTXBaseCall(aDXCall) = '') then
      begin
      Exit;
      end;

   SplitWords(UpperCase(aDecodedText), words, count);

   (* An 'a7'-style annotation WSJT-X appends, or a '?' low-confidence mark,
     is not part of the message. *)
   while (count > 0) and
         ((words[count - 1] = '?') or
          ((Length(words[count - 1]) = 2) and (words[count - 1][1] = 'A') and
           IsDigit(words[count - 1][2]))) do
      begin
      Dec(count);
      end;

   if count < 3 then
      begin
      Exit;
      end;
   if (WSJTXBaseCall(words[0]) <> WSJTXBaseCall(aMyCall)) or
      (WSJTXBaseCall(words[1]) <> WSJTXBaseCall(aDXCall)) then
      begin
      Exit;
      end;

   (* 'R' alone (Field Day's acknowledgement) is skipped; 'R-18' is one word. *)
   next := 2;
   aParts.Roger := False;
   if (words[next] = 'R') and (count > 3) then
      begin
      Inc(next);
      aParts.Roger := True;
      end;

   if IsSignedReport(words[next], snr) then
      begin
      aParts.HasReport := True;
      aParts.Snr := snr;
      found := True;
      end
   else if (words[next][1] = 'R') and IsSignedReport(Copy(words[next], 2, 3), snr) then
      begin
      aParts.HasReport := True;
      aParts.Snr := snr;
      aParts.Roger := True;
      found := True;
      end
   else if IsGrid4(words[next]) then
      begin
      aParts.Grid := words[next];
      found := True;
      end
   else if IsFieldDayClass(words[next]) then
      begin
      aParts.ExchClass := words[next];
      found := True;
      if (next + 1 < count) and IsSectionWord(words[next + 1]) then
         begin
         aParts.Section := words[next + 1];
         end;
      end;
   (* RRR, RR73 and 73 carry no exchange. *)

   Result := found;
end;

function WSJTXExchangeFromParts(const aFields: ExchangeInformationRecord;
                                aParts: TWSJTXReceivedParts;
                                out aText: string): boolean;
begin
   Result := WSJTXExchangeForMode(aFields, aParts, False, aText);
end;

function WSJTXExchangeForMode(const aFields: ExchangeInformationRecord;
                              aParts: TWSJTXReceivedParts;
                              aDigitalMode: boolean;
                              out aText: string): boolean;
var
   cannotSupply: boolean;
   report: string;
   qth: string;
   cls: string;

   procedure Add(const aWord: string);
   begin
      if aWord <> '' then
         begin
         if aText <> '' then
            begin
            aText := aText + ' ';
            end;
         aText := aText + aWord;
         end;
   end;

begin
   aText := '';
   Result := False;
   if (aParts = nil) or (not aParts.Any) then
      begin
      Exit;
      end;

   report := '';
   if aParts.HasReport then
      begin
      report := IntToStr(WSJTXSnrToRST(aParts.Snr));
      end;

   (* THE RST, NAME AND QTH SHAPE (General QSO): its typed form takes a lone
     leading RST and reads a second word as the NAME, so only the report. *)
   if aFields.Name and aFields.RST and aFields.QTH then
      begin
      cannotSupply := aFields.Age or aFields.Chapter or aFields.Check or
         aFields.ClassEI or aFields.FOCNumber or aFields.Kids or aFields.Power or
         aFields.Precedence or aFields.QSONumber or aFields.RandomChars or
         aFields.TenTenNum or aFields.Zone or aFields.ZoneOrSociety;
      if cannotSupply then
         begin
         Exit;
         end;
      if aDigitalMode then
         begin
         (* The report as WSJT-X sent it (-08, with its sign) and the grid,
           which the General QSO parser reads on a digital QSO
           (logstuff.ReadWSJTXTypedExchange). *)
         report := '';
         if aParts.HasReport then
            begin
            report := WSJTXFormatDBReport(aParts.Snr);
            end;
         Add(report);
         Add(aParts.Grid);
         end
      else
         begin
         aText := report;
         end;
      Result := aText <> '';
      Exit;
      end;

   cannotSupply := aFields.Age or aFields.Chapter or aFields.Check or
      aFields.FOCNumber or aFields.Kids or aFields.Name or aFields.Power or
      aFields.Precedence or aFields.QSONumber or aFields.RandomChars or
      aFields.TenTenNum or aFields.Zone or aFields.ZoneOrSociety;
   if cannotSupply then
      begin
      Exit;
      end;

   (* The QTH is the section when the class takes a class (Field Day), the
     grid otherwise. *)
   qth := '';
   cls := '';
   if aFields.QTH then
      begin
      if aFields.ClassEI then
         begin
         qth := aParts.Section;
         end
      else
         begin
         qth := aParts.Grid;
         end;
      end;
   if aFields.ClassEI then
      begin
      cls := aParts.ExchClass;
      end;
   if not aFields.RST then
      begin
      report := '';
      end;

   (* The order the typed parsers take: RST first, then the class, then the
     QTH. *)
   Add(report);
   Add(cls);
   Add(qth);
   Result := aText <> '';
end;

function WSJTXIsTheLoggedCall(const aStatusDXCall, aLoggedCall: string): boolean;
begin
   Result := (WSJTXBaseCall(aLoggedCall) <> '') and
             (WSJTXBaseCall(aStatusDXCall) = WSJTXBaseCall(aLoggedCall));
end;

function WSJTXShouldRestoreCall(const aDXCall, aEscapedCall, aLoggedCall: string;
                                aCallWindowEmpty: boolean): boolean;
begin
   Result := (aDXCall <> '') and
             aCallWindowEmpty and
             (WSJTXBaseCall(aEscapedCall) <> WSJTXBaseCall(aDXCall)) and
             (not WSJTXIsTheLoggedCall(aDXCall, aLoggedCall));
end;

function WSJTXOpensANewQso(const aDecodedText, aMyCall, aDXCall: string): boolean;
var
   parts: TWSJTXReceivedParts;
begin
   parts := TWSJTXReceivedParts.Create;
   try
      parts.Clear;
      Result := WSJTXParseAddressedMessage(aDecodedText, aMyCall, aDXCall, parts) and
                (not parts.Roger);
   finally
      parts.Free;
   end;
end;

function WSJTXDecodeToExchangeText(const aFields: ExchangeInformationRecord;
                                   const aDecodedText, aMyCall,
                                   aDXCall: string;
                                   out aText: string): boolean;
var
   parts: TWSJTXReceivedParts;
begin
   aText := '';
   parts := TWSJTXReceivedParts.Create;
   try
      parts.Clear;
      Result := WSJTXParseAddressedMessage(aDecodedText, aMyCall, aDXCall,
                                           parts) and
                WSJTXExchangeFromParts(aFields, parts, aText);
   finally
      parts.Free;
   end;
end;

end.
