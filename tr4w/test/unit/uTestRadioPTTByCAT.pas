unit uTestRadioPTTByCAT;
{$I ..\..\src\tr4w.inc}

(*
  Issue 36: what is known about keying each radio with a CAT command.

  THREE STATES, because "not listed" is not "lacks" (NY4I: "Agree with
  recommend").  The source is the wiki page "TR4W Feature to Radio Feature
  Matrix": its "PTT by CAT" column says Yes (pbcConfirmed) or No
  (pbcKnownAbsent); a blank, or a radio the page does not list, is
  pbcNotConfirmed.

  THE WALK IS EXHAUSTIVE, ON PURPOSE.  Every registered radio, on every link it
  claims, must appear in EXACTLY ONE of the three lists below and declare
  exactly that state.  So:
    - a new radio fails here by name until someone classifies it -- even when
      it would default to "not confirmed", because the point is that the
      choice is made consciously;
    - a radio that changes state without the matrix changing fails here;
    - a list entry that matches no registered radio fails here (a stale pin).

  The knowledge is a FIELD, not a Flags member, so a DefineCapabilities that
  assigns Flags wholesale cannot wipe it -- the IC-718 does exactly that
  (Flags := []) and must still read "known absent".

  Changing a list here is changing what the program tells an operator about
  a real radio: do it from the matrix (or a bench), not to make this pass.
*)

interface

uses
   SysUtils, Classes, uTR4WTestFramework, uFactoryRadioBase, uRadioRegistry;

type
   TRadioPTTByCATTests = class(TTestCase)
   protected
      procedure Test_EveryRegisteredRadioIsClassified;
      procedure Test_ReportDecision;
      procedure Test_KnowledgeText;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* The registry's display names, '|'-separated.  Strings rather than fixed
     arrays so a miscount is a test failure with a name, never a compile
     error. *)

   // "PTT by CAT" = Yes in the matrix.
   PTT_CONFIRMED =
      '|Elecraft K4|Elecraft K3|Elecraft KX3' +
      '|Icom IC-9700|Icom IC-7610|Icom IC-7300|Icom IC-7851|Icom IC-7850' +
      '|Icom IC-7100|Icom IC-9100|Icom IC-7000|Icom IC-7200|Icom IC-7600' +
      '|Icom IC-7700|Icom IC-756|Icom IC-756PRO|Icom IC-756PROII' +
      '|Icom IC-756PROIII|Icom IC-7800' +
      '|Kenwood TS-590|';

   // "PTT by CAT" = No in the matrix.
   PTT_KNOWN_ABSENT =
      '|Icom IC-746|Icom IC-718|';

   // Blank in the matrix, or not listed there.  NOT "cannot".
   PTT_NOT_CONFIRMED =
      '|Elecraft K2' +
      '|Icom IC-705|Icom IC-706|Icom IC-706MkII|Icom IC-706MkIIG|Icom IC-707' +
      '|Icom IC-725|Icom IC-726|Icom IC-728|Icom IC-729|Icom IC-7300MK2' +
      '|Icom IC-735|Icom IC-736|Icom IC-737|Icom IC-738|Icom IC-7410' +
      '|Icom IC-746PRO|Icom IC-761|Icom IC-765|Icom IC-775|Icom IC-7760' +
      '|Icom IC-78|Icom IC-781|Icom IC-905|Icom IC-910|Icom IC-970D' +
      '|Icom IC-7110' +
      '|Kenwood TS-140|Kenwood TS-2000|Kenwood TS-440|Kenwood TS-450' +
      '|Kenwood TS-480|Kenwood TS-570|Kenwood TS-690|Kenwood TS-850' +
      '|Kenwood TS-870|Kenwood TS-890S|Kenwood TS-940|Kenwood TS-950' +
      '|Kenwood TS-990S' +
      '|Ten-Tec Omni VI (CI-V)|Ten-Tec Orion' +
      '|Yaesu FT-100|Yaesu FT-1000|Yaesu FT-1000MP|Yaesu FT-1200' +
      '|Yaesu FT-2000|Yaesu FT-450|Yaesu FT-710|Yaesu FT-747GX|Yaesu FT-767' +
      '|Yaesu FT-817|Yaesu FT-818|Yaesu FT-840|Yaesu FT-847|Yaesu FT-857' +
      '|Yaesu FT-890|Yaesu FT-891|Yaesu FT-897|Yaesu FT-900|Yaesu FT-920' +
      '|Yaesu FT-950|Yaesu FT-990|Yaesu FT-991|Yaesu FTDX-10|Yaesu FTDX-101' +
      '|Yaesu FTDX-3000|Yaesu FTDX-5000|Yaesu FTDX-9000|Yaesu FTX-1F' +
      '|Flex 6000+|TCI (ExpertSDR / Thetis / AetherSDR)|DXLab Commander' +
      // HamLib-only entries (uRadioHamLibOnly): the driver is the generic
      // THamLibDirect, which knows nothing about the rig behind it.
      '|FLRig (HamLib bridge)|TRX-Manager (HamLib bridge)' +
      '|Expert TCI (HamLib bridge)|N3FJP ACLog (HamLib bridge)' +
      '|HamLib (any supported rig)|Yaesu FT-736R (via HamLib)' +
      '|Yaesu FT-757GXII (via HamLib)|';

function InList(const aList, aName: string): boolean;
begin
   Result := Pos('|' + aName + '|', aList) > 0;
end;

(* Every name in a '|'-list that is not in aSeen, as one readable string. *)
function UnseenNames(const aList: string; aSeen: TStringList): string;
var
   names: TStringList;
   i: integer;
begin
   Result := '';
   names := TStringList.Create;
   try
      names.StrictDelimiter := True;
      names.Delimiter := '|';
      names.DelimitedText := aList;
      for i := 0 to names.Count - 1 do
         begin
         if (names[i] <> '') and (aSeen.IndexOf(names[i]) < 0) then
            begin
            Result := Result + names[i] + '; ';
            end;
         end;
   finally
      names.Free;
   end;
end;

(* THE REGISTRY WALK, every id on every link it claims -- the Flex has two
  constructors, so CreateInstanceId alone would build only one of them. *)
procedure TRadioPTTByCATTests.Test_EveryRegisteredRadioIsClassified;
var
   ids: TArray<string>;
   id: string;
   link: TRadioLink;
   r: TFactoryRadioBase;
   radioName: string;
   expected: TPTTByCATKnowledge;
   listed: integer;
   unclassified: string;
   ambiguous: string;
   wrong: string;
   seen: TStringList;
   checked: integer;
begin
   BeginTest('Registry: every radio on every link is classified for PTT by CAT, exactly as the feature matrix says');
   unclassified := '';
   ambiguous := '';
   wrong := '';
   checked := 0;
   seen := TStringList.Create;
   try
      ids := uRadioRegistry.RegisteredIds;
      for id in ids do
         begin
         for link := Low(TRadioLink) to High(TRadioLink) do
            begin
            if ((link = rlSerial) and not uRadioRegistry.SupportsSerialId(id)) or
               ((link = rlNetwork) and not uRadioRegistry.SupportsNetworkId(id)) then
               begin
               Continue;
               end;
            r := uRadioRegistry.CreateInstanceForLinkId(id, link);
            if r = nil then
               begin
               Continue;
               end;
            try
               Inc(checked);
               radioName := uRadioRegistry.DisplayNameId(id);
               if seen.IndexOf(radioName) < 0 then
                  begin
                  seen.Add(radioName);
                  end;

               listed := 0;
               expected := pbcNotConfirmed;
               if InList(PTT_CONFIRMED, radioName) then
                  begin
                  Inc(listed);
                  expected := pbcConfirmed;
                  end;
               if InList(PTT_KNOWN_ABSENT, radioName) then
                  begin
                  Inc(listed);
                  expected := pbcKnownAbsent;
                  end;
               if InList(PTT_NOT_CONFIRMED, radioName) then
                  begin
                  Inc(listed);
                  expected := pbcNotConfirmed;
                  end;

               if listed = 0 then
                  begin
                  unclassified := unclassified + radioName +'; ';
                  end
               else if listed > 1 then
                  begin
                  ambiguous := ambiguous + radioName +'; ';
                  end
               else if r.Capabilities.PTTByCAT <> expected then
                  begin
                  wrong := wrong + radioName +' declares ' +
                           PTTByCATKnowledgeText(r.Capabilities.PTTByCAT) +
                           ', expected ' + PTTByCATKnowledgeText(expected) + '; ';
                  end;
            finally
               r.Free;
            end;
            end;
         end;

      CheckTrue(checked > 0, 'the registry produced no radios to check');
      CheckEquals('', unclassified,
                  'every registered radio must be classified for PTT by CAT -- add it to ONE list ' +
                  '(confirmed / known absent / not confirmed) from the feature matrix');
      CheckEquals('', ambiguous, 'a radio may appear in only one list');
      CheckEquals('', wrong, 'a radio declares a different PTT-by-CAT state than the matrix');
      CheckEquals('', UnseenNames(PTT_CONFIRMED, seen) +
                      UnseenNames(PTT_KNOWN_ABSENT, seen) +
                      UnseenNames(PTT_NOT_CONFIRMED, seen),
                  'a pinned name matches no registered radio -- a stale pin or a renamed radio');
   finally
      seen.Free;
   end;
end;

procedure TRadioPTTByCATTests.Test_ReportDecision;
begin
   BeginTest('PTTByCATReportFor: off says nothing; not confirmed logs; known absent notifies; confirmed says nothing');
   CheckTrue(PTTByCATReportFor(pbcNotConfirmed, False) = pbrNothing,
             'setting off: nothing, whatever the radio');
   CheckTrue(PTTByCATReportFor(pbcKnownAbsent, False) = pbrNothing,
             'setting off: nothing even for a radio known to lack it');
   CheckTrue(PTTByCATReportFor(pbcConfirmed, False) = pbrNothing,
             'setting off, confirmed radio: nothing');
   CheckTrue(PTTByCATReportFor(pbcConfirmed, True) = pbrNothing,
             'a confirmed radio is never reported');
   CheckTrue(PTTByCATReportFor(pbcNotConfirmed, True) = pbrLogOnly,
             'not confirmed: one log line, no notice -- "not listed" is not "lacks"');
   CheckTrue(PTTByCATReportFor(pbcKnownAbsent, True) = pbrNotice,
             'known absent: the operator is told');
end;

procedure TRadioPTTByCATTests.Test_KnowledgeText;
begin
   BeginTest('PTTByCATKnowledgeText names all three states');
   CheckEquals('not confirmed', PTTByCATKnowledgeText(pbcNotConfirmed), 'default state');
   CheckEquals('confirmed', PTTByCATKnowledgeText(pbcConfirmed), 'confirmed');
   CheckEquals('known absent', PTTByCATKnowledgeText(pbcKnownAbsent), 'known absent');
   CheckTrue(Ord(pbcNotConfirmed) = 0,
             'not confirmed MUST be ordinal 0: zeroed instance memory has to mean "nobody checked"');
end;

procedure TRadioPTTByCATTests.RunAllTests;
begin
   Test_EveryRegisteredRadioIsClassified;
   Test_ReportDecision;
   Test_KnowledgeText;
end;

end.
