Unit ZipUnit;
{$I GSF_FLAG.PAS}

InterFace
uses dos;

const
  CMP_BINARY = 0;
  CMP_ASCII  = 1;
  MAXBUFSIZE = $FFF2;

type
  BuffType = packed array [1..35256] of char;
  IntFunc  = function(var Buff:BuffType; var bSize:Word): Word;
  UserBuf  = array [0..MAXBUFSIZE] of char;
  UserBufType = ^UserBuf;
Var
  ZResult       : Integer;

Function Zip  (InPnt,ToPnt : Pointer; NumOfBytes: Word):Word; far;
Function UnZip(InPnt,ToPnt : Pointer; NumOfBytes: Word):Word; far;

Implementation

{$L IMPLODE.OBJ}

var
  DictionarySize:  Word;
  CompressionType: Word;
  Buffer:          Bufftype;
  ReadIndex:       Word;
  WriteIndex:      Word;
  BytesLeft:       Word;
  InBuf:           UserBufType;
  OutBuf:          UserBufType;

function Implode(Read:IntFunc;
                 Write:IntFunc;
                 var Buf:BuffType;
                 var Ctype:Word;
                 var bSize:Word): Integer; far; external;

function Explode(Read:IntFunc;
                 Write:IntFunc;
                 var Buf:BuffType): Integer; far; external;


function ReadData(var Buffer : BuffType; var BufferSize : Word): Word; far;
var BytesRead:Word;
begin
   If BufferSize > BytesLeft then BytesRead:=BytesLeft
                             else BytesRead:=BufferSize;
   Move(InBuf^[ReadIndex],Buffer,BytesRead);
   Dec(BytesLeft,BytesRead);
   Inc(ReadIndex,BytesRead);
   ReadData := BytesRead;
end;

function WriteData(var Buffer : BuffType; var BytesRead : Word): Word; far;
var byteswritten:Word;
begin
  Move(Buffer, OutBuf^[WriteIndex], BytesRead);
  Inc(WriteIndex,BytesRead);
  WriteData := BytesRead;
end;

Function Zip(InPnt,ToPnt : Pointer; NumOfBytes: Word):Word;
begin
  WriteIndex:=0;
  ReadIndex:=0;
  BytesLeft:=NumOfBytes;
  InBuf:=InPnt;
  OutBuf:=ToPnt;
  ZResult:=implode(ReadData,WriteData,Buffer,CompressionType,DictionarySize);
  Zip:=WriteIndex;
End;

Function UnZip(InPnt,ToPnt : Pointer; NumOfBytes: Word):Word;
begin
  WriteIndex:=0;
  ReadIndex:=0;
  BytesLeft:=NumOfBytes;
  InBuf:=InPnt;
  OutBuf:=ToPnt;
  ZResult := explode(ReadData,WriteData,Buffer);
  UnZip:=WriteIndex;
end;


begin
  DictionarySize  := 4096;
  CompressionType := CMP_BINARY;

end.



