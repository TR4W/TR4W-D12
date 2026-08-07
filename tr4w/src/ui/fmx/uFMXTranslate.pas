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
unit uFMXTranslate;

{
  Translates a designed FMX form by WALKING IT, with fall-through.

  THE PROBLEM THIS SOLVES.  TR4W ships nine language builds, so a caption cannot
  simply be typed into the Object Inspector and left there -- and the first
  answer to that was a hand-written ApplyCaptions per form, reassigning every
  string from a constant.  That worked, but it made the designer a liar: a
  caption typed there looked right and was silently overwritten at run time,
  which is exactly the surprise NY4I hit on the Preferences nav list
  (2026-08-06).

  THE RULE HERE IS FALL-THROUGH.  A control whose key is absent from the table
  KEEPS THE TEXT IT WAS DESIGNED WITH.  So:

    - the English build is fully WYSIWYG -- what you type in the designer is
      what ships, and there is no code to keep in step;
    - a non-English build overrides only the keys it supplies;
    - a control added in the designer needs NO code change to appear correctly
      in English, and needs a table entry only when it is translated.

  This is the shape GNU gettext for Delphi (dxgettext) uses, and it replaces
  ApplyCaptions on every form rather than adding a method to each.

  WHAT IT DOES NOT DO.  Text that changes at RUN TIME is not its business --
  'Searching...' on the Discover button, the active profile name, '(none)' in a
  combo.  Those are assigned from constants at the point of use and must stay
  that way; a walk of the form can only ever set what a control starts as.

  WHY OWNER-BASED AND NOT RECURSIVE.  Every control on these forms is owned by
  the form (a prerequisite of the designed-form conversion), so one pass over
  Components reaches every control at every nesting depth, including items
  streamed into a list.  Controls created at RUN TIME are owned by their parent
  list, not the form -- so they are correctly skipped, because their text came
  from code in the first place.

  HOW A LANGUAGE SUPPLIES STRINGS.  Assign FMXTranslateLookup once at startup.
  It is deliberately a plain hook rather than a table format invented in
  advance: when the i18n lift happens it can be backed by whatever the rest of
  the program settles on (resourcestring, an .ini, the src/lang units) without
  changing a single form.  Unassigned -- which is the state today -- every form
  keeps its designed text.
}

interface

uses
   System.Classes,
   System.SysUtils;

type
   // Given 'PrefsForm.lblMyRadios', return the translated text, or '' to leave
   // the designed text alone.  '' means "no translation", NOT "blank caption":
   // a form must never be able to lose a caption by supplying an empty string.
   TFMXTranslateLookup = function(const aKey: string): string;

var
   FMXTranslateLookup: TFMXTranslateLookup = nil;

// Walks aRoot and every component it owns, translating what it can.  Safe to
// call when no lookup is assigned: it returns immediately.
procedure TranslateForm(const aRoot: TComponent);

// The key a control is looked up by: '<RootName>.<ComponentName>', or just
// '<RootName>' for the form itself.  Exposed so a translator can generate the
// key list from the .fmx files without guessing the convention.
function TranslationKey(const aRoot, aComponent: TComponent): string;

implementation

uses
   System.TypInfo,
   MainUnit;   // logger

function TranslationKey(const aRoot, aComponent: TComponent): string;
begin
   if (aComponent = nil) or (aComponent = aRoot) then
      begin
      Result := aRoot.Name;
      end
   else
      begin
      Result := aRoot.Name + '.' + aComponent.Name;
      end;
end;

// Sets whichever of Text or Caption the control actually publishes.  FMX spells
// it Text on controls and Caption on the form, and there is no common ancestor
// declaring either -- so this is asked of the RTTI rather than guessed from the
// class.  Returns False when the control publishes neither, which is worth
// reporting: it means a table key exists for something that cannot display it.
function TrySetText(const aObject: TObject; const aValue: string): boolean;
const
   TEXT_KINDS = [tkString, tkLString, tkWString, tkUString];
var
   info: PPropInfo;
begin
   info := GetPropInfo(aObject, 'Text', TEXT_KINDS);
   if info = nil then
      begin
      info := GetPropInfo(aObject, 'Caption', TEXT_KINDS);
      end;

   Result := (info <> nil);
   if Result then
      begin
      SetStrProp(aObject, info, aValue);
      end;
end;

procedure TranslateOne(const aRoot: TComponent; const aComponent: TComponent);
var
   key: string;
   translated: string;
begin
   // An unnamed component cannot be keyed, and therefore cannot be translated.
   // That is not an error: it is how a control opts out.
   if aComponent.Name = '' then
      begin
      Exit;
      end;

   key := TranslationKey(aRoot, aComponent);
   translated := FMXTranslateLookup(key);
   if translated = '' then
      begin
      // FALL-THROUGH: keep the designed text.  This is the common case and the
      // whole point -- see the unit header.
      Exit;
      end;

   if not TrySetText(aComponent, translated) then
      begin
      // Reported rather than swallowed: a key that names a control with no Text
      // or Caption is a mistake in the table, and silence would leave the
      // translator believing the string had been used.
      logger.Warn('[Translate] "%s" has no Text or Caption property; ' +
                  'translation ignored', [key]);
      end;
end;

procedure TranslateForm(const aRoot: TComponent);
var
   i: integer;
begin
   if (aRoot = nil) or (not Assigned(FMXTranslateLookup)) then
      begin
      Exit;
      end;

   // The form's own Caption first, then everything it owns -- which is every
   // control on it, at every depth.  See the unit header on why ownership is
   // the right axis here.
   TranslateOne(aRoot, aRoot);
   for i := 0 to aRoot.ComponentCount - 1 do
      begin
      TranslateOne(aRoot, aRoot.Components[i]);
      end;
end;

end.
