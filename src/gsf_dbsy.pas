unit gsf_DBSy;
{-----------------------------------------------------------------------------
                          dBase III/IV File Handler

       gsf_DBSy Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit contains the objects to manipulate the data, index, and
       memo files that constitute a database.

   Changes:

      07/19/97 - Changed path work length in IndexTo to 260 bytes to allow
                 for long file names.

   !!RFG 082097  Added gsHuntDuplicate method to GSO_dBHandler.  This lets
                 the programmer check to see if the hunted key already
                 exists in the index.  Return value is a longint that holds
                 -1 if the tag cannot be found, 0 if the key does not
                 duplicate one already in the index, or the record number of
                 the first record with a duplicate key.

                 Added code in PostWrite NotifyEvent to set the new file
                 position properly when a record is updated. With
                 indexes, it will set the File_TOF/File_EOF if the new
                 indexed position is at the beginning or end of the
                 index.  In natural order, if the first or last record is
                 updated, the proper TOF/EOF flag is set.

    !!RFG 083097 In GSO_dBHandler.gsGetRec, added test for gsvIndexState so
                 that the I/O activity is reduced for indexing operations if
                 there are many rejected records via TestFilter or deleted
                 records.  This prevents the forced positioning of the file
                 to the last good record, which requires a reread and test of
                 every record.  This is needed during normal processing, but
                 is unnecessary in a controlled sequential read during
                 indexing.

   !!RFG 090297  added argument to CmprOEMBufr() to define the substitute
                 character to use for unequal field length comparisons.
                 Numeric fields in CDX indexes could fail.

   !!RFG 091297  Added testing for a corrupt index in IndexRoute and IndexTo.

   !!RFG 091297  Made gsIndex a function so error results could be returned.

   !!RFG 111297  Changed CopyFile and SortFile to use an index if it exists.

   !!RFG 111897  Ensured the memo files were properly closed in
                 gsCopyFromIndex.

   !!RFG 022198  Added code to gsGetRec to more efficiently handle a call
                 with RecNum set to 0.  It avoids recursion to find the
                 first record in the file.

   !!RFG 022798  In gsGetRec, reversed sequence of checking Filter and
                 Deleted conditions so that the deleted condition is
                 checked first.  This way the filter is not called for
                 deleted records when UseDeleted is false.

   !!RFG 031098  Corrected code in gsIndexFileRemove and gsIndexFileKill to
                 ensure IndexMaster is not nil before comparing its Owner
                 property to the target file object.

   !!RFG 032498  Changed gsSearchDBF so exact match compares ignore trailing
                 spaces.

   !!RFG 040698  Added code in gsPack to ensure record caching was cleared
                 in case deleted records were in cache as undeleted.

   !!RFG 041398  Added code in Reindex to call gsSetDBFCache(true) to use
                 cache to speed up sorting.  This can improve speed up to
                 50 percent for large files.

------------------------------------------------------------------------------}
{$I gsf_FLAG.PAS}
interface
uses
   Strings,
   gsf_Eror,
   gsf_Date,
   gsf_Xlat,
   vString,
{   gsf_Sort,}
   gsf_DOS,
   gsf_Disk,
   gsf_DBF,
   gsf_Expr,
   gsf_Indx,
   gsf_CDX,
{   gsf_MDX,
   gsf_NDX,
   gsf_NTX,
}
{   gsf_MIX,}
   gsf_Memo,
   gsf_Glbl;

{private}

const
   IndexesAvail    = 16{63};
   DBFCacheSize    : word = 32768;

type

{!   GSptrSortDB = ^GSobjSortDB;}

   GSP_dBHandler = ^GSO_dBHandler;
   GSO_dBHandler = object(GSO_dBaseFld)
      IndexMaster : GSptrIndexTag;
      PrimaryTagName: array[0..15] of char;
      IndexStack  : array[0..IndexesAvail] of GSptrIndexFile;
      CacheFirst  : Longint;
      CacheLast   : Longint;
      CachePtr    : GSptrByteArray;
      CacheRecs   : integer;
      CacheSize   : LongInt;
      CacheRead   : boolean;
      CacheAllowed: boolean;
      FilterRecord: boolean;
      gsvFound    : boolean;
      gsvFindNear : boolean;
      gsvRecRead  : boolean;
      DoingSort   : boolean;
      curMemo     : GSptrMemo;
      newMemo     : GSptrMemo;
      ReloadIndex : boolean;
      ActiveIndexChg: boolean;
      SearchMode  : word; {Mode flags for gsSearchDBF.  Default value is zero}
                          {Values are summed together for multiple conditions}
                          {1=Case Insensitive; 2=Use Exact; 4=Use Wildcards  }
                          {8=Use Filter; 16=Use Index; 32=Match at Start Only}

      constructor Create(const FName : String; FMode: byte);
      destructor  Destroy; virtual;
      Function    gsAppend: Boolean; virtual;
      function    gsClose: boolean; virtual;
{!      procedure   gsCopyFile(const filname: String);}
{!      procedure   gsCopyFromIndex(ixColl: GSptrSortDB; const filname: String);}
      procedure   gsCopyMemoRecord(df : GSP_dBHandler);
      procedure   gsCopyRecord(filobj: GSP_dBHandler);
      procedure   gsCopyStructure(const filname : String);
      function    gsDBFEvent(Event: dbFileEvent; Action: longint): boolean; virtual;
      Function    gsFind(const st : String) : boolean; virtual;
      function    gsGetKey(RecNum : Longint; var keyst: String): longint;
      function    gsGetRec(RecNum : LongInt): boolean; virtual;
{!      function    gsGrabRec(RecNum: longint): boolean;}
      Function    gsHuntDuplicate(const st, ky: String) : longint; virtual;
      Function    gsIndex(const INames, Tag: String): integer;   {!!RFG 091297}
      Procedure   gsIndexClear;
      function    gsIndexFileExtend(const IName: string): string;
      function    gsIndexFileIsOpen(const IName: string): integer;
      function    gsIndexFileRemove(const IName: String): integer;
      function    gsIndexFileKill(const IName: String): integer;
      function    gsIndexTagRemove(const IName, Tag: String): integer;
      procedure   gsIndexOrder(Value: integer);
      function    gsIndexPointer(Value: integer): GSptrIndexTag;
      function    gsIndexRoute(const IName: String): integer;
      function    gsIndexInsert(ix : GSptrIndexFile) : integer;
      Function    gsIndexTo(const IName, tag, keyexpr, forexpr: String;
                          uniq: GSsetIndexUnique;
                          ascnd: GSsetSortStatus): integer;
{!      Procedure   gsLoadToIndex(ixColl: GSptrSortDB; zfld: PChar);}
{      Function    gsMemoryIndexAdd(const tag, keyexpr, forexpr: String;
                     uniq: GSsetIndexUnique; ascnd: GSsetSortStatus): boolean;}
      Function    gsSetTagTo(const TName: String; SameRec: boolean): integer;
      Procedure   gsPack;
      Function    gsPutRec(RecNum : LongInt): Boolean; virtual;
      Procedure   gsRefresh;
      Procedure   gsReIndex;
      function    gsRead(blk : longint; var dat; len : longint): boolean; virtual;
      procedure   gsSetDBFCacheAllowed(tf: boolean);
      procedure   gsSetDBFCache(tf: boolean);
      procedure   gsResetRange;
      Procedure   gsSetRange(const RLo, RHi: String; LoIn, HiIn: boolean);
      procedure   gsSkip(RecCnt : LongInt); virtual;
{!      procedure   gsSortFile(const filname, zfld: String;
                           isascend : GSsetSortStatus);}
      function    gsTestFilter : boolean; virtual;
      Function    gsWithIndex: boolean; virtual;
      function    gsWrite(blk : longint; var dat; len : longint): boolean; virtual;
      Procedure   gsZap;
{      Function    gsSearchDBF(const s: String; var FNum : word;
                            var fromrec: longint; torec: longint): word;
}
      Procedure   gsSetLockProtocol(LokProtocol: GSsetLokProtocol); virtual;
      Function    gsLockIndexes: boolean; virtual;
      Function    gsUnLockIndexes: boolean;
   end;
{!
   GSobjSortDB = object(GSobjSort)
      curFile: GSP_dBHandler;
      newFile: GSP_dBHandler;
      KeyCnt: longint;
      procedure    OutputWord(Tag: Longint; Value: PChar); virtual;
   end;
}
implementation

const
   {$IFDEF DBASE3OK}
      IndexExt : string[4] = '.NDX';
   {$ELSE}
      {$IFDEF DBASE4OK}
         IndexExt : string[4] = '.MDX';
      {$ELSE}
         {$IFDEF FOXOK}
            IndexExt : string[4]= '.CDX';
         {$ELSE}
            {$IFDEF CLIPOK}
                IndexExt : string[4] = '.NTX';
            {$ENDIF}
         {$ENDIF}
      {$ENDIF}
   {$ENDIF}

constructor GSO_dBHandler.Create(const FName : String; FMode: byte);
var
   i : integer;
begin
   GSO_dBaseFld.Create(FName, FMode);
   if ObjType <> GSobtDBFFile then exit;
   ObjType := GSobtDBaseSys;
   CacheRead := false;
   CacheAllowed := true;
   CachePtr := nil;
   CacheFirst := -1;
   CacheLast := 0;
   FilterRecord := false;
   gsvFound := false;
   gsvFindNear := false;
   gsvRecRead := false;
   IndexMaster := nil;
   PrimaryTagName[0] := #0;
   for i := 1 to IndexesAvail do IndexStack[i] := nil;
   DoingSort := false;
   ObjType := GSobtDBaseSys;
   ReloadIndex := false;
   SearchMode := 0;
end;

destructor GSO_dBHandler.Destroy;
begin
   gsClose;
   inherited Destroy;
end;

{------------------------------------------------------------------------------
                              Record Processing
------------------------------------------------------------------------------}

Function GSO_dBHandler.gsLockIndexes: boolean;
VAR
   i: integer;
   j: integer;
   r: boolean;
BEGIN
   gsLockIndexes := false;
   for i := 1 to IndexesAvail do
      if (IndexStack[i] <> nil) and (IndexStack[i]^.DiskFile <> nil) then
      begin
         inc(IndexStack[i]^.DiskFile^.dfHideError);
         r := IndexStack[i]^.IndexLock;
         dec(IndexStack[i]^.DiskFile^.dfHideError);
         if not r then
         begin
            for j := 1 to i-1 do
               if IndexStack[j] <> nil then
               begin
                  IndexStack[j]^.DiskFile^.gsUnLock;
               end;
            gsSetLastError(dosLockViolated);
            FoundError(dosLockViolated,dbsBadIndexLock,
                       IndexStack[i]^.DiskFile^.dfFileName);
            exit;
         end;
      end;
   gsLockIndexes := true;
end;

Function GSO_dBHandler.gsUnlockIndexes: boolean;
VAR
   i: integer;
BEGIN
   for i := 1 to IndexesAvail do
      if (IndexStack[i] <> nil) and (IndexStack[i]^.DiskFile <> nil) then
      begin
         IndexStack[i]^.DiskFile^.gsUnLock;
      end;
   gsUnlockIndexes := true;
end;

Function GSO_dBHandler.gsAppend: boolean;
BEGIN
   gsAppend := false;
   if gsLockIndexes then
   begin
      gsAppend := inherited gsAppend;
      gsUnlockIndexes;
   end;
end;

function GSO_dBHandler.gsClose: boolean;
var
   i : integer;
begin
   gsClose := false;
   if dStatus <= NotOpen then exit;
   for i := 1 to IndexesAvail do
      if IndexStack[i] <> nil then
      begin
         IndexStack[i]^.Free;
         IndexStack[i] := nil;
      end;
   IndexMaster := nil;               {Set index active flag to false}
{   IndexHandle := -1;}
   if CachePtr <> nil then FreeMem(CachePtr, CacheSize);
   CachePtr := nil;
   CacheSize := 0;
   gsClose := GSO_dBaseFld.gsClose;
end;

function GSO_dBHandler.gsDBFEvent(Event: dbFileEvent; Action: longint): boolean;
var
   i: integer;
begin
   gsDBFEvent := inherited gsDBFEvent(Event, Action);
   case Event of
      dbPostWrite     : begin
                           ActiveIndexChg := false;
                           for i := 1 to IndexesAvail do
                           begin
                              if (IndexStack[i] <> nil) then
                              begin
                                 IndexStack[i]^.TagUpdate(RecNumber,Action = 0);
                              end;
                           end;
                           if IndexMaster <> nil then
                           begin
                              ActiveIndexChg := IndexMaster^.KeyUpdated;
                              IndexMaster^.KeySync(RecNumber, false);
                              File_TOF := IndexMaster^.TagBOF;
                              File_EOF := IndexMaster^.TagEOF;
                           end
                           else
                           begin
                              File_EOF := (Action = 0) or   {!!RFG 082097}
                                          (Action = NumRecs);
                              File_TOF := Action = 1;   {!!RFG 082097}
                           end;
                        end;
      dbFlush         : begin
                           if dStatus > NotOpen then
                           begin
                              for i := 1 to IndexesAvail do
                                 if (IndexStack[i] <> nil) and
                                    (IndexStack[i]^.DiskFile <> nil) then
                                    IndexStack[i]^.DiskFile^.gsFlush;
                           end;
                        end;
   end;
end;

Function GSO_dBHandler.gsFind(const st : String) : boolean;
var
   RNum   : longint;
   ps: GSptrIndexKeyData;
   dv: longint;
   c: char;
   sc: char;
begin
   gsvFound := false;
   gsFind := gsvFound;
   if NumRecs = 0 then exit;                    {!!RFG 022198}
   if dfLockStyle = ClipLock then
   begin
      if not gsLockIndexes then exit;
   end;
   if (IndexMaster <> nil) then
   begin
      ps := New(GSptrIndexKeyData, Create(256));
      ps^.ReplaceString(st);
      if IndexMaster^.KeyType = 'D' then
      begin
         IndexMaster^.JulDateStr(ps^.CharStr^,ps^.CharStr^,c);
         ps^.SizeStr := StrLen(ps^.CharStr^);
      end;
      ps^.Tag := IgnoreRecNum;
      RNum := IndexMaster^.KeyFind(ps);
      if RNum > 0 then                {RNum = 0 if no match, otherwise}
                                      {it holds the valid record number}
      begin
         if IndexMaster^.KeyType = 'C' then                   {!!RFG 090297}
             sc := ' '
         else
             sc := #0;
         gsvFound := false;
         GSO_dBaseDBF.gsGetRec(RNum);    {If match found, read the record}
         while ((not gsTestFilter) or
               (gsDelFlag and (not UseDeletedRec))) and
               (not File_EOF) do gsSkip(1);
         if not File_EOF then
         begin
            with IndexMaster^ do
            begin
               AdjustValue(ps);
               gsvFound := CmprOEMBufr(ps,CurKeyInfo,pCompareTbl,dv,sc) = 0;
               if not gsvFound then
                  if (not gsvExactMatch) and (dv > ps^.SizeStr) then   {!RFG 080597}
                     gsvFound := true;  {Non-Exact match test}
            end;
            if (not gsvFound) and (not gsvFindNear) then
            begin
               gsGetRec(Bttm_Record);
               File_EOF := True;
            end;
         end;
      end else
      begin                           {If no matching index key, then}
         gsvFound := False;              {Set Match Found Flag False}
         if (IndexMaster^.TagEOF) or (not gsvFindNear) then
         begin
            gsGetRec(Bttm_Record);
            File_EOF := True;
         end
         else
         begin
            RNum := IndexMaster^.KeyRead(-5);  {Read current index pos}
            gsGetRec(RNum);                        {read the record}
         end;
      end;
      ps^.Free;
   end else                           {If there is no index file, then}
   begin
      gsvFound := False;                 {Set Match Found Flag False}
      gsGetRec(Bttm_Record);
      File_EOF := True;
   end;
   if dfLockStyle = ClipLock then
   begin
      gsUnlockIndexes;
   end;
   gsFind := gsvFound;
end;                  {Find}

Function GSO_dBHandler.gsHuntDuplicate(const st, ky: String) : longint;
var
   im: GSptrIndexTag;
   ps: GSptrIndexKeyData;
   i: integer;
   c: char;
   pc: array[0..79] of char;
   em: boolean;
begin                                 {!!RFG 082097}
   gsHuntDuplicate := -1;
   if dfLockStyle = ClipLock then
   begin
      if not gsLockIndexes then exit;
   end;
   im := nil;
   StrPCopy(pc,st);
   i := 0;
   while (i < IndexesAvail) and (im = nil) do
   begin
      inc(i);
      if IndexStack[i] <> nil then
         im := IndexStack[i]^.TagByName(pc);
   end;
   if (im <> nil) then
   begin
      ps := New(GSptrIndexKeyData, Create(256));
      ps^.ReplaceString(ky);
      if im^.KeyType = 'D' then
      begin
         im^.JulDateStr(ps^.CharStr^,ps^.CharStr^,c);
         ps^.SizeStr := StrLen(ps^.CharStr^);
      end;
      ps^.Tag := IgnoreRecNum;
      em := gsvExactMatch;
      gsvExactMatch := true;
      gsHuntDuplicate := im^.HuntDuplicate(ps);
      gsvExactMatch := em;
      ps^.Free;
   end;
   if dfLockStyle = ClipLock then
   begin
      gsUnlockIndexes;
   end;
end;

function GSO_dBHandler.gsGetKey(RecNum : Longint; var keyst: String): longint;
begin
   if IndexMaster <> nil then
   begin
      gsGetKey := IndexMaster^.KeyRead(RecNum);
      keyst := IndexMaster^.CurKeyInfo^.GetString;
   end
   else
   begin
      keyst := '';
      gsGetKey := 0;
   end;
end;

function GSO_dBHandler.gsGetRec(RecNum : LongInt): boolean;
var
   inum  : longint;
   rnum  : longint;
   knum  : longint;
   cread : boolean;
   okread: boolean;
begin
   gsGetRec := false;
   gsvRecRead := false;
   if (RecNum = Same_Record) and (gsvRecRead) then exit;
{
   if dfLockStyle = ClipLock then
   begin
      if not gsLockIndexes then exit;
   end;
}
   inum := 0;
   cread := CacheRead;
   okread := false;
   File_EOF := false;
   File_TOF := false;
   rnum := RecNum;
   knum := RecNum;
   if (knum = Top_Record) or (knum = Same_Record) then knum := Next_Record
      else if knum = Bttm_Record then knum := Prev_Record;
   repeat
      if (IndexMaster <> nil) and (knum < 0) then
      begin
         CacheRead := false;
         rnum := IndexMaster^.KeyRead(rnum);
         inum := rnum;
         File_EOF := IndexMaster^.TagEOF;
         File_TOF := IndexMaster^.TagBOF;
      end;
      if (not File_EOF) and (not File_TOF) then   {Destroy if EOF reached}
      begin
         okread := inherited gsGetRec(rnum);        {!!RFG 022198}
         if not okread then                         {!!RFG 022198}
         begin                                      {!!RFG 022198}
            if (rnum = 0) or (rnum > numrecs) then  {!!RFG 022198}
               gsBlank;                             {!!RFG 022198}
            exit;                                   {!!RFG 022198}
         end;                                       {!!RFG 022198}
         gsGetRec := okread;                        {!!RFG 022198}
         if knum < 0 then                   {Destroy if physical record access}
            okread := (not (gsDelFlag and (not UseDeletedRec))) and
                       gsTestFilter;                {!!RFG 022798}
         rnum := knum;
      end;
   until okread or File_EOF or File_TOF;
   CacheRead := cread;
   if File_TOF then
   begin
      if (RecNum <> Top_Record) and (RecNum <> Bttm_Record) then
         gsGetRec := gsGetRec(Top_Record);   {Recursion for first filtered record}
      if File_TOF then
         gsBlank;
      File_TOF := True;
   end
   else
   if File_EOF then
   begin
(*!V!      if (RecNum <> Top_Record) and (RecNum <> Bttm_Record) and
         (not gsvIndexState) then                               {!!RFG 083097}
         gsGetRec := gsGetRec(Bttm_Record);  {Recursion for last filtered record}
*)
      if File_EOF then
         gsBlank;
      File_EOF := True;
   end;
   gsvRecRead := not (File_EOF or File_TOF);
   if IndexMaster <> nil then     {Resync index if necesary}
   begin
      if (RecNumber <> inum) and (gsvRecRead) then
         IndexMaster^.KeySync(RecNumber, ReloadIndex);
      ReloadIndex := false;
   end;
   if dfLockStyle = ClipLock then
   begin
      gsUnlockIndexes;
   end;
end;
{!
function GSO_dBHandler.gsGrabRec(RecNum : LongInt): boolean;
var
   ft: boolean;
   fe: boolean;
begin
   gsGrabRec := false;
   if (RecNum < 1) or (RecNum > NumRecs) then exit;
   ft := File_TOF;
   fe := File_EOF;
   gsGrabRec := gsRead(HeadLen+((RecNum-1) * RecLen), CurRecord^, RecLen);
   Move(CurRecord^, OrigRec^, RecLen);
   File_TOF := ft;
   File_EOF := fe;
end;
}
Function GSO_dBHandler.gsPutRec(RecNum : LongInt): boolean;
BEGIN
   gsPutRec := false;
   if gsLockIndexes then
   begin
      gsPutRec := inherited gsPutRec(RecNum);
      gsUnlockIndexes;
   end;
end;

function GSO_dBHandler.gsRead(blk : longint; var dat; len : longint): boolean;
begin
   if (not CacheRead) or (blk < HeadLen) then
      gsRead := inherited gsRead(blk,dat,len)
   else
   begin
      if (CacheFirst = -1) or
         (blk < CacheFirst) or
         (blk >= CacheLast-RecLen) then
      begin
         GSO_DiskFile.gsRead(blk,CachePtr^,CacheSize);
         CacheFirst := blk;
         CacheLast := (blk + dfGoodRec);
      end;
      if blk >= CacheLast then dfGoodRec := 0
      else
      begin
         dfGoodRec := RecLen;
         if DoingSort then
            CurRecord := @CachePtr^[blk - CacheFirst]
         else
            Move(CachePtr^[blk - CacheFirst],dat,RecLen);
      end;
      gsRead := dfGoodRec = len;
   end;
end;

procedure GSO_dBHandler.gsRefresh;
begin
   gsGetRec(Same_Record);
end;


Procedure GSO_dBHandler.gsSetDBFCacheAllowed(tf: boolean);
begin
   CacheAllowed := tf;
   if not tf then
      gsSetDBFCache(false);
end;

Procedure GSO_dBHandler.gsSetDBFCache(tf: boolean);
begin
   if not CacheAllowed then tf := false;
   if tf and CacheRead then exit;
   CacheRead := tf;
   if not tf then
   begin
      if CachePtr <> nil then FreeMem(CachePtr, CacheSize);
      CachePtr := nil;
      CacheSize := 0;
   end
   else
   begin
         CacheSize := MemAvail;
      if CacheSize > DBFCacheSize then
         CacheSize := DBFCacheSize
      else CacheSize := CacheSize - 16384;
      CacheSize := CacheSize - (CacheSize mod RecLen);
      if CacheSize < RecLen then CacheSize := RecLen;
      GetMem(CachePtr, CacheSize);
      CacheFirst := -1;
      CacheRecs := CacheSize div RecLen;
   end;
end;

Procedure GSO_dBHandler.gsResetRange;
begin
   if IndexMaster = nil then exit;
   IndexMaster^.SetRange(nil,false,nil,false);
end;

Procedure GSO_dBHandler.gsSetLockProtocol(LokProtocol: GSsetLokProtocol);
var
   i: integer;
begin
   inherited gsSetLockProtocol(LokProtocol);
   for i := 1 to IndexesAvail do
      if (IndexStack[i] <> nil) and (IndexStack[i]^.DiskFile <> nil) then
          IndexStack[i]^.DiskFile^.gsSetLockProtocol(LokProtocol);
end;

Procedure GSO_dBHandler.gsSetRange(const RLo, RHi: String; LoIn, HiIn: boolean);
var
   s1: GSptrString;
   s2: GSptrString;
begin
   if IndexMaster = nil then exit;
   s1 := New(GSptrString, Create(256));
   s2 := New(GSptrString, Create(256));
   s1^.ReplaceString(RLo);
   s2^.ReplaceString(RHi);
   IndexMaster^.SetRange(s1,LoIn,s2,HiIn);
   s2^.Free;
   s1^.Free;
   gsGetRec(Top_Record);
   if File_TOF then gsBlank;
end;

PROCEDURE GSO_dBHandler.gsSkip(RecCnt : LongInt);
VAR
   i  : integer;
   rn : longint;
   de : longint;
   dr : longint;
   rl : longint;
   rc : longint;
   im : pointer;

   procedure SkipFromDBF;
   begin
      rl := Recnumber + RecCnt;
      rc := rl;
      if (rl > NumRecs) then
      begin                         {flag out of file range}
         rc := 0;
         rl := NumRecs;
      end
      else
      if (rl < 1) then
      begin
         rc := 0;                   {flag out of file range}
         rl := 1;
      end;
   end;

   procedure SkipFromIndex;
   begin
      i := 1;
      repeat
         rc := IndexMaster^.KeyRead(dr);
         if rc > 0 then
            rl := rc
         else
            rl := IndexMaster^.KeyRead(de);
         inc(i);
      until (i > rn) or (rc = 0);
   end;


begin
   If RecCnt <> 0 then
   begin
      if RecCnt < 0 then de := Top_Record else de := Bttm_Record;
      rl := RecNumber;
      rn := abs(RecCnt);
      if RecCnt > 0 then dr := Next_Record else dr := Prev_Record;
      if (not FilterRecord) and UseDeletedRec then
      begin                                  {do fast skip}
         if (IndexMaster <> nil) then
         begin
            SkipFromIndex;
            if rl <> 0 then
            begin
               im := IndexMaster;
               IndexMaster := nil;
               gsGetRec(rl);
               IndexMaster := im;
            end;
         end
         else
         begin
            SkipFromDBF;
            gsGetRec(rl);
         end;
         if rc = 0 then
         begin
            File_EOF := de = Bttm_Record;
            File_TOF := de = Top_Record;
         end;
      end
      else
      begin
         repeat
            gsGetRec(dr);
            dec(rn);
         until (rn = 0) or File_EOF or File_TOF;
      end;
   end
   else gsGetRec(Same_Record);
end;

function GSO_dBHandler.gsTestFilter: boolean;
begin
   gsTestFilter := true;
end;

Function  GSO_dBHandler.gsWithIndex: boolean;
begin
   gsWithIndex := IndexStack[1] <> nil;
end;

function GSO_dBHandler.gsWrite(blk : longint; var dat; len : longint): boolean;
begin
   gsWrite := GSO_DiskFile.gsWrite(blk,dat,len);
   if blk = 0 then exit;
   if (CacheRead) then
   begin
      if (CacheFirst = -1) or
         (blk < CacheFirst) or
         (blk >= CacheLast-RecLen) then
      begin
      end
      else
         Move(dat,CachePtr^[blk - CacheFirst],len);
   end;
end;

{------------------------------------------------------------------------------
                              Index Processing
------------------------------------------------------------------------------}

function GSO_dBHandler.gsIndex(const INames, Tag: String): integer;  {!!RFG 091297}
var
   NameList: PChar;
   IName: PChar;
   NameListBegin: PChar;
   NameListEnd: PChar;
   NoLongName: boolean;
   rsl: integer;
begin
   rsl := 1;
   gsIndex := rsl;                                         {!!RFG 091297}
   gsIndexClear;
   if INames = '' then exit;
   GetMem(NameList,260);
   GetMem(IName,260);
   StrPCopy(NameList,INames);
   NameListBegin := NameList;
   NameListEnd := StrEnd(NameList);
   dec(NameListEnd);
   while (NameListEnd[0] in [' ',',',';']) and (NameListEnd >= NameListBegin) do
   begin
      NameListEnd[0] := #0;
      dec(NameListEnd);
   end;
   if StrLen(NameListBegin) > 0 then
   begin
      NameListEnd := NameListBegin;
      NoLongName := true;
      while NameListEnd[0] <> #0 do
      begin
         if NameListEnd[0] = '"' then NoLongName := not NoLongName;
         if NoLongName and (NameListEnd[0] in [' ',',',';']) then
            NameListEnd[0] := #9;
         inc(NameListEnd);
      end;
      repeat
         while NameListBegin[0] in [#9,'"'] do inc(NameListBegin);
         NameListEnd := NameListBegin;
         while not (NameListEnd[0] in [#9,'"',#0]) do inc(NameListEnd);
         StrLCopy(IName,NameListBegin,NameListEnd-NameListBegin);
         if StrLen(NameListBegin) > 0 then
            rsl := gsIndexRoute(StrPas(IName));    {!!RFG 091297}
         NameListBegin := NameListEnd;
      until (rsl <> 0) or (NameListEnd[0] = #0);   {!!RFG 091297}
      if rsl = 0 then                              {!!RFG 091297}
         gsSetTagTo(Tag,true);
   end;
   gsIndex := rsl;                                 {!!RFG 091297}
   FreeMem(NameList,260);
   FreeMem(IName,260);
end;

function GSO_dBHandler.gsIndexFileExtend(const IName: string): string;
var
   IFile: String;
begin
   IFile := AnsiUpperCase(IName);
   if ExtractFilePath(IFile) = '' then
      IFile := ExtractFilePath(StrPas(dfFileName))+ IFile;
   gsIndexFileExtend := ChangeFileExtEmpty(IFile,IndexExt);
end;

function GSO_dBHandler.gsIndexFileIsOpen(const IName: string): integer;
var
   i: integer;
begin
   gsIndexFileIsOpen := 0;;
   for i := 1 to IndexesAvail do
   begin
      if IndexStack[i] <> nil then
         if IndexStack[i]^.IsFileName(IName) then
            gsIndexFileIsOpen := i;
   end;
end;

function GSO_dBHandler.gsIndexFileRemove(const IName: String): integer;
var
   iz: integer;
begin
   gsIndexFileRemove := 1;
   if IName = '' then exit;
   iz := gsIndexFileIsOpen(IName);
   if iz = 0 then exit;
   if (IndexMaster <> nil) and (IndexMaster^.Owner = IndexStack[iz]) then
      gsSetTagTo('',true);
   IndexStack[iz]^.Free;
   IndexStack[iz] := nil;
   gsIndexFileRemove := 0;
end;

function GSO_dBHandler.gsIndexFileKill(const IName: String): integer;  {!!RFG 091397}
var
   iz: integer;
   b: boolean;
begin
   gsIndexFileKill := 1;
   if IName = '' then exit;
   if not GSFileExists(IName) then exit;
   iz := gsIndexFileIsOpen(IName);
   if iz > 0 then
   begin
      if (IndexMaster <> nil) and (IndexMaster^.Owner = IndexStack[iz]) then
         gsSetTagTo('',true);
      IndexStack[iz]^.Free;
      IndexStack[iz] := nil;
   end;
   if GSFileDelete(IName) <> 0 then
   begin
      iz := GSFileOpen(IName,fmOpenReadWrite+fmShareDenyNone);
      if iz > 0 then
      begin
         b := GSFileTruncate(iz,0);
         GSFileClose(iz);
         if not b then exit;
      end
      else exit;
   end;
   gsIndexFileKill := 0;
end;

Procedure GSO_dBHandler.gsIndexOrder(Value: integer);
var
   p: GSptrIndexTag;
begin
   p := gsIndexPointer(Value);
   if p <> nil then
      gsSetTagTo(StrPas(p^.TagName),true)
   else
      gsSetTagTo('',true);
end;

Function GSO_dBHandler.gsIndexPointer(Value: integer): GSptrIndexTag;
var
   i: integer;
   n: integer;
   n1: integer;
   p: GSptrIndexTag;
begin
   p := nil;
   if Value > 0 then
   begin
      n := 0;
      n1 := 0;
      i := 1;
      while (n < Value) and (i <= IndexesAvail) do
      begin
         if IndexStack[i] <> nil then
         begin
            n1 := n1 + IndexStack[i]^.TagCount;
            if n1 >= Value then
            begin
               n1 := Value - n;
               n := Value;
               p := IndexStack[i]^.TagByNumber(pred(n1));
            end
            else
               n := n1;
         end;
         inc(i);
      end;
   end;
   gsIndexPointer := p;
end;

function GSO_dBHandler.gsIndexTagRemove(const IName, Tag: String): integer;
var
   i   : integer;                     {Local working variable  }
   pc: array [0..16] of char;
   px: GSptrIndexTag;
   ix: GSptrIndexFile;
begin
   gsIndexTagRemove := 1;
   if Tag = '' then exit;
   StrPCopy(pc,CapClip(Tag,[' ']));
   ix := nil;
   px := nil;
   i := 0;
   while (i < IndexesAvail) and (px = nil) do
   begin
      inc(i);
      if IndexStack[i] <> nil then
      begin
         ix := IndexStack[i];
         px := ix^.TagByName(pc);
      end;
   end;
   if (px <> nil) and (px = IndexMaster) then
      gsSetTagTo('',true);
   if px <> nil then
   begin
      gsIndexTagRemove := -1;
      if ix^.DeleteTag(pc) then
      begin
         gsIndexTagRemove := 0;
         if ix^.TagCount = 0 then
            gsIndexFileRemove(ix^.GetFileName);
      end;
   end;
end;

function GSO_dBHandler.gsIndexRoute(const IName: String): integer;
var
   IExt: String[4];
   IFile: String;
   ix: GSptrIndexFile;
   IPC: PChar;
begin
   gsIndexRoute := 1;
   if IName = '' then exit;
   IFile := gsIndexFileExtend(IName);
   if (gsIndexFileIsOpen(IFile) <> 0)then exit;
   IExt := ExtractFileExt(IFile);
   ix := nil;
{$IFDEF FOXOK}
   if IExt = '.CDX' then
   begin
      ix := New(GSptrCDXFile, Create(@Self,IName,dfFileMode));
   end;
{$ENDIF}
{$IFDEF CLIPOK}
   if IExt = '.NTX' then
   begin
      ix := New(GSptrNTXFile, Create(@Self,IName,dfFileMode));
   end;
{$ENDIF}
{$IFDEF DBASE4OK}
   if IExt = '.MDX' then
   begin
      ix := New(GSptrMDXFile, Create(@Self,IName,dfFileMode));
   end;
{$ENDIF}
{$IFDEF DBASE3OK}
   if IExt = '.NDX' then
   begin
      ix := New(GSptrNDXFile, Create(@Self,IName,dfFileMode));
   end;
{$ENDIF}

   if (ix = nil) or (not ix^.CreateOK) then           {!!RFG 091297}
   begin
      GetMem(IPC, length(IFile)+1);
      StrPCopy(IPC, IFile);
      if (ix <> nil) and (ix^.Corrupted) then          {!!RFG 091297}
      begin
         FoundError(dbsIndexFileBad,gsfMsgOnly,IPC); {!!RFG 091297}
         gsIndexRoute := dbsIndexFileBad;              {!!RFG 091297}
      end
      else
      begin
         FoundError(dosFileNotFound,gsfMsgOnly,IPC);
         gsIndexRoute := dosFileNotFound;              {!!RFG 091297}
      end;
      FreeMem(IPC,length(IFile)+1);
      if ix <> nil then ix^.Free;                      {!!RFG 091297}
   end
   else
   begin
      gsIndexRoute := 0;
      gsIndexInsert(ix);
   end;
end;

Procedure GSO_dBHandler.gsIndexClear;
var
   i: integer;
begin
   for i := 1 to IndexesAvail do
      if IndexStack[i] <> nil then
      begin
         IndexStack[i]^.Free;
         IndexStack[i] := nil;
      end;
   IndexMaster := nil;               {Set index active flag to false}
   PrimaryTagName[0] := #0;
{   IndexHandle := -1;}
end;

Function GSO_dBHandler.gsIndexInsert(ix : GSptrIndexFile) : integer;
var
   i   : integer;                     {Local working variable  }
begin
   i := 1;
   while (IndexStack[i] <> nil) and (i <= IndexesAvail) do inc(i);
   if i <= IndexesAvail then
   begin
      IndexStack[i] := ix;
      gsIndexInsert := i;
   end else gsIndexInsert := -1;
end;

Function GSO_dBHandler.gsIndexTo(const IName, tag, keyexpr, forexpr: String;
                               uniq: GSsetIndexUnique;
                               ascnd: GSsetSortStatus): integer;
var
   IFile: array[0..259] of char;
   IWork: string;
   ITag: array[0..32] of char;
   IExt: String[4];
   FormK: array[0..255] of char;
   FormF: array[0..255] of char;
   crd: boolean;
   ix: GSptrIndexFile;
begin
   crd := CacheRead;
   gsIndexTo := 0;
   gsIndexClear;
   gsSetDBFCache(true);
   IWork := CapClip(IName,[' ','"']);
   IWork := gsIndexFileExtend(IWork);
   StrPCopy(IFile,IWork);
   ITag[0] := #0;
   if (length(Tag) < 32) and (length(Tag) > 0) then
      StrPCopy(ITag, Tag);
   IExt := AnsiUpperCase(ExtractFileExt(IName));
   if IExt = '' then IExt := IndexExt;
   StrPCopy(FormK,keyexpr);
   CompressExpression(FormK);
   if length(forexpr) > 0 then
      StrPCopy(FormF,forexpr)
   else
      FormF[0] := #0;
   CompressExpression(FormF);
   ix := nil;
{$IFDEF FOXOK}
   if IExt = '.CDX' then
   begin
      if (StrLen(ITag) = 0) then
      begin
         FoundError(cdxNoSuchTag,cdxInitError,'Tag Field is Empty');
         exit;           {Exit if formula is no good}
      end;
      ix := New(GSptrCDXFile, Create(@Self, StrPas(IFile), dfCreate));
      if ix <> nil then
      begin
         if ascnd in [AscendingGeneral, DescendingGeneral] then
         begin
            {$IFNDEF FOXGENERAL}
            FoundError(cdxNoCollateGen,cdxInitError,'General Collate Invalid');
            {$ENDIF}
            GSbytCDXCollateInfo := General;
         end
         else
            GSbytCDXCollateInfo := Machine;
      end;
   end;
{$ENDIF}
{$IFDEF DBASE4OK}
   if IExt = '.MDX' then
   begin
      if (StrLen(ITag) = 0) then
      begin
         FoundError(cdxNoSuchTag,cdxInitError,'Tag Field is Empty');
         exit;           {Exit if formula is no good}
      end;
      ix := New(GSptrMDXFile, Create(@Self, StrPas(IFile), dfCreate));
   end;
{$ENDIF}
{$IFDEF CLIPOK}
   if IExt = '.NTX' then
   begin
      StrPCopy(ITag,ExtractFileNameOnly(IName));
      ix := New(GSptrNTXFile, Create(@Self, StrPas(IFile), dfCreate));
   end;
{$ENDIF}
{$IFDEF DBASE3OK}
   if IExt = '.NDX' then
   begin
      StrPCopy(ITag,ExtractFileNameOnly(IName));
      ix := New(GSptrNDXFile, Create(@Self, StrPas(IFile), dfCreate));
   end;
{$ENDIF}
   if (ix <> nil) and (ix^.CreateOK) then
   begin
      ix^.Dictionary := ascnd in [AscendingGeneral, DescendingGeneral];
      if ascnd = AscendingGeneral then
         ascnd := Ascending
      else
         if ascnd = DescendingGeneral then
            ascnd := Descending;
      dState := dbIndex;
      ix^.AddTag(ITag, FormK, FormF, Ascnd=Ascending, Uniq=Unique);
      ix^.Free;
      dState := dbBrowse;
   end
   else
   begin
      if (ix <> nil) and (ix^.Corrupted) then            {!!RFG 091297}
         FoundError(dbsIndexFileBad,gsfMsgOnly,IFile)  {!!RFG 091297}
      else
         FoundError(dosFileNotFound,gsfMsgOnly,IFile);
      if ix <> nil then ix^.Free;
   end;
   gsSetDBFCache(crd);
end;

(*VV
Function GSO_dBHandler.gsMemoryIndexAdd(const tag, keyexpr, forexpr: String;
                                        uniq: GSsetIndexUnique;
                                        ascnd: GSsetSortStatus): boolean;
var
   ITag: array[0..32] of char;
   FormK: array[0..255] of char;
   FormF: array[0..255] of char;
   ix: GSptrIndexFile;
begin
   gsMemoryIndexAdd := false;
   if (tag = '') or (keyexpr = '') then exit;
   gsIndexFileRemove(Tag);
   if (length(Tag) < 32) and (length(Tag) > 0) then
      StrPCopy(ITag, AnsiUpperCase(Tag));
   StrPCopy(FormK,keyexpr);
   CompressExpression(FormK);
   if length(forexpr) > 0 then
      StrPCopy(FormF,forexpr)
   else
      FormF[0] := #0;
   CompressExpression(FormF);
   ix := New(GSptrMIXFile, Create(@Self, Tag));
   if (ix <> nil) and (ix^.CreateOK) then
   begin
      if ascnd in [AscendingGeneral, DescendingGeneral] then
      begin
         {$IFNDEF FOXGENERAL}
         FoundError(cdxNoCollateGen,cdxInitError,'General Collate Invalid');
         {$ENDIF}
         GSbytCDXCollateInfo := General;
      end
      else
         GSbytCDXCollateInfo := Machine;
      ix^.Dictionary := ascnd in [AscendingGeneral, DescendingGeneral];
      if ascnd = AscendingGeneral then
         ascnd := Ascending
      else
         if ascnd = DescendingGeneral then
            ascnd := Descending;
      ix^.AddTag(ITag, FormK, FormF, Ascnd=Ascending, Uniq=Unique);
      gsIndexInsert(ix);
      gsSetTagTo(tag,false);
      gsMemoryIndexAdd := true;
   end
   else
   begin
      if ix <> nil then ix^.Free;
      FoundError(dosFileNotFound,dbsIndexFileBad,ITag);
   end;
end;
*)

Function GSO_dBHandler.gsSetTagTo(const TName: String; SameRec: boolean): integer;
var
   i   : integer;                     {Local working variable  }
   pc: array [0..16] of char;
   px: GSptrIndexTag;
begin                                      {!!RFG 043098}
   if TName = '' then
   begin
      gsResetRange;
      if IndexMaster <> nil then IndexMaster^.TagClose;
      IndexMaster := nil;
      gsSetDBFCache(true);
      if not SameRec then gsGetRec(Top_Record);
      gsSetTagTo := 0;
      exit;
   end;
   StrPCopy(pc,CapClip(TName,[' ']));
   px := nil;
   i := 0;
   while (i < IndexesAvail) and (px = nil) do
   begin
      inc(i);
      if IndexStack[i] <> nil then
         px := IndexStack[i]^.TagByName(pc);
   end;
   if px = nil then
   begin
      gsSetTagTo := -1;
      exit;
   end;
   gsResetRange;
   if IndexMaster <> nil then IndexMaster^.TagClose;
   IndexMaster := nil;
   gsSetDBFCache(false);
   StrCopy(PrimaryTagName,pc);
   IndexMaster := px;
   IndexMaster^.TagOpen(1);
   if not SameRec then
      gsGetRec(Top_Record)
   else
      gsGetRec(Same_Record);
   gsSetTagTo := i;
end;

Procedure GSO_dBHandler.gsReIndex;
var
   rxIndexMaster : GSptrIndexTag;
   i   : integer;
   crd: boolean;
begin
   rxIndexMaster := IndexMaster;
   IndexMaster := nil;
   crd := CacheRead;             {!!RFG 041398}
   gsSetDBFCache(true);          {!!RFG 041398}
   for i := 1 to IndexesAvail do
   begin
      if IndexStack[i] <> nil then
         IndexStack[i]^.ReIndex;
   end;
   gsSetDBFCache(crd);           {!!RFG 041398}
   IndexMaster := rxIndexMaster;
   if IndexMaster <> nil then IndexMaster^.TagOpen(0);
   gsGetRec(Top_Record);
end;


{------------------------------------------------------------------------------
                  File Modifying Routine (Sort, Copy, Pack, Zap)
------------------------------------------------------------------------------}
(*!
Procedure GSO_dBHandler.gsCopyFile;  {(filname : String);}
var
   FCopy  : GSP_dBHandler;
   RecPos : longint;

BEGIN
   repeat until gsLokFile;
   gsHdrRead;
   gsStatusUpdate(StatusStart,StatusCopy,NumRecs);
   RecPos := RecNumber;
   gsCopyStructure(filname);
   FCopy := New(GSP_dBHandler, Create(filname,fmOpenReadWrite));
   FCopy^.gsOpen;
   FCopy^.gsLokFile;
   if WithMemo then
   begin
      curMemo := gsMemoType;
      newMemo := FCopy^.gsMemoType;
   end;
   gsGetRec(Top_Record);
   while not File_EOF do           {Read .DBF sequentially}
   begin
      gsStatusUpdate(StatusCopy,RecNumber,0);
      move(CurRecord^,FCopy^.CurRecord^,RecLen+1);
      if WithMemo then gsCopyMemoRecord(FCopy);
      FCopy^.gsAppend;
      gsGetRec(Next_Record);
   end;
   FCopy^.gsLokOff;
   FCopy^.Free;
   gsStatusUpdate(StatusStop,0,0);
   if WithMemo then
   begin
      curMemo^.Free;
      newMemo^.Free;
   end;
   gsGetRec(RecPos);
   gsLokOff;
END;                        { CopyFile }
*)

Procedure GSO_dBHandler.gsCopyRecord;  {(filobj : GSP_dBHandler);}
BEGIN

{!!} filobj^.gsBlank;
{!!} filobj^.gsAppend;

   move(CurRecord^,filobj^.CurRecord^,RecLen+1);

   if WithMemo then begin
      curMemo := gsMemoType;
      newMemo := filobj^.gsMemoType;
      gsCopyMemoRecord(filobj);
      curMemo^.Free;
      newMemo^.Free;
   end;
{!!   filobj^.gsAppend;}
{!!}   filobj^.gsReplace;
END;                        { CopyRecord }


procedure GSO_dBHandler.gsCopyMemoRecord(df : GSP_dbHandler);
var
   fp     : integer;
   mbuf   : PChar;
   rl     : FloatNum;
   tcnt   : longint;
   vcnt   : longint;
   blk    : longint;
begin
   for fp := 1 to NumFields do begin
      if Fields^[fp].dbFieldType in ['B','G','M'] then begin
         blk := Trunc(gsNumberGetN(fp));
         if (blk <> 0) then begin
            vcnt := curMemo^.moMemoSize(blk) + 16;
            GetMem(mbuf, vcnt);
            curMemo^.moMemoRead(mbuf, blk, vcnt);
            tcnt := 0;
            newMemo^.moMemoWrite(mbuf, tcnt, vcnt);
            rl := tcnt;
            df^.gsNumberPutN(fp,rl);
            FreeMem(mbuf, vcnt);
         end;
      end;
   end;
end;


procedure GSO_dBHandler.gsCopyStructure;  {(filname : String);}
var
   NuFile : GSP_DBFBuild;
   fp     : integer;
BEGIN
   case FileTarget of
{      DB4WithMemo  : NuFile := New(GSP_DB4Build, Create(filname));}
      FxPWithMemo  : NuFile := New(GSP_DBFoxBuild, Create(filname));
{      else NuFile := New(GSP_DB3Build, Create(filname));}
   end;

   for fp := 1 to NumFields do
      NuFile^.InsertField(gsFieldName(fp),Fields^[fp].dbFieldType,
                          Fields^[fp].dbFieldLgth,Fields^[fp].dbFieldDec);
   NuFile^.Free;
END;


Procedure GSO_dBHandler.gsPack;
var
   rxIndexMaster : GSptrIndexTag;
   fp            : integer;
   i, j          : longint;
   eofm: char;
   dbfchgd: boolean;
   crd: boolean;
begin      {Pack}
   eofm := EOFMark;
   if not gsLokFullFile then
   begin
      dfFileErr := dosAccessDenied;
      gsTestForOk(dfFileErr, dbsPackError);
      exit;
   end;
{   gsHdrRead;}
   rxIndexMaster := IndexMaster;
   crd := CacheRead;
   if WithMemo then
      curMemo := gsMemoType;
   IndexMaster := nil;               {Set index active flag to false}
   gsSetDBFCache(false);  {!!RGF 040698}   {Clear any current cached records}
   gsSetDBFCache(true);
   gsStatusUpdate(StatusStart,StatusPack,NumRecs);
   j := 0;
   for i := 1 to NumRecs do           {Read .DBF sequentially}
   begin
      gsRead(HeadLen+((i-1) * RecLen), CurRecord^, RecLen);
      RecNumber := i;
      if not gsDelFlag then             {Write to work file if not deleted}
      begin
         inc(j);                      {Increment record count for packed file }
         if j <> i then GSO_dBaseFld.gsPutRec(j);
      end
      else
         if WithMemo then
         begin
            for fp := 1 to NumFields do
            begin
               if Fields^[fp].dbFieldType in ['B','G','M'] then
               begin
                  curMemo^.MemoLocation := Trunc(gsNumberGetN(fp));
                  if (curMemo^.MemoLocation <> 0) then
                     CurMemo^.moMemoBlockRelease(curMemo^.MemoLocation);
               end;
            end;
         end;
      gsStatusUpdate(StatusPack,i,0);
   end;
   dbfchgd := NumRecs > j;         {If records were deleted then...}
   if dbfchgd then
   begin
      NumRecs := j;                   {Store new record count in objectname}
      gsWrite(HeadLen+(j*RecLen), eofm, 1);
                                      {Write End of File byte at file end}
      gsTruncate(HeadLen+(j*RecLen)+1);
                                      {Set new file size for dBase file};
   end;
   dStatus := Updated;
{   gsHdrWrite;}
   gsStatusUpdate(StatusStop,0,0);
   if WithMemo then
      curMemo^.Free;
   if dbfchgd then gsReIndex;
   gsLokOff;
   IndexMaster := rxIndexMaster;
   gsSetDBFCache(crd);
   if IndexMaster <> nil then
   begin
      IndexMaster^.TagOpen(0);
   end;
   gsGetRec(Top_Record);
END;                        { Pack }

                     {-------------------------------}

{-----------------------------------------------------------------------------
                               File Sorting Routines
-----------------------------------------------------------------------------}
(*!
Procedure GSO_dBHandler.gsLoadToIndex(ixColl: GSptrSortDB; zfld: PChar);
var
   ftyp : char;
   fchg : boolean;
   Rsl: array[0..255] of char;
begin
   gsStatusUpdate(StatusStart,StatusSort,NumRecs);
   gsGetRec(Top_Record);             {Read all dBase file records}
   while not File_EOF do
   begin
      SolveExpression(@Self,'GSSortEngine',zfld,rsl,ftyp,fchg);
      ixColl^.InsertWord(RecNumber, rsl);
      gsStatusUpdate(StatusSort,RecNumber,0);
      gsGetRec(Next_Record);
   end;
   gsStatusUpdate(StatusStop,0,0);
end;
*)
(*!
procedure GSO_dBHandler.gsCopyFromIndex(ixColl: GSptrSortDB;const filname: String);
var
   FCopy  : GSP_dBHandler;
BEGIN
   gsStatusUpdate(StatusStart,StatusCopy,ixColl^.WordCount);
   ixColl^.KeyCnt := 0;
   gsCopyStructure(filname);
   FCopy := New(GSP_dBHandler, Create(filname,fmOpenReadWrite));
   FCopy^.gsOpen;
   if WithMemo then
   begin
      curMemo := gsMemoType;
      newMemo := FCopy^.gsMemoType;
   end;
   ixColl^.curFile := @Self;
   ixColl^.newFile := FCopy;
   ixColl^.DisplayWord;
   FCopy^.gsClose;
   FCopy^.Free;
   if WithMemo then                {!!RFG 111897}
   begin                           {!!RFG 111897}
      curMemo^.Free;               {!!RFG 111897}
      newMemo^.Free;               {!!RFG 111897}
   end;                            {!!RFG 111897}
   gsStatusUpdate(StatusStop,0,0);
end;
*)

(*!
Procedure GSO_dBHandler.gsSortFile;
                           {(filname, zfld: String; isascend : SortStatus);}
var
   pckey : PChar;
   ixColl: GSptrSortDB;
   rn    : longint;
   ps    : PChar;

begin
   if GSFileIsOpen(filname+'.DBF') then
   begin
      GetMem(ps, 261);
      StrPCopy(ps, filname+'.DBF');
      FoundError(gsFileAlreadyOpen, dbsSortFile, ps);
      FreeMem(ps, 261);
      exit;
   end;

   if zfld <> '' then
   begin
      GetMem(pckey,255);
      StrPCopy(pckey,zfld);
      rn := RecNumber;
      if rn = 0 then rn := Top_Record;

      ixColl := New(GSptrSortDB, Create(false,isascend=SortUp,gsvTempDir));
      gsLoadToIndex(ixColl, pckey);
      gsCopyFromIndex(ixColl, filname);
      FreeMem(pckey,255);
      ixColl^.Free;
      gsGetRec(rn);
   end;
end;
*)

 {-------------------------------}

Procedure GSO_dBHandler.gsZap;
var
   mbuf : array[0..dBaseMemoSize] of byte;
   i : longint;                    {Local variables   }
   ib: byte;
   eofm: char;
   MemoFile: GSptrMemo;
begin              {Zap}
   eofm := EOFMark;
   if not gsLokFullFile then
   begin
      dfFileErr := dosAccessDenied;
      gsTestForOk(dfFileErr, dbsZapError);
      exit;
   end;
   if WithMemo then
   begin
      MemoFile := gsMemoType;
      if not MemoFile^.gsLockFile then
      begin
         dfFileErr := dosAccessDenied;
         gsTestForOk(dfFileErr, dbsZapError);
      end
      else
      begin
         MemoFile^.gsRead(0,mbuf,512);
         i := 0;
         move(i,mbuf[0],SizeOf(i));
         if MemoFile^.TypeMemo = FXPWithMemo then
         begin
            ib := 512 div FoxMemoSize;
            if (512 mod FoxMemoSize) <> 0 then inc(ib);
            mbuf[3] := ib;
         end
         else
         begin
            ib := 1;
            mbuf[0] := ib;
         end;
         MemoFile^.gsWrite(0,mbuf,512);
         MemoFile^.gsTruncate(512);
         MemoFile^.gsUnLock;
         MemoFile^.Free;
      end;
   end;
   NumRecs := 0;                   {Store new record count in objectname}
   RecNumber := 0;
   dStatus := Updated;
   gsHdrWrite(false);
   gsWrite(HeadLen, eofm, 1);
   gsTruncate(HeadLen);
   dStatus := NotUpdated;
   gsLokOff;
   GSO_dBaseDBF.gsClose;
   GSO_dBaseDBF.gsOpen;
   gsReIndex;
END;                        { Zap }

{------------------------------------------------------------------------------
                           Database Search Routine
------------------------------------------------------------------------------}
(*
Function GSO_dBHandler.gsSearchDBF(const s : string; var FNum : word;
                          var fromrec: longint; toRec: longint): word;
var
   BTable: string[255];
   MTable: string[255];
   crd : boolean;
   ia : pointer;
   lr : longint;
   sloc: word;
   i   : integer;
   Strt: word;
   Size: word;
   rnum: longint;
   rsl : integer;
   ns  : real;
   rs  : real;
   di  : longint;
   dr  : longint;
   li  : boolean;
   lv  : boolean;
   mp  : integer;
   ml  : integer;
   mc  : integer;
   fstrt: integer;
   ffini: integer;
   floc: integer;
   multifld: boolean;
   caseinsensitive: boolean;
   matchexact: boolean;
   usewildcards: boolean;
   useindex: boolean;
   usefilter: boolean;
   astrbegin: boolean;
   astrend: boolean;
   hasqmarks: boolean;
   startonly: boolean;

   function MatchField: integer;
   var
      mfi: integer;
      mfe: integer;
   begin
      MatchField := 0;
      if length(MTable) < length(BTable) then exit;
      if caseinsensitive then
         MTable := AnsiUpperCase(MTable);
      if hasqmarks then
         for mfi := 1 to length(BTable) do
            if BTable[mfi] = '?' then MTable[mfi] := '?';
      if matchexact then
      begin
         while (length(MTable) > length(BTable)) and   {!!RFG 032498}
               (MTable[length(Mtable)] = ' ') do
                MTable[0] := pred(MTable[0]);
         if BTable = MTable then MatchField := 1;
      end
      else
      begin
         mfi := pos(BTable,MTable);
         if (mfi > 1) and (not astrbegin) then mfi := 0;
         if (mfi > 0) and (not astrend) then
         begin
            MTable := RTrim(MTable);
            mfe := mfi + length(BTable) - 1;
            if length(MTable) > mfe then mfi := 0;
         end;
         MatchField := mfi;
      end;
   end;


begin
   rnum := 1;
   sloc := 0;
   if (FNum > NumFields) or (length(s) = 0) then
   begin
      gsSearchDBF := 0;
      exit;
   end;

   caseinsensitive := (SearchMode and 1) <> 0;
   matchexact := (SearchMode and 2) <> 0;
   usewildcards := (SearchMode and 4) <> 0;
   usefilter := (SearchMode and 8) <> 0;
   useindex := (SearchMode and 16) <> 0;
   startonly := (SearchMode and 32) <> 0;

{   if toRec = 0 then toRec := NumRecs;}
   fstrt := FNum;
   ffini := FNum;
   multifld := FNum = 0;
   if multifld then
   begin
      fstrt := 1;
      ffini := numFields;
   end;
   if caseinsensitive then
      BTable := AnsiUpperCase(s)
   else
      BTable := s;
   if usewildcards then
   begin
      astrbegin := BTable[1] = '*';
      astrend := BTable[length(BTable)] = '*';
      if astrbegin then system.delete(BTable,1,1);
      if astrend and (length(BTable) > 0) then
         system.delete(BTable,length(BTable),1);
      if astrbegin then
         hasqmarks := false
      else
         hasqmarks := pos('?',BTable) <> 0;
      if astrbegin or astrend or hasqmarks then
         matchexact := false;
   end
   else
   begin
      astrbegin := not startonly;
      astrend := not matchexact;
      hasqmarks := false;
   end;
   di := GS_Date_Juln(s);
   val(s,ns,rsl);
   if rsl <> 0 then ns := 0.0;
   li := pos(s[1],LogicalTrue) > 0;
   gsStatusUpdate(StatusStart,StatusSearch,NumRecs);
   lr := RecNumber;
   ia := IndexMaster;
   if not usefilter then
      dState := dbIndex;
   if (not useindex) then
      IndexMaster := nil;
   crd := CacheRead;
   if IndexMaster = nil then
      gsSetDBFCache(true);
   {$IFDEF DELPHI}try{$ENDIF}
   if fromrec = 0 then
      gsGetRec(Top_Record)
   else
   begin
      gsGetRec(fromrec);
      gsSkip(1);
   end;
   while (not File_EOF) and ((RecNumber <= toRec) or (torec = 0)) and
         (sloc = 0) do
   begin
      floc := fstrt;
      repeat
         FNum := floc;
         Strt := 1;
         if FNum > 1 then
            for i := 1 to FNum-1 do
               Strt := Strt + gsFieldLength(i);
         Size := gsFieldLength(FNum);
         if sloc = 0 then
         case gsFieldType(FNum) of
         'C' : begin
                  move(CurRecord^[Strt],MTable[1],Size);
                  MTable[0] := chr(Size);
                  sloc := MatchField;
               end;
         'F',
         'N' : begin
                  sloc := 0;
                  if rsl = 0 then
                  begin
                     rs := gsNumberGetN(FNum);
                     if rs = ns then sloc := 1;
                  end;
               end;
         'D' : begin
                  sloc := 0;
                  dr := gsDateGetN(FNum);
                  if di = dr then sloc := 1;
               end;
         'L' : begin
                  sloc := 0;
                  if not multifld then
                  begin
                     lv := gsLogicGetN(FNum);
                     if li = lv then sloc := 1;
                  end;
               end;
         'M' : begin
                  sloc := 0;
                  mp := 0;
                  gsMemoGetN(FNum);
                  ml := gsMemoLinesN(FNum);
                  if ml > 0 then
                  begin
                     mc := 1;
                     while (mc <= ml) and (sloc = 0) do
                     begin
                        MTable := gsMemoGetLineN(FNum,mc);
                        sloc := MatchField;
                        if sloc > 0 then
                           sloc := sloc + mp
                        else
                           mp := mp + length(MTable) + 2;
                        inc(mc);
                     end;
                  end;
               end;
         end;
         inc(floc);
      until (floc > ffini) or (sloc > 0);
       if sloc = 0 then
      begin
         inc(rnum);
         gsStatusUpdate(StatusSearch,rnum,0);
         gsGetRec(Next_Record);
      end;
   end;
   {$IFDEF DELPHI}finally{$ENDIF}
   dState := dbBrowse;
   gsSetDBFCache(crd);
   IndexMaster := ia;
   if sloc > 0 then
   begin
      fromrec := RecNumber;
      gsGetRec(fromrec);            {Reset for index}
   end
   else
      if lr > 0 then gsGetRec(lr);
   gsSearchDBF := sloc;
   gsStatusUpdate(StatusStop,rnum,0);
   {$IFDEF DELPHI}end;{$ENDIF}
end;
*)

{-----------------------------------------------------------------------------
                               GSobjSortDB
-----------------------------------------------------------------------------}
{!
procedure GSobjSortDB.OutputWord(Tag: Longint; Value: PChar);
begin
   curFile^.gsGetRec(Tag);
   inc(KeyCnt);
   curFile^.gsStatusUpdate(StatusCopy,KeyCnt,0);
   move(curFile^.CurRecord^,newFile^.CurRecord^,curFile^.RecLen);
   if curFile^.WithMemo then curFile^.gsCopyMemoRecord(newFile);
   newFile^.gsAppend;
end;
}
{-----------------------------------------------------------------------------
                                 Initialization
-----------------------------------------------------------------------------}

end.

