unit vString;
{-----------------------------------------------------------------------------
                          Generic String Routines

       written by Valery Votintsev.

------------------------------------------------------------------------------}
{$I GSF_FLAG.PAS}
interface
uses
   gsf_Eror,
   gsf_Glbl,
   gsf_Xlat,
   Strings;

Type
   pCodeTable = ^CodeTable;
   CodeTable = Array[0..255] of char;

Const
   CRLF :string[2] = #$0D#$0A;
   MaxCollectionSize = 65520 div SizeOf(Pointer);

Dos2Win:CodeTable =
      {  0    1    2    3    4    5    6    7    8    9 }
{  0} (#000,#001,#002,#003,#004,#005,#006,#007,#008,#009,
{ 10}  #010,#011,#012,#013,#014,#015,#016,#017,#018,#019,
{ 20}  #020,#021,#022,#023,#024,#025,#026,#027,#028,#029,
{ 30}  #030,#031,#032,#033,#034,#035,#036,#037,#038,#039,
{ 40}  #040,#041,#042,#043,#044,#045,#046,#047,#048,#049,
{ 50}  #050,#051,#052,#053,#054,#055,#056,#057,#058,#059,
{ 60}  #060,#061,#062,#063,#064,#065,#066,#067,#068,#069,
{ 70}  #070,#071,#072,#073,#074,#075,#076,#077,#078,#079,
{ 80}  #080,#081,#082,#083,#084,#085,#086,#087,#088,#089,
{ 90}  #090,#091,#092,#093,#094,#095,#096,#097,#098,#099,
{100}  #100,#101,#102,#103,#104,#105,#106,#107,#108,#109,
{110}  #110,#111,#112,#113,#114,#115,#116,#117,#118,#119,
{120}  #120,#121,#122,#123,#124,#125,#126,#127,
{120}                                          #192,#193,
{130}  #194,#195,#196,#197,#198,#199,#200,#201,#202,#203,
{140}  #204,#205,#206,#207,#208,#209,#210,#211,#212,#213,
{150}  #214,#215,#216,#217,#218,#219,#220,#221,#222,#223,
{160}  #224,#225,#226,#227,#228,#229,#230,#231,#232,#233,
{170}  #234,#235,#236,#237,#238,#239,#127,#127,#172,#124,
{180}  #043,#043,#043,#173,#134,#043,#124,#043,#043,#124,
{190}  #043,#043,#043,#043,#043,#043,#045,#043,#043,#043,
{200}  #043,#043,#043,#043,#043,#045,#043,#043,#043,#043,
{210}  #043,#178,#163,#138,#140,#142,#135,#043,#043,#144,
{220}  #131,#190,#179,#188,#240,#241,#242,#243,#244,#245,
{230}  #246,#247,#248,#249,#250,#251,#252,#253,#254,#255,
{240}  #168,#184,#170,#186,#175,#191,#161,#162,#154,#156,
{250}  #158,#157,#185,#159,#127,#160);


Dos2Koi:CodeTable =
      {  0    1    2    3    4    5    6    7    8    9 }
{  0} (#000,#001,#002,#003,#004,#005,#006,#007,#008,#009,
{ 10}  #010,#011,#012,#013,#014,#015,#016,#017,#018,#019,
{ 20}  #020,#021,#022,#023,#024,#025,#026,#027,#028,#029,
{ 30}  #030,#031,#032,#033,#034,#035,#036,#037,#038,#039,
{ 40}  #040,#041,#042,#043,#044,#045,#046,#047,#048,#049,
{ 50}  #050,#051,#052,#053,#054,#055,#056,#057,#058,#059,
{ 60}  #060,#061,#062,#063,#064,#065,#066,#067,#068,#069,
{ 70}  #070,#071,#072,#073,#074,#075,#076,#077,#078,#079,
{ 80}  #080,#081,#082,#083,#084,#085,#086,#087,#088,#089,
{ 90}  #090,#091,#092,#093,#094,#095,#096,#097,#098,#099,
{100}  #100,#101,#102,#103,#104,#105,#106,#107,#108,#109,
{110}  #110,#111,#112,#113,#114,#115,#116,#117,#118,#119,
{120}  #120,#121,#122,#123,#124,#125,#126,#127,
{120}                                          #$E1,#$E2,
{130}  #$F7,#$E7,#$E4,#$E5,#$F6,#$FA,#$E9,#$EA,#$EB,#$EC,
{140}  #$ED,#$EE,#$EF,#$F0,#$F2,#$F3,#$F4,#$F5,#$E6,#$E8,
{150}  #$E3,#$FE,#$FB,#$FD,#$FF,#$F9,#$F8,#$FC,#$E0,#$F1,
{160}  #$C1,#$C2,#$D7,#$C7,#$C4,#$C5,#$D6,#$DA,#$C9,#$CA,
{170}  #$CB,#$CC,#$CD,#$CE,#$CF,#$D0,#$90,#$91,#$92,#$81,
{180}  #$87,#$B2,#$B4,#$A7,#$A6,#$B5,#$A1,#$A8,#$AE,#$AD,
{190}  #$AC,#$83,#$84,#$89,#$88,#$86,#$80,#$8A,#$AF,#$B0,
{200}  #$AB,#$A5,#$BB,#$B8,#$B1,#$A0,#$BE,#$B9,#$BA,#$B6,
{210}  #$B7,#$AA,#$A9,#$A2,#$A4,#$BD,#$BC,#$85,#$82,#$8D,
{220}  #$8C,#$8E,#$8F,#$8B,#$D2,#$D3,#$D4,#$D5,#$C6,#$C8,
{230}  #$C3,#$DE,#$DB,#$DD,#$DF,#$D9,#$D8,#$DC,#$C0,#$D1,
{240}  #$B3,#$A3,#$99,#$98,#$93,#$9B,#$9F,#$97,#$9C,#$95,
{250}  #$9E,#$96,#$BF,#$9D,#$94,#$20);


type

   String80   = string[80];
   String12   = String[12];

   GSsetClipChars = set of Char;

   GSObjectPtr = ^GSObject;
   GSObject = object
      constructor Create;
      procedure Free;
      destructor Destroy; virtual;
   end;

   GSptrBaseObject = ^GSobjBaseObject;
   GSobjBaseObject = object(GSObject)
      ObjType     : longint;
      constructor Create;
   end;

   GSptrCollection = ^GSobjCollection;
   GSobjCollection = object(GSobjBaseObject)
      Items       : GSptrPointerArray;
      Count       : Integer;
      Limit       : Integer;
      Delta       : Integer;
      constructor Create(ALimit, ADelta: Integer);
      destructor  Destroy; virtual;
      function    At(Index: Integer): Pointer;
      procedure   AtDelete(Index: Integer);
      procedure   AtFree(Index: integer);
      procedure   AtInsert(Index: Integer; Item: Pointer);
      procedure   AtPut(Index: Integer; Item: Pointer);
      procedure   Delete(Item: Pointer);
      procedure   DeleteAll;
      procedure   FreeOne(Item: Pointer);
      procedure   FreeAll;
      procedure   FreeItem(Item: Pointer); virtual;
      function    IndexOf(Item: Pointer): Integer; virtual;
      procedure   Insert(Item: Pointer); virtual;
      procedure   SetLimit(ALimit: Integer); virtual;
   end;


   GSptrString = ^GSobjString;
   GSobjString = object(GSobjBaseObject)
      CharStr  : GSptrCharArray;
      SizeBuf  : word;
      SizeStr  : word;
      constructor Create(Size: word);
      destructor Destroy; virtual;
      function AssignString(AGSptrString: GSptrString): boolean;
      procedure ClearString;
      function CloneString: GSptrString;
      function PutBufr(ABufr: Pointer; Size: word): boolean;
      function PutString(const AString: string): boolean;
      function PutPChar(APChar: PChar): boolean;
      function ReplaceString(const AString: string): boolean;
      function ReplaceBufr(ABufr: Pointer; Size: word): boolean;
      function ReplacePChar(APChar: PChar): boolean;
      function GetBufr(ABufr: Pointer; Size: word): Pointer;
      function GetString: string;
      function GetPChar(APChar: PChar): PChar;
      procedure StringUpper;
   end;

   GSptrSortedCollection = ^GSobjSortedCollection;
   GSobjSortedCollection = object(GSobjCollection)
      Duplicates  : Boolean;
      constructor Create(ALimit, ADelta: Integer);
      function    Compare(Key1, Key2: PChar): Integer; virtual;
      function    IndexOf(Item: Pointer): Integer; virtual;
      procedure   Insert(Item: Pointer); virtual;
      function    KeyOf(Item: Pointer): Pointer; virtual;
      function    Search(Key: Pointer; var Index: Integer): Boolean; virtual;
   end;

   GSptrStringCollection = ^GSobjStringCollection;
   GSobjStringCollection = object(GSobjSortedCollection)
      constructor Create(ALimit, ADelta: Integer);
      function    Compare(Key1, Key2: PChar): Integer; virtual;
      procedure   FreeItem(Item: Pointer); virtual;
   end;





Function  StrGSNew(s: PChar): PChar;
Procedure StrGSDispose(s: PChar);

function  PadL(const strn : String; lth : integer) : String;
function  PadR(const strn : String; lth : integer) : String;
function  PadC(strn : String; lth : integer) : String;
procedure StrPadR(s: PChar; c: char; n: integer);
function  CapClip(const t : String; ClipEm: GSsetClipChars) : String;
Function  Strip_Flip(const st : String): String;
function  SubStr(const s : String; b,l : integer) : String;

Function  Upper(S:String):String;
Function  Lower(S:String):String;
Function  UpCase(Ch : Char) : Char;
Function  Locase(Ch : Char) : Char;
function  AnsiUpperCase(const S: string): string;
function  AnsiLowerCase(const S: string): string;
function  AnsiLowerBuff(Str: PChar; Length: Word): Word;
function  AnsiUpperBuff(Str: PChar; Length: Word): Word;
Function  FirstUpChar(chprev, ch: char): char;
procedure StrLowerCase(Str: PChar; Length: longint);
procedure StrUpperCase(Str: PChar; Length: longint);

function  LTrim(const strn : String): String; {Deletes leading spaces}
function  RTrim(const strn : String): String; {Deletes trailing spaces}
function  AllTrim(const strn : String): String;
procedure StrTrimR(s: PChar);

function  Unique_Field : String;     {Used to create a unique 8-byte String}
Function  InsCommas(S:string):string;
function  IntToStr(value: longint): string;
function  StrToInt(S:string): Longint;
Function  ConvertStr(S:String;Table:pCodeTable):String;
Function  ConvertChar(C:Char;Table:pCodeTable):char;
Procedure Byte2Hex(byt: byte; var ch1, ch2: char);
procedure Hex2Byte(var byt: byte; ch1, ch2: char);
Function  Real2Str(R : Real;L,D:integer) : string;

Function Left(const S:String;n:byte):String;
Function Right(const S:String;n:byte):String;
Function Replicate(const Strn:String;Numb:Byte):String;
Function ReplaceAll(S:string;const Search,Repl:string):String;
Function Spaces(n:byte):string;
Function EmptyStr(const S:String):Boolean;

Function ExtractFileNameOnly(const FileName: String): String;
Function ChangeFileExtEmpty(const FileName, Extension: String): String;
Function ExtractFileExt(const FileName: String): String;
Function ExtractFileName(const FileName: String): String;
Function ExtractFilePath(const FileName: String): String;
Function ChangeFileExt(const FileName, Extension: String): String;

function ScanUpBufr(s:string; buf: pChar; ix: longint): LongInt;
Function AT(const S,S1:String):byte;
function BinAT(const s:string;var src;len:longint):longint;
Function RAT(Ch:Char;Line:string):Byte;
function CmprIntegers(V1, V2: longint): integer;


implementation

Uses
   DOS,
   Gsf_DOS;
{------------------------------------------------------------------------------
                                     GSObject
------------------------------------------------------------------------------}

constructor GSObject.Create;
type
  Image = record
    Link: Word;
    Data: record end;
  end;
begin
   FillChar(Image(Self).Data, SizeOf(Self) - SizeOf(GSObject), 0);
end;

procedure GSObject.Free;
begin
  Dispose(GSObjectPtr(@Self), Destroy);
end;

destructor GSObject.Destroy;
begin
end;

{------------------------------------------------------------------------------
                                  GSobjBaseObject
------------------------------------------------------------------------------}

constructor GSobjBaseObject.Create;
begin
   inherited Create;
   ObjType := GSobtInitializing;
end;

{------------------------------------------------------------------------------
                                  GSobjCollection
------------------------------------------------------------------------------}

constructor GSobjCollection.Create(ALimit, ADelta: Integer);
begin
   inherited Create;
   ObjType := GSobtCollection;
   Items := nil;
   Count := 0;
   Limit := 0;
   Delta := ADelta;
   SetLimit(ALimit);
end;

destructor GSobjCollection.Destroy;
begin
   FreeAll;
   SetLimit(0);
end;

function GSobjCollection.At(Index: Integer): Pointer;
begin
   if (Index < 0) or (Index >= Count) then
   begin
      FoundPgmError(tpCollectionIndex,-1,nil);
      At := nil;
   end
      else At := Items^[Index];
end;

procedure GSobjCollection.AtDelete(Index: Integer);
begin
   if (Index >= 0) and (Index < Count) then
   begin
      if Index < Count-1 then
         move(Items^[Index+1],Items^[Index],((Count-1)-Index)*4);
      dec(Count);
   end
   else FoundPgmError(tpCollectionIndex,-1,nil);
end;

procedure  GSobjCollection.AtFree(Index: integer);
var
   Item: pointer;
begin
   Item := At(Index);
   AtDelete(Index);
   FreeItem(Item);
end;

procedure GSobjCollection.AtInsert(Index: Integer; Item: Pointer);
var
   wli: longint;
begin
   if (Index >= 0) and (Index <= Count) then
   begin
      if Count = Limit then SetLimit(Limit+Delta);
      if Index <> Count then
      begin
         wli := Count-Index;
         move(Items^[Index],Items^[Index+1],wli*SizeOf(Pointer));
      end;
      Items^[Index] := Item;
      inc(Count);
   end
   else FoundPgmError(tpCollectionIndex,-1,nil);
end;

procedure GSobjCollection.AtPut(Index: Integer; Item: Pointer);
begin
   if (Index >= 0) and (Index <= Count) then
      Items^[Index] := Item
   else FoundPgmError(tpCollectionIndex,-1,nil);
end;

procedure GSobjCollection.Delete(Item: Pointer);
begin
   AtDelete(IndexOf(Item));
end;

procedure GSobjCollection.DeleteAll;
begin
   Count := 0;
end;

procedure GSobjCollection.FreeOne(Item: Pointer);
begin
   Delete(Item);
   FreeItem(Item);
end;

procedure GSobjCollection.FreeAll;
var
  I: Integer;
begin
   for I := 0 to Count - 1 do FreeItem(At(I));
   Count := 0;
end;

procedure GSobjCollection.FreeItem(Item: Pointer);
begin
   if Item <> nil then GSptrBaseObject(Item)^.Free;
end;

function GSobjCollection.IndexOf(Item: Pointer): Integer;
var
   i          : integer;
   foundit    : boolean;
begin
   foundit := false;
   i := 0;
   while not foundit and (i < Count) do
   begin
      foundit := Item = Items^[i];
      if not foundit then inc(i);
   end;
   if foundit then IndexOf := i else IndexOf := -1;
end;

procedure GSobjCollection.Insert(Item: Pointer);
begin
   AtInsert(Count, Item);
end;

procedure GSobjCollection.SetLimit(ALimit: Integer);
var
   AItems: GSptrPointerArray;
   wli: longint;
begin
   if ALimit < Count then ALimit := Count;
   if ALimit > MaxCollectionSize then ALimit := MaxCollectionSize;
   if ALimit <> Limit then
   begin
      if ALimit = 0 then AItems := nil else
      begin
         wli := ALimit;
         GetMem(AItems,wli * SizeOf(Pointer));
         wli := Count;
         if (Count <> 0) and (Items <> nil) then
            Move(Items^, AItems^, wli * SizeOf(Pointer));
      end;
      wli := Limit;
      if Limit <> 0 then FreeMem(Items, wli * SizeOf(Pointer));
      Items := AItems;
      Limit := ALimit;
   end;
end;


{------------------------------------------------------------------------------
                                  GSobjString
------------------------------------------------------------------------------}

constructor GSobjString.Create(Size: word);
begin
   inherited Create;
   CharStr := nil;
   SizeBuf := Size;
   SizeStr := 0;
   if Size > 0 then
   begin
      GetMem(CharStr, SizeBuf);
      FillChar(CharStr^, SizeBuf, #0);
   end;
   ObjType := GSobtCollection;
end;

destructor GSobjString.Destroy;
begin
   if SizeBuf > 0 then
      FreeMem(CharStr,SizeBuf);
   inherited Destroy;
end;

function GSobjString.AssignString(AGSptrString: GSptrString): boolean;
begin
   AssignString := false;
   if AGSptrString = nil then exit;
   if SizeBuf > 0 then
      FreeMem(CharStr,SizeBuf);
   CharStr := nil;
   if AGSptrString^.SizeBuf > 0 then
   begin
      GetMem(CharStr,AGSptrString^.SizeBuf);
      Move(AGSptrString^.CharStr^,CharStr^,AGSptrString^.SizeBuf);
   end;
   SizeBuf := AGSptrString^.SizeBuf;
   SizeStr := AGSptrString^.SizeStr;
   AssignString := true;
end;

procedure GSobjString.ClearString;
begin
   if SizeBuf > 0 then
      FreeMem(CharStr,SizeBuf);
   CharStr := nil;
   SizeBuf := 0;
   SizeStr := 0;
end;

function GSobjString.CloneString: GSptrString;
var
   cs: GSptrString;
begin
   cs := New(GSptrString, Create(0));
   cs^.AssignString(@Self);
   CloneString := cs;
end;

function GSobjString.PutString(const AString: string): boolean;
begin
   if SizeBuf > 0 then
      FreeMem(CharStr,SizeBuf);
   CharStr := nil;
   SizeBuf := length(AString);
   if SizeBuf > 0 then
   begin
      GetMem(CharStr,SizeBuf);
      Move(AString[1],CharStr^,SizeBuf);
   end;
   SizeStr := SizeBuf;
   PutString := true;
end;

function GSobjString.PutPChar(APChar: PChar): boolean;
begin
   PutPChar := false;
   if APChar = nil then exit;
   if SizeBuf > 0 then
      FreeMem(CharStr,SizeBuf);
   CharStr := nil;
   SizeStr := StrLen(APChar);
   SizeBuf := succ(SizeStr);
   GetMem(CharStr,SizeBuf);
   if SizeStr > 0 then
      Move(APChar[0],CharStr^,SizeBuf)
   else
      CharStr^[0] := #0;
   PutPChar := true;
end;

function GSobjString.PutBufr(ABufr: Pointer; Size: word): boolean;
begin
   PutBufr := false;
   if ABufr = nil then exit;
   if SizeBuf > 0 then
      FreeMem(CharStr,SizeBuf);
   CharStr := nil;
   SizeBuf := Size;
   if SizeBuf > 0 then
   begin
      GetMem(CharStr,SizeBuf);
      Move(ABufr^,CharStr^,Size);
   end;
   SizeStr := Size;
   PutBufr := true;
end;

function GSobjString.ReplaceString(const AString: string): boolean;
begin
   ReplaceString := false;
   if length(AString) <= SizeBuf then
   begin
      SizeStr := length(AString);
      if SizeStr > 0 then
         Move(AString[1],CharStr^,SizeStr);
      ReplaceString := true;
   end;
end;

function GSobjString.ReplaceBufr(ABufr: Pointer; Size: word): boolean;
begin
   ReplaceBufr := false;
   if ABufr = nil then exit;
   SizeStr := SizeBuf;
   if Size < SizeBuf then
      SizeStr := Size;
   Move(ABufr^,CharStr^,SizeStr);
   ReplaceBufr := true;
end;

function GSobjString.ReplacePChar(APChar: PChar): boolean;
begin
   if SizeBuf = 0 then
   begin
      PutPChar(APChar);
   end
   else
   begin
      if APChar = nil then
         SizeStr := 0
      else
         SizeStr := StrLen(APChar);
      if SizeStr >= SizeBuf then
         SizeStr := pred(SizeBuf);
      Move(APChar[0],CharStr^,succ(SizeStr));
   end;
   ReplacePChar := true;
end;

function GSobjString.GetBufr(ABufr: Pointer; Size: word): Pointer;
begin
   if (CharStr = nil) or (ABufr = nil) then
      GetBufr := nil
   else
   begin
      if Size > SizeBuf then Size := SizeBuf;
      Move(CharStr^,ABufr^,Size);
      GetBufr := ABufr;
   end;
end;

function GSobjString.GetString: string;
var
   s: String;
   ps: PChar;
begin
   s := '';
   if CharStr <> nil then
   begin
      GetMem(ps, succ(SizeStr));
      s := StrPas(GetPChar(ps));
      FreeMem(ps, succ(SizeStr));
   end;
   GetString := s;
end;

function GSobjString.GetPChar(APChar: PChar): PChar;
begin
   if (APChar = nil) then
      GetPChar := nil
   else
   begin
      if (CharStr = nil) then
         APChar[0] := #0
      else
      begin
         Move(CharStr^,APChar[0],SizeStr);
         APChar[SizeStr] := #0;
      end;
      GetPChar := APChar;
   end;
end;

procedure GSobjString.StringUpper;
begin
   if (SizeStr = 0) or (CharStr = nil) then exit;
      AnsiUpperBuff(PChar(CharStr),SizeStr);
end;


{------------------------------------------------------------------------------
                               GSobjSortedCollection
------------------------------------------------------------------------------}

constructor GSobjSortedCollection.Create(ALimit, ADelta: Integer);
begin
   inherited Create(ALimit, ADelta);
   ObjType := GSobtSortedCollection;
   Duplicates := False;
end;

function GSobjSortedCollection.Compare(Key1, Key2: PChar): Integer;
begin
   Compare := 0;
end;

function GSobjSortedCollection.IndexOf(Item: Pointer): Integer;
var
   I: Integer;
begin
   IndexOf := -1;
   if Search(KeyOf(Item), I) then
   begin
      if Duplicates then
         while (I < Count) and (Item <> Items^[I]) do Inc(I);
      if I < Count then IndexOf := I;
   end;
end;

procedure GSobjSortedCollection.Insert(Item: Pointer);
var
   I: Integer;
begin
   if not Search(KeyOf(Item), I) or Duplicates then AtInsert(I, Item);
end;

function GSobjSortedCollection.KeyOf(Item: Pointer): Pointer;
begin
   KeyOf := Item;
end;

function GSobjSortedCollection.Search(Key: Pointer; var Index: Integer): Boolean;
var
   L, H, I, C: Integer;
begin
   Search := False;
   L := 0;
   H := Count - 1;
   while L <= H do
   begin
      I := (L + H) shr 1;
      C := Compare(KeyOf(Items^[I]), Key);
      if C < 0 then L := I + 1 else
      begin
         H := I - 1;
         if C = 0 then
         begin
            Search := True;
            if not Duplicates then L := I;
         end;
      end;
   end;
   Index := L;
end;

{ ----------------------------------------------------------------------------
                               GSobjStringCollection
-----------------------------------------------------------------------------}

constructor GSobjStringCollection.Create;
begin
   inherited Create(32,16);
   ObjType := GSobtStringCollection;
end;

function GSobjStringCollection.Compare(Key1, Key2: PChar): Integer;
var
   i: integer;
begin
   Compare := CmprOEMPChar(Key1,Key2,pCompareTbl,i);
end;

procedure GSobjStringCollection.FreeItem(Item: Pointer);
begin
   StrGSDispose(PChar(Item));
end;





{------------------------------------------------------------------------------
                           Global procedures/functions
------------------------------------------------------------------------------}

Procedure Byte2Hex(byt: byte; var ch1, ch2: char);
var
   b1: byte;
   b2: byte;
begin
   b1 := byt shr 4;
   b2 := byt and $0F;
   if b1 > 9 then
      ch1 := chr(55 + b1)
   else
      ch1 := chr(48 + b1);
   if b2 > 9 then
      ch2 := chr(55 + b2)
   else
      ch2 := chr(48 + b2);
end;

procedure Hex2Byte(var byt: byte; ch1, ch2: char);
var
   b1: byte;
   b2: byte;
begin
   b1 := 0;
   b2 := 0;
   if ch1 in ['0'..'9'] then b1 := ord(ch1) - 48
      else if ch1 in ['A'..'F'] then b1 := ord(ch1) - 55;
   if ch2 in ['0'..'9'] then b2 := ord(ch2) - 48
      else if ch2 in ['A'..'F'] then b2 := ord(ch2) - 55;
   byt := (b1 shl 4) or b2;
end;


function CapClip(const t : String; ClipEm: GSsetClipChars) : String;
var
   l : integer;
   f : integer;
   s: string;
begin
   l := length(t);                 {Load String length}
   while (l > 0) and (t[l] in ClipEm) do
      dec(l);  {Loop searching down to first non-blank}
   if l > 0 then                      {Return trimmed length}
   begin
      f := 1;
      while (f < l) and (t[f] in ClipEm) do inc(f);
      s := System.Copy(t,f,l);
      CapClip := AnsiUpperCase(s);
   end
   else
      CapClip := '';
end;


function CmprIntegers(V1, V2: longint): integer;
var
   V: longint;
begin
   V := V1-V2;
   if V < 0 then V := -1
      else
         if V > 0 then V := 1;
   CmprIntegers := V;
end;


Function FirstUpChar(chprev, ch: char): char;
var
   cha: array[0..1] of char;
begin
   cha[0] := ch;
   if chprev in [#0,#$20..#$26,#$28..#$2F,#$3A..#$40,#$5B..#$5F,#$7B..#$7F] then
      AnsiUpperBuff(@cha,1);
   FirstUpChar := cha[0];
end;

function PadL( const strn : String; lth : integer) : String;
var
   wks : String[255];
   i   : integer;
begin
   wks := '';
   i := length(strn);                    {Load String255 length}
   if i > 0 then
   begin
      if i >= lth then
      begin
         PadL := System.Copy(strn,succ(i-lth),lth);
         exit;
      end;
      FillChar(wks,succ(lth),#32);
      move(strn[1],wks[succ(lth-i)],i);
      wks[0] := chr(lth);
   end;
   PadL := wks;
end;

function PadR(const strn : String; lth : integer) : String;
var
   wks : String[255];
   i   : integer;
begin
   wks := '';
   i := length(strn);                    {Load String255 length}
{   if i > 0 then begin}
      if i >= lth then begin
         PadR := System.Copy(strn,1,lth);
         exit;
      end;
      FillChar(wks,succ(lth),#32);
      wks[0] := chr(lth);
      move(strn[1],wks[1],i);                   {Load work String255}
{   end;}
   PadR := wks;
end;


Function StrGSNew(s: PChar): PChar;
var
   p: PChar;
   c: word;
begin
   if (s = nil) or (s[0] = #0) then
      StrGSNew := nil
   else
   begin
      c := StrLen(s) + 3;
      GetMem(p, c);
      move(c, p[0], 2);
      inc(p,2);
      StrCopy(p,s);
      StrGSNew := p;
   end;
end;

Procedure StrGSDispose(s: PChar);
var
   c: word;
begin
   if s = nil then exit;
   dec(s,2);
   move(s[0],c,2);
   FreeMem(s,c);
end;


Function Strip_Flip(const st : String): String;
var
   wst,
   wstl : String;
   i    : integer;
begin
   wst := RTrim(st);
   wst := wst + ' ';
   i := pos('~', wst);
   if i <> 0 then
   begin
      wstl := copy(wst,1,pred(i));
      system.delete(wst,1,i);
      wst := wst + wstl;
   end;
   Strip_Flip := wst;
end;

procedure StrPadR(s: PChar; c: char; n: integer);
var
   i: integer;
begin
   i := StrLen(s);
   while i < n do
   begin
      s[i] := c;
      inc(i);
   end;
   s[i] := #0;
end;

procedure StrTrimR(s: PChar);
var
   i: integer;
begin
   i := StrLen(s);
   while (i > 0) and (s[pred(i)] = #32) do dec(i);
   s[i] := #0;
end;

procedure StrLowerCase(Str: PChar; Length: longint);
begin
      AnsiLowerBuff(Str,Length);
end;

procedure StrUpperCase(Str: PChar; Length: longint);
begin
      AnsiUpperBuff(Str,Length);
end;

function AllTrim(const strn : String): String;
begin
   AllTrim:=RTrim(LTrim(strn));
end;

function LTrim(const strn : String): String;
var
   l : integer;
   i : integer;
begin
   l := length(strn);                 {Load String length}
   i := 1;
   while (i <= l) and (strn[i] = ' ') do
      inc(i);                          {Loop searching up to first non-blank}
   if i <= l then                      {Return trimmed length}
      LTrim := System.Copy(strn,i,l)
   else
      LTrim := '';
end;

function RTrim(const strn : String): String;
var
   l : integer;
begin
   l := length(strn);                 {Load String length}
   while (l > 0) and (strn[l] = ' ') do
         dec(l);                  {Loop searching down to first non-blank}
   if l > 0 then                      {Return trimmed length}
      RTrim := System.Copy(strn,1,l)
   else
      RTrim := '';
end;

const
   chrsavail : String[36] =  '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
var
   LastUnique : String[8];


function Unique_Field : String;
var
   y, mo, d, dow  : Word;
   h, mn, s, hund : Word;
   wk, ymd, hms   : longint;
   LS             : String[16];

begin
   repeat
      GetTime(h,mn,s,hund);
      GetDate(y,mo,d,dow);
      ymd := 10000+(mo*100)+d;
      hms := ((h+10)*1000000)+(longint(mn)*10000)+(s*100)+hund;
      wk := ymd mod 26;
      LS := chrsavail[succ(wk) + 10];
      ymd := ymd div 26;
      repeat
         wk := ymd mod 36;
         LS := LS + chrsavail[succ(wk)];
         ymd := ymd div 36;
      until ymd = 0;
      repeat
         wk := hms mod 36;
         LS := LS + chrsavail[succ(wk)];
         hms := hms div 36;
      until hms= 0;
   until LS <> LastUnique;
   LastUnique := LS;
   Unique_Field := LS;                {Return the unique field}
end;

Function InsCommas(S:string):string;
{Convert Numeral String "1234567" to "1,234,567"}
var
  i:integer;
begin
   i:= length(s)+1;
   while i > 1 do begin
      dec(i,3);
      If i>1 then Insert(',',s,i);
   end;
   InsCommas:=s;
end;

function IntToStr(value: longint): string;
var
   s: string;
begin
   Str(Value,s);
   IntToStr := s;
end;

function StrToInt;  {(s : String) : longint;}
var
   r : integer;
   n : longint;
begin
   val(s,n,r);
   if r <> 0 then StrToInt := 0
      else StrToInt := n;
end;

function AnsiUpperCase(const S : String) : String;
var
   MaxLen: integer;
   AnsiStr: PChar;
begin
   MaxLen := length(S);
   GetMem(AnsiStr,MaxLen+1);
   StrPCopy(AnsiStr,S);
   AnsiUpperBuff(AnsiStr,MaxLen);
   AnsiUpperCase := StrPas(AnsiStr);
   FreeMem(AnsiStr,MaxLen+1);
end;

function AnsiLowerCase(const S : String) : String;
var
   MaxLen: integer;
   AnsiStr: PChar;
begin
   MaxLen := length(S);
   GetMem(AnsiStr,MaxLen+1);
   StrPCopy(AnsiStr,S);
   AnsiLowerBuff(AnsiStr,MaxLen);
   AnsiLowerCase := StrPas(AnsiStr);
   FreeMem(AnsiStr,MaxLen+1);
end;

function AnsiUpperBuff(Str: PChar; Length: Word): Word;
begin
   AnsiUpperBuff := Length;
   CaseOEMPChar(Str,pCtyUpperCase, Length);
end;

function AnsiLowerBuff(Str: PChar; Length: Word): Word;
begin
   AnsiLowerBuff := Length;
   CaseOEMPChar(Str,pCtyLowerCase, Length);
end;


{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Function Left(const S:String;n:byte):String;
begin
   Left:=Copy(S,1,n);
end;

{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Function Right(const S:String;n:byte):String;
Var
   i:byte;
begin
   i:=length(S)-n+1;
   If i<=0 then i:=1;
   Right:=Copy(S,i,n);
end;


{-----------------------------------------------------------}
Function RAT(Ch:Char;Line:string):Byte;
var
   Point:Byte;
   i:byte;
   l:byte absolute Line;

begin
   Point:=0;
   For i:=l downto 1 do begin
      If Line[i]=Ch then begin
         Point:=i;
	 break;
      end;
   end;
   RAT:=Point;
end;

Function Replicate(const Strn:String;Numb:Byte):String;
{------- Repeat repeated Substring -------------}
Var i:Byte;
    St:String;
Begin
  St:='';
  For i:=1 to Numb do St:=St+Strn;
  Replicate:=St;
end;

{ ---------------------------------------------------------- }
Function Real2Str(R : Real;L,D:integer) : string;
var s:string;
begin
   Str(R:l:d,s);
   Real2Str:= s;
end;

{------------------------------------------------}
Function Spaces(n:byte):string;
var s:string;
    i:byte;
begin
  s:='';
  For i:=1 to n do S:=S+' ';
  Spaces:=S;
end;

function PadC;  {(strn : String; lth : integer) : String;}
var
   wks : String;
   i   : integer;
begin
   i := length(strn);                    {Load String length}
   if i >= lth then begin
      PadC := System.Copy(strn,succ((i-lth) div 2),lth);
      exit;
   end;
   FillChar(wks,succ(lth),#32);
   move(strn[1],wks[succ((lth-i) div 2)],i);
   wks[0] := chr(lth);
   PadC := wks;
end;

{--------------  ---------------------------}
Function Upper(S:String):String;
var
  i : Integer;
begin
  for i := 1 to Length(s) do
    s[i] := Upcase(s[i]);
  Upper:=S;
end;

{--------------  ---------------------------}
Function Lower(S:String):String;
var
  i : Integer;
begin
  for i := 1 to Length(s) do
    s[i] := Locase(s[i]);
  Lower:=S;
end;

{------------------------------------------------------}
Function UpCase(Ch : Char) : Char; Assembler;
{Return uppercased char, with Russian character support}

Asm
        mov     al,ss:[bp+6]
       { -----------  Convert English Characters }
        CMP     AL,'a'
        JB      @1               { if AL < 'a'          }
        CMP     AL,'z'
        JA      @2               { if AL > 'z'          }
        SUB     AL,20H           { Convert to uppercase }
        JMP     @1
        { -----------  Convert Russian Characters}
@2:
       CMP AL,' '
       JB  @1

       CMP AL,'¯'
       JA  @3
       AND AL,0DFH      { Convert chars " ¡¢...¯" }
        JMP     @1
@3:
       CMP AL,'à'
       JB  @1

       CMP AL,'ï'
       JA  @4
       SUB AL,050H      { Convert chars "àáâ...ï" }
        JMP     @1
@4:
       CMP AL,'ñ'
       JNE @1
       DEC AL           { Convert e: -> E:        }
@1:
END;

{-------------------------------------------------------}
Function Locase(Ch : Char) : Char; Assembler;
{Return lowercased char, with Danish character support  }
Asm
        mov     al,ss:[bp+6]
        { -----------  Convert English Characters  }
        CMP     AL,'A'
        JB      @1                { if AL < 'A'    }
        CMP     AL,'Z'
        JA      @2                { if AL > 'Z'    }
        ADD     AL,20H            { Convert to lowercase }
        JMP     @1
        { -----------  Convert Russian Characters }
@2:
       CMP AL,'€'
       JB  @1

       CMP AL,''
       JA  @3
       ADD AL,20H      { Convert chars " ¡¢...¯" }
        JMP     @1
@3:
       CMP AL,''
       JB  @1

       CMP AL,'Ÿ'
       JA  @4
       ADD AL,050H      { Convert chars "àáâ...ï" }
        JMP     @1
@4:
       CMP AL,'ð'
       JNE @1
       INC AL           { Convert E: -> e:  }
@1:
END;

{-----------------------------------------------------------}
Function  EmptyStr(const S:String):Boolean;
begin
  EmptyStr := (S[0]=#0);
end;


Function ExtractFileNameOnly(const FileName: String): String;
var
   ixn   : integer;
   ixe   : integer;
   sn    : string;
   se    : string;
begin
   sn := ExtractFileName(FileName);
   se := ExtractFileExt(FileName);
   ixe := length(se);
   if ixe > 0 then
   begin
      ixn := succ(length(sn)- ixe);
      if System.Copy(sn,ixn,ixe) = se then
         System.Delete(sn,ixn,ixe);
   end;
   ExtractFileNameOnly := sn;
end;

Function  ChangeFileExtEmpty(const FileName, Extension: String): String;
begin
   if ExtractFileExt(FileName) = '' then
      ChangeFileExtEmpty := ChangeFileExt(FileName,Extension)
   else
      ChangeFileExtEmpty := FileName;
end;

Function ExtractFileExt(const FileName: String): String;
var
   i     : integer;
begin
   i := length(FileName);
   while not (FileName[i] in ['.','\',':']) and (i > 0) do dec(i);
   if (i <> 0) and (FileName[i] = '.') then
      ExtractFileExt := system.copy(FileName,i,4)
   else
      ExtractFileExt := '';
end;

Function ExtractFileName(const FileName: String): String;
var
   first : integer;
   i     : integer;
begin
   i := length(FileName);
   while (i > 0) and (not (FileName[i] in ['\',':'])) do dec(i);
   first := succ(i);
   ExtractFileName := system.copy(FileName,first,255);
end;

Function ExtractFilePath(const FileName: String): String;
var
   i     : integer;
begin
   i := length(FileName);
   while (i > 0) and (not (FileName[i] in ['\',':'])) do dec(i);
   if i > 0 then
      ExtractFilePath := system.copy(FileName,1,i)
   else
      ExtractFilePath := '';
end;

Function ChangeFileExt(const FileName, Extension: String): String;
var
   i   : integer;
   Pth : string;
begin
   Pth := FileName;
   i := length(Pth);
   while not (Pth[i] in ['.','\',':']) and (i > 0) do dec(i);
   if (i <> 0) then
      if (Pth[i] = '.') then System.Delete(Pth,i,255);
   Pth := Pth + Extension;
   ChangeFileExt := Pth;
end;



function BinAT(const s:string;var src;len:longint):longint;assembler;
{Search substring S in the SRC buffer}
{return 0 if not found}
Asm
    push   ds                   { begin }
    lds    si, s
    cld

    lodsb
    or     al,al                { If S = '' then GoTo @2 }
    je     @2

    mov    dl,al                { DL := Length(S) }
    xor    dh,dh

    les    di,src               { ES:DI := Addr( src )   }
    mov    cx,word ptr [len]    { CX    := Length(src) }
{    xor    ch,ch}
    sub    cx,dx                { CX    := Length(src) - Lenth(S) }
    jb     @2                   { If Length(src) < Length(S) then GoTo 2}
    inc    cx
    {inc    di}

@1: lodsb                       { AL := next byte }
    repnz scasb                 { search AL in the src }
    jne    @2                   { If not found then goto @2 }

    mov    ax,di                { }
    mov    bx,cx                { }
    mov    cx,dx                { }
    dec    cx                   { }
    rep cmpsb                   { }
    je     @3                   { }

    mov    di,ax                { }
    mov    cx,bx                { }
    mov    si, word ptr s       { }
    inc    si                   { }
    jmp    @1                   { }

@2: xor    ax,ax                { }
    jmp    @4                   { }
@3: {dec    ax}                 { }
    sub    ax,word ptr src      { }
@4:
    xor dx,dx                   { }
    pop DS
    mov    sp,bp                { }
end;


function ScanUpBufr(s:string; buf: pChar; ix: longint): LongInt;
var
   lFound: boolean;
   i:integer;
   l1: longint;
   l2: longint;
   iy: longint;
   n:longint;
   OldPointer:pChar;
   c1,c2:char;
begin
   ScanUpBufr := 0;
   lFound:=False;

   If s <> '' then begin
      l1 := Length(s);
      l2 := ix;
      n:=l2-l1;

      If (n >= 0) then begin {¥á«¨ ¨áª®¬ ï áâà®ª  æ¥«¨ª®¬ ã¬¥é ¥âáï ¢ ¡ãä¥à¥}
         Inc(n);
         ix := 0;
         iy := 0;
         OldPointer:=buf;

         repeat            {find first searched char}

            Buf:=OldPointer;
            ix:=iy;
            For i:=1 to l1 do begin
               c1:=UpCase(s[i]);
               c2:=UpCase(Char(Buf^));
               If c1 <> c2 then Break
               else begin
                  Inc(ix);
                  Inc(Buf);
               end;
            end;
            If ix-iy = l1 then begin
               lFound:=True;
               ScanUpBufr := succ(iy);
            end;
            inc(iy);
            Inc(OldPointer);
         until (ix >= n) or (iy>= n) or lFound;
      end;

   end;

end;

Function AT(const S,S1:String):byte;
begin
   AT := POS(s,s1);
end;

Function SubStr;  {(s : String; b,l : integer) : String;}
var
   st : String;
   i  : integer;
begin
   st := '';
   if b < 0 then b := 1;
   st := system.copy(s, b, l);
   SubStr := st;
end;


Function  ConvertChar(C:Char;Table:pCodeTable):char;
begin
   If Table <> NIL then
      ConvertChar:=Table^[Byte(C)];
end;



Function ConvertStr(S:String;Table:pCodeTable):String;
Var i:integer;
begin
   If Table <> NIL then begin
      For i:=1 to length(S) do begin
         S[i]:=Table^[Byte(S[i])];
      end;
   end;
   ConvertStr:=S;
end;


{-----------------------------------------------}
Function ReplaceAll(S:string;const Search,Repl:string):String;
var p:byte;
begin
   Repeat
      p:=Pos(Search,S);
      If p>0 then begin
         Delete(S,p,Length(Search));
         Insert(Repl,S,p);
      end;
   until (p=0);
   ReplaceAll:=S;
end;


end.
