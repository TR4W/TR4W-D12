# Preferences keyboard/navigation capture index

November 11, 2026; staged Windows TR4W 5.0.37; GUI-TEST console session at 1280 × 800 / 96 DPI. These are captured runtime page tags, not a designer-derived expected inventory. Open a screenshot to read the selected page and its visible controls.

All 47 observed focus cycles returned within the bound and reversed correctly. This does not certify semantic order, every conditional state, or missing hover help. See [results and issues](GUI_DOCUMENTATION_TEST_REPORT.md) and existing [Tab-order issue #151](https://github.com/TR4W/TR4W-D12/issues/151). The focus count includes the navigation/search and available footer controls as encountered in that page state.

| Runtime tag | App report | Forward focus steps | Reverse matches | Hidden/disabled focused | Screenshot |
| --- | --- | --- | --- | --- | --- |
| 1 | panel | 21 | Yes | 0 | [Open](gui-test/preferences/preferences-1.png) |
| 2 | panel | 6 | Yes | 0 | [Open](gui-test/preferences/preferences-2.png) |
| 26 | panel | 22 | Yes | 0 | [Open](gui-test/preferences/preferences-26.png) |
| 27 | panel | 7 | Yes | 0 | [Open](gui-test/preferences/preferences-27.png) |
| 48 | panel | 9 | Yes | 0 | [Open](gui-test/preferences/preferences-48.png) |
| 3 | panel | 7 | Yes | 0 | [Open](gui-test/preferences/preferences-3.png) |
| 39 | panel | 9 | Yes | 0 | [Open](gui-test/preferences/preferences-39.png) |
| 21 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-21.png) |
| 20 | panel | 19 | Yes | 0 | [Open](gui-test/preferences/preferences-20.png) |
| 38 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-38.png) |
| 24 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-24.png) |
| 35 | panel | 17 | Yes | 0 | [Open](gui-test/preferences/preferences-35.png) |
| 32 | panel | 5 | Yes | 0 | [Open](gui-test/preferences/preferences-32.png) |
| 22 | panel | 16 | Yes | 0 | [Open](gui-test/preferences/preferences-22.png) |
| 25 | panel | 14 | Yes | 0 | [Open](gui-test/preferences/preferences-25.png) |
| 4 | panel | 14 | Yes | 0 | [Open](gui-test/preferences/preferences-4.png) |
| 5 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-5.png) |
| 6 | panel | 19 | Yes | 0 | [Open](gui-test/preferences/preferences-6.png) |
| 7 | panel | 14 | Yes | 0 | [Open](gui-test/preferences/preferences-7.png) |
| 31 | panel | 5 | Yes | 0 | [Open](gui-test/preferences/preferences-31.png) |
| 36 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-36.png) |
| 8 | panel | 14 | Yes | 0 | [Open](gui-test/preferences/preferences-8.png) |
| 9 | panel | 7 | Yes | 0 | [Open](gui-test/preferences/preferences-9.png) |
| 10 | panel | 16 | Yes | 0 | [Open](gui-test/preferences/preferences-10.png) |
| 41 | panel | 5 | Yes | 0 | [Open](gui-test/preferences/preferences-41.png) |
| 43 | panel | 6 | Yes | 0 | [Open](gui-test/preferences/preferences-43.png) |
| 44 | panel | 14 | Yes | 0 | [Open](gui-test/preferences/preferences-44.png) |
| 45 | panel | 9 | Yes | 0 | [Open](gui-test/preferences/preferences-45.png) |
| 42 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-42.png) |
| 40 | panel | 8 | Yes | 0 | [Open](gui-test/preferences/preferences-40.png) |
| 47 | panel | 10 | Yes | 0 | [Open](gui-test/preferences/preferences-47.png) |
| 46 | panel | 11 | Yes | 0 | [Open](gui-test/preferences/preferences-46.png) |
| 34 | panel | 6 | Yes | 0 | [Open](gui-test/preferences/preferences-34.png) |
| 37 | panel | 7 | Yes | 0 | [Open](gui-test/preferences/preferences-37.png) |
| 29 | panel | 15 | Yes | 0 | [Open](gui-test/preferences/preferences-29.png) |
| 11 | panel | 12 | Yes | 0 | [Open](gui-test/preferences/preferences-11.png) |
| 28 | panel | 13 | Yes | 0 | [Open](gui-test/preferences/preferences-28.png) |
| 23 | panel | 13 | Yes | 0 | [Open](gui-test/preferences/preferences-23.png) |
| 33 | panel | 15 | Yes | 0 | [Open](gui-test/preferences/preferences-33.png) |
| 12 | placeholder | 4 | Yes | 0 | [Open](gui-test/preferences/preferences-12.png) |
| 15 | panel | 8 | Yes | 0 | [Open](gui-test/preferences/preferences-15.png) |
| 13 | placeholder | 8 | Yes | 0 | [Open](gui-test/preferences/preferences-13.png) |
| 16 | panel | 9 | Yes | 0 | [Open](gui-test/preferences/preferences-16.png) |
| 17 | panel | 6 | Yes | 0 | [Open](gui-test/preferences/preferences-17.png) |
| 18 | panel | 5 | Yes | 0 | [Open](gui-test/preferences/preferences-18.png) |
| 19 | panel | 6 | Yes | 0 | [Open](gui-test/preferences/preferences-19.png) |
| 14 | panel | 7 | Yes | 0 | [Open](gui-test/preferences/preferences-14.png) |

The Web Server leaf (tag 12) is the reported empty task route (#279). The External Software parent (tag 13) reports placeholder internally but displays child-navigation buttons; it is not another empty leaf. The rest report a panel, which alone does not prove their content is complete.
