unit gsf_Xlat;
{-----------------------------------------------------------------------------
                          International Character Sets

      gsf_Xlat Copyright (c) 1996 Griffin Solutions, Inc.

      Date
         4 Apr 1996

      Programmer:
         Richard F. Griffin                     tel: (912) 953-2680
         Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
         102 Molded Stone Pl
         Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

      --------------------------------------------------------------
      This unit handles character conversion and comparison for
      international character sets.

   Description

      This unit initializes country-specific information and character sets
      for use in languages that use different alphabets than English.  It is
      designed to allow the developer to determine the character set for the
      program by including an xxxxxxxx.NLS file that provides four different
      256-byte tables--UpperCase, LowerCase, Dictionary, and Standard ASCII
      character sets.  The character set used is based on the country code
      and code page as described in the MS-DOS manual in the chapter titled
      "Customizing for International Use".

      The xxxxxxxx.NLS files included have file names that are constructed
      as CcccPppp.NLS, where ccc is the country code and ppp is the code
      page.  For example, file C001P437.NLS is the include file for the
      United States (country code 001), and code page 437 (English); file
      C049P850.NLS is for Germany (country code 049), and code page 850
      (Multilingual (Latin I)).  To include a file, it must replace the
      $I C001P437.NLS directive at the beginning of the implementation
      section.  BE SURE THE FILE IS IN THE INCLUDE DIRECTORIES PATH.

      The character tables are described below:
      -----------------------------------------

      UpperCase  -  This is a 256-byte table that is used to translate an
         ASCII character to its uppercase equivalent.  For example, the
         table below is the UpperCase table from C001P437.NLS.  If the
         character 'a' used this translation table, it would retrieve the
         value at $61 (ASCII value for 'a'), which is $41 (ASCII value for
         'A').  This table is also valid for characters stored above the
         first 128 bytes.  These characters are often alphabetical codes
         containing umlauts.  Look at the character at $A0 (a lowercase 'a'
         with an accent mark).  This character also translates to an
         uppercase 'A' ($41).  There are also many lowercase characters in
         this region whose uppercase equivalent is also in the upper 128
         bytes.  The character at location $81 is a lowercase 'u' with two
         dots above the character.  This translates to $9A, which is an
         uppercase 'U' with two dots above the character.

              0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
         0   $00 $01 $02 $03 $04 $05 $06 $07 $08 $09 $0A $0B $0C $0D $0E $0F
         1   $10 $11 $12 $13 $14 $15 $16 $17 $18 $19 $1A $1B $1C $1D $1E $1F
         2   $20 $21 $22 $23 $24 $25 $26 $27 $28 $29 $2A $2B $2C $2D $2E $2F
         3   $30 $31 $32 $33 $34 $35 $36 $37 $38 $39 $3A $3B $3C $3D $3E $3F
         4   $40 $41 $42 $43 $44 $45 $46 $47 $48 $49 $4A $4B $4C $4D $4E $4F
         5   $50 $51 $52 $53 $54 $55 $56 $57 $58 $59 $5A $5B $5C $5D $5E $5F
         6   $60 $41 $42 $43 $44 $45 $46 $47 $48 $49 $4A $4B $4C $4D $4E $4F
         7   $50 $51 $52 $53 $54 $55 $56 $57 $58 $59 $5A $7B $7C $7D $7E $7F
         8   $80 $9A $45 $41 $8E $41 $8F $80 $45 $45 $45 $49 $49 $49 $8E $8F
         9   $90 $92 $92 $4F $99 $4F $55 $55 $59 $99 $9A $9B $9C $9D $9E $9F
         A   $41 $49 $4F $55 $A5 $A5 $A6 $A7 $A8 $A9 $AA $AB $AC $AD $AE $AF
         B   $B0 $B1 $B2 $B3 $B4 $B5 $B6 $B7 $B8 $B9 $BA $BB $BC $BD $BE $BF
         C   $C0 $C1 $C2 $C3 $C4 $C5 $C6 $C7 $C8 $C9 $CA $CB $CC $CD $CE $CF
         D   $D0 $D1 $D2 $D3 $D4 $D5 $D6 $D7 $D8 $D9 $DA $DB $DC $DD $DE $DF
         E   $E0 $E1 $E2 $E3 $E4 $E5 $E6 $E7 $E8 $E9 $EA $EB $EC $ED $EE $EF
         F   $F0 $F1 $F2 $F3 $F4 $F5 $F6 $F7 $F8 $F9 $FA $FB $FC $FD $FE $FF

      LowerCase  - This is a 256-byte table used to translate an uppercase
         character to its lowercase equivalent.  The translation technique
         is the same as for the UpperCase description above.

      Dictionary - Initially set to UpperCase, but provides a pointer so
         that the programmer may create a table with a custom sort sequence.
         This 256-byte table provides a translation based on the
         collation sequence of the character set.  This provides more
         than just setting uppercase for characters.  It ensures that
         punctuation symbols as well as alphabetical characters are
         ordered in a sequence that makes sense. The values in the table
         are the character weight of the ASCII value in that location.
         This allows sorting of two characters by getting their character
         weights from the table, and ordering based on the lowest weight
         first.  As you can see from the table below, several of the
         characters have the character weight of $41 (ASCII 'A').  Just
         as importantly, many currency symbols (pound, yen, franc, cent,
         peseta) in the upper 128 bytes from $9B to $9F all have the
         weight of $24 ('$').

         The character weight is not required to translate to an existing
         ASCII character index.  For the letter 'A', if you wished that
         it were the lowest possible weight, then the weight $00 would be
         set at index $41 and all other locations that shared the same
         character weight.  Then 'B' would be assigned the weight $01,
         'C' assigned $02, etc.  The character weight simply reflects the
         relative ranking of the character at the indexed position in the
         table.

              0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
         0   $00 $01 $02 $03 $04 $05 $06 $07 $08 $09 $0A $0B $0C $0D $0E $0F
         1   $10 $11 $12 $13 $14 $15 $16 $17 $18 $19 $1A $1B $1C $1D $1E $1F
         2   $20 $21 $22 $23 $24 $25 $26 $27 $28 $29 $2A $2B $2C $2D $2E $2F
         3   $30 $31 $32 $33 $34 $35 $36 $37 $38 $39 $3A $3B $3C $3D $3E $3F
         4   $40 $41 $42 $43 $44 $45 $46 $47 $48 $49 $4A $4B $4C $4D $4E $4F
         5   $50 $51 $52 $53 $54 $55 $56 $57 $58 $59 $5A $5B $5C $5D $5E $5F
         6   $60 $41 $42 $43 $44 $45 $46 $47 $48 $49 $4A $4B $4C $4D $4E $4F
         7   $50 $51 $52 $53 $54 $55 $56 $57 $58 $59 $5A $7B $7C $7D $7E $7F
         8   $43 $55 $45 $41 $41 $41 $41 $43 $45 $45 $45 $49 $49 $49 $41 $41
         9   $45 $41 $41 $4F $4F $4F $55 $55 $59 $4F $55 $24 $24 $24 $24 $24
         A   $41 $49 $4F $55 $4E $4E $A6 $A7 $3F $A9 $AA $AB $AC $21 $22 $22
         B   $B0 $B1 $B2 $B3 $B4 $B5 $B6 $B7 $B8 $B9 $BA $BB $BC $BD $BE $BF
         C   $C0 $C1 $C2 $C3 $C4 $C5 $C6 $C7 $C8 $C9 $CA $CB $CC $CD $CE $CF
         D   $D0 $D1 $D2 $D3 $D4 $D5 $D6 $D7 $D8 $D9 $DA $DB $DC $DD $DE $DF
         E   $E0 $53 $E2 $E3 $E4 $E5 $E6 $E7 $E8 $E9 $EA $EB $EC $ED $EE $EF
         F   $F0 $F1 $F2 $F3 $F4 $F5 $F6 $F7 $F8 $F9 $FA $FB $FC $FD $FE $FF

      Standard   - Initially set to nil to do a straight ASCII compare.
         It may be assigned a table address if the programmer wants to
         design a custom 'ASCII' sort.  This table normally contains the
         ASCII code for that index, which means you return with the same
         value that was used as the index.  The reason for having the table
         is to provide a capability to modify the ASCII order by changing
         the character weight.  The table as provided will provide a 'pure'
         ASCII sort.

      Usage
      -----

         During initialization, the table addresses are assigned to
         pointers pCtyUpperCase, pCtyLowerCase, pCtyDictionary, and
         pCtyStandard.  In addition, the pointer pCompareTbl is assigned
         the address of pCtyStandard, and pCompareITbl is assigned the
         address of pCtyUpperCase.

         In Griffin Solutions routines, string comparisons that are case
         sensitive will use the table pointed to by pCompareTbl.  The
         string comparisons that are case insensitive will use pCompareITbl.
         Therefore. by assigning another table to these pointers, the
         programmer could create any type of sort that was desired.

   Changes:

      07/19/97 - changed CaseOEMPChar() to have an additional argument to
                 protect for the maximum length.  This clears undefined
                 errors where the byte just beyond the buffer might be
                 modified if the PChar did not end with a #0.

      08/05/97 - changed CmprOEMBufr() to handle characters below #32
                 (space) when the other buffer is null-terminated.

   !!RFG 090297  added argument to CmprOEMBufr() to define the substitute
                 character to use for unequal field length comparisons.
                 Numeric fields in CDX indexes could fail.

   !!RFG 012198  added test in CmprOEMBufr to test for unequal field
                 comparisons where the comparison was 1 and the compare
                 position was greater than the length of the first key.
                 This happened on keys where characters < #32 were used.
                 For example, 'PAUL' and 'PAUL'#31 would determine that
                 'PAUL' was greater than 'PAUL'#31 because the default
                 #32 would be compared against the #31 in the second key.
------------------------------------------------------------------------------}
{$I gsf_FLAG.PAS}
interface

uses
   gsf_Glbl;

var
   ctyCountry            : word;
   ctyCodePage           : word;
   ctyDateFormat         : word;
   ctyDateSeparator      : char;
   ctyThousandsSeparator : char;
   ctyDecimalSeparator   : char;
   ctyCurrencySymbol     : array[0..4] of char;
   ctyCurrencySymPos     : byte;
   ctyDecimalPlaces      : byte;
   ctyTimeFormat         : byte;
   ctyTimeSeparator      : char;
   ctyDataSeparator      : char;
   pCtyUpperCase         : GSptrByteArray;
   pCtyLowerCase         : GSptrByteArray;
   pCtyDictionary        : GSptrByteArray;
   pCtyStandard          : GSptrByteArray;
   pCompareTbl           : GSptrByteArray;
   pCompareITbl          : GSptrByteArray;

procedure ConvertAnsiToNative(AnsiStr, NativeStr: PChar; MaxLen: longint);
procedure ConvertNativeToAnsi(NativeStr, AnsiStr: PChar; MaxLen: longint);

procedure CaseOEMPChar(stp: PChar; tbl: GSptrByteArray; Len: word);

function CmprOEMChar(ch1, ch2: char; tbl: GSptrByteArray): integer;
function CmprOEMBufr(st1, st2: pointer; tbl: GSptrByteArray;
                     var ix: longint; SubChar: char): integer;
function CmprOEMPChar(st1, st2: PChar; tbl: GSptrByteArray; var ix: integer): integer;
function CmprOEMString(const st1, st2: string; tbl: GSptrByteArray): integer;

{$IFDEF DUMY1234}
procedure NLSInit;
{$ENDIF}

implementation
uses vString;
{$I C007P866.NLS}

procedure ConvertAnsiToNative(AnsiStr, NativeStr: PChar; MaxLen: longint);
begin
   if AnsiStr <> NativeStr then
      Move(AnsiStr[0],NativeStr[0],MaxLen);
end;

procedure ConvertNativeToAnsi(NativeStr, AnsiStr: PChar; MaxLen: longint);
begin
   if NativeStr <> AnsiStr then
      Move(NativeStr[0],AnsiStr[0],MaxLen);
end;

procedure CaseOEMPChar(stp: PChar; tbl: GSptrByteArray; Len: word);
var
   ix     : word;
begin
   if stp = nil then exit;
   if tbl = nil then exit;
   ix := 0;
   while (ix < len) and (stp[ix] <> #0) do
   begin
      stp[ix] := chr(tbl^[ord(stp[ix])]);
      inc(ix);
   end;
end;

function CmprOEMChar(ch1, ch2: char; tbl: GSptrByteArray): integer;
var
   flg : integer;
   df: integer;
begin
   if tbl = nil then
   begin
      if ch1 = ch2 then CmprOEMChar := 0
         else if ch1 < ch2 then CmprOEMChar := -1
            else CmprOEMChar := 1;
      exit;
   end;
   flg := 0;
   df := tbl^[ord(ch1)];
   df := df - tbl^[ord(ch2)];
   if df < 0 then
      flg := -1
   else
      if df > 0 then flg := 1;
   CmprOEMChar := flg;
end;

function CmprOEMPChar(st1, st2: PChar; tbl: GSptrByteArray; var ix: integer): integer;
var
   df: integer;
   c1: char;
   c2: char;
   xlat: boolean;
begin
   ix := 0;
   if (st1 = nil) or (st2 = nil) then
   begin
      df := 0;
      if (st1 = nil) and (st2 <> nil) then dec(df)
      else
         if (st2 = nil) and (st1 <> nil) then inc(df);
      CmprOEMPChar := df;
      exit;
   end;
   xlat :=  tbl <> nil;
   if xlat then
   begin
      repeat
         c1 := st1[ix];
         c2 := st2[ix];
         if c1 <> c2 then
         begin
            df := tbl^[ord(c1)];
            df := df - tbl^[ord(c2)];
         end
         else
            df := 0;
         inc(ix);
      until (df <> 0) or (c1 = #0);
   end
   else
   begin
      repeat
         c1 := st1[ix];
         df := ord(c1) - ord(st2[ix]);
         inc(ix);
      until (df <> 0) or (c1 = #0);
   end;
   if df = 0 then
      CmprOEMPChar := 0
   else
      if df < 0 then
         CmprOEMPChar := -1
      else
         CmprOEMPChar := 1;
end;

function CmprOEMString(const st1, st2: string; tbl: GSptrByteArray): integer;
var
   flg : integer;
   len : word;
   ix  : word;
   df: integer;
begin
   if tbl = nil then
   begin
      if st1 = st2 then CmprOEMString := 0
         else if st1 < st2 then CmprOEMString := -1
            else CmprOEMString := 1;
      exit;
   end;
   ix := 1;
   flg := 0;
   len := length(st1);
   if len < length(st2) then flg := -1
      else if len > length(st2) then
      begin
         flg := 1;
         len := length(st2);
      end;
   while ix <= len do
   begin
      df := tbl^[ord(st1[ix])];
      df := df - tbl^[ord(st2[ix])];
      if df < 0 then
      begin
         flg := -1;
         ix := len;
      end
      else
         if df > 0 then
         begin
            flg := 1;
            ix := len;
         end;
      inc(ix);
   end;
   CmprOEMString := flg;
end;

function CmprOEMBufr(st1, st2: pointer; tbl: GSptrByteArray;
                     var ix: longint; SubChar: char): integer;
var
   df: longint;
   c1: char;
   c2: char;
   xlat: boolean;
   lm1: longint;
   lm2: longint;
   lmt: longint;
begin
   lm1 := GSptrString(st1)^.SizeStr;
   lm2 := GSptrString(st2)^.SizeStr;
   xlat :=  tbl <> nil;
   lmt := lm1;
   if lm2 > lm1 then lmt := lm2;
   ix := 0;

   repeat
      if lm1 <= ix then
         c1 := SubChar
      else
         c1 := GSptrString(st1)^.CharStr^[ix];
      if lm2 <= ix then
         c2 := SubChar
      else
         c2 := GSptrString(st2)^.CharStr^[ix];

      if xlat then begin
         if c1 <> c2 then begin
            df := tbl^[ord(c1)];
            df := df - tbl^[ord(c2)];
         end
         else
            df := 0;
      end
      else
      begin
         df := ord(c1) - ord(c2);
      end;
      inc(ix);
   until (df <> 0) or (ix >= lmt);
   CmprOEMBufr := df;

   if df = 0 then begin
      inc(ix);
      df := lm1 - lm2;
   end;

   if df < 0 then
         CmprOEMBufr := -1
   else
      if df > 0 then
         if (ix > lm1) then              {!!RFG 012198}
            CmprOEMBufr := -1            {!!RFG 012198}
         else                            {!!RFG 012198}
            CmprOEMBufr := 1;
end;

procedure OEMInit;
begin
   NLSInit;
   pCompareTbl := pCtyStandard;
   pCompareITbl := pCtyUpperCase;
end;

{------------------------------------------------------------------------------
                           Setup and Exit Routines
------------------------------------------------------------------------------}

begin
   OEMInit;
end.


