unit gsF_Memo;
{-----------------------------------------------------------------------------
                    dBase III/IV & FoxPro Memo File Handler

       gsF_Memo Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit handles the objects for all dBase III/IV Memo (.DBT)
       and FoxPro (.FPT) file operations.

   Changes:

      !!RFG 102097 Added FoundError virtual method to pass errors to the
                   owning DBF object.  This allows capture at a single
                   point regardless of the object that fails.

------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}
interface
uses
   Strings,
   gsF_Dos,
   gsF_Eror,
   gsF_Disk,
   vString,
   gsF_Xlat,
   gsF_Glbl;

{private}

const
   moHeaderSize = 32;

type

{!   moLineCode = (NoReturn, HardReturn, SoftReturn);}


   GSrecMemoHeader = packed record
      case byte of
         0 : (DBIV       : SmallInt;
              StartLoc   : SmallInt;
              LenMemo    : longint;);
         1 :  (Fox20     : longint;);
         2 :  (NextEmty  : longint;
               BlksEmty  : longint;);
         3 :  (BlkArray  :array[0..31] of char;);
   end;

   GSptrMemo = ^GSobjMemo;
   GSobjMemo  = object(GSO_DiskFile)
      Owner        : GSP_DiskFile;
      TypeMemo     : Byte;   {83 for dBase III; 8B for dBase IV; F5 for FoxPro}
      MemoBufPtr   : PChar;
      MemoBuffer   : PChar;
      MemoBufSize  : LongInt; {!VV - was integer}
      MemoLocation : Longint; {Current Memo record location}
      MemoBloksUsed: Longint;    {Memo Size in blocks}
      BytesPerBlok : longint; {Memo Block size}
      MemoChanged  : boolean; {Memo Changed Flag}
      MemoHeader   : GSrecMemoHeader;
{      MemoLineLen  : integer;}

      constructor Create(AOwner: GSP_DiskFile; const FName : String; DBVer, FM : byte);
      destructor  Destroy; virtual;
      Procedure   FoundError(Code, Info:integer; StP: PChar); virtual;
      procedure   moAdjustBuffer(NewSpace: longint);
      function    gsClose: boolean; virtual;
      procedure   moHuntAvailBlock(numbytes : longint); virtual;
      procedure   moMemoBlockRelease(rpt : longint); virtual;
      Procedure   moMemoClear;
      procedure   moMemoPutLast(ps: PChar); virtual;
      function    moMemoLock : boolean;
      procedure   moMemoSetParam(var bl: longint); virtual;
      function    moMemoOffSet: integer; virtual;
      procedure   gsOpen; virtual;
      Procedure   moMemo2File(blk: longint; const FileName:string);
      Function    moFile2Memo(blk: longint; const FileName:string):longint;
      procedure   moMemoRead(buf: pointer; blk: longint; var cb: longint);
      Procedure   moMemoSpaceUsed(blk: longint; var cb: longint);
      function    moMemoWrite(buf: pointer;var blk: longint;var cb: longint): longint;
(*!
      function    moFindLine(lnum: integer; var lstart, lend: PChar): integer;
      Procedure   moMemoDelLine(linenum : integer);
      function    moMemoGetLine(linenum : integer) : String;
      Procedure   moMemoInsert(linenum : integer; const st : String;
                             TypeRtn: moLineCode);
      Procedure   moMemoInsLine(linenum : integer; const st : String);
      function    moMemoLines : integer;
      procedure   moMemoGet(rpt : longint);
      function    moMemoPut(rpt : longint) : longint;
      procedure   moMemoWidth(l : integer);
*)
      function    moMemoSize(blk: longint): longint;
   end;

(*
   GSptrMemo3 = ^GSobjMemo3;
   GSobjMemo3 = object(GSobjMemo)
   end;

   GSptrMemo4 = ^GSobjMemo4;
   GSobjMemo4 = object(GSobjMemo)
      procedure   moMemoBlockRelease(rpt : longint); virtual;
      procedure   moHuntAvailBlock(numbytes : longint); virtual;
      procedure   moMemoPutLast(ps: PChar); virtual;
      procedure   moMemoSetParam(var bl: longint); virtual;
      function    moMemoOffSet: integer; virtual;
      procedure   gsOpen; virtual;
   end;
*)
   GSptrFXMemo20 = ^GSobjFXMemo20;
   GSobjFXMemo20 = object(GSobjMemo)
      constructor Create(AOwner: GSP_DiskFile; const FName : String; DBVer, FM : byte);
      procedure   moHuntAvailBlock(numbytes : longint); virtual;
      procedure   moMemoPutLast(ps: PChar); virtual;
      procedure   moMemoSetParam(var bl: longint); virtual;
      function    moMemoOffSet: integer; virtual;
      procedure   gsOpen; virtual;
   end;

{------------------------------------------------------------------------------
                            IMPLEMENTATION SECTION
------------------------------------------------------------------------------}

implementation

const
   WorkBlockSize = 32768; {Don't read from disk more than 32K bytes}
   MaxEditLength = 255;

{------------------------------------------------------------------------------
                                GSobjMemo
------------------------------------------------------------------------------}


CONSTRUCTOR GSobjMemo.Create(AOwner: GSP_DiskFile; const FName : String;
                           DBVer, FM : byte);
var
   ext : String[4];
   pth : String;
begin
   case DBVer of
         DB3WithMemo,
         DB4WithMemo : ext := '.DBT';
         VFP3File,
         FXPWithMemo : ext := '.FPT';
      end;
   pth := CapClip(FName,[' ','"']);
   pth := ChangeFileExt(pth,ext);
   inherited Create(pth,FM);
   Owner := AOwner;
   TypeMemo := DBVer;
   MemoBufPtr := nil;
   MemoBuffer := nil;
   MemoBufSize := 0;
   BytesPerBlok := dBaseMemoSize;
{!   MemoLineLen := 255;}
   MemoBloksUsed := 0;
   MemoLocation := 0;
   if not dfFileExst then
      gsTestForOk(dosFileNotFound, mmoInitError)
   else
   begin
      gsOpen;
      ObjType := GSobtDBTFile;
   end;
end;

destructor GSobjMemo.Destroy;
begin
   inherited Destroy;
end;

Procedure GSobjMemo.FoundError(Code, Info:integer; StP: PChar);
begin                                               {!!RFG 102097}
   if Owner <> nil then
      Owner^.FoundError(Code,Info,StP)
   else
      inherited FoundError(Code,Info,StP);
end;


Procedure GSobjMemo.moAdjustBuffer(NewSpace: longint);
var
   linetemp: PChar;
   lenchk: longint;
   sof: integer;
begin
   if MemoBufPtr <> nil then
      sof := (moMemoOffset)+StrLen(MemoBuffer)
   else
      sof := moMemoOffset;
   lenchk := sof+NewSpace+1;
   if lenchk > 65519 then
   begin
      FoundError(gsMemoAccessError, mmoMemoTooLarge, nil);
      exit;
   end;
   if lenchk > MemoBufSize then
   begin                        {get one extra block, just in case}
      lenchk := ((lenchk + BytesPerBlok) div BytesPerBlok) * BytesPerBlok;
      GetMem(linetemp, lenchk);
      FillChar(linetemp^,lenchk,#0);
      if MemoBufPtr <> nil then
      begin
         Move(MemoBufPtr^,linetemp^,MemoBufSize);
         FreeMem(MemoBufPtr, MemoBufSize);
      end;
      MemoBufPtr := linetemp;
      MemoBuffer := MemoBufPtr + moMemoOffset;
      MemoBufSize := lenchk;
   end;
end;

function GSobjMemo.gsClose: boolean;
begin
   moMemoClear;
   gsClose := inherited gsClose;
end;

procedure GSobjMemo.moHuntAvailBlock(numbytes : longint);
var
   BlksReq : longint;
   procedure NewDB3Block;
   begin
      gsRead(0, MemoHeader, moHeaderSize); {read header block from the .DBT}
      MemoLocation := MemoHeader.NextEmty;
      MemoHeader.NextEmty := MemoHeader.NextEmty + BlksReq;
      gsWrite(0, MemoHeader, moHeaderSize);
   end;

   procedure OldDB3Block;
   begin
      if MemoBloksUsed < BlksReq then NewDB3Block;
   end;

begin
   BlksReq := (numbytes+2+pred(BytesPerBlok)) div BytesPerBlok; {2 = $1A1A}
   if (MemoLocation > 0) then
      OldDB3Block
   else
      NewDB3Block;
   MemoBloksUsed := BlksReq;
   FillChar(MemoHeader, SizeOf(MemoHeader), #0);
end;

Procedure GSobjMemo.moMemoBlockRelease(rpt : longint);
begin                          {dummy to match GSobjMemo4.MemoBlockRelease}
end;


(*!
{Find line number, return with lstart = line begin, lend = next line begin}
{or nil if at the end of the memo.                                        }
{if line number not found, lstart and lend = nil; return highest line num}
function GSobjMemo.moFindLine(lnum: integer; var lstart, lend: PChar): integer;
var
   i: integer;
begin
   lend := MemoBuffer;
   lstart := nil;
   i := 0;
   while (lend <> nil) and (lend[0] <> #0) and (i < lnum) do
   begin
      inc(i);
      lstart := lend;
      while (not (lend[0] in [#0,#$0D,#$8D])) do inc(lend);
      if lend[0] <> #0 then
      begin
         inc(lend);
         if lend[0] = #$0A then inc(lend);
      end;
   end;
   if i <> lnum then
   begin
      lstart := nil;
      lend := nil;
   end;
   moFindLine := i;
end;
*)
{!
Procedure GSobjMemo.moMemoDelLine(linenum : integer);
var
   linestart: PChar;
   lineend: PChar;
begin
   linestart := nil;
   if MemoBufSize > 0 then
      if linenum > 0 then moFindLine(linenum, linestart, lineend);
   if linestart <> nil then
   begin
      if lineend <> nil then
         StrCopy(linestart,lineend)
      else
         linestart[0] := #0;
   end
   else
      FoundError(gsMemoAccessError, mmoMemoLineMissing, nil);
end;

function GSobjMemo.moMemoGetLine(linenum : integer) : String;
var
   linestart: PChar;
   lineend: PChar;
   linetemp: PChar;
   linechk: PChar;
begin
   linestart := nil;
   if MemoBufSize > 0 then
      if linenum > 0 then moFindLine(linenum, linestart, lineend);
   if linestart <> nil then
   begin
      GetMem(linetemp,succ(lineend-linestart));
      StrLCopy(linetemp,linestart,lineend-linestart);
      linechk := StrEnd(linetemp)-1;
      while (linechk >= linetemp) and (linechk[0] in [#$0D,#$0A,#$8D]) do
      begin
         linechk[0] := #0;
         dec(linechk);
      end;
      moMemoGetLine := StrPas(linetemp);
      FreeMem(linetemp,succ(lineend-linestart));
   end
   else
   begin
      moMemoGetLine := '';
   end;
end;

Procedure GSobjMemo.moMemoInsert(linenum : integer; const st : String;
                               TypeRtn: moLineCode);
var
   linestart: PChar;
   lineend: PChar;
   linetemp: PChar;
begin
   linestart := nil;
   GetMem(linetemp,length(st)+3);
   StrPCopy(linetemp,st);
   if TypeRtn = HardReturn then
      StrCat(linetemp,#$0D#$0A)
   else
      if TypeRtn = SoftReturn then
         StrCat(linetemp,#$8D#$0A);
   moAdjustBuffer(StrLen(linetemp));
   if (linenum = -1) or (linenum = 0) then
   begin
      StrCat(MemoBuffer,linetemp)
   end
   else
   begin
      if linenum > 0 then
      begin
         moFindLine(linenum, linestart, lineend);
         if linestart <> nil then
         begin
            Move(linestart[0], linestart[StrLen(linetemp)], StrLen(linestart));
            Move(linetemp[0],linestart[0],StrLen(linetemp));
         end
         else
            StrCat(MemoBuffer,linetemp)
      end
      else
      begin
         FreeMem(linetemp,length(st)+3);
         FoundError(gsMemoAccessError, mmoMemoLineMissing, nil);
         exit;
      end;
   end;
   FreeMem(linetemp,length(st)+3);
end;

Procedure GSobjMemo.moMemoInsLine(linenum : integer; const st : String);
begin
   moMemoInsert(linenum,st,HardReturn);
end;


Function GSobjMemo.moMemoLines : integer;
var
   linestart: PChar;
   lineend: PChar;
begin
   moMemoLines := moFindLine(MaxInt, linestart, lineend);
end;
}
Procedure GSobjMemo.moMemoClear;
begin
   if MemoBufPtr <> nil then FreeMem(MemoBufPtr, MemoBufSize);
   MemoBuffer := nil;
   MemoBufPtr := nil;
   MemoBufSize := 0;
end;


Function GSobjMemo.moMemoLock : boolean;
var
   rsl: boolean;
begin
   rsl := false;
   case dfLockStyle of
      DB4Lock  : begin
                    rsl := gsLockRecord(dfDirtyReadMax - 1, 2);
                 end;
      ClipLock : begin
                    rsl := gsLockRecord(dfDirtyReadMax, 1);
                 end;
      Default,
      FoxLock  : begin
                    rsl := gsLockRecord(dfDirtyReadMax - 1, 1);
                 end;
   end;
   moMemoLock := rsl;
   if not rsl then gsTestForOk(dfFileErr,dskLockError);
end;

(*!
Procedure GSobjMemo.moMemoGet(rpt : longint);
var
   cb: longint;
   lstart: PChar;
   lend: PChar;
   i: integer;
   v: integer;
   hc: char;
BEGIN                       { Get Memo Field }
   moMemoClear;
   MemoLocation := rpt;     {Save starting block number}
   MemoBloksUsed := 0;
   if rpt = 0 then exit;
   moMemoSpaceUsed(rpt, cb);
   moAdjustBuffer(cb);
   MemoBuffer := MemoBufPtr+moMemoOffset;
   MemoBloksUsed := (cb+pred(BytesPerBlok)) div BytesPerBlok;
   gsRead((rpt*BytesPerBlok), MemoBufPtr^, cb);
   if MemoLineLen < 1 then exit;  {Don't do wordwrap}

   lend := MemoBuffer;

   for i := moMemoOffset to cb-succ(moMemoOffset) do
      if lend[i] = #0 then lend[i] := '~';

   i := 0;
   while (lend <> nil) and (lend[0] <> #0) do
   begin
      inc(i);
      lstart := lend;
      lend := StrPos(lstart,#$0D);
      if lend = nil then
         lend := StrPos(lstart,#$8D);  {Check for soft return}
      if lend <> nil then
         v := lend - lstart
      else
         v := StrLen(lstart);
      if v > MemoLineLen then          {insert soft return}
      begin
         lend := lstart + MemoLineLen - 1;
         while (lend > lstart) and (lend[0] <> ' ') and (lend[0] <> '-') do
            dec(lend);
         if lend = lstart then
            lend := lstart + pred(MemoLineLen);
         hc := lend[0];
         lend[0] := #$0D;
         moMemoInsert(i+1,'',SoftReturn);
         lend[0] := hc;
         inc(lend,2);
      end
      else
      begin
         if lend <> nil then
         begin
            if lend[0] <> #0 then
               inc(lend);
            if lend[0] = #$0A then inc(lend);
         end;
      end;
   end;
end;

Function GSobjMemo.moMemoPut(rpt : longint) : longint;
var
   rsl : boolean;
   lstart: PChar;
   lend: PChar;
   bCnt : longint;                     {dB4 = bytes in memo; dB3 = zero}
   es: array[0..7] of char;
BEGIN                       { Put Memo Field }
   if dfFileShrd then
      rsl := moMemoLock
   else rsl := true;
   if not rsl then
   begin
      moMemoPut := rpt;
      exit;
   end;
   if MemoBuffer <> nil then
   begin
      lstart := MemoBuffer;
      while (lstart[0] <> #0) and (lstart[0] <> #$8D) do inc(lstart);
      if lstart[0] = #$8D then
      begin
         lend := lstart;
         inc(lend);
         if lend[0] = #$0A then inc(lend);
         while lend[0] <> #0 do
         begin
            lstart[0] := lend[0];
            inc(lend);
            inc(lstart);
            if lend[0] = #$8D then
            begin
               inc(lend);
               if lend[0] = #$0A then inc(lend);
            end;
         end;
         lstart[0] := #0;
      end;
      bCnt := StrLen(MemoBuffer);
   end
   else
      bcnt := 0;
   if bcnt = 0 then
   begin
      MemoLocation := 0;
      MemoBloksUsed := 0;
      moMemoClear;
      moMemoPut := 0;
      gsUnLock;
      exit;
   end;
   MemoLocation := rpt;
   moHuntAvailBlock(bCnt);
   if moMemoOffset > 0 then
      Move(MemoHeader,MemoBufPtr[0],moMemoOffset);
   StrCopy(es,'');
   moMemoPutLast(es);
   if StrLen(es) > 0 then
      moMemoInsert(-1,es,NoReturn);
   gsWrite(MemoLocation*BytesPerBlok, MemoBufPtr[0], MemoBloksUsed*BytesPerBlok);
   moMemoPut := MemoLocation;
   gsUnLock;
end;
*)

Procedure GSobjMemo.moMemoPutLast(ps: PChar);
begin
   StrCopy(ps,#$1A#$1A);
end;

Procedure GSobjMemo.moMemoSetParam(var bl: longint);
begin
   bl := 0;
end;

{!
Procedure GSobjMemo.moMemoWidth(l : integer);
begin
   MemoLineLen := l;
end;
}
Function GSobjMemo.moMemoOffset: integer;
begin
   moMemoOffset := 0;
end;

PROCEDURE GSobjMemo.gsOpen;
BEGIN
   if dfClosed then
      gsReset;     {If memo file, then open .DBT file}
END;

Procedure GSobjMemo.moMemoRead(buf: pointer; blk: longint; var cb: longint);
var
   pba: GSptrCharArray;               {pointer to BUF allocated}
   rsz: longint;
   rwk: longint;
   sof: longint;
BEGIN
   if cb = 0 then exit;
   MemoLocation := blk;               {Save starting block number}
   MemoBloksUsed := 0;                {Initialize blocks read}
   if MemoLocation = 0 then
   begin
      cb := 0;                        {blocks used = 0}
      pba := buf;
      pba^[0] := #0;                  {#0 -> BUF[0] }
      exit;
   end;
   moMemoSpaceUsed(blk, rsz);   {rsz = number of bytes used by memo}
   rsz := rsz - moMemoOffset;   {rsz = bytes used by text only     }
   if cb < rsz then             {if wanted to read less than rsz   }
      rsz := cb                 {  then we will read less :)       }
   else
      cb := rsz;                { else CB = real Memo Text size    }
   sof := moMemoOffset;         {offset in memo block (=8 bytes)   }

   MemoBloksUsed := (cb+sof+ pred(BytesPerBlok)) div BytesPerBlok;
                                {How many blocks occupied by memo  }
   repeat
      if rsz > WorkBlockSize then begin
         rwk := WorkBlockSize;          {how many to read in this step   }
         rsz := rsz - WorkBlockSize;    {the rest of memo not readed else}
      end else begin
         rwk := rsz;                    {read the last rest of memo      }
         rsz := 0;                      {all the memo rest will be readed}
      end;
      gsRead((blk*BytesPerBlok)+sof,buf^,rwk);
      inc(sof,rwk);                     {sof := sof+rwk;}
      buf := GSGetPointer(buf,rwk);     {shift buf pointer to +rwk}
   until rsz <= 0;
END;

{VV - new procedure for Writing Memo to a File}
Procedure GSobjMemo.moMemo2File(blk: longint; const FileName:string);
var
   buf: GSptrCharArray;               {pointer to BUF allocated}
   rsz: longint;
   rwk: longint;
   sof: longint;
   F  : integer;  {Output File handler}
BEGIN
   MemoLocation:=blk;
   if MemoLocation = 0 then exit;   {Exit if Memo Empty}
   GetMem(buf,WorkBlockSize);       {Allocate Memory for work buffer}
   F:=GsFileCreate(FileName); {Create the File}

   MemoLocation := blk;           {Save starting block number}
   MemoBloksUsed := 0;            {Initialize blocks read}
   moMemoSpaceUsed(blk, rsz);     {rsz = number of bytes used by memo}
   rsz := rsz - moMemoOffset;     {rsz = bytes used by text only     }
   sof := moMemoOffset;           {offset in memo block (=8 bytes)   }

   MemoBloksUsed := (rsz + sof+ pred(BytesPerBlok)) div BytesPerBlok;
                                  {How many blocks used by memo  }
   repeat
      if rsz > WorkBlockSize then begin
         rwk := WorkBlockSize;          {how many to read in this step   }
         rsz := rsz - WorkBlockSize;    {the rest of memo not readed else}
      end else begin
         rwk := rsz;                    {read the last rest of memo      }
         rsz := 0;                      {all the memo rest will be readed}
      end;
      gsRead((blk*BytesPerBlok)+sof,buf^,rwk);
      inc(sof,rwk);                     {sof := sof+rwk;}

      gsFileWrite(F,buf^,rwk);     {Write to the file rwk bytes}

   until rsz <= 0;

   gsFileClose(F);            {Close the File }
   FreeMem(buf,WorkBlockSize);{Dispose Memory of work buffer}
END;

{VV - new procedure for Writing File into the Memo}
Function GSobjMemo.moFile2Memo(blk: longint; const FileName:string):longint;
var
   buf: GSptrCharArray;               {pointer to BUF allocated}
   F  : integer;  {Output File handler}
var
   rsl : boolean;
   rsz : longint;
   rwk : longint;
   sof : longint;
   pb: PChar;
BEGIN
   If (not GsFileExists(FileName)) then exit; {Exit If No File     }
   GetMem(buf,WorkBlockSize);       {Allocate Memory for work buffer}
{   pb:=pointer(buf);}
   F:=GsFileOpen(FileName,fmOpenRead); {Open the File}

   moFile2Memo := blk;                  {It is Old Memo Location}

   if dfFileShrd then
      rsl := moMemoLock                 {Try to Lock the MEMO   }
   else rsl := true;

   if not rsl then begin
      moFile2Memo := 0;                 {Exit if can't lock     }
      exit;
   end;

   MemoLocation := blk;           {Remember Old Memo Location}
   rsz := gsf_dos.gsFileSize(FileName);     {Get count of bytes in the file}
   moHuntAvailBlock(rsz);         {If MemoSize>OldSize then New MemoLocation}
   sof := moMemoOffset;
   if sof > 0 then
      gsWrite(MemoLocation*BytesPerBlok, MemoHeader, sof);

   repeat
      if rsz > WorkBlockSize then begin
         rwk := WorkBlockSize;
         rsz := rsz - WorkBlockSize;
      end else begin
         rwk := rsz;
         rsz := 0;
      end;

      gsFileRead(F,buf^,rwk);     {Read from the file rwk bytes}
      gsWrite((MemoLocation*BytesPerBlok)+sof, buf^, rwk);
      sof := sof+rwk;
{      buf := GSGetPointer(buf,rwk);}
   until rsz <= 0;

{   buf:=GsPtrCharArray(pb);}

   GetMem(pb,BytesPerBlok);
   FillChar(pb[0],BytesPerBlok,#0);
   moMemoPutLast(pb);

   rwk := sof mod BytesPerBlok;

   if rwk > 0 then
      gsWrite((MemoLocation*BytesPerBlok)+sof, pb[0], BytesPerBlok - rwk);

   blk := MemoLocation;
   FreeMem(pb,BytesPerBlok);
   moFile2Memo := MemoLocation;
   gsUnLock;

   gsFileClose(F);            {Close the File }
   FreeMem(buf,WorkBlockSize);{Dispose Memory of work buffer}
END;

Procedure GSobjMemo.moMemoSpaceUsed(blk: longint; var cb: longint);
{Calculate Memo Length in BYTES (CB) started from the BLK block}
var
   ml: longint;
   mc: longint;
   fini: boolean;
   tblok: gsPtrByteArray;
BEGIN
   cb := moMemoOffset;             {get data offset in memo}
   if (blk = 0) then exit;         {exit if memo empty}

   gsRead(blk*BytesPerBlok, MemoHeader, moHeaderSize);
                                   {Read the beginning of memo}
   moMemoSetParam(cb);             {cb = Total Memo Length (bytes)}

   if moMemoOffset > 0 then
   begin                 {Test for Fox or DBIV memo}
      exit;              {Exit if FoxBase because all done}
   end;

   {Continue for DBIII}
   fini := false;
   ml := blk;                   {Save starting block number}
   cb := 0;                     {Let Memo length = 0 first }
   GetMem(tblok,BytesPerBlok);  {tblock - temp buffer for read}

   while (not fini) do          {loop until Done (EOF mark)}
   begin
      gsRead(ml*BytesPerBlok, tblok^, BytesPerBlok);
      inc(ml);                  {then we will read the next block}
      mc := 0;                  {byte counter in temp buf}
      while (mc < BytesPerBlok) and (fini = false) do
      begin
         inc(cb);               {how many blocks readed allready}
         if (tblok^[mc] = $1A) or (cb = 65520) then
         begin
            fini := true;       {Stop if EOF mark or too many blocks used}
            dec(cb);
         end;
         inc(mc);               {Step to next input buffer location}
      end;
   end;
   FreeMem(tblok,BytesPerBlok);
END;

function GSobjMemo.moMemoWrite(buf: pointer; var blk: longint;var cb: longint): longint;
var
   rsl : boolean;
   rsz : longint;
   rwk : longint;
   sof : longint;
   pb: PChar;
BEGIN
   moMemoWrite := blk;                  {It is Old Memo Location}
   if (cb = 0) and (blk = 0) then exit; {Exit If Memo Empty     }
   if dfFileShrd then
      rsl := moMemoLock                 {Try to Lock the MEMO   }
   else rsl := true;
   if not rsl then
   begin
      moMemoWrite := 0;                 {Exit if can't lock     }
      exit;
   end;

   MemoLocation := blk;                 {Remember Old Memo Location}
   rsz := cb;                     {Get count of bytes in memo field}
   moHuntAvailBlock(rsz);         {If MemoSize>OldSize then New MemoLocation}
   sof := moMemoOffset;
   if sof > 0 then
      gsWrite(MemoLocation*BytesPerBlok, MemoHeader, sof);
   repeat
      if rsz > WorkBlockSize then
      begin
         rwk := WorkBlockSize;
         rsz := rsz - WorkBlockSize;
      end
      else
      begin
         rwk := rsz;
         rsz := 0;
      end;
      gsWrite((MemoLocation*BytesPerBlok)+sof, buf^, rwk);
      sof := sof+rwk;
      buf := GSGetPointer(buf,rwk);
   until rsz <= 0;
   GetMem(pb,BytesPerBlok);
   FillChar(pb[0],BytesPerBlok,#0);
   moMemoPutLast(pb);
   rwk := sof mod BytesPerBlok;
   if rwk > 0 then
      gsWrite((MemoLocation*BytesPerBlok)+sof, pb[0], BytesPerBlok - rwk);
   blk := MemoLocation;
   FreeMem(pb,BytesPerBlok);
   moMemoWrite := MemoLocation;
   gsUnLock;
end;

function GSobjMemo.moMemoSize(blk: longint): longint;
{Calculate how many bytes are in MEMO field started from blk}
var
   cb: longint;
begin
   moMemoSpaceUsed(blk, cb);
   cb := cb-moMemoOffset;
   moMemoSize := cb;
end;

(*!
{------------------------------------------------------------------------------
                                GSobjMemo4
------------------------------------------------------------------------------}

procedure GSobjMemo4.moHuntAvailBlock(numbytes : longint);
var
   BlksReq : integer;
   WBlok1  : longint;
   WBlok2  : longint;
   WBlok3  : longint;

   procedure FitDB4Block;
   var
      match   : boolean;
   begin
      match := false;
      gsRead(0, MemoHeader, moHeaderSize);    {read header block from the .DBT}
      WBlok3 := gsFileSize div BytesPerBlok;
      if WBlok3 = 0 then     {empty file, fill up header block}
      begin
         inc(WBlok3);
         gsWrite(0, MemoHeader, moHeaderSize);
      end;
      with MemoHeader do
      begin
         WBlok1 := NextEmty;
         WBlok2 := 0;
         while not match and (WBlok1 <> WBlok3) do
         begin
            gsRead(WBlok1*BytesPerBlok, MemoHeader, moHeaderSize);
            if BlksEmty >= BlksReq then
            begin
               match := true;
               WBlok3 := NextEmty;
               if BlksEmty > BlksReq then      {free any blocks not needed}
               begin
                  WBlok3 := WBlok1+BlksReq;
                  BlksEmty := BlksEmty - BlksReq;
                  gsWrite(WBlok3*BytesPerBlok, MemoHeader, moHeaderSize);
               end;
            end
            else                            {new memo won't fit this chunk}
            begin
               WBlok2 := WBlok1;            {keep previous available chunk}
               WBlok1 := NextEmty;          {get next available chunk}
            end;
         end;
         if not match then WBlok3 := WBlok3 + BlksReq;
         gsRead(WBlok2*BytesPerBlok, MemoHeader, moHeaderSize);
         NextEmty := WBlok3;
         gsWrite(WBlok2*BytesPerBlok, MemoHeader, moHeaderSize);
      end;
   end;

begin
   BlksReq := ((numbytes+moMemoOffset) div BytesPerBlok)+1;
   if (MemoLocation > 0) then moMemoBlockRelease(MemoLocation);
   FitDB4Block;
   MemoLocation := WBlok1;
   MemoBloksUsed := BlksReq;
   MemoHeader.DBIV := -1;
   MemoHeader.StartLoc:= moMemoOffset;
   MemoHeader.LenMemo := numbytes+moMemoOffset;
end;

Procedure GSobjMemo4.moMemoBlockRelease(rpt : longint);
var
   blks     : longint;
begin
{   blks := MemoBloksUsed;}
   with MemoHeader do
   begin
      gsRead(rpt*BytesPerBlok, MemoHeader, moMemoOffset);
      blks := (BlksEmty + (BytesPerBlok-1)) div BytesPerBlok;
      gsRead(0, MemoHeader, moMemoOffset);
      BlksEmty := blks;
      gsWrite(rpt*BytesPerBlok, MemoHeader, moMemoOffset);
      NextEmty := rpt;
      BlksEmty := 0;
   end;
   gsWrite(0, MemoHeader, moMemoOffset);
end;

Procedure GSobjMemo4.moMemoPutLast(ps: PChar);
begin
end;

Procedure GSobjMemo4.moMemoSetParam(var bl: longint);
begin
   if MemoHeader.DBIV = -1 then
   begin
      bl := MemoHeader.LenMemo;
   end
   else
   begin
      gsTestForOk(gsBadDBTRecord, mmoMemoSetParamErr);
      bl := moMemoOffset;
   end;
end;

Function GSobjMemo4.moMemoOffset: integer;
begin
   moMemoOffset := 8;
end;

PROCEDURE GSobjMemo4.gsOpen;
var
   pb: pointer;
BEGIN
   if dfClosed then
   begin
      gsReset;     {If memo file, then open .DBT file}
      gsRead(0, MemoHeader, moHeaderSize);
      Move(MemoHeader.BlkArray[20],BytesPerBlok,SizeOf(longint));
      if gsFileSize < BytesPerBlok then
      begin
         GetMem(pb,BytesPerBlok);
         FillChar(pb^,BytesPerBlok,#0);
         Move(MemoHeader, pb^, gsFileSize);
         gsWrite(0, pb^, BytesPerBlok);
         FreeMem(pb,BytesPerBlok);
      end;
   end;
END;
*)

{------------------------------------------------------------------------------
                                GSobjFXMemo20
------------------------------------------------------------------------------}


procedure MakeLeft2RightInt(r: longint; var x);
var
   a:  array[0..3] of byte absolute x;
   ra: array[0..3] of byte absolute r;
begin
   a[0] := ra[3];
   a[1] := ra[2];
   a[2] := ra[1];
   a[3] := ra[0];
end;

Function MakeLongInt(var x): longint;
var
   a:  array[0..3] of byte absolute x;
   r:  longint;
   ra: array[0..3] of byte absolute r;
begin
   ra[0] := a[3];
   ra[1] := a[2];
   ra[2] := a[1];
   ra[3] := a[0];
   MakeLongInt := r;
end;

CONSTRUCTOR GSobjFXMemo20.Create(AOwner: GSP_DiskFile; const FName : String;
                               DBVer, FM : byte);
begin
   inherited Create(AOwner, FName,DBVer,FM);
   ObjType := GSobtFPTFile;
end;

procedure GSobjFXMemo20.moHuntAvailBlock(numbytes : longint);
var
   BlksReq : longint;

   procedure NewFoxBlock;
   begin
      with MemoHeader do
      begin
         gsRead(0, MemoHeader, moMemoOffset);  {read header block from the .DBT}
         MemoLocation := MakeLongInt(NextEmty);
         MakeLeft2RightInt(MemoLocation + BlksReq, NextEmty);
         gsWrite(0, MemoHeader, moMemoOffset);
      end;
   end;

   procedure OldFoxBlock;
   begin
      if MemoBloksUsed < BlksReq then NewFoxBlock;
   end;

begin
   BlksReq := ((numbytes+moMemoOffset) div BytesPerBlok)+1;
   if (MemoLocation > 0) then
      OldFoxBlock
   else
      NewFoxBlock;
   MemoBloksUsed := BlksReq;
   MakeLeft2RightInt(1,MemoHeader.BlkArray[0]);
   MakeLeft2RightInt(numbytes,MemoHeader.BlkArray[4]);
end;

Procedure GSobjFXMemo20.moMemoPutLast(ps: PChar);
begin
end;

Procedure GSobjFXMemo20.moMemoSetParam(var bl: longint);
{Real Memo Length = Text Memo Length + Memo Block Header Length}
begin
   if (MemoHeader.Fox20 = $01000000) or (MemoHeader.Fox20 = 0) then
   begin
      bl := MakeLongInt(MemoHeader.LenMemo)+moMemoOffset;
   end
   else

   begin
      gsTestForOk(gsBadDBTRecord, mmoMemoSetParamErr);
      bl := moMemoOffset;
   end;
end;

Function GSobjFXMemo20.moMemoOffset: integer;
{If FoxBase - Set Real Memo offset to 8 bytes from the memo begin}
begin
   moMemoOffset := 8;
end;

PROCEDURE GSobjFXMemo20.gsOpen;
BEGIN
   if dfClosed then
   begin
      gsReset;     {If memo file, then open .FPT file}
      gsRead(0, MemoHeader, moHeaderSize);
      BytesPerBlok := MakeLongInt(MemoHeader.BlkArray[4]) and $FFFF;
   end;
END;

end.

