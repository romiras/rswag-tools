Unit gsF_Disk;
{------------------------------------------------------------------------------
                               Disk File Handler

       gsF_Disk Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit handles the objects for all untyped disk file I/O.

   Changes:
      08 Aug 20 - Changed GSxxxObjectColl name to GSxxxFileColl to better
                  indicate what the object is.

    !!RFG 082097  Added dfReadCount and dfWriteCount to GSO_Diskfile object
                  to track I/O activity for benchmark/tuning efforts.
    !!RFG 020598  Removed Mutex waiting in gsUnlock to avoid possible
                  gridlock if another thread is attempting to lock and
                  owns the mutex.  This would prevent the other thread
                  from unlocking the record the first thread is waiting
                  for.
    !!RFG 022098  Removed code that automatically tried to open a file
                  in ReadOnly mode if it failed in ReadWrite.  This was
                  included originally to allow CD-Rom files to be opened
                  without changing the mode in the program.  It causes a
                  problem when opening against a file already opened in
                  Exclusive mode.
------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}
interface
uses
   Strings,
   gsF_Glbl,
   gsF_Eror,
   vString,
   gsF_Xlat,
   gsF_Date,
   gsF_DOS;

const
   GSwrdAccessSeconds : word = 2;

{private}
type

   GSP_DiskFile = ^GSO_DiskFile;
   GSO_DiskFile = Object (GSobjBaseObject)
      dfFileHndl : integer;
      dfFileErr  : integer;    {I/O error code}
      dfFileExst : boolean;    {True if file exists}
      dfFileName : PChar;      {File Name}
      dfFilePosn : longint;    {File Position}
      dfFileShrd : boolean;    {Is the File shared? True if shared}
      dfFileMode : byte;       {File Open Mode}
      dfFileFlsh : GSsetFlushStatus; {File Flush Status}
      dfReadOnly : boolean;    {ReadOnly Flag}
      dfGoodRec  : longint;
      dfLockRec  : Boolean;
      dfFileLocked: Boolean;   {True if the File is locked}
      dfLockPos  : Longint;    {Lock Position}
      dfLockLth  : Longint;    {Lock Length  }
      dfHideError: integer;
      dfHasWritten: boolean;   {True if has written}
      dfClosed   : boolean;    {True if the file is closed}
      dfAutoShare: boolean;    {True if AUTO sharing used}
      dfDirtyReadLmt : longint;
      dfDirtyReadMin : longint;
      dfDirtyReadMax : longint;
      dfDirtyReadRng : longint;
      dfLockStyle    : GSsetLokProtocol; {Lock Style}
      dfReadCount    : longint;                 {!!RFG 082097}
      dfWriteCount   : longint;                 {!!RFG 082097}

      Constructor  Create(const Fname: String; Fmode: byte); {Create File Obj}
      destructor   Destroy; virtual;                         {Destroy File Obj}
      Procedure    FoundError(Code, Info:integer; StP: PChar); virtual;
      Function     gsClose: boolean; virtual;                {Close File}
      Function     gsFileSize : longint; virtual;            {File Size}
      Function     gsFlush: boolean; virtual;                {Flush File}
      Function     gsLockFile : Boolean; virtual;            {Lock File}
      Function     gsLockRecord(FilePosition,FileLength: LongInt): Boolean; virtual;
      Function     gsRead(blk : longint; var dat; len : longint): Boolean; virtual;
      Function     gsReset: Boolean; virtual;                {Reset File}
      Function     gsReWrite: Boolean; virtual;              {Rewrite File}
      Function     gsSetFlushCondition(Condition : GSsetFlushStatus): Boolean;
      Procedure    gsSetLockProtocol(LokProtocol: GSsetLokProtocol); virtual;
      Procedure    gsStatusUpdate(stat1,stat2,stat3 : longint); virtual;
      Procedure    gsStatusLink(stat1,stat2,stat3 : longint);
      Function     gsTestForOk(Code, Info : integer): boolean;
      Function     gsTruncate(loc : longint): Boolean; virtual;{Truncate File}
      Function     gsUnLock : Boolean; virtual;
      Function     gsWrite(blk : longint; var dat; len : longint): Boolean; virtual;
   end;

Procedure GS_ClearLocks;
Function  GS_FileActiveHere(FilName: PChar): GSP_DiskFile;

{------------------------------------------------------------------------------
                            IMPLEMENTATION SECTION
------------------------------------------------------------------------------}

implementation

type
   GSptrFileColl = ^GSobjFileColl;
   GSobjFileColl = object(GSobjCollection)
      constructor Create;
      Destructor Destroy; virtual;
      procedure FreeAll;
      procedure FreeItem(Item: Pointer); virtual;
   end;

var
   FileLog       : GSptrFileColl;

{------------------------------------------------------------------------------
                              Global Routines
------------------------------------------------------------------------------}

Function GS_FileActiveHere(FilName: PChar): GSP_DiskFile;
var
   i    : integer;
   optr : GSP_DiskFile;
   ok: boolean;
begin
   GS_FileActiveHere := nil;
   ok := false;
   if (FileLog <> nil) and (FileLog^.Count > 0) then
   begin
      i := 0;
      while (not ok) and (i < FileLog^.Count) do
      begin
         optr :=  FileLog^.Items^[i];
         with optr^ do
            if StrComp(FilName,dfFileName) = 0 then
            begin
               ok := true;
               GS_FileActiveHere := optr;
            end;
         inc(i);
      end;
   end;
   if not ok then
      GS_FileActiveHere := nil;
end;


Procedure GS_ClearLocks;
var
   i    : integer;
   optr : GSP_DiskFile;
begin
   if (FileLog <> nil) and (FileLog^.Count > 0) then
   begin
      for i := 0 to FileLog^.Count-1 do
      begin
         optr :=  FileLog^.Items^[i];
         with optr^ do
            if dfLockRec then
               GS_UnLockFile(dfFileHndl,dfLockPos,dfLockLth);
      end;
   end;
end;


{------------------------------------------------------------------------------
                              GSO_DiskFile
------------------------------------------------------------------------------}

Constructor GSO_DiskFile.Create(const Fname: String; Fmode: byte);
var
   FNup : array[0..259] of char;
   Attr : integer;
begin
   inherited Create;
   StrPCopy(FNup,GSGetExpandedFile(Fname));
   StrUpperCase(FNup, StrLen(FNup));
   dfFileMode := Fmode;
   dfFileShrd := dfFileMode > 8;
   dfFileName := StrGSNew(FNup);
   Attr := GSGetFAttr(StrPas(FNup));
   dfFileExst := Attr >= 0;
   if Attr = -1 then
      Attr := 0;
   if (Attr and $01) > 0 then    {is the file Read-Only?}
      dfFileMode := dfFileMode and $F8;  {Then force read only}
   dfReadOnly := ((dfFileMode and $07) = 0);
   dfFilePosn := 0;
   dfFileHndl := 0;
   dfLockRec := false;
   dfFileLocked := false;
   dfFileFlsh := NeverFlush;
   dfHideError := 0;
   dfHasWritten := false;
   dfClosed := true;
   dfAutoShare := true;
   dfReadCount := 0;
   dfWriteCount := 0;

   {Default to FoxPro Record Locking Protocol}

   dfLockStyle       := Default;
   dfDirtyReadLmt    := $FFFFFFFF;
   dfDirtyReadMin    := $40000000;
   dfDirtyReadMax    := $7FFFFFFE;
   dfDirtyReadRng    := $3FFFFFFF;
   ObjType := GSobtDiskFile;
end;

destructor GSO_DiskFile.Destroy;
begin
   gsClose;
   StrGSDispose(dfFileName);
   inherited Destroy;
end;

Procedure GSO_DiskFile.FoundError(Code, Info:integer; StP: PChar);
begin
   FoundPgmError(Code,Info,StP);
end;

Function GSO_DiskFile.gsClose: boolean;
begin
   if not dfClosed then
   begin
      dfFileErr := 0;
      if (FileLog <> nil) and (FileLog^.IndexOf(@Self) <> -1) then
         FileLog^.Delete(@Self);
      if GS_FileActiveHere(dfFileName) <> nil then
      begin
         if dfHasWritten then gsFlush;
      end
      else
      begin
         if dfLockRec then gsUnLock;
         GSFileClose(dfFileHndl);
         dfClosed := true;
         dfFilePosn := 0;
         dfFileHndl := 0;
      end;
   end;
   gsClose := true;
end;

Function GSO_DiskFile.gsFileSize : longint;
var
   fs: longint;
begin
   fs := GSFileSeek(dfFileHndl,0,2);
   if fs = -1 then
      dfFileErr := GSGetLastError
   else
      dfFileErr := 0;
   gsTestForOK(dfFileErr,dskFileSizeError);
   gsFileSize := fs;
end;

Function GSO_DiskFile.gsFlush: boolean;
begin
   gsFlush := false;
   if not dfHasWritten then
   begin
      gsFlush := true;
      exit;
   end;
   if dfClosed then exit;
   dfFileErr := GS_Flush(dfFileHndl);
   dfHasWritten := false;
   gsFlush := gsTestForOk(dfFileErr,dskFlushError);
end;

Function GSO_DiskFile.gsLockFile : Boolean;
begin
   if dfFileShrd then
      gsLockFile :=  gsLockRecord(0,dfDirtyReadLmt)
   else
      gsLockFile := true;
end;

Function GSO_DiskFile.gsLockRecord(FilePosition,FileLength: LongInt): boolean;
var
   hour: word;
   min: word;
   sec: word;
   sec100: word;
   limitsec: word;
   startsec: word;
begin
   if (not dfFileShrd) then dfFileErr := 1
   else
   begin
      if dfLockRec then
      begin
         if (FilePosition = dfLockPos) and (FileLength = dfLockLth) then
            dfFileErr := 0
         else
            dfFileErr := dosLockViolated;
      end
      else
      begin
         dfLockPos := FilePosition;
         dfLockLth := FileLength;
         dfFileErr := GS_LockFile(dfFileHndl,dfLockPos,dfLockLth);
         if not (dfFileErr in [0,1]) then
         begin
            gsGetTime(hour,min,sec,sec100);
            startsec := sec;
            limitsec := sec+GSwrdAccessSeconds;
            repeat
               dfFileErr := GS_LockFile(dfFileHndl,dfLockPos,dfLockLth);
               GSCheckMessages;
               gsGetTime(hour,min,sec,sec100);
               if sec < startsec then sec := sec+60;
            until (dfFileErr in [0,1]) or (sec > limitsec);
         end;
         dfLockRec := dfFileErr = 0;
         if dfLockRec then
            dfFileLocked := (FilePosition = 0) and (FileLength = dfDirtyReadLmt);
      end;
   end;
   gsLockRecord := dfFileErr = 0;
end;

Function GSO_DiskFile.gsRead(blk : longint; var dat; len : longint): Boolean;
var
   fs: longint;
   hour: word;
   min: word;
   sec: word;
   sec100: word;
   limitsec: word;
   startsec: word;
begin
   if blk = -1 then blk := dfFilePosn;
   fs := GSFileSeek(dfFileHndl, blk, 0);
   IF fs <> -1 THEN               {If seek ok, read the record}
   BEGIN
      dfFileErr := 0;
      dfGoodRec := GSFileRead(dfFileHndl, dat, len);
      if dfGoodRec = -1 then
         dfFileErr := GSGetLastError;
      if dfFileErr = 0 then dfFilePosn := (blk+len);
   end
   else
      dfFileErr := GSGetLastError;
   if dfFileErr <> 0 then
   begin
      gsGetTime(hour,min,sec,sec100);
      startsec := sec;
      limitsec := sec+GSwrdAccessSeconds;
      repeat
         fs := GSFileSeek(dfFileHndl, blk, 0);
         IF fs <> -1 THEN               {If seek ok, read the record}
         BEGIN
            dfFileErr := 0;
            dfGoodRec := GSFileRead(dfFileHndl, dat, len);
            if dfGoodRec = -1 then
               dfFileErr := GSGetLastError;
            if dfFileErr = 0 then dfFilePosn := (blk+len);
         end
         else
            dfFileErr := GSGetLastError;
         GSCheckMessages;
         gsGetTime(hour,min,sec,sec100);
         if sec < startsec then sec := sec+60;
      until (dfFileErr = 0) or (sec > limitsec);
   end;
   gsRead := gsTestForOk(dfFileErr,dskReadError);
   if dfFileErr = 0 then
   begin                            {!!RFG 082097}
      inc(dfReadCount);             {!!RFG 082097}
      if dfGoodRec < len then
      begin
         dfFileErr := gsShortDiskRead;
         gsRead := false;
      end;                          {!!RFG 082097}
   end;
end;

Function GSO_DiskFile.gsReset: Boolean;
var
   WrkMode : byte;
   FilePtr : GSP_DiskFile;
begin
   dfFileErr := 0;
   FilePtr :=  GS_FileActiveHere(dfFileName);
   if FilePtr = nil then
   begin
      WrkMode := dfFileMode;
      dfFileHndl := GSFileOpen(StrPas(dfFileName),WrkMode);
      if dfFileHndl = -1 then
         dfFileErr := GSGetLastError;
(*                                                   {!!RFG 022098}
      if (dfFileErr <> 0) and (not dfReadOnly) then
      begin                                 {if not read only}
         WrkMode := dfFileMode and $F8;  {Then force read only}
         dfFileHndl := GSFileOpen(StrPas(dfFileName),WrkMode);
         if dfFileHndl = -1 then
            dfFileErr := GSGetLastError
         else
            dfFileErr := 0;
      end;
      dfReadOnly := ((dfFileMode and $07) = 0);
*)
      if (dfFileErr = 0) and (not dfReadOnly) then
      begin
         if dfFileShrd then
         begin
            inc(dfHideError);
            gsLockRecord(0,1);
            if dfFileErr = 0 then
            begin
               gsUnLock;
            end
            else
            begin
               dfFileShrd := false;
            end;
            dfFileErr := 0;
            dec(dfHideError);
         end;
      end;
   end
   else
   begin
      dfFileShrd := FilePtr^.dfFileShrd;
      dfFileHndl := FilePtr^.dfFileHndl;
   end;
   if dfFileErr = 0 then
   begin
      dfFilePosn := 0;
      if FileLog = nil then
         FileLog := New(GSptrFileColl, Create)
      else
         if FileLog^.IndexOf(@Self) = -1 then FileLog^.Insert(@Self);
      dfClosed := false;
   end;
   gsReset := gsTestForOK(dfFileErr,dskResetError);
end;

Function GSO_DiskFile.gsReWrite: Boolean;
begin
   if GS_FileActiveHere(dfFileName) <> nil then
      dfFileErr := dosInvalidAccess
   else
   begin
      dfFileHndl := GSFileCreate(StrPas(dfFileName));
      if dfFileHndl <> -1 then
      begin
         GSFileClose(dfFileHndl);
         gsReset;
         dfFileErr := 0;
      end
      else
         dfFileErr := GSGetLastError;;
   end;
   gsRewrite := gsTestForOk(dfFileErr,dskRewriteError);
end;

Function GSO_DiskFile.gsSetFlushCondition(Condition : GSsetFlushStatus): Boolean;
begin
   dfFileFlsh := Condition;
   gsSetFlushCondition := true;
end;

Procedure GSO_DiskFile.gsSetLockProtocol(LokProtocol: GSsetLokProtocol);
begin
   dfLockStyle := LokProtocol;
   case LokProtocol of
      DB4Lock  : begin
                    dfDirtyReadMin := $40000000;
                    dfDirtyReadMax := $EFFFFFFF;
                    dfDirtyReadRng := $B0000000;
                 end;
      ClipLock : begin
                    dfDirtyReadMin := 1000000000;
                    dfDirtyReadMax := 1000000000;
                    dfDirtyReadRng := 1000000000;
                 end;
      Default,
      FoxLock  : begin
                    dfDirtyReadMin := $40000000;
                    dfDirtyReadMax := $7FFFFFFE;
                    dfDirtyReadRng := $3FFFFFFF;
                 end;
   end;
end;

Procedure GSO_DiskFile.gsStatusUpdate(stat1,stat2,stat3 : longint);
begin
end;

Procedure GSO_DiskFile.gsStatusLink(stat1,stat2,stat3 : longint);
begin
   gsStatusUpdate(stat1,stat2,stat3);
end;

Function GSO_DiskFile.gsTestForOk(Code, Info : integer): boolean;
begin
   if Code <> 0 then
      GSSetLastError(Code);                   {!!RFG 022098}
   if (Code <> 0) and (dfHideError = 0) then
   begin
      FoundError(Code,Info,dfFileName);
      gsTestForOk := false;
   end
   else
      gsTestForOk := true;
end;

Function GSO_DiskFile.gsTruncate(loc : longint): Boolean;
begin
   if dfReadOnly or ((dfFileShrd) and (not dfFileLocked)) then
      dfFileErr := dosAccessDenied
   else
   begin
      if loc = -1 then loc := dfFilePosn;
      if not GSFileTruncate(dfFileHndl,loc) then
         dfFileErr := GSGetLastError;
      if dfFileErr = 0 then
   end;
   gsTruncate := gsTestForOk(dfFileErr,dskTruncateError);
end;

Function GSO_DiskFile.gsUnLock : Boolean;
var
   hour: word;
   min: word;
   sec: word;
   sec100: word;
   limitsec: word;
   startsec: word;
begin
   dfFileErr := 0;
   dfFileLocked := false;
   if dfLockRec then
      dfFileErr := GS_UnLockFile(dfFileHndl,dfLockPos,dfLockLth);
   if dfFileErr <> 0 then
   begin
      gsGetTime(hour,min,sec,sec100);
      startsec := sec;
      limitsec := sec+GSwrdAccessSeconds;
      repeat
         dfFileErr := GS_UnLockFile(dfFileHndl,dfLockPos,dfLockLth);
         GSCheckMessages;
         gsGetTime(hour,min,sec,sec100);
         if sec < startsec then sec := sec+60;
      until (dfFileErr in [0,1]) or (sec > limitsec);
   end;
   if dfLockRec then
      if (dfFileFlsh = UnLockFlush) and (not dfReadOnly) then gsFlush;
   dfLockRec := false;
   gsUnLock := gsTestForOk(dfFileErr,dskUnlockError);
end;

Function GSO_DiskFile.gsWrite(blk : longint; var dat; len : longint): boolean;
var
   hour: word;
   min: word;
   sec: word;
   sec100: word;
   limitsec: word;
   startsec: word;
   fs: longint;
begin
   if blk = -1 then blk := dfFilePosn;
   fs := GSFileSeek(dfFileHndl, blk, 0);
   IF fs <> -1 THEN               {If seek ok, read the record}
   BEGIN
      dfFileErr := 0;
      dfGoodRec := GSFileWrite(dfFileHndl, dat, len);
      if dfGoodRec = -1 then
         dfFileErr := GSGetLastError;
      if dfFileErr = 0 then dfFilePosn := (blk+len);
   end
   else
      dfFileErr := GSGetLastError;
   if dfFileErr <> 0 then
   begin
      gsGetTime(hour,min,sec,sec100);
      startsec := sec;
      limitsec := sec+GSwrdAccessSeconds;
      repeat
         fs := GSFileSeek(dfFileHndl, blk, 0);
         IF fs <> -1 THEN               {If seek ok, read the record}
         BEGIN
            dfFileErr := 0;
            dfGoodRec := GSFileWrite(dfFileHndl, dat, len);
            if dfGoodRec = -1 then
               dfFileErr := GSGetLastError;
            if dfFileErr = 0 then dfFilePosn := (blk+len);
         end
         else
            dfFileErr := GSGetLastError;
         GSCheckMessages;
         gsGetTime(hour,min,sec,sec100);
         if sec < startsec then sec := sec+60;
      until (dfFileErr = 0) or (sec > limitsec);
   end;
   if dfFileErr = 0 then
   begin
      inc(dfWriteCount);                      {!!RFG 082097}
      dfHasWritten := true;
      if dfFileFlsh = WriteFlush then gsFlush;
   end;
   gsWrite := gsTestForOk(dfFileErr,dskWriteError);
end;

{------------------------------------------------------------------------------
                               GSobjFileColl
------------------------------------------------------------------------------}

constructor GSobjFileColl.Create;
begin
   inherited Create(32,16);
   ObjType := GSobtFileColl;
end;

destructor GSobjFileColl.Destroy;
begin
   SetLimit(0);
   inherited Destroy;
end;

procedure GSobjFileColl.FreeAll;
begin
   Count := 0;
end;

procedure GSobjFileColl.FreeItem(Item: Pointer);
begin
end;


{------------------------------------------------------------------------------
                           Setup and Exit Routines
------------------------------------------------------------------------------}
var
   ExitSave      : pointer;

{$F+}
procedure ExitHandler;
begin
   GS_ClearLocks;
   if FileLog <> nil then
      FileLog^.Free;
   FileLog := nil;
   ExitProc := ExitSave;
end;
{$F-}




begin
   ExitSave := ExitProc;
   ExitProc := @ExitHandler;
   FileLog := New(GSptrFileColl, Create);

end.
