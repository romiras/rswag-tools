unit gsF_DBF;
{-----------------------------------------------------------------------------
                          dBase III/IV File Handler

       gsF_DBF Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit handles the object for all dBase III/IV file (.DBF)
       operations.  The object to manipulate the fields in the
       records of a dBase file is also contained here.

   Changes:
             07/16/97 - fixed gsCreateDBF to close and release memory it
                        allocated.
      !!RFG 081897 Changed multi-user update testing by placing the time
                   of the update rather than maintaining a count.  This
                   eliminates the header reading required for every record
                   update.  Also added UserID information so that the User
                   who last updated the table is known.

                   Added gsExternalChange function, which returns true if
                   another application modified the table.

                   Added gsAssignUserID procedure, which assigns a longint
                   id for the current user.  This id is placed in the DBF
                   header each time gsHdrWrite is called (normally for each
                   record write).  The ID allows tracing file updates for
                   debugging/audit purposes.

                   Added gsReturnDateTimeUser procedure that returns the
                   date, time, and user for the last DBF file update.
                   These are three longint vars.

                   Replaced TableChanged boolean with ExtTableChg to indicate
                   another application changed something in the table.  This
                   is set during gsHdrRead.

                   Replaced var UpdateCount with UpdateTime, which keeps the
                   time of the last update as computed in gsHdrWrite.

      !!RFG 081997 Changed gsLokOff so gsHdrWrite is only called if unlocking
                   a file lock.  It is bypassed if it is a record lock.

      !!RFG 082097 Added code in GSO_dBaseDBF.Create to initialize RecModified
                   to false.  There was a possibility of this indicating true
                   in a Delphi application since Delphi does not initialize
                   objects memory to zeros.
      !!RFG 082897 Fixed recursion problem in gsExternalChange
      !!RFG 083097 Added gsvIndexState to flag Index conditions for faster
                   index operations.  This is used in GSO_dBHandler.gsGetRec.
      !!RFG 091697 Added more calls to gsHdrRead to ensure the NumRecs value
                   was current.  Added in gsAppend, gsClose, and gsPutRec.
      !!RFG 121097 Added Header locking at the beginning of the Append process
                   to ensure no other application will read an 'old' header.
      !!RFG 020598 Now use the actual size of the file to compute the record
                   count instead of the count in the header.  This is
                   consistent with dBase and avoids bad header data if the
                   header was not updated on a program failure.
                   recordcount = (filesize-headerlength) div recordsize
      !!RFG 022198 Added code to gsGetRec to more efficiently handle a call
                   with RecNum set to 0.
      !!RFG 032598 Changed error reporting in gsNumberPutN to report the
                   Field name when a number is too large to fit in the field.
      !!RFG 051198 Allowed character data fields to be > 255 bytes in 32-bit
                   Delphi.  This accomodates Clipper fields that use the
                   decimals part of the field descriptor to allow large
                   character fields.  This is not available in 16-bit programs
                   because of the limitation of strings to 255 bytes.

------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}
interface
uses
   gsF_Glbl,
   gsF_Disk,
   gsF_Memo,
   gsF_Eror,
   gsF_Date,
   gsF_XLat,
   vString,
   gsF_DOS,
   Strings;

{private}

Const
   MaxFieldNumber = 32; {512}
type

   dbFileStatus = (Invalid, NotOpen, NotUpdated, Updated);
   dbFileState = (dbInactive, dbBrowse, dbEdit, dbAppend, dbIndex, dbCopy);
   dbFileEvent = (dbRecordChange, dbFieldChange, dbTableChange, dbRecordWrite,
                  dbPreRead, dbPreWrite, dbPostRead, dbPostWrite, dbFlush);

   dbInsertFieldProc  = Function(FldNo: integer; var s: String;
                                 var t: char; var l,d: integer): boolean;


   GSP_DBFHeader = ^GSR_DBFHeader;
   GSR_DBFHeader = packed Record
      DBType     : Byte;                  {DataBase Type}
      Year       : Byte;                  {Last         }
      Month      : Byte;                  {  Updated    }
      Day        : Byte;                  {      Date   }
      RecordCount: LongInt;               {Record Counter}
      Location   : Word;
      RecordLen  : Word;                  {Record Length}
      Reserve1   : Array[0..1] of Byte;
      TranIncmpl : byte;
      Encrypted  : byte;
      MultUseFlg : Longint;
      UserIDLast : Longint;               {!!RFG 081897}
      Reserve2   : Array[0..3] of Byte;
      DBTableFlag: Byte;                  {Table Flags}
                                          {  1 = production index}
                                          {  2 = has memos (VFP)}
                                          {  4 = is a DBC (VFP)}
      LangID     : Byte;
      Reserve3   : Array[0..1] of Byte;
   end;

   GSP_DBFField = ^GSR_DBFField;
   GSR_DBFField = packed Record
      dbFieldName    : array[0..10] of char;  {Field Name}
      dbFieldType    : Char;                  {Field Type: B,C,D,L,M,N}
      dbFieldOffset  : Longint;               {Field Offset}
      dbFieldLgth    : Byte;                  {Field Offset}
      dbFieldDec     : Byte;                  {Decimal Length}
      dbFieldFlag    : Byte;          {Added for VFP Field Flags}
                                      {    1 = System Column}
                                      {    2 = Can store null values}
                                      {    4 = Binary Column (Char and Memo)}
              {Following fields available for use}
      ResBytes     : array[0..4] of byte;
      ResWord      : word;
              {Used Internally}
      dbFieldNum     : word;          {Used by GS to hold the field number}
      dbMemoObj      : GSptrMemo;     {Pointer to Memo Object}
   end;

   GSP_FieldArray = ^GSA_FieldArray;
   GSA_FieldArray  = ARRAY[1..MaxFieldNumber] OF GSR_DBFField;

   GSP_dBaseDBF = ^GSO_dBaseDBF;
   GSO_dBaseDBF = object(GSO_DiskFile)
      HeadProlog   : GSR_DBFHeader;   {Image of file header}
      dStatus      : dbFileStatus;    {Holds Status Code of file}
      dState       : dbFileState;
      NumRecs      : LongInt;         {Number of records in file}
      HeadLen      : Integer;         {Header + Field Descriptor length}
      RecLen       : Integer;         {Length of record}
      NumFields    : Integer;         {Number of fields in the record}
      Fields       : GSP_FieldArray;  {Pointer to memory array holding}
                                      {field descriptors}
      RecNumber    : LongInt;         {Physical record number last read}
      CurRecord    : GSptrCharArray;  {Pointer to memory array holding}
                                      {the current record data.  Refer}
                                      {to Appendix B for record structure}
      CurRecHold   : GSptrCharArray;
      OrigRec      : GSptrCharArray;  {Keeps original record on change}
      CurRecChg    : GSptrByteArray;
      File_EOF     : boolean;         {True if access tried beyond end of file}
      File_TOF     : boolean;         {True if access tried before record 1}
      FileVers     : byte;
      FileTarget   : byte;            {Used to determine memo conversion type}
      FileIsLocked : boolean;
      IndexFlag    : byte;
      MemoFlag     : byte;
      DBCFlag      : byte;
      LockCount    : word;
      UpdateTime   : longint;             {!!RFG 081897}
                                {bits 0-9 = sec100; 10-15 = sec; 16-21 = min}
                                {22-27 = hour                               }
      ExtTableChg  : boolean;
      IntTableChg  : boolean;
      RecModified  : boolean;
      UseDeletedRec: Boolean;
      gsvExactMatch: boolean;
      gsvTempDir   : PChar;
      gsvUserID    : longint;             {!!RFG 081897}
      gsvIndexState: boolean;             {!!RFG 083097}
      HdrLocked    : integer;             {!!RFG 121097}
      UseFileSize  : boolean;             {!!RFG 020598}
      CONSTRUCTOR Create(const FName : String; FMode: byte);
      DESTRUCTOR  Destroy; virtual;
      Procedure   FreeDBFResources;
      Function    gsAppend: Boolean; virtual;
      Function    gsAppendFast: Boolean; virtual;
{!      procedure   gsAssignUserID(Usr: longint);}
      Function    gsClose: Boolean; virtual;
      function    gsDBFEvent(Event: dbFileEvent; Action: longint): boolean; virtual;
      Function    gsDelFlag: boolean;
      Function    gsExternalChange: integer;
      Function    gsFlush: Boolean; virtual;
      Function    gsGetRec(RecNum: LongInt): Boolean; virtual;
      Function    gsHdrRead: Boolean;
      Function    gsHdrWrite(IgnoreLockedFile: boolean): Boolean; {!!RFG 081897}
      Function    gsLokApnd: boolean; virtual;
      Function    gsLokFile: boolean; virtual;
      Function    gsLokFullFile: boolean; virtual;
      Function    gsLokHeader(OnOff: boolean): integer;
      Function    gsLokIt(fposn,flgth: longint): boolean;
      Function    gsLokOff: Boolean; virtual;
      Function    gsLokRcrd: boolean; virtual;
      Function    gsOpen: Boolean; virtual;
      Function    gsPutRec(RecNum : LongInt): Boolean; virtual;
      Function    gsReplace: Boolean; virtual;
{      procedure   gsReturnDateTimeUser(var dt, tm, us: longint);}
      Procedure   gsSetLockProtocol(LokProtocol: GSsetLokProtocol); virtual;
      Procedure   gsStatusUpdate(stat1,stat2,stat3 : longint); virtual;
      Function    gsWithIndex: boolean; virtual;
   end;

   GSP_dBaseFld = ^GSO_dBaseFld;
   GSO_dBaseFld = object(GSO_dBaseDBF)
      WithMemo    : boolean;         {True if memo file present}
      WithIndex   : boolean;         {True if production index present}
      FieldPtr    : GSP_DBFField;
      OEMChars    : boolean;
      Constructor Create(const FName : String; FMode: byte);
      DESTRUCTOR  Destroy; virtual;
      function    gsFieldExists(const fldst : String): Boolean;
      Function    gsAnalyzeField(const fldst: String) : GSP_DBFField; virtual;
      Procedure   gsBlank; virtual;
      Function    gsCheckField(const st : String; ftyp : char) : GSP_DBFField;
      Procedure   gsClearFldChanged;
      Function    gsClose: Boolean; virtual;
      Function    gsDateGet(const st : String) : GS_Date_StrTyp; virtual;
      Function    gsDateGetN(n : integer) : GS_Date_StrTyp; virtual;
      Function    gsDatePut(const st: String; jdte: GS_Date_StrTyp): Boolean; virtual;
      Function    gsDatePutN(n : integer; jdte : GS_Date_StrTyp): Boolean; virtual;
      Function    gsDeleteRec: Boolean; virtual;
      Function    gsFieldGet(const fnam : String) : String; virtual;
      Function    gsFieldGetN(fnum : integer) : String; virtual;
      Function    gsFieldLocate(fdsc: GSP_FieldArray; const st: String;
                              var i: integer): boolean;
      Function    gsFieldNo(const st: String): integer;
      Function    gsFieldPull(fr: GSP_DBFField; fp: GSptrCharArray) : String;
      Procedure   gsFieldPush(fr: GSP_DBFField;const st : String;
                            fp: GSptrCharArray);
      Function    gsFieldPut(const fnam, st : String): Boolean; virtual;
      Function    gsFieldPutN(fnum: integer; const st: String): Boolean; virtual;
      Function    gsFieldDecimals(i : integer) : integer; virtual;
      Function    gsFieldLength(i : integer) : integer; virtual;
      Function    gsFieldOffset(i : integer) : longint; virtual;
      Function    gsFieldName(i : integer) : String; virtual;
      Function    gsFieldType(i : integer) : char; virtual;
      Function    gsFormula(who, st, fmrec : PChar; var Typ: char;
                          var Chg: boolean): integer; virtual;
      Function    gsGetRec(RecNum: LongInt): Boolean; virtual;
      Function    gsLogicGet(const st : String) : boolean; virtual;
      Function    gsLogicGetN(n : integer) : boolean; virtual;
      Function    gsLogicPut(const st : String; b : boolean): Boolean; virtual;
      Function    gsLogicPutN(n : integer; b : boolean): Boolean; virtual;
      Function    gsMemoType: GSptrMemo;
      Function    gsMemoFieldCheck(n: integer): GSptrMemo;
      Function    gsMemoFieldNumber(const st: string): integer;
{      Function    gsMemoGet(const st : String) : boolean; virtual;
      Function    gsMemoGetN(n : integer) : boolean; virtual;
      Function    gsMemoPut(const st : String): Boolean; virtual;
      Function    gsMemoPutN(n : integer): Boolean; virtual;
      Function    gsMemoLines(const fnam: string): integer;
      Function    gsMemoGetLine(const fnam: string;linenum: integer): string;
      Function    gsMemoDelLine(const fnam: string;linenum: integer): boolean;
      Function    gsMemoInsLine(const fnam: string;linenum: integer;
                              const st: string): boolean;
      Function    gsMemoWidth(const fnam: string;l: integer): boolean;

      Function    gsMemoLinesN(fnum: integer): integer;
      Function    gsMemoGetLineN(fnum: integer;linenum: integer): string;
      Function    gsMemoDelLineN(fnum: integer;linenum: integer): boolean;
      Function    gsMemoInsLineN(fnum: integer;linenum: integer;
                               const st: string): boolean;
      Function    gsMemoWidthN(fnum: integer;l: integer): boolean;
}
      Function    gsMemoSize(const fnam: string): longint;
      Function    gsMemoSizeN(fnum: integer): longint;

      Function    gsMemoClear(const fnam: string): boolean;
      Function    gsMemoClearN(fnum: integer): boolean;
      Function    gsMemoLoad(const fieldnam: string;buf: pointer;
                           var cb: longint): boolean;
      Function    gsMemoLoadN(fieldnum: integer;buf: pointer;
                            var cb: longint): boolean;
      Function    gsMemoSave(const fnam: string; buf: pointer;
                           var cb: longint): longint;
      Function    gsMemoSaveN(fnum: integer;buf: pointer;
                            var cb: longint): longint;
      Function    gsMemo2File(const fieldnam,filename: string): boolean;
      Function    gsMemo2FileN(fieldnum: integer;const filename:string): boolean;
      Function    gsFile2Memo(const fieldnam,filename: string): boolean;
      Function    gsFile2MemoN(fieldnum: integer;const filename:string): boolean;
      Function    gsNumberGet(const st : String) : FloatNum; virtual;
      Function    gsNumberGetN(n : integer) : FloatNum; virtual;
      Function    gsNumberPut(const st: String; r: FloatNum): Boolean; virtual;
      Function    gsNumberPutN(n : integer; r : FloatNum): Boolean; virtual;
{
      Function    gsStringGet(const fnam : String) : String; virtual;
      Function    gsStringGetN(fnum : integer) : String; virtual;
      Function    gsStringPut(const fnam, st : String): Boolean; virtual;
      Function    gsStringPutN(fnum: integer; const st: String): Boolean;virtual;
}
      Function    gsUndelete: Boolean; virtual;
   end;


   GSP_DBFBuild = ^GSO_DBFBuild;
   GSO_DBFBuild = object(GSobjCollection)
      dbTypeNoMo  : byte;
      dbTypeMemo  : byte;
      dFile       : GSP_DiskFile;
      mFile       : GSP_DiskFile;
      HeadRec     : GSR_DBFHeader;
      FileName    : String;
      hasMemo     : boolean;
      dbRecLen    : integer;
      dbTitle     : String[8];
      GoodToGo    : boolean;
      Constructor Create(const FName : String);
      Destructor  Destroy; virtual;
      Procedure   Complete; virtual;
      procedure   FreeItem(Item: Pointer); virtual;
      Procedure   InsertField(const s: String; t: char; l,d: integer); virtual;
      Procedure   WriteDBF; virtual;
      Procedure   WriteDBT; virtual;
   end;
{
   GSP_DB3Build = ^GSO_DB3Build;
   GSO_DB3Build = GSO_DBFBuild;

   GSP_DB4Build = ^GSO_DB4Build;
   GSO_DB4Build = object(GSO_DBFBuild)
      Constructor Create(const FName : String);
      Procedure   WriteDBT; virtual;
   end;
}
   GSP_DBFoxBuild = ^GSO_DBFoxBuild;
   GSO_DBFoxBuild = object(GSO_DBFBuild)
      Constructor Create(const FName : String);
      Procedure   WriteDBT; virtual;
   end;

Function gsCreateDBF(const fname: string; ftype: char;
                                          fproc: dbInsertFieldProc): boolean;
Function gsCreateDBFEx(const fname: string; ftype: char;
                                    fproc: dbInsertFieldProc): GSP_DiskFile;

{------------------------------------------------------------------------------
                            IMPLEMENTATION SECTION
------------------------------------------------------------------------------}

implementation

const
   EohMark  = #$0D;          {Byte stored at end of the header}


{------------------------------------------------------------------------------
                                Global Routines
------------------------------------------------------------------------------}

Function gsCreateDBFEx(const fname: string; ftype: char;
                                    fproc: dbInsertFieldProc): GSP_DiskFile;
var
   fx: GSP_DBFBuild;
   i: integer;
   s: String;
   t: char;
   l: integer;
   d: integer;
   b: boolean;
begin
   gsCreateDBFEx := nil;
   if fname = '' then exit;
   if @fproc = nil then exit;
   fx := nil;
   case ftype of
{      '3',
      'C' : fx := New(GSP_DB3Build, Create(fname));
      '4',
      '5' : fx := New(GSP_DB4Build, Create(fname));}
      'F' : fx := New(GSP_DBFoxBuild, Create(fname));
   end;
   if fx = nil then exit;
   i := 1;
   repeat
      b := fproc(i,s,t,l,d);
      inc(i);
      if (b) and (length(s) > 0) then
         fx^.InsertField(s,t,l,d);
   until (not b) or (length(s) = 0);
   fx^.GoodToGo := b;
   fx^.Complete;
   gsCreateDBFEx := fx^.dFile;
   fx^.dFile := nil;
   fx^.GoodToGo := false;                                     {RFG 071697}
   Dispose(fx,Destroy);                                          {RFG 071697}
end;

Function gsCreateDBF(const fname: string; ftype: char;
                                          fproc: dbInsertFieldProc): boolean;
var
   p: GSP_DiskFile;
begin
   p := gsCreateDBFEx(fname,ftype,fproc);
   gsCreateDBF := p <> nil;
   if p <> nil then
      p^.Free;
end;


{------------------------------------------------------------------------------
                                GSO_dBaseDBF
------------------------------------------------------------------------------}


CONSTRUCTOR GSO_dBaseDBF.Create; {(const FName : String; FMode: byte)}
const
   ext: string = '.DBF';
VAR
   fl  : integer;                   {field length working variable}
   Pth : String;
begin
   Pth := CapClip(FName,[' ','"']);
   Pth := ChangeFileExtEmpty(Pth,ext);
   inherited Create(Pth, FMode);
   if ObjType <> GSobtDiskFile then exit;
   inc(dfHideError);
   CurRecord := nil;
   CurRecHold := nil;
   Fields := nil;
   CurRecChg := nil;
   OrigRec := nil;
   gsvTempDir := nil;
   dStatus := Invalid;             {Set file status to 'Invalid'}
   dfFileErr := 0;
   if not dfFileExst then
      dfFileErr := dosFileNotFound
   else
   begin
      gsReset;                       {File length of one byte}
      if dfFileErr = 0 then
      begin
         FileIsLocked := false;
                  {ProcessHeader}
         if GSO_DiskFile.gsRead(0, HeadProlog, 32) then
         begin
            CASE HeadProlog.DBType OF        {test for valid dBase types}
            DB3File,
            DB3WithMemo,
            {DB4File,}
            DB4WithMemo,
            {FxPFile,}
            FXPWithMemo,
            VFP3File    : begin                            {Good File}
                             FileVers := HeadProlog.DBType;
                             NumRecs := HeadProlog.RecordCount;
                             HeadLen := HeadProlog.Location;  {length of header}
                             RecLen := HeadProlog.RecordLen;  {Length of record}
                             IndexFlag := HeadProlog.DBTableFlag and $01;
                             MemoFlag := HeadProlog.DBTableFlag and $02;
                             DBCFlag := HeadProlog.DBTableFlag and $04;
                             UpdateTime := HeadProlog.MultUseFlg;
                          end;
            ELSE
               dfFileErr := gsBadDBFHeader;
            END;
         END;                      {CASE}
         FileTarget := FileVers;        {set copy type to current type}
                     {End ProcessHeader}
      end;
      if dfFileErr = 0 then           {Load file structure information}
      begin
         RecNumber := 0;                 {Set current record to zero}
         File_EOF := false;              {Set End of File flag to false}
         File_TOF := true;               {Set Top of File flag to true};
         NumRecs := (gsFileSize-HeadLen) div RecLen;   {!!RFG 020598}
         fl := HeadLen-33;               {Size of field descriptors}
         if FileVers = VFP3File then
            fl := fl - 263;
         GetMem(Fields, fl);             {Allocate memory for fields buffer.}
         NumFields := fl div 32;         {Number of fields}
         inherited gsRead(-1, Fields^, fl);          {Store field data}
         LockCount := 0;
         dStatus := NotOpen;             {Set file status to 'Not Open'   }
         GSO_DiskFile.gsClose;             {Finished with file for now}
         GetMem(CurRecord, RecLen+1);    {Allocate memory for record buffer}
         FillChar(CurRecord^,RecLen,' ');
         CurRecord^[RecLen] := EofMark;  {End of file flag after record}
         CurRecHold := CurRecord;
         GetMem(OrigRec, RecLen+1);
         FillChar(OrigRec^,RecLen,' ');
         GetMem(CurRecChg,succ(NumFields));
         ExtTableChg := false;
         IntTableChg := false;
         UseDeletedRec := true;
         dfAutoShare := true;
         gsvExactMatch := false;
         gsvUserID := 0;
         gsvIndexState := false;              {!!RFG 083097}
         RecModified := false;                {!!RFG 082097}
         HdrLocked := 0;                  {!!RFG 121097}
      end;
   end;
   if (dfFileErr = 0) then
      if (Fields = nil) or (CurRecord = nil) then
         dfFileErr := tpHeapOverFlow;
   dec(dfHideError);
   if dfFileErr <> 0 then
   begin
      gsTestForOk(dfFileErr,dbfInitError);
      FreeDBFResources;
   end
   else
   begin
      ObjType := GSobtDBFFile;
      gsDBFEvent(dbTableChange,0);
   end;
end;

Destructor GSO_dBaseDBF.Destroy;
begin
   FreeDBFResources;
   inherited Destroy;
end;

procedure GSO_dBaseDBF.FreeDBFResources;
var
   fl: longint;
begin
   gsClose;              {Close the file before finishing up}
   StrGSDispose(gsvTempDir);
   gsvTempDir := nil;
   if (CurRecHold <> nil) then
      FreeMem(CurRecHold, RecLen+1);{DeAllocate memory for record buffer}
   CurRecHold := nil;
   if CurRecChg <> nil then
      FreeMem(CurRecChg,succ(NumFields));
   CurRecChg := nil;
   if Fields <> nil then
   begin
      fl := HeadLen-33;               {Size of field descriptors}
      if FileVers = VFP3File then
         fl := fl - 263;
      FreeMem(Fields, fl);  {DeAllocate memory for fields buffer.}
      Fields := nil;
   end;
   if OrigRec <> nil then
      FreeMem(OrigRec, RecLen+1);   {DeAllocate memory for record buffer}
   OrigRec := nil;

end;

Function GSO_dBaseDBF.gsAppend: boolean;
var
   b : boolean;
   lko: boolean;
   rsl: integer;
BEGIN
   b := false;                                      {!!RFG 121097}
   gsDBFEvent(dbPreWrite,0);
   rsl := gsLokHeader(true);                        {!!RFG 121097}
   if not (rsl in [0,1]) then                       {!!RFG 121097}
   begin                                            {!!RFG 121097}
      gsTestForOk(dfFileErr, dbfHdrWriteError);     {!!RFG 121097}
      gsAppend := false;                            {!!RFG 121097}
      exit;                                         {!!RFG 121097}
   end;                                             {!!RFG 121097}
   if dfAutoShare and not FileIsLocked then
      lko := gsLokApnd                              {!!RFG 121097}
   else
      lko := true;
   if lko then                                      {!!RFG 121097}
   begin
      dStatus := Updated;             {Set file status to 'Updated'}
      gsHdrRead;                        {!!RFG 091697}
      CurRecord^[0] := GS_dBase_UnDltChr;
      inc(NumRecs);
      RecNumber := NumRecs;               {Store record number as current record }
      if gsWrite(HeadLen+((RecNumber-1)*RecLen), CurRecord^, RecLen+1) then
         b := gsHdrWrite(true)
      else
         b := false;
      gsLokOff;
   end;
   rsl := gsLokHeader(false);                       {!!RFG 121097}
   if not (rsl in [0,1]) then                       {!!RFG 121097}
   begin                                            {!!RFG 121097}
      gsTestForOk(dfFileErr, dbfHdrWriteError);     {!!RFG 121097}
   end;                                             {!!RFG 121097}
   if b then
   begin
      File_EOF := false;                     {!!RFG 082097}
      File_TOF := false;  {RecNumber = 1;}   {970418}
      gsDBFEvent(dbPostWrite,0);
      Move(CurRecord^, OrigRec^, RecLen);
   end;
   gsAppend := b;
END;

Function GSO_dBaseDBF.gsAppendFast: boolean;
BEGIN
   dStatus := Updated;             {Set file status to 'Updated'}
   CurRecord^[0] := GS_dBase_UnDltChr;
   gsHdrRead;                        {!!RFG 091697}
   inc(NumRecs);
   RecNumber := NumRecs;               {Store record number as current record }
   gsWrite(HeadLen+((RecNumber-1)*RecLen), CurRecord^, RecLen+1);
   File_EOF := true;
   File_TOF := false;  {RecNumber = 1;}   {970418}
   gsAppendFast := true;
END;
{!
procedure  GSO_dBaseDBF.gsAssignUserID(Usr: longint);
begin
   gsvUserID := Usr;
end;
}

Function GSO_dBaseDBF.gsClose: boolean;
begin
   gsClose := false;
   IF dStatus <= NotOpen THEN exit;     {Exit if file not open}
   IF dStatus = Updated THEN
   begin
      gsHdrRead;                        {!!RFG 091697}
      if gsHdrWrite(false) then     {Write new header information if the}
                                       {file was updated in any way}
         gsClose := GSO_DiskFile.gsClose   {Go close file}
      else gsClose := false
   end
   else
      gsClose := GSO_DiskFile.gsClose;
   FileIsLocked := false;
   dStatus := NotOpen;                 {Set objectname.dStatus to 'NotOpen'}
END;                        { GS_dBase_Close }

function GSO_dBaseDBF.gsDBFEvent(Event: dbFileEvent; Action: longint): boolean;
begin
   gsDBFEvent := true;
   case Event of
      dbPostRead,
      dbPostWrite     : begin
                           RecModified := false;
                           dState := dbBrowse;
                        end;
      dbPreRead       : begin
                           dState := dbBrowse;
                        end;
      dbFieldChange   : RecModified := true;
   end;
end;

Function GSO_dBaseDBF.gsDelFlag: boolean;
begin
   if CurRecord = nil then
      gsDelFlag := false
   else
      if CurRecord^[0] = GS_dBase_DltChr then
         gsDelFlag := true
      else
         gsDelFlag := false;
end;

Function GSO_dBaseDBF.gsExternalChange: integer;
var
   r: integer;         {!!RFG 082897}
begin
   r := 0;
   gsHdrRead;
   if ExtTableChg then
      r := 2;
   if IntTableChg then
      r := r + 1;
   ExtTableChg := false;
   IntTableChg := false;
   gsExternalChange := r;
end;

Function GSO_dBaseDBF.gsFlush: boolean;
var
   holdflush : GSsetFlushStatus;
   i: integer;
   j: integer;
begin
   gsFlush := (dStatus = NotUpdated) or (dStatus = NotOpen);
   if (dStatus = NotUpdated) or (dStatus = NotOpen) then exit;
   holdflush := dfFileFlsh;        {turn off flush temporarily to avoid}
   dfFileFlsh := NeverFlush;       {an endless loop if WriteFlush, as the}
   if gsHdrWrite(false) then       {header write would call Flush again}
   begin
      gsFlush := GSO_DiskFile.gsFlush;
      if Fields <> nil then
      begin
         j := 0;
         for i := 1 to NumFields do
            if Fields^[i].dbMemoObj <> nil then j := i;
         if j > 0 then
             Fields^[j].dbMemoObj^.gsFlush;    {flush Memo file}
      end;
      gsDBFEvent(dbFlush,RecNumber);
   end;
   dfFileFlsh := holdFlush;
end;

Function GSO_dBaseDBF.gsGetRec(RecNum : LongInt): boolean;
VAR
   RNum   : LongInt;                  {Local working variable  }
   RNumInt: integer;
BEGIN
   gsGetRec := false;
   if NumRecs = 0 then
      gsHdrRead;                    {Ensure nobody else added records}
   if (NumRecs = 0) then
   begin
      File_EOF := true;
      File_TOF := true;
      exit;
   end;
   if RecNum = 0 then exit;         {!!RFG 022198}
   RNum := RecNum;                    {Store RecNum locally for modification}
   if RecNum > MaxInt then            {Set RNumInt to valid value for case}
      RNumInt := 1                    {testing                            }
   else
      RNumInt := RecNum;
   File_EOF := false;                 {Initialize End of File Flag to false}
   File_TOF := false;
   case RNumInt of
      Same_Record : RNum := RecNumber;
      Next_Record : RNum := RecNumber + 1;   {Advance one record}
      Prev_Record : begin
                       RNum := RecNumber - 1;   {Back up one record}
                       if RNum = 0 then
                       begin
                          File_TOF := true;
                          Exit;
                       end;
                    end;
      Top_Record  : RNum := 1;               {Set to the first record}
      Bttm_Record : RNum := NumRecs;
      else
         if (RNum < 1) then
         begin
            dfFileErr := gsDBFRangeError;
            gsTestForOk(dfFileErr,dbfGetRecError);
            File_EOF := true;
            File_TOF := true;
            exit;
         end;
   end;
   if (RNum > NumRecs) then
   begin
      gsHdrRead;    {Confirm NumRecs set to the last record}
      if (RNum > NumRecs) then
      begin {see if normal skip to 1+last or REAL range error}
         if (RNum > succ(NumRecs)) then  {Out of range?}
         begin
           dfFileErr := gsDBFRangeError;
           gsTestForOk(dfFileErr,dbfGetRecError);
         end;
         File_EOF := true;
{!V!         exit;}
      end;
   end;
   gsDBFEvent(dbPreRead,RecNum);
   if not gsRead(HeadLen+((RNum-1) * RecLen), CurRecord^, RecLen) then
                                      {Read RecLen bytes into memory buffer}
                                      {for the correct physical record}
   begin
      File_EOF := dfFileErr = gsShortDiskRead;
{!V!      exit;}
   end;

{-Fix for Mark-}
{-Removed for VFP 3.0}
(*
   if CurRecord^[1] = #0 then
   begin
      FillChar(CurRecord^[1],RecLen-1,' ');
      gsWrite(HeadLen+((RNum-1)*RecLen),CurRecord^,RecLen);
   end;
*)
   RecNumber := RNum;                 {Set objectname.RecNumber = this record }
   gsDBFEvent(dbPostRead,RNum);
   Move(CurRecord^, OrigRec^, RecLen);
   gsGetRec := true;
END;                  {GetRec}

Function GSO_dBaseDBF.gsHdrRead: Boolean;
var
   rs: longint;
begin
   if dfFileShrd and not FileIsLocked then
   begin
      if GSO_DiskFile.gsRead(0, HeadProlog, 32) then
      begin
         rs := (gsFileSize-HeadLen) div RecLen;   {!!RFG 020598}
         ExtTableChg :=  (NumRecs <> rs) or {!!RFG 081897}
                         (UpdateTime <> HeadProlog.MultUseFlg);
         NumRecs := rs;                           {!!RFG 020598}
         UpdateTime := HeadProlog.MultUseFlg;
         gsHdrRead := true;
      end
      else
      begin
         gsHdrRead := false;
      end;
   end
   else
   begin
      gsHdrRead := true;
   end;
end;

Function GSO_dBaseDBF.gsHdrWrite(IgnoreLockedFile: boolean): Boolean;
var
   rsl : word;
   yy, mm, dd, wd : word;     {Local variables to get today's date}
   hour, min, sec, sec100: word;
begin
   gsHdrWrite := true;
   if dfReadOnly or (dStatus <> Updated) then exit;  {!!RFG 081897}
   ExtTableChg := false;
   if FileIsLocked and IgnoreLockedFile then exit;   {!!RFG 081897}
   rsl := gsLokHeader(true);
   if not (rsl in [0,1]) then
   begin
      gsTestForOk(dfFileErr, dbfHdrWriteError);
      gsHdrWrite := false;
      exit;
   end;
   gsGetTime (hour,min,sec,sec100);                    {!!RFG 081897}
   UpdateTime := hour;                                 {!!RFG 081897}
   UpdateTime := (UpdateTime shl 6) + min;             {!!RFG 081897}
   UpdateTime := (UpdateTime shl 6) + sec;             {!!RFG 081897}
   UpdateTime := (UpdateTime shl 10) + sec100;         {!!RFG 081897}
   gsGetDate (yy,mm,dd,wd);
   HeadProlog.year := yy mod 100;  {Extract the Year}
   HeadProlog.month := mm;         {Extract the Month}
   HeadProlog.day := dd;           {Extract the Day}
   HeadProlog.RecordCount := NumRecs; {Update number records in file}
   HeadProlog.DBTableFlag := IndexFlag or MemoFlag or DBCFlag;
   HeadProlog.MultUseFlg := UpdateTime;
   HeadProlog.UserIDLast := gsvUserID;   {!!RFG 081897}
   if gsWrite(0, HeadProlog, 32) then
      dStatus := NotUpdated;          {Reset updated status}
   rsl := gsLokHeader(false);
   if not (rsl in [0,1]) then
   begin
      gsTestForOk(dfFileErr, dbfHdrWriteError);
      gsHdrWrite := false;
      exit;
   end;
   gsHdrWrite := true;
end;

Function GSO_dBaseDBF.gsLokApnd;  {: boolean;}
begin
   gsLokApnd := gsLokIt(dfDirtyReadMax,1);
end;

Function GSO_dBaseDBF.gsLokFile;  {: boolean;}
var
   fl: boolean;
begin
   fl := gsLokIt(dfDirtyReadMin, dfDirtyReadRng);
   FileIsLocked := false;         {Lock file, allow dirty read}
   if fl then gsHdrRead;          {Only call if the lock was successful}
   FileIsLocked := fl;
   gsLokFile := FileIsLocked;
end;

Function GSO_dBaseDBF.gsLokFullFile;  {: boolean;}
var
   fl: boolean;
begin
   fl := gsLokIt(0, dfDirtyReadLmt); {Lock all possible filesize}
   FileIsLocked := false;                                            {Lock file, allow dirty read}
   gsHdrRead;
   FileIsLocked := fl;
   gsLokFullFile := FileIsLocked;
end;

Function GSO_dBaseDBF.gsLokHeader(OnOff: boolean): integer;     {!!RFG 121097}

var
   rsl : word;
   hour, min, sec, sec100: word;
   limitsec: word;
   startsec: word;
begin
   rsl := 0;
   if dfFileShrd and (not FileIsLocked) then
   begin
      if OnOff then
      begin
         if HdrLocked = 0 then
            rsl := GS_LockFile(dfFileHndl,0,32)
         else
            rsl := 0;
      end
      else
      begin
         if HdrLocked = 1 then
            rsl := GS_UnLockFile(dfFileHndl,0,32)
         else
            rsl := 0;
      end;
      if not (rsl in [0,1]) then
      begin
         gsGetTime(hour,min,sec,sec100);
         startsec := sec;
         limitsec := sec+GSwrdAccessSeconds;
         repeat
            if OnOff then
               rsl := GS_LockFile(dfFileHndl,0,32)
            else
               rsl := GS_UnLockFile(dfFileHndl,0,32);
            GSCheckMessages;
            gsGetTime(hour,min,sec,sec100);
            if sec < startsec then sec := sec+60;
         until (rsl in [0,1]) or (sec > limitsec);
      end;
   end;
   if OnOff then
      inc(HdrLocked)
   else
      dec(HdrLocked);
   dfFileErr := rsl;
   gsLokHeader := rsl;
end;

Function GSO_dBaseDBF.gsLokIt;  {(fposn,flgth: longint): boolean}
var
   rsl: boolean;
begin
   if dfFileShrd then
   begin
      if not dfLockRec then LockCount := 0;
      rsl := FileIsLocked;
      if not rsl then
      begin
         rsl := gsLockRecord(fposn,flgth);
         if not rsl then gsTestForOk(dfFileErr,dskLockError);
      end;
      if rsl then
      begin
         inc(LockCount);
         gsLokIt := true;
      end
      else
         gsLokIt := false;
   end
   else
      gsLokIt := true;
end;

Function GSO_dBaseDBF.gsLokRcrd;  {: boolean;}
var
  rsl: boolean;
begin
   rsl := false;
   case dfLockStyle of
      DB4Lock  : begin
                    rsl := gsLokIt(dfDirtyReadMax - RecNumber - 1, 1);
                 end;
      ClipLock : begin
                    rsl := gsLokIt(dfDirtyReadMin + RecNumber, 1);
                 end;
      Default,
      FoxLock  : begin
                    if gsWithIndex then
                       rsl := gsLokIt(dfDirtyReadMax - RecNumber, 1)
                    else
                       rsl := gsLokIt(dfDirtyReadMin+
                                  (HeadLen+((RecNumber-1)*RecLen)), 1);
                 end;
   end;
   gsLokRcrd := rsl;
end;

Function GSO_dBaseDBF.gsLokOff: boolean;
begin
   gsLokOff := true;
   if not dfLockRec then
   begin
      LockCount := 0;
      exit;
   end;
   dec(LockCount);
   if LockCount > 0 then exit;   {Could have stacked locks if programmer}
                                 {and automatic locking.  Only unlock   }
                                 {when all locks clear                  }
   if FileIsLocked then gsHdrWrite(false);                {!!RFG 081997}
   GSLokOff := gsUnlock;
   FileIsLocked := false;
end;

Function GSO_dBaseDBF.gsOpen: boolean;
BEGIN              { GS_dBase_Open }
   gsOpen := true;
   if dStatus = NotOpen then          {Do only if file not already open}
   begin
      gsOpen := gsReset;               {Open .DBF file}
      dStatus := NotUpdated;          {Set status to 'Not Updated' }
      RecNumber := 0;                 {Set current record to zero }
      File_TOF := true;
      FillChar(CurRecord^,RecLen,' ');{empty record buffer}
      FillChar(OrigRec^,RecLen,' ');{empty record buffer}
      LockCount := 0;
      dState := dbInactive;
      gsHdrRead;                        {!!RFG 091697}
   end;
END;               { GS_dBase_Open }

Function GSO_dBaseDBF.gsPutRec(RecNum : LongInt): boolean;
VAR
   Stus   : boolean;
BEGIN
   gsDBFEvent(dbPreWrite,RecNum);
   Stus := true;
   IF (RecNum > NumRecs) or (RecNum < 1) or (dState = dbAppend) then
      Stus := gsAppend
   else
   begin
      if dfAutoShare and not FileIsLocked then
      begin
         Stus := gsLokRcrd;
      end;
      if Stus then
      begin
         dStatus := Updated;            {Set file status to 'Updated'}
         Stus := gsWrite(HeadLen+((RecNum-1)*RecLen),CurRecord^,RecLen);
         if Stus then
         begin
            RecNumber := RecNum;
            IntTableChg := true;                {!!RFG 081997}
            gsHdrRead;                          {!!RFG 091697}
            gsHdrWrite(true);                   {!!RFG 081897}
         end;
         if dfAutoShare and not FileIsLocked then
            gsLokOff;
      end;
   end;
   gsPutRec := Stus;
   if Stus then
   begin
      gsDBFEvent(dbPostWrite,RecNum);
      Move(CurRecord^, OrigRec^, RecLen);
   end;
END;                        {PutRec}

Function GSO_dBaseDBF.gsReplace: boolean;
begin
   gsReplace := gsPutRec(RecNumber);
end;
{
procedure GSO_dBaseDBF.gsReturnDateTimeUser(var dt, tm, us: longint);
begin
   gsHdrRead;
   dt := HeadProlog.Year;
   dt := (dt shl 8) + HeadProlog.Month;
   dt := (dt shl 8) + HeadProlog.Day;
   tm := UpdateTime;
   us := HeadProlog.UserIDLast;
end;
}

Procedure GSO_dBaseDBF.gsSetLockProtocol(LokProtocol: GSsetLokProtocol);
var
   i: integer;
begin
   inherited gsSetLockProtocol(LokProtocol);
   for i := 1 to NumFields do
       if Fields^[i].dbMemoObj <> nil then
          Fields^[i].dbMemoObj^.gsSetLockProtocol(LokProtocol);
end;

Procedure GSO_dBaseDBF.gsStatusUpdate(stat1,stat2,stat3 : longint);
begin
end;

Function  GSO_DBaseDBF.gsWithIndex: boolean;
begin
   gsWithIndex := false;
end;

{------------------------------------------------------------------------------
                                GSO_dBaseFld
------------------------------------------------------------------------------}

constructor GSO_dBaseFld.Create(const FName : String; FMode: byte);
var
   i   : integer;
   offset : integer;
begin
   GSO_dBaseDBF.Create(FName, FMode);
   if ObjType <> GSobtDBFFile then exit;
   Case FileVers of
      DB3WithMemo,
      DB4WithMemo,
      FXPWithMemo : WithMemo := true;
      VFP3File    : WithMemo := (HeadProlog.DBTableFlag and $02) <> 0;
      else WithMemo := false;
   end;
   offset := 1;
   for i := 1 to NumFields do
   begin
      Fields^[i].dbFieldNum := i;
      Fields^[i].dbFieldOffset := offset;
      Fields^[i].dbMemoObj := nil;
      offset := offset + Fields^[i].dbFieldLgth;
   end;
   OEMChars := true;
   WithIndex := IndexFlag <> 0;
   gsClearFldChanged;
end;

Destructor GSO_dBaseFld.Destroy;
var
   i : integer;
begin
   if Fields <> nil then
   begin
      for i := 1 to NumFields do
      begin
         if Fields^[i].dbMemoObj <> nil then
         begin
            Fields^[i].dbMemoObj^.Free;
            Fields^[i].dbMemoObj := nil;
         end;
      end;
   end;
   inherited Destroy;
end;

function GSO_dBaseFld.gsAnalyzeField(const fldst : String): GSP_DBFField;
var
   LastFieldCk : integer;
   FPC: array[0..79] of char;
begin
   LastFieldCk := NumFields;
   if gsFieldLocate(Fields,fldst,LastFieldCk) then
      gsAnalyzeField := @Fields^[LastFieldCk]
   else
   begin
      gsAnalyzeField := nil;
      StrPCopy(FPC,fldst);
      FoundError(gsInvalidField,dbfAnalyzeField,FPC)
   end;
end;

function GSO_dBaseFld.gsFieldExists(const fldst : String): Boolean;
var
   LastFieldCk : integer;
   FPC: array[0..79] of char;
begin
   LastFieldCk := NumFields;
   if gsFieldLocate(Fields,fldst,LastFieldCk) then
      gsFieldExists := True
   else
      gsFieldExists := False;
end;

procedure GSO_dBaseFld.gsBlank;
var
   i: integer;
begin
   FillChar(CurRecord^[0], RecLen, ' '); {Fill spaces for RecLen bytes}
   for i := 1 to NumFields do
   begin
      if Fields^[i].dbMemoObj <> nil then Fields^[i].dbMemoObj^.moMemoClear;
      if Fields^[i].dbFieldType in ['N','F'] then
         gsNumberPutN(i,0.0);
      if FileVers = VFP3File then
         if Fields^[i].dbFieldType in ['I','B','G','M','T','Y'] then
            gsNumberPutN(i,0.0);
   end;
   FillChar(CurRecChg^,succ(NumFields),#1);
   gsDBFEvent(dbRecordChange,0);
end;

function  GSO_dBaseFld.gsCheckField;
                          {(const st: String255; ftyp: char): GSP_DBFField;}
var
   FPtr : GSP_DBFField;
   typOk: boolean;
   FPC: array[0..79] of char;
begin
   FPtr := gsAnalyzeField(st);
   if FPtr <> nil then
   begin
      if FPtr^.dbFieldType <> ftyp then
      begin
         typOk := false;
         case ftyp of
            'N' : typOk := (FPtr^.dbFieldType in ['M','F','B','G','I']);
            'G' : typOk := (FPtr^.dbFieldType in ['M','B']);
         end;
         if not typOk then
         begin
            StrPCopy(FPC, st);
            FoundError(gsBadFieldType,dbfCheckFieldError,FPC);
            FPtr := nil;
         end;
      end;
   end;
   gsCheckField := FPtr;
end;

procedure GSO_dBaseFld.gsClearFldChanged;
begin
   FillChar(CurRecChg^,succ(NumFields),#0);
end;

Function GSO_dBaseFld.gsClose: boolean;
var
   i: integer;
begin
   for i := 1 to NumFields do
   begin
      if Fields^[i].dbMemoObj <> nil then
      begin
         Fields^[i].dbMemoObj^.Free;
         Fields^[i].dbMemoObj := nil;
      end;
   end;
   gsClose := inherited gsClose;
END;                        { GS_dBase_Close }

function  GSO_dBaseFld.gsDateGet(const st: String): GS_Date_StrTyp;
begin
   FieldPtr := gsCheckField(st,'D');
   if (FieldPtr <> nil) then
      gsDateGet := gsDateGetN(FieldPtr^.dbFieldNum)
   else
      gsDateGet := GS_Date_Empty;
end;

function  GSO_dBaseFld.gsDateGetN;  {(n : integer) : longint;}
var
{   v : longint;}
   s,s1 : GS_Date_StrTyp;
{   p : PChar;
   p1: PChar;}
begin
   if (n > NumFields) or (n < 1) then s := GS_Date_Empty
   else
   begin
      FieldPtr := @Fields^[n];
      s1 := gsFieldPull(FieldPtr, CurRecord);
      s:=Copy(s1,7,2)+'.'+Copy(s1,5,2)+'.';
      If GSblnUseCentury then
           s:=s+Copy(s1,1,4)
      else s:=s+Copy(s1,3,2);

{
      v := GS_Date_Juln(s);
      if v = GS_Date_JulInv then
      begin
         GetMem(p,80);
         StrCopy(p, 'Invalid date in field ');
         p1 := StrEnd(p);
         StrPCopy(p1, ExtractFileNameOnly(StrPas(dfFileName)));
         p1 := StrEnd(p1);
         StrCopy(p1,'->');
         p1 := StrEnd(p1);
         StrCopy(p1, FieldPtr^.dbFieldName);
         p1 := StrEnd(p1);
         StrPCopy(p1,' ('+s+')');
         FoundError(gsBadFieldType,gsFMsgOnly,p);
         FreeMem(p,80);
         v := 0;
      end;
}
   end;
   gsDateGetN := s;
end;

function GSO_dBaseFld.gsDatePut(const st : String; jdte : GS_Date_StrTyp): boolean;
begin
   FieldPtr := gsCheckField(st,'D');
   if (FieldPtr <> nil) then
       gsDatePut := gsDatePutN(FieldPtr^.dbFieldNum, jdte)
   else
      gsDatePut := false;
end;

function GSO_dBaseFld.gsDatePutN;  {(n : integer; jdte : longint)}
var s:GS_Date_StrTyp;
begin
{   if jdte = GS_Date_JulInv then
   begin
      gsDatePutN := false;
      FoundError(gsBadFieldType,dbfBadDateString,nil);
      exit;
   end;
}
   if (n > NumFields) or (n < 1) then
      gsDatePutN := false
   else
   begin
      FieldPtr := @Fields^[n];
      if FieldPtr^.dbFieldType = 'D' then
      begin
         s:=Copy(jdte,4,2)+Copy(jdte,1,2);

         If jdte[7] > '5' then
            s:='19'+Copy(jdte,7,2)+s
         else
            s:='20'+Copy(jdte,7,2)+s;

         gsFieldPush(FieldPtr,s{GS_Date_dBStor(jdte)}, CurRecord);
         gsDatePutN := true;
      end
      else
         gsDatePutN := false;
   end;
end;

function GSO_dBaseFld.gsDeleteRec: boolean;
begin
   CurRecord^[0] := GS_dBase_DltChr;  {Put '*' in first byte of current record}
   CurRecChg^[0] := 1;
   gsDeleteRec := gsPutRec(RecNumber);    {Write the current record to disk }
end;                 {GS_dBase_Delete}

Function GSO_dBaseFld.gsFieldGet;  {(const fnam : String255) : String255}
begin
   FieldPtr := gsAnalyzeField(fnam);
   if (FieldPtr <> nil)  then
      gsFieldGet := gsFieldPull(FieldPtr, CurRecord)
         else gsFieldGet := '';
end;

Function GSO_dBaseFld.gsFieldGetN;  {(fnum : integer) : String255}
begin
   if (fnum > NumFields) or (fnum < 1) then
   begin
      gsFieldGetN := '';
      exit;
   end;
   FieldPtr := @Fields^[fnum];
   gsFieldGetN := gsFieldPull(FieldPtr, CurRecord);
end;

Function GSO_dBaseFld.gsFieldLocate(fdsc: GSP_FieldArray; const st: String;
                                  var i: integer): boolean;
var
   mtch : boolean;
   ix   : integer;
   d: integer;
   za   : array[0..11] of char;
begin
   StrPCopy(za,st);
   ix := StrLen(za);
   while (za[ix] = ' ') and (ix > 0) do
   begin
      za[ix] := #0;
      dec(ix);
   end;
   ix := NumFields;
   i := 1;
   mtch := false;
   while (i <= ix) and not mtch do
   begin
      if CmprOEMPChar
             (za,GSR_DBFField(fdsc^[i]).dbFieldName,pCtyUpperCase,d) = 0 then
         mtch := true
      else
         inc(i);
   end;
   gsFieldLocate := mtch;
end;

Function GSO_dBaseFld.gsFieldNo(const st : string): integer;
var
   LastFieldCk : integer;
begin
   if not gsFieldLocate(Fields,st,LastFieldCk) then
      LastFieldCk := 0;
   gsFieldNo := LastFieldCk;
end;

Function GSO_dBaseFld.gsFieldPull(fr: GSP_DBFField; fp: GSptrCharArray) : String;
var
   s: PChar;
   siz: word;
begin
   with fr^ do begin
      siz := dbFieldLgth;
      GetMem(s,siz+1);
      StrLCopy(s, PChar(fp)+dbFieldOffset, siz);
      gsFieldPull := StrPas(s);
      FreeMem(s,siz+1);
   end;
end;

Procedure GSO_dBaseFld.gsFieldPush(fr: GSP_DBFField; const st : String;
                                 fp: GSptrCharArray);
var
   len: integer;
   siz: integer;
begin
   len := length(st);
   with fr^ do
   begin
      siz := dbFieldLgth;
      FillChar(fp^[dbFieldOffset],siz,#32);
      if len > 0 then
      begin
         if len > siz then len := siz;
         if dbFieldType in ['C','L','D'] then
            move(st[1],fp^[dbFieldOffset],len)
         else
            move(st[1],fp^[dbFieldOffset+(siz-len)],len);
      end;
      CurRecChg^[Fr^.dbFieldNum] := 1;
   end;
   gsDBFEvent(dbFieldChange,fr^.dbFieldNum);
end;

function GSO_dBaseFld.gsFieldPut(const fnam, st : String): boolean;
begin
   FieldPtr := gsAnalyzeField(fnam);
   if (FieldPtr <> nil)  then
   begin
      gsFieldPush(FieldPtr,st, CurRecord);
      gsFieldPut := true;
   end
   else
      gsFieldPut := false;
end;

function GSO_dBaseFld.gsFieldPutN(fnum : integer; const st : String): boolean;
begin
   if (fnum > NumFields) or (fnum < 1) then
      gsFieldPutN := false
   else
   begin
      FieldPtr := @Fields^[fnum];
      gsFieldPush(FieldPtr,st, CurRecord);
      gsFieldPutN := true;
   end;
end;

function GSO_dBaseFld.gsFieldDecimals;  {(i : integer) : integer}
begin
   if (i > NumFields) or (i < 1) then
   begin
      gsFieldDecimals := 0;
      exit;
   end;
   FieldPtr := @Fields^[i];
   if not (FieldPtr^.dbFieldType = 'C') then
      gsFieldDecimals := FieldPtr^.dbFieldDec
   else
      gsFieldDecimals := 0;
end;

function GSO_dBaseFld.gsFieldLength(i : integer) : integer;
var
   siz: integer;
begin
   if (i > NumFields) or (i < 1) then
   begin
      gsFieldLength := 0;
      exit;
   end;
   FieldPtr := @Fields^[i];
   siz := FieldPtr^.dbFieldLgth;
   gsFieldLength := siz;
end;

function GSO_dBaseFld.gsFieldName(i : integer) : String;
begin
   if (i > NumFields) or (i < 1) then
   begin
      gsFieldName := '';
      exit;
   end;
   FieldPtr := @Fields^[i];
   gsFieldName := StrPas(FieldPtr^.dbFieldName);
end;

function GSO_dBaseFld.gsFieldType;  {(i : integer) : char}
begin
   if (i > NumFields) or (i < 1) then
   begin
      gsFieldType := #0;
      exit;
   end;
   FieldPtr := @Fields^[i];
   gsFieldType := FieldPtr^.dbFieldType;
end;

function GSO_dBaseFld.gsFieldOffset;  {(i : integer) : integer}
begin
   if (i > NumFields) or (i < 1) then
   begin
      gsFieldOffset := 0;
      exit;
   end;
   FieldPtr := @Fields^[i];
   gsFieldOffset := FieldPtr^.dbFieldOffset;
end;

Function GSO_dBaseFld.gsFormula(who, st, fmrec: PChar;
                              var Typ: char; var Chg: boolean): integer;
begin
   gsFormula := -1;
end;

function GSO_dBaseFld.gsGetRec(RecNum : LongInt): boolean;
VAR
   i      : integer;
BEGIN
   if GSO_dBaseDBF.gsGetRec(RecNum) then
   begin
      gsGetRec := true;
      gsClearFldChanged;           {Clear changed flag for all fields}
      for i := 1 to NumFields do
         if Fields^[i].dbMemoObj <> nil then Fields^[i].dbMemoObj^.moMemoClear;
   end
   else
      gsGetRec := false;
end;

function  GSO_dBaseFld.gsLogicGet(const st : String) : boolean;
begin
   FieldPtr := gsCheckField(st,'L');
   if (FieldPtr <> nil) then
      gsLogicGet := gsLogicGetN(FieldPtr^.dbFieldNum)
   else
      gsLogicGet := false;
end;

function  GSO_dBaseFld.gsLogicGetN;  {(n : integer) : boolean}
var
   v : boolean;
begin
   if (n > NumFields) or (n < 1) then v := false
   else
   begin
      FieldPtr := @Fields^[n];
      v := pos(gsFieldPull(FieldPtr, CurRecord), LogicalTrue) > 0;
   end;
   gsLogicGetN := v;
end;

function GSO_dBaseFld.gsLogicPut(const st : String; b : boolean): boolean;
begin
   FieldPtr := gsCheckField(st,'L');
   if (FieldPtr <> nil)  then
      gsLogicPut := gsLogicPutN(FieldPtr^.dbFieldNum, b)
   else
      gsLogicPut := false;
end;

function GSO_dBaseFld.gsLogicPutN;  {(n : integer; b : boolean)}
begin
   if (n > NumFields) or (n < 1) then
      gsLogicPutN := false
   else
   begin
      FieldPtr := @Fields^[n];
      if FieldPtr^.dbFieldType = 'L' then
      begin
         if b then
            gsFieldPush(FieldPtr, 'T', CurRecord)
         else
            gsFieldPush(FieldPtr, 'F', CurRecord);
         gsLogicPutN := true;
      end
      else
      begin
         FoundError(gsBadFieldType,dbfCheckFieldError,nil);
         gsLogicPutN := false;
      end;
   end;
end;

Function GSO_dBaseFld.gsMemoType: GSptrMemo;
var
   pMemo: GSptrMemo;
begin
   pMemo := nil;
   gsMemoType := nil;
   if not WithMemo then exit;
   case FileVers of
      DB3WithMemo : pMemo := New(GSptrMemo,Create(@Self,StrPas(dfFileName),FileVers,dfFileMode));
{!      DB4WithMemo : pMemo := New(GSptrMemo4,Create(@Self,StrPas(dfFileName),FileVers,dfFileMode));}
      VFP3File,
      FXPWithMemo : pMemo := New(GSptrFXMemo20,Create(@Self,StrPas(dfFileName),FileVers,dfFileMode));
   end;
   if pMemo <> nil then
   begin
      if (pMemo^.ObjType = GSobtFPTFile) or
         (pMemo^.ObjType = GSobtDBTFile) then
            pMemo^.gsSetLockProtocol(dfLockStyle)
      else
      begin
         pMemo^.Free;
         pMemo := nil;
      end;
   end;
   WithMemo := pMemo <> nil;
   gsMemoType := pMemo;
end;

Function GSO_dBaseFld.gsMemoFieldCheck(n: integer): GSptrMemo;
begin
   if (n > NumFields) or (n < 1) or
      (not (Fields^[n].dbFieldType in ['M','G','B'])) then gsMemoFieldCheck := nil
   else
   begin
      if Fields^[n].dbMemoObj = nil then
         Fields^[n].dbMemoObj := gsMemoType;
      gsMemoFieldCheck := Fields^[n].dbMemoObj;
   end;
end;

Function GSO_dBaseFld.gsMemoFieldNumber(const st: string): integer;
var
   i: integer;
begin
   FieldPtr := gsCheckField(st,'G');
   if (FieldPtr <> nil) then
   begin
      i := FieldPtr^.dbFieldNum;
      gsMemoFieldNumber := i;
      if Fields^[i].dbMemoObj = nil then
         Fields^[i].dbMemoObj := gsMemoType;
   end
   else
      gsMemoFieldNumber := 0;
end;
{
function  GSO_dBaseFld.gsMemoGet(const st: String): boolean;
begin
   gsMemoGet := gsMemoGetN(gsMemoFieldNumber(st));
end;

function  GSO_dBaseFld.gsMemoGetN(n : integer) : boolean;
var
   v : longint;
   f : FloatNum;
   m : GSptrMemo;
begin
   v := 0;
   m := gsMemoFieldCheck(n);
   if m <> nil then
   begin
      f := gsNumberGetN(n);
      v := trunc(f);
      if v > 0 then
         m^.moMemoGet(v)
      else
         m^.moMemoClear;
   end;
   gsMemoGetN := v > 0;
end;

function GSO_dBaseFld.gsMemoPut(const st : String): boolean;
begin
   gsMemoPut := gsMemoPutN(gsMemoFieldNumber(st));
end;

function GSO_dBaseFld.gsMemoPutN(n : integer): boolean;
var
   f: FloatNum;
   v1: longint;
   v2: longint;
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(n);
   if m <> nil then
   begin
      f := gsNumberGetN(n);
      v1 := trunc(f);
      v2 := m^.moMemoPut(v1);
      if v1 <> v2 then
      begin
         f := v2;
         gsNumberPutN(n, f);
      end;
      gsMemoPutN := true;
   end
   else
      gsMemoPutN := false;
end;

Function GSO_dBaseFld.gsMemoLines(const fnam: string): integer;
begin
   gsMemoLines := gsMemoLinesN(gsMemoFieldNumber(fnam));
end;

Function GSO_dBaseFld.gsMemoLinesN(fnum: integer): integer;
var
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
      gsMemoLinesN := m^.moMemoLines
   else
      gsMemoLinesN := 0;
end;

Function GSO_dBaseFld.gsMemoGetLine(const fnam: string;linenum: integer): string;
begin
   gsMemoGetLine := gsMemoGetLineN(gsMemoFieldNumber(fnam),linenum);
end;

Function GSO_dBaseFld.gsMemoGetLineN(fnum: integer;linenum: integer): string;
var
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
      gsMemoGetLineN := m^.moMemoGetLine(linenum)
   else
      gsMemoGetLineN := '';
end;

Function GSO_dBaseFld.gsMemoDelLine(const fnam: string;linenum: integer): boolean;
begin
   gsMemoDelLine := gsMemoDelLineN(gsMemoFieldNumber(fnam),linenum);
end;

Function GSO_dBaseFld.gsMemoDelLineN(fnum: integer;linenum: integer): boolean;
var
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
   begin
      m^.moMemoDelLine(linenum);
      gsMemoDelLineN := true;
   end
   else
      gsMemoDelLineN := false;
end;
}
Function GSO_dBaseFld.gsMemoClear(const fnam: string): boolean;
begin
   gsMemoClear := gsMemoClearN(gsMemoFieldNumber(fnam));
end;

Function GSO_dBaseFld.gsMemoClearN(fnum: integer): boolean;
var
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
   begin
      m^.moMemoClear;
      gsMemoClearN := true;
   end
   else
      gsMemoClearN := false;
end;

{
Function GSO_dBaseFld.gsMemoInsLine(const fnam: string;linenum: integer;
                              const st: string): boolean;
begin
   gsMemoInsLine := gsMemoInsLineN(gsMemoFieldNumber(fnam),linenum,st);
end;

Function GSO_dBaseFld.gsMemoInsLineN(fnum: integer;linenum: integer;
                               const st: string): boolean;
var
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
   begin
      gsMemoInsLineN := true;
      m^.moMemoInsLine(linenum,st);
   end
   else
      gsMemoInsLineN := false;
end;

Function GSO_dBaseFld.gsMemoWidth(const fnam: string;l: integer): boolean;
begin
   gsMemoWidth := gsMemoWidthN(gsMemoFieldNumber(fnam),l);
end;

Function GSO_dBaseFld.gsMemoWidthN(fnum: integer;l: integer): boolean;
var
   m : GSptrMemo;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
   begin
      gsMemoWidthN := true;
      m^.moMemoWidth(l);
   end
   else
      gsMemoWidthN := false;
end;
}


Function GSO_dBaseFld.gsMemoSize(const fnam: string): longint;
begin
   gsMemoSize := gsMemoSizeN(gsMemoFieldNumber(fnam));
end;

Function GSO_dBaseFld.gsMemoSizeN(fnum: integer): longint;
var
   m : GSptrMemo;
   blk: longint;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
   begin
      blk := trunc(gsNumberGetN(fnum));
      gsMemoSizeN := m^.moMemoSize(blk);
   end
   else
      gsMemoSizeN := 0;
end;


Function GSO_dBaseFld.gsMemoLoad(const fieldnam: string;buf: pointer;
                           var cb: longint): boolean;
begin
   gsMemoLoad := gsMemoLoadN(gsMemoFieldNumber(fieldnam),buf,cb);
end;

Function GSO_dBaseFld.gsMemoLoadN(fieldnum: integer;buf: pointer;
                            var cb: longint): boolean;
var
   m : GSptrMemo;
   i: longint;
   f: FloatNum;
begin
   m := gsMemoFieldCheck(fieldnum);
   if m <> nil then
   begin
      f := gsNumberGetN(fieldnum);
      i := trunc(f);
      m^.moMemoRead(buf,i,cb);  {load CB blocks to BUF start from i-block}
      gsMemoLoadN := true;
   end
   else
      gsMemoLoadN := false;
end;

{new------------------------------------------------------------------}
Function GSO_dBaseFld.gsMemo2File(const fieldnam,filename: string): boolean;
begin
   gsMemo2File := gsMemo2FileN(gsMemoFieldNumber(fieldnam),filename);
end;

Function GSO_dBaseFld.gsMemo2FileN(fieldnum: integer;const filename:string): boolean;
var
   m : GSptrMemo;
   i: longint;
   f: FloatNum;
begin
   m := gsMemoFieldCheck(fieldnum);
   if m <> nil then
   begin
      f := gsNumberGetN(fieldnum);
      i := trunc(f);
      m^.moMemo2File(i,filename);  {}
      gsMemo2FileN := true;
   end
   else
      gsMemo2FileN := false;
end;
{new------------------------------------------------------------------}
Function GSO_dBaseFld.gsFile2Memo(const fieldnam,filename: string): boolean;
begin
   gsFile2Memo := gsFile2MemoN(gsMemoFieldNumber(fieldnam),filename);
end;

Function GSO_dBaseFld.gsFile2MemoN(fieldnum: integer;const filename:string): boolean;
var
   m : GSptrMemo;
   i: longint;
   f: FloatNum;
begin
   m := gsMemoFieldCheck(fieldnum);
   if m <> nil then
   begin
      f := gsNumberGetN(fieldnum);
      i := trunc(f);
      i := m^.moFile2Memo(i,filename);  {}
      f := i;
      gsNumberPutN(fieldnum, f);
      gsFile2MemoN :=true;
   end
   else
      gsFile2MemoN := false;
end;
{----------------------------------------------------------------}

Function GSO_dBaseFld.gsMemoSave(const fnam: string;buf: pointer;
                           var cb: longint): longint;
begin
   gsMemoSave := gsMemoSaveN(gsMemoFieldNumber(fnam),buf,cb);
end;

Function GSO_dBaseFld.gsMemoSaveN(fnum: integer;buf: pointer;
                            var cb: longint): longint;
var
   m : GSptrMemo;
   f: FloatNum;
   i: longint;
begin
   m := gsMemoFieldCheck(fnum);
   if m <> nil then
   begin
      f := gsNumberGetN(fnum);  {Get Old Memo Location}
      i := trunc(f);
      gsMemoSaveN := m^.moMemoWrite(buf,i,cb);
      f := i;
      gsNumberPutN(fnum, f);
   end
   else
      gsMemoSaveN := 0;
end;

function GSO_dBaseFld.gsNumberGet(const st : String) : FloatNum;
begin
   FieldPtr := gsCheckField(st,'N');
   if (FieldPtr <> nil) then
      gsNumberGet := gsNumberGetN(FieldPtr^.dbFieldNum)
   else
      gsNumberGet := 0.0;
end;

function  GSO_dBaseFld.gsNumberGetN;  {(n : integer) : FloatNum}
var
   v : FloatNum;
   li: longint;
   r : integer;
   s : string[31];
   p : PChar;
   p1: PChar;
begin
   if (n > NumFields) or (n < 1) then v := 0.0
   else
   begin
      FieldPtr := @Fields^[n];
      if (FileVers = VFP3File) and
         (FieldPtr^.dbFieldType in ['Y','T','B','I','M','G']) then
      begin
         case FieldPtr^.dbFieldType of
            'I',
            'M',
            'G'  : begin
                      Move(CurRecord^[FieldPtr^.dbFieldOffset],li,SizeOf(Longint));
                      v := li;
                   end;
            'B'  : begin
                      Move(CurRecord^[FieldPtr^.dbFieldOffset],v,8);
                   end;
            'T'  : begin
                      Move(CurRecord^[FieldPtr^.dbFieldOffset],li,SizeOf(Longint));
                      if li = $20202020 then
                         li := 2415019;        {assign 12/30/1899 as date}
                      v := li - GSTimeStampDiff;
                      v := v * GSMSecsInDay;
                      Move(CurRecord^[FieldPtr^.dbFieldOffset+SizeOf(Longint)],li,SizeOf(Longint));
                      if li = $20202020 then
                         li := 0;        {assign midnight as time}
                      v := v+li;
                   end;
            'Y'  : begin
                      Move(CurRecord^[FieldPtr^.dbFieldOffset+SizeOf(Longint)],li,SizeOf(Longint));
                      v := li;
                      v := v*$10000*$10000;
                      Move(CurRecord^[FieldPtr^.dbFieldOffset],li,SizeOf(Longint));
                      v := v+li;
                      v := v/10000;
                   end;
         end;
      end
      else
      begin
         s := RTrim(gsFieldPull(FieldPtr, CurRecord));
         if length(s) = 0 then
            v := 0.0
         else
         begin
            val(s,v,r);
            if r <> 0 then
            begin
               GetMem(p,80);
               StrCopy(p, 'Invalid number in field ');
               p1 := StrEnd(p);
               StrPCopy(p1, ExtractFileNameOnly(StrPas(dfFileName)));
               p1 := StrEnd(p1);
               StrCopy(p1,'->');
               p1 := StrEnd(p1);
               StrCopy(p1, FieldPtr^.dbFieldName);
               p1 := StrEnd(p1);
               StrPCopy(p1,' ('+s+')');
               FoundError(gsBadFieldType,gsFMsgOnly,p);
               FreeMem(p,80);
               v := 0;
            end;
         end;
      end;
   end;
   gsNumberGetN := v;
end;

function GSO_dBaseFld.gsNumberPut(const st : String; r : FloatNum): boolean;
begin
   FieldPtr := gsCheckField(st,'N');
   if (FieldPtr <> nil)  then
      gsNumberPut := gsNumberPutN(FieldPtr^.dbFieldNum, r)
   else
      gsNumberPut := false;
end;

function GSO_dBaseFld.gsNumberPutN(n : integer; r : FloatNum): boolean;
var
   s: string;
   m: boolean;
   li: longint;
   z: FloatNum;
begin
   if (n > NumFields) or (n < 1) then
      gsNumberPutN := false
   else
   begin
      FieldPtr := @Fields^[n];
      m := FieldPtr^.dbFieldType in ['N','M','F','B','G'];
      if (not m) and (FileVers = VFP3File) then
         m := FieldPtr^.dbFieldType in ['B','I','T','Y'];
      if m then
      begin
         if (FileVers = VFP3File) and
            (FieldPtr^.dbFieldType in ['Y','T','B','I','M','G']) then
         begin
            case FieldPtr^.dbFieldType of
               'I',
               'M',
               'G'  : begin
                         li := trunc(r);
                         Move(li,CurRecord^[FieldPtr^.dbFieldOffset],SizeOf(Longint));
                      end;
               'B'  : begin
                         Move(r,CurRecord^[FieldPtr^.dbFieldOffset],8);
                      end;
               'T'  : begin
                         z := r / GSMSecsInDay;
                         li := trunc(z);
                         z := li;
                         li := li + GSTimeStampDiff;
                         Move(li,CurRecord^[FieldPtr^.dbFieldOffset],SizeOf(Longint));
                         li := trunc(r - (z * GSMSecsInDay));
                         Move(li,CurRecord^[FieldPtr^.dbFieldOffset+SizeOf(Longint)],SizeOf(Longint));
                      end;
               'Y'  : begin
                         r := r*10000;
                         z := (r/$10000)/$10000;
                         li := trunc(z);
                         Move(li,CurRecord^[FieldPtr^.dbFieldOffset+SizeOf(Longint)],SizeOf(Longint));
                         z := z*$10000*$10000;
                         z := r-z;
                         li := trunc(z);
                         Move(li,CurRecord^[FieldPtr^.dbFieldOffset],SizeOf(Longint));
                      end;
            end;
            CurRecChg^[FieldPtr^.dbFieldNum] := 1;
            gsNumberPutN := true;
         end
         else
         begin
            Str(r:FieldPtr^.dbFieldLgth:FieldPtr^.dbFieldDec,s);
            if length(s) > FieldPtr^.dbFieldLgth then
            begin
               s := StrPas(FieldPtr^.dbFieldName) + ' - ' + s + #0;  {!!RFG 032598}
               FoundError(gsNumberTooBig,dbfBadNumberString,@s[1]);
               gsNumberPutN := false;
            end
            else
            begin
               gsFieldPush(FieldPtr, s, CurRecord);
               gsNumberPutN := true;
            end;
         end;
      end
      else
      begin
         FoundError(gsBadFieldType,dbfCheckFieldError,nil);
         gsNumberPutN := false;
      end;
   end;
end;
{
Function GSO_dBaseFld.gsStringGet(const fnam : String): String;
var
   Fldnum: integer;
begin
   if gsFieldLocate(Fields,fnam,Fldnum) then
      gsStringGet := gsStringGetN(FldNum)
         else gsStringGet := '';
end;

Function GSO_dBaseFld.gsStringGetN(fnum : integer) : String;
var
   s : String;
   d : longint;
begin
   if (fnum > NumFields) or (fnum < 1) then
   begin
      gsStringGetN := '';
      exit;
   end;
   FieldPtr := @Fields^[fnum];
   with FieldPtr^ do
   begin
      s := gsFieldPull(FieldPtr, CurRecord);
      s := RTrim(s);
      case dbFieldType of
         'D' : begin
                  d := GS_Date_DBLoad(s);
                  s := GS_Date_View(d)
               end;
         'L' : begin
                  if pos(s,LogicalTrue) > 0 then
                     s := 'T'
                  else
                     s := 'F';
               end;
         'M' : begin
                 if FileVers = VFP3File then
                 begin
                    if gsNumberGetN(fnum) > 0.1 then
                       s := '1'
                    else
                       s := '0';
                 end
                 else
                     s := LTrim(s);
                  if s > '0' then  s := '---MEMO---' else s := '---memo---';
               end;
         'G' : begin
                  s := LTrim(s);
                  if s > '0' then  s := '-GENERAL--' else s := '-general--';
               end;
         'B' : begin
                  s := LTrim(s);
                  if s > '0' then  s := '--BINARY--' else s := '--binary--';
               end;
         'F',
         'N' : begin
                  s := LTrim(s);
                  if length(s) = 0 then
                  begin
                     Str(0.0:FieldPtr^.dbFieldLgth:FieldPtr^.dbFieldDec,s);
                     s := LTrim(s);
                  end;
               end;
      end;
   end;
   gsStringGetN := s;
end;

function GSO_dBaseFld.gsStringPut(const fnam, st : String): boolean;
begin
   FieldPtr := gsAnalyzeField(fnam);
   if (FieldPtr <> nil) then
      gsStringPut := gsStringPutN(FieldPtr^.dbFieldNum, st)
   else
      gsStringPut := false;
end;

function GSO_dBaseFld.gsStringPutN(fnum : integer; const st : String): boolean;
var
   v : FloatNum;
   r : integer;
   s : string[32];
begin
   if (fnum > NumFields) or (fnum < 1) then
      gsStringPutN := false
   else
   begin
      FieldPtr := @Fields^[fnum];
      case FieldPtr^.dbFieldType of
         'D' : gsStringPutN := gsDatePutN(fnum,GS_Date_Juln(st));
         'N' : begin
                  s := RTrim(st);
                  if length(s) = 0 then
                     v := 0.0
                  else
                  begin
                     val(s,v,r);
                     if (r <> 0) then
                     begin
                        FoundError(gsBadFieldType,dbfBadNumberString,nil);
                        gsStringPutN := false;
                        exit;
                     end;
                  end;
                  gsStringPutN := gsNumberPutN(fnum, v);
               end;
      else
         gsFieldPush(FieldPtr,st,CurRecord);
         gsStringPutN := true;
      end;
   end;
end;
}

Function GSO_dBaseFld.gsUnDelete: boolean;
begin
   CurRecord^[0] := GS_dBase_UnDltChr;
                                     {Put ' ' in first byte of current record}
   CurRecChg^[0] := 1;
   gsUnDelete := gsPutRec(RecNumber);
                                     {Write the current record to disk }
end;

{-----------------------------------------------------------------------------
                              GSO_DBFBuild
-----------------------------------------------------------------------------}

Constructor GSO_DBFBuild.Create(const FName : String);
const
   ext : string = '.DBF';
begin
   inherited Create(32,32);
   FillChar(FileName,4,#0);   {For Delphi 2.0 -- doesn't like objects}
   hasMemo := false;
   dbTypeNoMo := DB3File;
   dbTypeMemo := DB3WithMemo;
   FileName := CapClip(FName,[' ','"']);
   FileName := ChangeFileExtEmpty(FileName,ext);
   dbRecLen := 1;
   dbTitle := ExtractFileNameOnly(FileName);
   GoodToGo := true;
   dFile := nil;
end;

Destructor GSO_DBFBuild.Destroy;
begin
   if dFile = nil then Complete;
   if dFile <> nil then
      dFile^.Free;
   inherited Destroy;
end;

procedure GSO_DBFBuild.Complete;
begin
   if GoodToGo then
   begin
      dFile := nil;
      dFile := New(GSP_DiskFile, Create(FileName,fmOpenReadWrite));
      if (dFile = nil) or (dFile^.ObjType <> GSobtDiskFile) then exit;
      if dFile^.gsRewrite then
      begin
         WriteDBF;
         if HasMemo then WriteDBT;
      end
      else
         dFile^.ObjType := GSobtInitializing;
   end;
end;

procedure GSO_DBFBuild.FreeItem;  {(Item: Pointer)}
begin
  if Item <> nil then
  begin
     FreeMem(Item, SizeOf(GSR_DBFField));
  end;
end;


procedure GSO_DBFBuild.InsertField(const s : String; t : char; l,d : integer);
var
   f : GSP_DBFField;
   j : integer;
begin
   j := length(s);
   if j = 0 then exit;
   if j > 10 then j := 10;
   GetMem(f, SizeOf(GSR_DBFField));
   FillChar(f^, SizeOf(GSR_DBFField), #0);
   Move(s[1],f^.dbFieldName,j);
      AnsiUpperBuff(f^.dbFieldName,j);
   f^.dbFieldType := UpCase(t);
   case f^.dbFieldType of
      'D' : begin
               l := 8;
               d := 0;
            end;
      'L' : begin
               l := 1;
               d := 0;
            end;
      'B',
      'G',
      'M' : begin
               l := 10;
               d := 0;
               hasMemo := true;
            end;
      'C' : begin
               d := l div 256;
               l := l mod 256;
            end;
   end;
   f^.dbFieldLgth := l;
   f^.dbFieldDec := d;
   f^.dbFieldOffset := 0;
   f^.dbFieldNum := 0;
   if f^.dbFieldType = 'M' then hasMemo := true;
   dbRecLen := dbRecLen + l;
   if f^.dbFieldType = 'C' then
      dbRecLen := dbRecLen + (d * 256);
   Insert(f);
end;

Procedure GSO_DBFBuild.WriteDBF;
var
   i : integer;
   yy, mm, dd, wd : word;             {Variables to hold GetDate values}
   eofm: char;
   eohm: char;
BEGIN
   eofm := EOFMark;
   eohm := EOHMark;
   if hasMemo then HeadRec.DBType := dbTypeMemo
      else HeadRec.DBType := dbTypeNoMo;
   gsGetDate (yy,mm,dd,wd);
   HeadRec.year := yy mod 100; {Year}
   HeadRec.month := mm; {Month}
   HeadRec.day := dd; {Day}
   HeadRec.RecordCount := 0;
   HeadRec.Location := (Count*32) + 33;
   HeadRec.RecordLen := dbRecLen;
   FillChar(HeadRec.Reserve1,20,#0);
   dFile^.gsWrite(0, HeadRec, 32);
   for i := 0 to Count-1 do
      dFile^.gsWrite(-1, Items^[i]^, 32);
   dFile^.gsWrite(-1, eohm, 1);            {Put EOH marker }
   dFile^.gsWrite(-1, eofm, 1);            {Put EOF marker }
END;

Procedure GSO_DBFBuild.WriteDBT;
var
   buf : array[0..31] of byte;
   i : integer;
   eofm: char;
begin
   eofm := EOFMark;
   FillChar(buf,32,#0);
   buf[0] := $01;
   move(dbTitle[1],buf[8],length(dbTitle));
   FileName := ChangeFileExt(FileName,'.DBT');
   mFile := New(GSP_DiskFile, Create(FileName,fmOpenReadWrite));
   mFile^.gsRewrite;
   mFile^.gsWrite(0, buf, 32);
   FillChar(buf,32,#0);
   for i := 1 to 15 do mFile^.gsWrite(-1, buf, 32);
   mFile^.gsWrite(-1, eofm, 1);
   mFile^.Free;
end;

{-----------------------------------------------------------------------------
                                GSO_DB4Build
-----------------------------------------------------------------------------}
{
Constructor GSO_DB4Build.Create(const FName : String);
begin
   inherited Create(FName);
   dbTypeNoMo := DB4File;
   dbTypeMemo := DB4WithMemo;
end;

Procedure GSO_DB4Build.WriteDBT;
var
   buf : array[0..31] of byte;
begin
   FillChar(buf,32,#0);
   buf[0] := $01;
   move(dbTitle[1],buf[8],length(dbTitle));
   buf[18] := $02;
   buf[19] := $01;
   buf[21] := $02;
   FileName := ChangeFileExt(FileName,'.DBT');
   mFile := New(GSP_DiskFile, Create(FileName,fmOpenReadWrite));
   mFile^.gsRewrite;
   mFile^.gsWrite(0, buf, 24);
   mFile^.Free;
end;
}
{-----------------------------------------------------------------------------
                                GSO_DBFoxBuild
-----------------------------------------------------------------------------}

Constructor GSO_DBFoxBuild.Create(const FName : String);
begin
   inherited Create(FName);
   dbTypeNoMo := DB3File;
   dbTypeMemo := FXPWithMemo;
end;

Procedure GSO_DBFoxBuild.WriteDBT;
var
   buf : array[0..511] of byte;
   ib   : word;
begin
   ib := 512 div FoxMemoSize;
   if (512 mod FoxMemoSize) <> 0 then inc(ib);
   FillChar(buf,512,#0);
   buf[2] := Hi(ib);
   buf[3] := Lo(ib);
   buf[6] := Hi(FoxMemoSize);
   buf[7] := Lo(FoxMemoSize);
   FileName := ChangeFileExt(FileName,'.FPT');
   mFile := New(GSP_DiskFile, Create(FileName,fmOpenReadWrite));
   mFile^.gsRewrite;
   mFile^.gsWrite(0, buf, 512);
   if (512 mod FoxMemoSize) <> 0 then
   begin
      FillChar(buf,512,#0);
      mFile^.gsWrite(512, buf, 512 mod FoxMemoSize); {!!RFG 022798}
   end;
   mFile^.Free;
end;



end.

