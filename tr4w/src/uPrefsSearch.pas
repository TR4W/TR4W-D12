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
unit uPrefsSearch;
{$I tr4w.inc}

{
  RANKING FOR THE PREFERENCES SEARCH BOX -- and nothing else.

  Preferences has 27 sections and opens collapsed, deliberately: "an operator
  looking for one setting should not be handed 27 lines". Search is the other
  half of that bargain.

  WHY THIS IS ITS OWN UNIT, with no LCL in it.  The ranking is the only part of
  search with a right and a wrong answer, and it is the part a user notices when
  it is wrong -- typing 'far' and not getting FARNSWORTH is a bug you can only
  find by trying it, unless it is testable. Keeping it free of TControl means the
  unit-test executable can link it without dragging a UI framework in, which is
  the same rule that keeps uSettingsDeclarations testable.

  The form does the enumerating, the sorting and the jumping. This unit answers
  one question: how well does this setting match what the operator typed.

  MATCHING BOTH NAMES IS THE POINT, not a nicety. An operator who has typed
  'SAY HI ENABLE' into Ctrl-J for fifteen years will type it here, and the
  Preferences caption reads 'Send a greeting'. Every migrated setting is a row
  that LEFT Ctrl-J, so without the legacy name in the index the migration
  silently invalidates the vocabulary of every long-time user.

  MULTI-TOKEN AND ALL TOKENS MUST MATCH.  'cw far' finds FARNSWORTH ENABLE
  because both tokens appear across the caption and the command. Tokens are ANDed
  rather than ORed: an operator adding a word is narrowing, exactly as the
  Windows Settings box does -- 'en' then 'env'.
}

interface

const
   { Scores, highest first. Exposed so a test can assert ORDER by name rather
     than by magic number, and so the form can show a separator between strong
     and weak matches if it ever wants to. }
   PREFS_MATCH_NONE          = 0;
   PREFS_MATCH_COMMAND_PART  = 10;   // 'zero' in LEADING ZERO CHARACTER
   PREFS_MATCH_CAPTION_PART  = 20;   // 'greet' in 'Send a greeting'
   PREFS_MATCH_COMMAND_WORD  = 30;   // a word in the command starts with it
   PREFS_MATCH_CAPTION_WORD  = 40;   // a word in the caption starts with it
   PREFS_MATCH_COMMAND_START = 50;   // 'say hi' -> SAY HI ENABLE
   PREFS_MATCH_CAPTION_START = 60;   // 'send' -> 'Send a greeting'
   PREFS_MATCH_EXACT         = 100;  // the whole caption or command

{ How well does one setting match what was typed?

  PREFS_MATCH_NONE means "do not show it". Anything higher sorts descending, and
  the caller breaks ties however it likes -- by caption, so the list is stable
  while the operator keeps typing rather than reshuffling under the cursor.

  aNeedle is matched case-insensitively and may hold several space-separated
  tokens, ALL of which must match something. An empty needle matches nothing:
  the results list stays shut until there is something to search for. }
function PrefsMatchScore(const aCaption, aCommand, aNeedle: string): integer;

implementation

uses
   SysUtils;

{ Does aHay contain aNeedle at the start of any WORD?  'zero' matches
  'LEADING ZERO CHARACTER' at word 2. Cheaper and more predictable than fuzzy
  matching, and it is what makes a partial word feel like it worked. }
function StartsAWord(const aHay, aNeedle: string): boolean;
var
   i: integer;
   atStart: boolean;
begin
   Result := False;
   if (aNeedle = '') or (Length(aNeedle) > Length(aHay)) then
      begin
      Exit;
      end;

   for i := 1 to Length(aHay) - Length(aNeedle) + 1 do
      begin
      atStart := (i = 1) or (aHay[i - 1] = ' ') or (aHay[i - 1] = '-');
      if atStart and (Copy(aHay, i, Length(aNeedle)) = aNeedle) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

{ The score for ONE token. Zero means this token matched nothing, which kills
  the whole match -- see PrefsMatchScore. }
function TokenScore(const aCaption, aCommand, aToken: string): integer;
begin
   if (aCaption = aToken) or (aCommand = aToken) then
      begin
      Result := PREFS_MATCH_EXACT;
      end
   else if Copy(aCaption, 1, Length(aToken)) = aToken then
      begin
      Result := PREFS_MATCH_CAPTION_START;
      end
   else if Copy(aCommand, 1, Length(aToken)) = aToken then
      begin
      Result := PREFS_MATCH_COMMAND_START;
      end
   else if StartsAWord(aCaption, aToken) then
      begin
      Result := PREFS_MATCH_CAPTION_WORD;
      end
   else if StartsAWord(aCommand, aToken) then
      begin
      Result := PREFS_MATCH_COMMAND_WORD;
      end
   else if Pos(aToken, aCaption) > 0 then
      begin
      Result := PREFS_MATCH_CAPTION_PART;
      end
   else if Pos(aToken, aCommand) > 0 then
      begin
      Result := PREFS_MATCH_COMMAND_PART;
      end
   else
      begin
      Result := PREFS_MATCH_NONE;
      end;
end;

function PrefsMatchScore(const aCaption, aCommand, aNeedle: string): integer;
var
   cap, cmd, needle, token: string;
   sp, score, best: integer;
   any: boolean;
begin
   Result := PREFS_MATCH_NONE;

   needle := Trim(UpperCase(aNeedle));
   if needle = '' then
      begin
      Exit;
      end;

   cap := UpperCase(aCaption);
   cmd := UpperCase(aCommand);

   // THE WHOLE NEEDLE AS ONE PHRASE, FIRST. 'SAY HI ENABLE' is three tokens,
   // and scoring it token-by-token would rank it below a row that merely
   // contains all three words somewhere -- so typing a setting's full name
   // would NOT put it at the top, which is the one case a search box must get
   // right. A contiguous phrase scores at least as well as its tokens do.
   Result := TokenScore(cap, cmd, needle);
   if Result = PREFS_MATCH_EXACT then
      begin
      Exit;
      end;

   // THE WEAKEST TOKEN DECIDES.  Scoring by the best token would let one strong
   // hit carry a row whose other token matched nothing anywhere -- 'cw zzz'
   // would still return every CW setting, which reads as a broken search rather
   // than an empty result.
   best := PREFS_MATCH_EXACT + 1;
   any  := False;

   while needle <> '' do
      begin
      sp := Pos(' ', needle);
      if sp = 0 then
         begin
         token  := needle;
         needle := '';
         end
      else
         begin
         token  := Copy(needle, 1, sp - 1);
         needle := Trim(Copy(needle, sp + 1, Length(needle)));
         end;

      if token = '' then
         begin
         Continue;
         end;

      score := TokenScore(cap, cmd, token);
      if score = PREFS_MATCH_NONE then
         begin
         // One token matched nothing: the row is out, even if the phrase pass
         // above scored it. 'farnsworth zzz' must return nothing.
         Result := PREFS_MATCH_NONE;
         Exit;
         end;

      any := True;
      if score < best then
         begin
         best := score;
         end;
      end;

   // The better of the two readings: a phrase hit, or the weakest of the tokens.
   // Never worse than the phrase pass already found, so adding a word can narrow
   // the list but cannot demote a row that still contains the phrase.
   if any and (best > Result) then
      begin
      Result := best;
      end;
end;

end.
