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
unit uPendingCounties;
{$I tr4w.inc}

{
  Pending county queue for state-QP exchanges.

  When the operator's exchange names more than one county for the same QSO --
  either slash-separated ("DAL/BAY") or space-separated ("DAL BAY") -- the
  parser in LOGSTUFF.PAS (ProcessRSTAndDomesticQTHExchange) keeps the first
  valid county in RXData.QTHString for the QSO it is currently building, and
  pushes any additional valid counties onto this queue.

  TryLogContact then drains the queue inline immediately after writing the
  first QSO -- one extra LogContact per queued county.  No extra Enter press,
  no PostMessage, no window refill.  The queue is rebuilt on every call to
  the parser, so it always reflects the current exchange field content.

  Issue #885 -- county-line bridging support.
}

interface

uses
  Classes;

// Push a county abbreviation onto the end of the queue.
procedure QueuePendingCounty(const ACounty: string);

// Remove and return the first county from the queue.
// Returns '' when the queue is empty.
function DequeuePendingCounty: string;

// True when at least one county is waiting in the queue.
function HasPendingCounties: Boolean;

// Number of counties currently in the queue.
function PendingCountiesCount: Integer;

// Discard all queued counties.  Called by the parser at the start of every
// exchange parse so the queue always reflects the current entry.
procedure ClearPendingCounties;

implementation

var
  // Ordered FIFO of remaining county abbreviations (in user-typed order).
  // Lazily allocated.
  FPendingCounties : TStringList = nil;

procedure QueuePendingCounty(const ACounty: string);
begin
  if not Assigned(FPendingCounties) then
    FPendingCounties := TStringList.Create;
  FPendingCounties.Add(ACounty);
end;

function DequeuePendingCounty: string;
begin
  if not Assigned(FPendingCounties) or (FPendingCounties.Count = 0) then
    begin
    Result := '';
    Exit;
    end;
  Result := FPendingCounties[0];
  FPendingCounties.Delete(0);
end;

function HasPendingCounties: Boolean;
begin
  Result := Assigned(FPendingCounties) and (FPendingCounties.Count > 0);
end;

function PendingCountiesCount: Integer;
begin
  if Assigned(FPendingCounties) then
    Result := FPendingCounties.Count
  else
    Result := 0;
end;

procedure ClearPendingCounties;
begin
  if Assigned(FPendingCounties) then
    FPendingCounties.Clear;
end;

initialization
  FPendingCounties := nil;

finalization
  if Assigned(FPendingCounties) then
    begin
    FPendingCounties.Free;
    FPendingCounties := nil;
    end;

end.
