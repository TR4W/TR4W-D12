unit uTestCaptionText;

(* uCaptionText.DisplayedText: the text a caption PAINTS. '&&' is the case the
   hand-written stripper it replaced in uQTCSendForm got wrong -- it removed
   both ampersands, so a literal one measured as nothing. The '(&X)' cases are
   the Japanese and Korean catalogues' form. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCaptionTextTests = class(TTestCase)
   protected
      procedure TestHotkeyMarkers;
      procedure TestSuffixGroups;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Controls,       (* TCaption *)
   uCaptionText;

(* A UTF-16 literal as the LCL's caption type, converted explicitly. *)
function AsCaption(const s: string): TCaption;
begin
   Result := TCaption(s);
end;

procedure TCaptionTextTests.TestHotkeyMarkers;
begin
   BeginTest('TestHotkeyMarkers');
   CheckEquals('File', string(DisplayedText('&File')), 'a lone marker is removed');
   CheckEquals('Exit', string(DisplayedText('E&xit')), 'wherever it is');
   CheckEquals('Q&A', string(DisplayedText('Q&&A')), '&& paints one &');
   CheckEquals('A&B', string(DisplayedText('A&&&B')), 'the pair, then a marker');
   CheckEquals('&', string(DisplayedText('&&')), '&& alone');
   CheckEquals('Save', string(DisplayedText('Save&')), 'a trailing lone & paints nothing');
   CheckEquals('NEXT [return]', string(DisplayedText('N&EXT [return]')),
               'a QTC button caption measures as before');
   CheckEquals('Beacons monitor', string(DisplayedText('Beacons monitor')),
               'a caption with no markup is unchanged');
   CheckEquals('', string(DisplayedText('')), 'empty');
end;

(* '(&S)' is markup, so a title built from '<save>(&S)...' reads '<save>...',
   not '<save>(S)...'. *)
procedure TCaptionTextTests.TestSuffixGroups;
begin
   BeginTest('TestSuffixGroups');
   CheckEquals(#$4FDD#$5B58 + '...',
               string(DisplayedText(AsCaption(#$4FDD#$5B58 + '(&S)...'))),
               'a CJK (&X) group is dropped, the ellipsis stays');
   CheckEquals(#$4FDD#$5B58,
               string(DisplayedText(AsCaption(#$4FDD#$5B58 + #$FF08 + '&S' + #$FF09))),
               'fullwidth parentheses too');
   CheckEquals('Text', string(DisplayedText('Text (&B)')),
               'with the space before it');
   CheckEquals('Q (&X)', string(DisplayedText('Q (&&X)')),
               '(&&X) is literal text and stays');
end;

procedure TCaptionTextTests.RunAllTests;
begin
   TestHotkeyMarkers;
   TestSuffixGroups;
end;

end.
