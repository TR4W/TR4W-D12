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

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* CTY.DAT PRIMARY PREFIX -> ADIF DXCC ENTITY CODE. GENERATED -- DO NOT EDIT.

  Regenerate with tools/dxcc/gen_dxcc_entities.py (its header says where the
  numbers come from and what it refuses to write).

  WHY IT EXISTS. CTY.DAT carries no DXCC number, ADIF's DXCC field IS that
  number, and a POTA hunter's country is whatever his callsign says (Q62,
  2026-10-17). The key is ContestExchange.QTH.CountryID -- the entity's
  primary prefix exactly as cty.dat spells it, star included: '*GM/s'
  (Shetland) is ADIF 279, Scotland, the entity DXCC credits it to.

  A PREFIX THIS TABLE DOES NOT KNOW ANSWERS 0 -- an operator's own cty.dat may
  name an entity added after this table was made -- and the caller leaves the
  DXCC tag out rather than guess. PURE: no globals. *)
unit uDXCCEntities;

{$I tr4w.inc}

interface

(* The ADIF DXCC entity code of the CTY entity aCountryID (its primary prefix,
  e.g. 'K' -> 291, 'VE' -> 1), or 0 when the table has no such entity. *)
function ADIFDXCCOfCTYEntity(const aCountryID: string): integer;

(* The table itself, for the test that holds it to the shipped cty.dat. *)
function DXCCEntityCount: integer;
function DXCCEntityPrefixAt(aIndex: integer): string;

implementation

type
   TDXCCEntity = record
      Prefix: string[6];
      Code: integer;
   end;

const
   DXCC_ENTITY_COUNT = 346;

   DXCC_ENTITIES: array[0 .. DXCC_ENTITY_COUNT - 1] of TDXCCEntity = (
      (Prefix: '*4U1V'; Code: 206),
      (Prefix: '*GM/s'; Code: 279),
      (Prefix: '*IG9'; Code: 248),
      (Prefix: '*IT9'; Code: 248),
      (Prefix: '*JW/b'; Code: 259),
      (Prefix: '*TA1'; Code: 390),
      (Prefix: '1A'; Code: 246),
      (Prefix: '1S'; Code: 247),
      (Prefix: '3A'; Code: 260),
      (Prefix: '3B6'; Code: 4),
      (Prefix: '3B8'; Code: 165),
      (Prefix: '3B9'; Code: 207),
      (Prefix: '3C'; Code: 49),
      (Prefix: '3C0'; Code: 195),
      (Prefix: '3D2'; Code: 176),
      (Prefix: '3D2/c'; Code: 489),
      (Prefix: '3D2/r'; Code: 460),
      (Prefix: '3DA'; Code: 468),
      (Prefix: '3V'; Code: 474),
      (Prefix: '3W'; Code: 293),
      (Prefix: '3X'; Code: 107),
      (Prefix: '3Y/b'; Code: 24),
      (Prefix: '3Y/p'; Code: 199),
      (Prefix: '4J'; Code: 18),
      (Prefix: '4L'; Code: 75),
      (Prefix: '4O'; Code: 514),
      (Prefix: '4S'; Code: 315),
      (Prefix: '4U1I'; Code: 117),
      (Prefix: '4U1U'; Code: 289),
      (Prefix: '4W'; Code: 511),
      (Prefix: '4X'; Code: 336),
      (Prefix: '5A'; Code: 436),
      (Prefix: '5B'; Code: 215),
      (Prefix: '5H'; Code: 470),
      (Prefix: '5N'; Code: 450),
      (Prefix: '5R'; Code: 438),
      (Prefix: '5T'; Code: 444),
      (Prefix: '5U'; Code: 187),
      (Prefix: '5V'; Code: 483),
      (Prefix: '5W'; Code: 190),
      (Prefix: '5X'; Code: 286),
      (Prefix: '5Z'; Code: 430),
      (Prefix: '6W'; Code: 456),
      (Prefix: '6Y'; Code: 82),
      (Prefix: '7O'; Code: 492),
      (Prefix: '7P'; Code: 432),
      (Prefix: '7Q'; Code: 440),
      (Prefix: '7X'; Code: 400),
      (Prefix: '8P'; Code: 62),
      (Prefix: '8Q'; Code: 159),
      (Prefix: '8R'; Code: 129),
      (Prefix: '9A'; Code: 497),
      (Prefix: '9G'; Code: 424),
      (Prefix: '9H'; Code: 257),
      (Prefix: '9J'; Code: 482),
      (Prefix: '9K'; Code: 348),
      (Prefix: '9L'; Code: 458),
      (Prefix: '9M2'; Code: 299),
      (Prefix: '9M6'; Code: 46),
      (Prefix: '9N'; Code: 369),
      (Prefix: '9Q'; Code: 414),
      (Prefix: '9U'; Code: 404),
      (Prefix: '9V'; Code: 381),
      (Prefix: '9X'; Code: 454),
      (Prefix: '9Y'; Code: 90),
      (Prefix: 'A2'; Code: 402),
      (Prefix: 'A3'; Code: 160),
      (Prefix: 'A4'; Code: 370),
      (Prefix: 'A5'; Code: 306),
      (Prefix: 'A6'; Code: 391),
      (Prefix: 'A7'; Code: 376),
      (Prefix: 'A9'; Code: 304),
      (Prefix: 'AP'; Code: 372),
      (Prefix: 'BS7'; Code: 506),
      (Prefix: 'BV'; Code: 386),
      (Prefix: 'BV9P'; Code: 505),
      (Prefix: 'BY'; Code: 318),
      (Prefix: 'C2'; Code: 157),
      (Prefix: 'C3'; Code: 203),
      (Prefix: 'C5'; Code: 422),
      (Prefix: 'C6'; Code: 60),
      (Prefix: 'C9'; Code: 181),
      (Prefix: 'CE'; Code: 112),
      (Prefix: 'CE0X'; Code: 217),
      (Prefix: 'CE0Y'; Code: 47),
      (Prefix: 'CE0Z'; Code: 125),
      (Prefix: 'CE9'; Code: 13),
      (Prefix: 'CM'; Code: 70),
      (Prefix: 'CN'; Code: 446),
      (Prefix: 'CP'; Code: 104),
      (Prefix: 'CT'; Code: 272),
      (Prefix: 'CT3'; Code: 256),
      (Prefix: 'CU'; Code: 149),
      (Prefix: 'CX'; Code: 144),
      (Prefix: 'CY0'; Code: 211),
      (Prefix: 'CY9'; Code: 252),
      (Prefix: 'D2'; Code: 401),
      (Prefix: 'D4'; Code: 409),
      (Prefix: 'D6'; Code: 411),
      (Prefix: 'DL'; Code: 230),
      (Prefix: 'DU'; Code: 375),
      (Prefix: 'E3'; Code: 51),
      (Prefix: 'E4'; Code: 510),
      (Prefix: 'E5/n'; Code: 191),
      (Prefix: 'E5/s'; Code: 234),
      (Prefix: 'E6'; Code: 188),
      (Prefix: 'E7'; Code: 501),
      (Prefix: 'EA'; Code: 281),
      (Prefix: 'EA6'; Code: 21),
      (Prefix: 'EA8'; Code: 29),
      (Prefix: 'EA9'; Code: 32),
      (Prefix: 'EI'; Code: 245),
      (Prefix: 'EK'; Code: 14),
      (Prefix: 'EL'; Code: 434),
      (Prefix: 'EP'; Code: 330),
      (Prefix: 'ER'; Code: 179),
      (Prefix: 'ES'; Code: 52),
      (Prefix: 'ET'; Code: 53),
      (Prefix: 'EU'; Code: 27),
      (Prefix: 'EX'; Code: 135),
      (Prefix: 'EY'; Code: 262),
      (Prefix: 'EZ'; Code: 280),
      (Prefix: 'F'; Code: 227),
      (Prefix: 'FG'; Code: 79),
      (Prefix: 'FH'; Code: 169),
      (Prefix: 'FJ'; Code: 516),
      (Prefix: 'FK'; Code: 162),
      (Prefix: 'FK/c'; Code: 512),
      (Prefix: 'FM'; Code: 84),
      (Prefix: 'FO'; Code: 175),
      (Prefix: 'FO/a'; Code: 508),
      (Prefix: 'FO/c'; Code: 36),
      (Prefix: 'FO/m'; Code: 509),
      (Prefix: 'FP'; Code: 277),
      (Prefix: 'FR'; Code: 453),
      (Prefix: 'FS'; Code: 213),
      (Prefix: 'FT/g'; Code: 99),
      (Prefix: 'FT/j'; Code: 124),
      (Prefix: 'FT/t'; Code: 276),
      (Prefix: 'FT/w'; Code: 41),
      (Prefix: 'FT/x'; Code: 131),
      (Prefix: 'FT/z'; Code: 10),
      (Prefix: 'FW'; Code: 298),
      (Prefix: 'FY'; Code: 63),
      (Prefix: 'G'; Code: 223),
      (Prefix: 'GD'; Code: 114),
      (Prefix: 'GI'; Code: 265),
      (Prefix: 'GJ'; Code: 122),
      (Prefix: 'GM'; Code: 279),
      (Prefix: 'GU'; Code: 106),
      (Prefix: 'GW'; Code: 294),
      (Prefix: 'H4'; Code: 185),
      (Prefix: 'H40'; Code: 507),
      (Prefix: 'HA'; Code: 239),
      (Prefix: 'HB'; Code: 287),
      (Prefix: 'HB0'; Code: 251),
      (Prefix: 'HC'; Code: 120),
      (Prefix: 'HC8'; Code: 71),
      (Prefix: 'HH'; Code: 78),
      (Prefix: 'HI'; Code: 72),
      (Prefix: 'HK'; Code: 116),
      (Prefix: 'HK0/a'; Code: 216),
      (Prefix: 'HK0/m'; Code: 161),
      (Prefix: 'HL'; Code: 137),
      (Prefix: 'HP'; Code: 88),
      (Prefix: 'HR'; Code: 80),
      (Prefix: 'HS'; Code: 387),
      (Prefix: 'HV'; Code: 295),
      (Prefix: 'HZ'; Code: 378),
      (Prefix: 'I'; Code: 248),
      (Prefix: 'IS'; Code: 225),
      (Prefix: 'J2'; Code: 382),
      (Prefix: 'J3'; Code: 77),
      (Prefix: 'J5'; Code: 109),
      (Prefix: 'J6'; Code: 97),
      (Prefix: 'J7'; Code: 95),
      (Prefix: 'J8'; Code: 98),
      (Prefix: 'JA'; Code: 339),
      (Prefix: 'JD/m'; Code: 177),
      (Prefix: 'JD/o'; Code: 192),
      (Prefix: 'JT'; Code: 363),
      (Prefix: 'JW'; Code: 259),
      (Prefix: 'JX'; Code: 118),
      (Prefix: 'JY'; Code: 342),
      (Prefix: 'K'; Code: 291),
      (Prefix: 'KG4'; Code: 105),
      (Prefix: 'KH0'; Code: 166),
      (Prefix: 'KH1'; Code: 20),
      (Prefix: 'KH2'; Code: 103),
      (Prefix: 'KH3'; Code: 123),
      (Prefix: 'KH4'; Code: 174),
      (Prefix: 'KH5'; Code: 197),
      (Prefix: 'KH6'; Code: 110),
      (Prefix: 'KH7K'; Code: 138),
      (Prefix: 'KH8'; Code: 9),
      (Prefix: 'KH8/s'; Code: 515),
      (Prefix: 'KH9'; Code: 297),
      (Prefix: 'KL'; Code: 6),
      (Prefix: 'KP1'; Code: 182),
      (Prefix: 'KP2'; Code: 285),
      (Prefix: 'KP4'; Code: 202),
      (Prefix: 'KP5'; Code: 43),
      (Prefix: 'LA'; Code: 266),
      (Prefix: 'LU'; Code: 100),
      (Prefix: 'LX'; Code: 254),
      (Prefix: 'LY'; Code: 146),
      (Prefix: 'LZ'; Code: 212),
      (Prefix: 'OA'; Code: 136),
      (Prefix: 'OD'; Code: 354),
      (Prefix: 'OE'; Code: 206),
      (Prefix: 'OH'; Code: 224),
      (Prefix: 'OH0'; Code: 5),
      (Prefix: 'OJ0'; Code: 167),
      (Prefix: 'OK'; Code: 503),
      (Prefix: 'OM'; Code: 504),
      (Prefix: 'ON'; Code: 209),
      (Prefix: 'OX'; Code: 237),
      (Prefix: 'OY'; Code: 222),
      (Prefix: 'OZ'; Code: 221),
      (Prefix: 'P2'; Code: 163),
      (Prefix: 'P4'; Code: 91),
      (Prefix: 'P5'; Code: 344),
      (Prefix: 'PA'; Code: 263),
      (Prefix: 'PJ2'; Code: 517),
      (Prefix: 'PJ4'; Code: 520),
      (Prefix: 'PJ5'; Code: 519),
      (Prefix: 'PJ7'; Code: 518),
      (Prefix: 'PY'; Code: 108),
      (Prefix: 'PY0F'; Code: 56),
      (Prefix: 'PY0S'; Code: 253),
      (Prefix: 'PY0T'; Code: 273),
      (Prefix: 'PZ'; Code: 140),
      (Prefix: 'R1FJ'; Code: 61),
      (Prefix: 'S0'; Code: 302),
      (Prefix: 'S2'; Code: 305),
      (Prefix: 'S5'; Code: 499),
      (Prefix: 'S7'; Code: 379),
      (Prefix: 'S9'; Code: 219),
      (Prefix: 'SM'; Code: 284),
      (Prefix: 'SP'; Code: 269),
      (Prefix: 'ST'; Code: 466),
      (Prefix: 'SU'; Code: 478),
      (Prefix: 'SV'; Code: 236),
      (Prefix: 'SV/a'; Code: 180),
      (Prefix: 'SV5'; Code: 45),
      (Prefix: 'SV9'; Code: 40),
      (Prefix: 'T2'; Code: 282),
      (Prefix: 'T30'; Code: 301),
      (Prefix: 'T31'; Code: 31),
      (Prefix: 'T32'; Code: 48),
      (Prefix: 'T33'; Code: 490),
      (Prefix: 'T5'; Code: 232),
      (Prefix: 'T7'; Code: 278),
      (Prefix: 'T8'; Code: 22),
      (Prefix: 'TA'; Code: 390),
      (Prefix: 'TF'; Code: 242),
      (Prefix: 'TG'; Code: 76),
      (Prefix: 'TI'; Code: 308),
      (Prefix: 'TI9'; Code: 37),
      (Prefix: 'TJ'; Code: 406),
      (Prefix: 'TK'; Code: 214),
      (Prefix: 'TL'; Code: 408),
      (Prefix: 'TN'; Code: 412),
      (Prefix: 'TR'; Code: 420),
      (Prefix: 'TT'; Code: 410),
      (Prefix: 'TU'; Code: 428),
      (Prefix: 'TY'; Code: 416),
      (Prefix: 'TZ'; Code: 442),
      (Prefix: 'UA'; Code: 54),
      (Prefix: 'UA2'; Code: 126),
      (Prefix: 'UA9'; Code: 15),
      (Prefix: 'UK'; Code: 292),
      (Prefix: 'UN'; Code: 130),
      (Prefix: 'UR'; Code: 288),
      (Prefix: 'V2'; Code: 94),
      (Prefix: 'V3'; Code: 66),
      (Prefix: 'V4'; Code: 249),
      (Prefix: 'V5'; Code: 464),
      (Prefix: 'V6'; Code: 173),
      (Prefix: 'V7'; Code: 168),
      (Prefix: 'V8'; Code: 345),
      (Prefix: 'VE'; Code: 1),
      (Prefix: 'VK'; Code: 150),
      (Prefix: 'VK0H'; Code: 111),
      (Prefix: 'VK0M'; Code: 153),
      (Prefix: 'VK9C'; Code: 38),
      (Prefix: 'VK9L'; Code: 147),
      (Prefix: 'VK9M'; Code: 171),
      (Prefix: 'VK9N'; Code: 189),
      (Prefix: 'VK9W'; Code: 303),
      (Prefix: 'VK9X'; Code: 35),
      (Prefix: 'VP2E'; Code: 12),
      (Prefix: 'VP2M'; Code: 96),
      (Prefix: 'VP2V'; Code: 65),
      (Prefix: 'VP5'; Code: 89),
      (Prefix: 'VP6'; Code: 172),
      (Prefix: 'VP6/d'; Code: 513),
      (Prefix: 'VP8'; Code: 141),
      (Prefix: 'VP8/g'; Code: 235),
      (Prefix: 'VP8/h'; Code: 241),
      (Prefix: 'VP8/o'; Code: 238),
      (Prefix: 'VP8/s'; Code: 240),
      (Prefix: 'VP9'; Code: 64),
      (Prefix: 'VQ9'; Code: 33),
      (Prefix: 'VR'; Code: 321),
      (Prefix: 'VU'; Code: 324),
      (Prefix: 'VU4'; Code: 11),
      (Prefix: 'VU7'; Code: 142),
      (Prefix: 'XE'; Code: 50),
      (Prefix: 'XF4'; Code: 204),
      (Prefix: 'XT'; Code: 480),
      (Prefix: 'XU'; Code: 312),
      (Prefix: 'XW'; Code: 143),
      (Prefix: 'XX9'; Code: 152),
      (Prefix: 'XZ'; Code: 309),
      (Prefix: 'YA'; Code: 3),
      (Prefix: 'YB'; Code: 327),
      (Prefix: 'YI'; Code: 333),
      (Prefix: 'YJ'; Code: 158),
      (Prefix: 'YK'; Code: 384),
      (Prefix: 'YL'; Code: 145),
      (Prefix: 'YN'; Code: 86),
      (Prefix: 'YO'; Code: 275),
      (Prefix: 'YS'; Code: 74),
      (Prefix: 'YU'; Code: 296),
      (Prefix: 'YV'; Code: 148),
      (Prefix: 'YV0'; Code: 17),
      (Prefix: 'Z2'; Code: 452),
      (Prefix: 'Z3'; Code: 502),
      (Prefix: 'Z6'; Code: 522),
      (Prefix: 'Z8'; Code: 521),
      (Prefix: 'ZA'; Code: 7),
      (Prefix: 'ZB'; Code: 233),
      (Prefix: 'ZC4'; Code: 283),
      (Prefix: 'ZD7'; Code: 250),
      (Prefix: 'ZD8'; Code: 205),
      (Prefix: 'ZD9'; Code: 274),
      (Prefix: 'ZF'; Code: 69),
      (Prefix: 'ZK3'; Code: 270),
      (Prefix: 'ZL'; Code: 170),
      (Prefix: 'ZL7'; Code: 34),
      (Prefix: 'ZL8'; Code: 133),
      (Prefix: 'ZL9'; Code: 16),
      (Prefix: 'ZP'; Code: 132),
      (Prefix: 'ZS'; Code: 462),
      (Prefix: 'ZS8'; Code: 201)
   );

function ADIFDXCCOfCTYEntity(const aCountryID: string): integer;
var
   i: integer;
begin
   Result := 0;
   for i := Low(DXCC_ENTITIES) to High(DXCC_ENTITIES) do
      begin
      if DXCC_ENTITIES[i].Prefix = aCountryID then
         begin
         Result := DXCC_ENTITIES[i].Code;
         Exit;
         end;
      end;
end;

function DXCCEntityCount: integer;
begin
   Result := DXCC_ENTITY_COUNT;
end;

function DXCCEntityPrefixAt(aIndex: integer): string;
begin
   Result := string(DXCC_ENTITIES[aIndex].Prefix);
end;

end.
