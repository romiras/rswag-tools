unit gsf_Shel;
{-----------------------------------------------------------------------------
                            dBase File Interface

       gsf_Shel Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit provides access to Griffin Solutions dBase Objects
       using high-level procedures and functions that make Object
       Oriented Programming transparent to the user.  It provides a
       selection of commands similar to the dBase format.

   Changes:

      !!RFG 081897 Added ExternalChange function, which reports if this or
                   another application modified the table.  A return of
                   0 means no changes, 1 means this application made a
                   change, 2 means an external application changed the
                   table, and 3 means there was both an internal and
                   external change, with the external change ocurring
                   last.  All change flags are cleared when this function
                   is called.

                   Added AssignUserID procedure, which assigns a longint
                   id for the current user.  This id is placed in the DBF
                   header each time gsHdrWrite is called (normally for each
                   record write).  The ID allows tracing file updates for
                   debugging/audit purposes.

                   Added ReturnDateTimeUser procedure that returns the
                   date, time, and user for the last DBF file update.
                   These are three longint vars.

                   Changed method Go() so that if Go(Same_Record) is called
                   the current EOF/BOF flags are returned.  In the past,
                   the EOF/BOF flags were set false when the record was
                   reread.

     !!RFG 082097  Added HuntDuplicate function.  This lets the programmer
                   check to see if the hunted key already exists in the index.
                   Return value is a longint that holds -1 if the tag cannot
                   be found, 0 if the key does not duplicate one already in
                   the index, or the record number of the first record with a
                   duplicate key.

     !!RFG 091297  Made Index a function so error results could be returned.

------------------------------------------------------------------------------}
{$I gsf_FLAG.PAS}

interface
uses
   vKbd,
      Strings,

   gsf_DBSy,
   gsf_Eror,
   gsf_Xlat,
   vString,
{   gsf_Sort,}
   gsf_Date,
   gsf_DOS,
   gsf_Disk,
   gsf_DBF,
   gsf_Expr,
   gsf_Indx,
{!   gsf_NDX,}
   gsf_Memo,
   gsf_Glbl;

type
   gsDateTypes = (American,ANSI,British,French,German,Italian,Japan,
                  USA, MDY, DMY, YMD);

   gsSortStatus = (Ascending, Descending, SortUp, SortDown,
                   SortDictUp, SortDictDown, NoSort,
                   AscendingGeneral, DescendingGeneral);
   gsIndexUnique = (Unique, Duplicates);

   gsLokProtocol = (Default, DB4Lock, ClipLock, FoxLock);

   gsFlushAction = (NeverFlush,WriteFlush,AppendFlush,UnLockFlush);

{private}

   ErrorProc     = CaptureError;
   FilterCheck   = Function: boolean;
   FormulaProc   = Function(who, st, rsl : PChar;
                            var Typ: char; var Chg: boolean): integer;
   StatusProc    = CaptureStatus;

   pDBFObject = ^DBFObject;
   DBFObject = object(GSO_dBHandler)
      DBFAlias    : string12;
      DBFFilter   : FilterCheck;
      DBFFormula  : FormulaProc;
      DBFStatus   : StatusProc;
      constructor Create(const FName : String; FMode: byte);
      Function    gsFormula(who,st,rsl: PChar;var Typ: char;var Chg: boolean):
                                                           integer; virtual;
      Procedure   gsStatusUpdate(stat1,stat2,stat3 : longint); virtual;
      Function    gsTestFilter : boolean; virtual;
   end;

   GSR_FieldDesc = packed Record
      FieldName    : String[11];
      FieldType    : Char;
      FieldLen     : Byte;
      FieldDec     : Byte;
   end;

Const
   NewArea = True;
   OldArea = False;
var
   DBFActive  : pDBFObject;
   DBFUsed    : integer;
   DBFAreas   : array[0..AreaLimit] of pDBFObject;

{public}

   Procedure  SetAlias(cAl:string);
   Function   Alias : string;
{!   Function   ALock : boolean;}
   Procedure  Append;
{!   procedure  AssignUserID(id: longint);}
   Procedure  ClearRecord;
   Procedure  CloseDataBases;
   Procedure  CopyRecordTo(FAlias:String12{area: integer}; filname: string);
{!   Procedure  CopyStructure(filname : string);}
{!   Procedure  CopyTo(filname : string);}
   function   CreateDBF(const fname: string; ftype: char;
                                       fproc: dbInsertFieldProc): boolean;
   Function   CurrentArea : byte;
{!   Function   CurDate: longint;}
{!   Function   DBF : string;}
{!   Function   DBFError : integer;}
   Function   dBOF : boolean;
   Function   dEOF : boolean;
   Function   Deleted : boolean;
   Procedure  DeleteRec;
{!   Function   ExternalChange: integer;}
{   Function   FieldName(n : integer) : string;}
{   Function   FieldCount : integer;}
{   Function   FieldDec(n : integer) : integer;}
   Function   FieldLen(n : integer) : integer;
   Function   FieldNo(fn : string) : integer;
   Function   FieldExists(const fnam:string):boolean;
{   Function   FieldType(n : integer) : char;}
{   Function   FileExist(FName : string) : boolean;}
   Procedure  Find(ss : string);
{!   Function   FLock : boolean;}
{!   Procedure  FlushDBF;}
   Function   Found : boolean;
   Function   GetPercent: integer;
   Procedure  Go(n : longint);
   Procedure  GoBottom;
{!   Procedure  GoPercent(n: integer);}
   Procedure  GoTop;
{!   Function   HuntDuplicate(const st, ky: String) : longint;}
   Function   Index(INames,Tag : string): integer;            {!!RFG 091297}
{!   Function   IndexCount: integer;}
{!   Function   IndexCurrent: string;}
   Function   IndexCurrentOrder: integer;
{!   Function   IndexExpression(Value: integer): string;}
{!   Function   IndexKeyLength(Value: integer): integer;
   Function   IndexKeyType(Value: integer): char;
   Function   IndexFilter(Value: integer): string;
   Function   IndexUnique(Value: integer): boolean;
   Function   IndexAscending(Value: integer): boolean;
   Function   IndexFileName(Value: integer): string;
   Procedure  IndexIsProduction(tf: boolean);
   Function   IndexMaintained: boolean;
   Procedure  IndexFileInclude(const IName: string);
   Procedure  IndexFileRemove(const IName: string);
   Procedure  IndexTagRemove(const IName, Tag: string);
}
   Procedure  IndexOn(const IName, tag, keyexp, forexp: String;
                      uniq: gsIndexUnique; ascnd: gsSortStatus);
   Function   IndexTagName(Value: integer): string;
{!   Function   LUpdate: string;
   Function   MemoryIndexAdd(const tag, keyexpr, forexpr: String;
                 uniq: gsIndexUnique; ascnd: gsSortStatus): boolean;
}
   Procedure  Pack;
   Procedure  Recall;
   Function   RecCount : longint;
   Function   RecNo : longint;
   Function   RecSize : word;
{!   Procedure  Reindex;}
   Procedure  Replace;
{!   Function   RLock : boolean;}
{!   procedure  ReturnDateTimeUser(var dt, tm, us: longint);}
{!   Function   SearchDBF(const s: String; var FNum : word;
                        var fromrec: longint; torec: longint): word;
}
   Function   SelectArea(Obj : byte): boolean;
   Function   Select(FAlias:String12): boolean;
{!   Function   SelectAsDBF(pDBF: pDBFObject): boolean;}
{!   Function   SelectedDBF: pDBFObject;}
   Procedure  SetCentury(tf: boolean);
   Procedure  SetCenturyWrap(CenYear: byte);
   Procedure  SetDateStyle(dt : gsDateTypes);
{!   Procedure  SetDBFCache(tf: boolean);}
{!   Procedure  SetDBFCacheAllowed(tf: boolean);}
{!   Procedure  SetErrorCapture(UserRoutine : ErrorProc);}
   Procedure  SetExact(tf: boolean);
{!   Procedure  SetFileHandles(hndls : byte);
   Procedure  SetFilterThru(UserRoutine : FilterCheck);
   Procedure  SetFlush(fs: gsFlushAction);
   Procedure  SetFormulaProcess(UserRoutine1 : FormulaProc);
}
{!   Procedure  SetLock(tf: boolean);}
{!   Procedure  SetLockProtocol(LokProtocol: gsLokProtocol);}
{!   Procedure  SetNear(tf: boolean);}
   Procedure  SetOrderTo(order : integer);
{   Procedure  SetRange(RLo, RHi: string);
   Procedure  SetStatusCapture(UserRoutine : StatusProc);
}
   Procedure  SetTagTo(TName: string);
{!   Procedure  SetTempDirectory(const Value: String);}
  Procedure   SetDeleted(tf: boolean);
{!   Procedure  SetUseDeleted(tf: boolean);}
   Procedure  Skip(n : longint);
{!   Procedure  SortTo(filname, formla: string; sortseq: gsSortStatus);}
{!   Procedure  Unlock;}
{!   Procedure  UnlockAll;}
   Function   Use(FName : string;FALias:string12;IsNewArea:boolean): boolean;
{   Function   Use(FName : string;FAlias:String12): boolean;}
{   Function   UseCreateDBF(const fname: string; ftype: char;
                                      fproc: dbInsertFieldProc): boolean;
}
   Function   UseEx(FName : string; FAlias:String12;InNewArea,ReadWrite, Shared: boolean): boolean;
   Procedure  Zap;

     {dBase field handling routines}

{!   Procedure  AssignMemo(st, nm : string);}
{!   Procedure  SaveMemo(st, nm : string);}
{!   Procedure  MemoDelLine(st: string;linenum : integer);
   function   MemoGetLine(st: string;linenum : integer) : string;
   Procedure  MemoInsLine(st: string;linenum : integer; stx : string);
   procedure  MemoGet(st : string);
   procedure  MemoGetN(n : integer);
   Procedure  MemoWidth(st: string;l : integer);
   function   MemoLines(st: string) : integer;
   procedure  MemoPut(st : string);
   procedure  MemoPutN(n : integer);
   Function   MemoLinesN(fnum: integer): integer;
   Function   MemoGetLineN(fnum: integer;linenum: integer): string;
   Procedure  MemoDelLineN(fnum: integer;linenum: integer);
   Procedure  MemoInsLineN(fnum: integer;linenum: integer;st: string);
   Procedure  MemoWidthN(fnum: integer;l: integer);
}
   Function   MemoSize(fnam: string): longint;
   Function   MemoSizeN(fnum: integer): longint;

   Procedure  MemoRead(const fname: string;buf: Pointer; var cb: longint);
   Procedure  MemoClear(st: string);
   Procedure  MemoClearN(fnum: integer);
   Procedure  MemoLoad(fnam: string;buf: PChar; var cb: longint);
   Function   MemoSave(fnam: string;buf: PChar; var cb: longint): longint;
   Procedure  MemoLoadN(fnum: integer;buf: PChar; var cb: longint);
   Function   MemoSaveN(fnum: integer;buf: PChar; var cb: longint): longint;
   Procedure  Memo2File(const fieldname,filename:string); {Extract Attachment}
   Procedure  File2Memo(const fieldname,filename:string); {Import Attachment }

   Function   DateGet(st : string) : GS_Date_StrTyp;
   Function   DateGetN(n : integer) : GS_Date_StrTyp;
   Procedure  DatePut(st : string; dte : GS_Date_StrTyp);
   Procedure  DatePutN(n : integer; dte : GS_Date_StrTyp);
   Function   DateValid(s:GS_Date_StrTyp):boolean;
   Function   FieldGet(fnam : string) : string;
   Function   FieldGetN(fnum : integer) : string;
   Procedure  FieldPut(fnam, st : string);
   Procedure  FieldPutN(fnum : integer; st : string);
{!   Function   FloatGet(st : string) : FloatNum;
   Function   FloatGetN(n : integer) : FloatNum;
   Procedure  FloatPut(st : string; r : FloatNum);
   Procedure  FloatPutN(n : integer; r : FloatNum);
}
   Function   LogicGet(st : string) : boolean;
   Function   LogicGetN(n : integer) : boolean;
   Procedure  LogicPut(st : string; b : boolean);
   Procedure  LogicPutN(n : integer; b : boolean);
   Function   IntegerGet(st : string) : LongInt;
   Function   IntegerGetN(n : integer) : LongInt;
   Procedure  IntegerPut(st : string; i : LongInt);
   Procedure  IntegerPutN(n : integer; i : LongInt);
{!   Function   NumberGet(st : string) : FloatNum;
   Function   NumberGetN(n : integer) : FloatNum;
   Procedure  NumberPut(st : string; r : FloatNum);
   Procedure  NumberPutN(n : integer; r : FloatNum);
}
{   Function   StringGet(fnam : string) : string;
   Function   StringGetN(fnum : integer) : string;
   Procedure  StringPut(fnam, st : string);
   Procedure  StringPutN(fnum : integer; st : string);
}


{private}

     {Special functions}
(*
Function TableOpen(const FName : string; FMode: byte): pDBFObject;
Function TableFileName(TPtr: pDBFObject): String;
Function TableDeletedOn(TPtr: pDBFObject): Boolean;
Function TableGetRecordBuf(TPtr: pDBFObject): Pointer;
Procedure TableSetRecordBuf(TPtr: pDBFObject; RPtr: Pointer);
Function TableToBeginning(TPtr: pDBFObject): Boolean;
Function TableToEnding(TPtr: pDBFObject): Boolean;
Function TableFieldOffset(TPtr: pDBFObject; iField: word): longint;
Function TableSetTag(TPtr: pDBFObject; const IName, TName: string;
                     SameRec: boolean): integer;
Function TableExtractKey(TPtr: pDBFObject; RBuf, RKey: Pointer): boolean;
Function TableSetRange(TPtr: pDBFObject; RLo, RHi: Pointer;
                       IsKey, LoIn, HiIn: boolean): boolean;
Function TableResetRange(TPtr: pDBFObject): boolean;
Function TableFindKey(TPtr: pDBFObject; RKey, RBuf: Pointer;
                      IsKey: boolean): boolean;
Function TableHasIndex(TPtr: pDBFObject): boolean;
Procedure TableTrapErrors;
*)

{public}

     {dBase type functions}

function CTOD(strn : string) : longint;
function DTOC(jul : longint) : string;
function DTOS(jul : longint) : string;


     {Default capture procedures}

Function  DefFilterCk: boolean;
Function  DefFormulaBuild(who,st,rsl: PChar;var Typ: char;
                                            var Chg: boolean):integer;
Procedure DefCapStatus(stat1,stat2,stat3 : longint);


implementation



{-----------------------------------------------------------------------------
                            Data Capture Procedures
------------------------------------------------------------------------------}

constructor DBFObject.Create(const FName : String; FMode: byte);
begin
   if not GSO_dBHandler.Create(FName,FMode) then fail;
   if ObjType <> GSobtDBaseSys then exit;
   DBFFilter := DefFilterCk;
   DBFFormula := DefFormulaBuild;
   DBFStatus := DefCapStatus;
end;

Function DBFObject.gsFormula(who, st, rsl : PChar;
                           var Typ: char; var Chg: boolean): integer;
begin
   gsFormula :=  DBFFormula(who, st, rsl, Typ, Chg);
end;

Procedure DBFObject.gsStatusUpdate(stat1,stat2,stat3 : longint);
begin
   DBFStatus(stat1,stat2,stat3);
end;

Function DBFObject.gsTestFilter : boolean;
begin
   if dState = dbIndex then
      gsTestFilter := true
   else
   begin
      if DBFFilter then
         gsTestFilter := inherited gsTestFilter
      else
         gsTestFilter := false;
   end;
end;


                    {Default capture routines}
{$F+}
Function DefFilterCk: boolean;
begin
   DefFilterCk := true;
end;

Function DefFormulaBuild(who, st, rsl : PChar;
                         var Typ: char; var Chg: boolean): integer;
begin
   DefFormulaBuild := -1;
end;

Procedure DefCapStatus(stat1,stat2,stat3 : longint);
begin
end;
{$F-}
{-----------------------------------------------------------------------------
                        High-Level Procedures/Functions
------------------------------------------------------------------------------}

function CheckUsedArea: boolean;
begin
   if DBFActive = nil then
   begin
      FoundPgmError(gsAreaIsNotInUse,0,'Area not active');
      CheckUsedArea := false;
   end
   else
      CheckUsedArea := true;
end;

Procedure SetAlias(cAl:string);
begin
   DBFActive^.DBFAlias := cAl;
end;


Function Alias : string;
begin
   if DBFActive <> nil then
      Alias := DBFActive^.DBFAlias
   else
      Alias := '';
end;
{!
Function ALock : boolean;
begin
   if CheckUsedArea then
      ALock := DBFActive^.gsLokApnd
   else
      ALock := false;
end;

Procedure AssignUserID(id: longint);
begin
   if CheckUsedArea then
      DBFActive^.gsAssignUserID(id);
end;
}

Procedure  CopyStructure(filname : string);
begin
   if CheckUsedArea then
      DBFActive^.gsCopyStructure(filname);
end;


Procedure Append;
begin
   if CheckUsedArea then
      DBFActive^.gsAppend;
end;

Procedure ClearRecord;
begin
   if CheckUsedArea then
      DBFActive^.gsBlank;
end;

Procedure CloseDatabases;
var i : integer;
begin
   for i := 1 to AreaLimit do
      if (DBFAreas[i] <> nil) then
      begin
         DBFAreas[i]^.Free;
         DBFAreas[i] := nil;
      end;
   DBFActive := nil;
   DBFUsed := 1;
end;

Procedure  CopyRecordTo(FAlias:String12{area: integer}; filname: string);
var
   area,oldarea : integer;
begin
   if filname <> '' then begin
      oldarea := DBFUsed;
      If not GsFileExists(filname) then
         CopyStructure(filname);    { Create New DataBase If not exists }
{      Select(area);  }
      Use(filname,FAlias,NewArea);
      area:=DBFUsed;
      SelectArea(oldarea);
   end
   else
      if not CheckUsedArea then exit;

   DBFActive^.gsCopyRecord(DBFAreas[area]);
{   Select(FAlias);
   Replace;
   SelectArea(oldarea);
}
end;

(*
Procedure  CopyTo(filname : string);
begin
   if CheckUsedArea then
      DBFActive^.gsCopyFile(filname);
end;
*)

function CreateDBF(const fname: string; ftype: char;
                                        fproc: dbInsertFieldProc): boolean;
begin
   CreateDBF := gsCreateDBF(fname,ftype,fproc);
end;

function CTOD(strn : string) : longint;
var
   v : longint;
begin
   v := GS_Date_Juln(strn);
   if v > 0 then
      CTOD := v
   else
      CTOD := 0;
end;

Function CurrentArea : byte;
begin
   CurrentArea := DBFUsed;
end;
{!
Function CurDate: longint;
begin
   CurDate := GS_Date_Curr;
end;

Function DBF : string;
begin
   if DBFActive = nil then
      DBF := ''
   else
      DBF := StrPas(DBFActive^.dfFileName);
end;
}

Function DBFError : integer;
begin
   CheckUsedArea;
   DBFError := GSGetLastError;
   GSSetLastError(0);
end;

Function dBOF : boolean;
begin
   if CheckUsedArea then
      dBOF := DBFActive^.File_TOF
   else
      dBOF := false;
end;

Function Deleted : boolean;
begin
   if CheckUsedArea then
      Deleted := DBFActive^.gsDelFlag
   else
      Deleted := false;
end;

Procedure DeleteRec;
begin
   if CheckUsedArea then
      DBFActive^.gsDeleteRec;
end;

Function dEOF : boolean;
begin
   if CheckUsedArea then
      dEOF := DBFActive^.File_EOF
   else
      dEOF := false;
end;

function DTOC(jul : longint) : string;
begin
   DTOC := GS_Date_View(jul);
end;

function DTOS(jul : longint) : string;
begin
   DTOS := GS_Date_DBStor(jul);
end;
{
Function ExternalChange: integer;
begin
   if CheckUsedArea then
      ExternalChange := DBFActive^.gsExternalChange
   else
      ExternalChange := 0;
end;
{
Function FieldName(n : integer) : string;
var
   st : string;
begin
   if CheckUsedArea then begin
      st := DBFActive^.gsFieldName(n);
      if st = '' then
         GSSetLastError(220);
      FieldName := st;
   end
   else
      FieldName := '';
end;


Function FieldCount : integer;
begin
   if CheckUsedArea then
      FieldCount := DBFActive^.NumFields
   else
      FieldCount := 0;
end;
}

Function FieldDec(n : integer) : integer;
begin
   if CheckUsedArea then
      FieldDec := DBFActive^.gsFieldDecimals(n)
   else
      FieldDec := 0;
end;

Function FieldLen(n : integer) : integer;
begin
   if CheckUsedArea then
      FieldLen := DBFActive^.gsFieldLength(n)
   else
      FieldLen := 0;
end;

Function FieldNo(fn : string) : integer;
var
   mtch : boolean;
   i,
   ix   : integer;
   za   : string[16];
begin
   if CheckUsedArea then
   begin
      fn := RTrim(AnsiUpperCase(fn));
      ix := DBFActive^.NumFields;
      i := 1;
      mtch := false;
      while (i <= ix) and not mtch do
      begin
         za := StrPas(DBFActive^.Fields^[i].dbFieldName);
         if za = fn then
            mtch := true
         else
            inc(i);
      end;
      if mtch then
         FieldNo := i
      else
         FieldNo := 0;
   end
   else
      FieldNo := 0;
end;

Function FieldExists(const fnam:string):boolean;
begin
   FieldExists := DbfActive^.gsFieldExists(fnam);
end;

Function FieldType(n : integer) : char;
begin
   if CheckUsedArea then
      FieldType := DBFActive^.gsFieldType(n)
   else
      FieldType := '?';
end;
{
Function FileExist(FName : string): boolean;
begin
   FileExist := GSFileExists(FName);
end;
}
Procedure Find(ss : string);
begin
   if CheckUsedArea then
      DBFActive^.gsFind(ss)
   else
      DBFActive^.gsvFound := false;
end;

{!
Function FLock : boolean;
begin
   if CheckUsedArea then
      FLock := DBFActive^.gsLokFile
   else
      FLock := false;
end;

Procedure FlushDBF;
begin
   if not CheckUsedArea then exit;
   DBFActive^.dStatus := Updated;
   DBFActive^.gsFlush;
end;
}
Function Found : boolean;
begin
   if CheckUsedArea then
      Found := DBFActive^.gsvFound
   else
      Found := false;
end;

function GetPercent: integer;
var
   i: longint;
begin
   GetPercent := 0;
   if not CheckUsedArea then exit;
   if RecCount = 0 then exit;
   if DBFActive^.IndexMaster = nil then
   begin
      i := (RecNo*100) div RecCount;
   end
   else
   begin
      i := DBFActive^.IndexMaster^.KeyIsPercentile;
   end;
   GetPercent := i;
end;

Procedure Go(n : longint);
var
   feof: boolean;
   fbof: boolean;
begin
   feof := false;
   fbof := false;
   if CheckUsedArea then
   begin
      if n = Same_Record then              {!!RFG 081897}
      begin                                {!!RFG 081897}
         feof := DBFActive^.File_EOF;      {!!RFG 081897}
         fbof := DBFActive^.File_TOF;      {!!RFG 081897}
      end;                                 {!!RFG 081897}
      DBFActive^.gsGetRec(n);
      if n = Same_Record then              {!!RFG 081897}
      begin                                {!!RFG 081897}
         DBFActive^.File_EOF := feof;      {!!RFG 081897}
         DBFActive^.File_TOF := fbof;      {!!RFG 081897}
      end;
   end;
end;

Procedure GoBottom;
begin
   if CheckUsedArea then
      DBFActive^.gsGetRec(Bttm_Record);
end;
{!
Procedure GoPercent(n: integer);
var
   lc: longint;
begin
   if not CheckUsedArea then exit;
   if DBFActive^.IndexMaster = nil then
   begin
      if n > 100 then
         n := 100
      else
         if n < 0 then
            n := 0;
      lc := (RecCount * n) div 100;
      if lc = 0 then lc := 1;
      Go(lc);
   end
   else
   begin
      lc := DBFActive^.IndexMaster^.KeyByPercent(n);
      Go(lc);
   end;
end;
}
Procedure GoTop;
begin
   if CheckUsedArea then
      DBFActive^.gsGetRec(Top_Record);
end;
(*!
Function HuntDuplicate(const st, ky: String): longint;
begin                                                 {!!RFG 082097}
   HuntDuplicate := -1;
   if CheckUsedArea then
      HuntDuplicate := DBFActive^.gsHuntDuplicate(st, ky);
end;
*)
Function Index(INames, Tag : string): integer;        {!!RFG 091297}
begin
   if CheckUsedArea then
      Index := DBFActive^.gsIndex(INames,Tag)
   else
      Index := 0;
end;
{!
Procedure  IndexFileInclude(const IName: string);
begin
   if CheckUsedArea then
      DBFActive^.gsIndexRoute(IName);
end;

Procedure  IndexFileRemove(const IName: string);
begin
   if CheckUsedArea then
      DBFActive^.gsIndexFileRemove(IName);
end;

Procedure IndexTagRemove(const IName, Tag: string);
begin
   if CheckUsedArea then
      DBFActive^.gsIndexTagRemove(IName, Tag);
end;
}
Procedure IndexOn(const IName, tag, keyexp, forexp: String;
                  uniq: gsIndexUnique; ascnd: gsSortStatus);
begin
   if CheckUsedArea then
   DBFActive^.gsIndexTo(IName, tag, keyexp, forexp,
                      GSsetIndexUnique(uniq), GSsetSortStatus(ascnd));
end;
{!
function IndexExpression(Value: integer): string;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexExpression := StrPas(p^.KeyExpr)
      else
         IndexExpression := '';
   end
   else
      IndexExpression := '';
end;

function IndexKeyLength(Value: integer): integer;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexKeyLength := p^.KeyLength
      else
         IndexKeyLength := 0;
   end
   else
      IndexKeyLength := 0;
end;

function IndexKeyType(Value: integer): char;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexKeyType := p^.KeyType
      else
         IndexKeyType := 'C';
   end
   else
      IndexKeyType := '?';
end;

function IndexFilter(Value: integer): string;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if (p <> nil) and (p^.ForExpr <> nil) then
         IndexFilter := StrPas(p^.ForExpr)
      else
         IndexFilter := '';
   end
   else
      IndexFilter := '';
end;

function IndexUnique(Value: integer): boolean;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexUnique := p^.KeyIsUnique
      else
         IndexUnique := false;
   end
   else
      IndexUnique := false;
end;

function IndexAscending(Value: integer): boolean;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexAscending := p^.KeyIsAscending
      else
         IndexAscending := false;
   end
   else
      IndexAscending := false;
end;

function IndexFileName(Value: integer): string;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexFileName := StrPas(p^.Owner^.IndexName)
      else
         IndexFileName := '';
   end
   else
      IndexFileName := '';
end;
}

function IndexTagName(Value: integer): string;
var
   p: GSptrIndexTag;
begin
   if CheckUsedArea then
   begin
      p := DBFActive^.gsIndexPointer(Value);
      if p <> nil then
         IndexTagName := StrPas(p^.TagName)
      else
         IndexTagName := '';
   end
   else
      IndexTagName := '';
end;

{!
function IndexCount: integer;
var
   i: integer;
   n: integer;
begin
   n := 0;
   if CheckUsedArea then
   begin
      i := 1;
      while (i <= IndexesAvail) do
      begin
         if DBFActive^.IndexStack[i] <> nil then
            n := n + DBFActive^.IndexStack[i]^.TagCount;
         inc(i);
      end;
   end;
   IndexCount := n;
end;

function IndexCurrent: string;
begin
   if CheckUsedArea then
   begin
      if DBFActive^.IndexMaster <> nil then
         IndexCurrent := StrPas(DBFActive^.IndexMaster^.TagName)
      else
         IndexCurrent := '';
   end
   else
      IndexCurrent := '';
end;
}

function IndexCurrentOrder: integer;
var
   p: GSptrIndexTag;
   i: integer;
   n: integer;
   ni: integer;
begin
   IndexCurrentOrder := 0;
   if CheckUsedArea then
   begin
      with DBFActive^ do
      begin
         if IndexMaster <> nil then
         begin
            p := nil;
            n := 0;
            ni := 0;
            i := 1;
            while (p = nil) and (i <= IndexesAvail) do
            begin
               if IndexStack[i] <> nil then
               begin
                  p := IndexStack[i]^.TagByNumber(ni);
                  inc(ni);
                  if p <> nil then
                  begin
                     inc(n);
                     if StrComp(p^.TagName,PrimaryTagName) <> 0 then
                        p := nil;
                  end
                  else
                  begin
                     inc(i);
                     ni := 0;
                  end;
               end;
            end;
            if p <> nil then
               IndexCurrentOrder := n;
         end;
      end;
   end;
end;

{!
procedure IndexIsProduction(tf: boolean);
begin
   if CheckUsedArea then
   begin
      if tf then
         DBFActive^.IndexFlag := $01
      else
         DBFActive^.IndexFlag := $00;
      DBFActive^.WithIndex := tf;
      DBFActive^.dStatus := Updated;
      DBFActive^.gsHdrWrite(false);
   end;
end;

Function IndexMaintained: boolean;
begin
   IndexMaintained := false;
   if CheckUsedArea then
      IndexMaintained := DBFActive^.IndexFlag > 0;
end;

Function LUpdate: string;
var
   yy, mm, dd : word;
   hh, mn, ss : word;
   fd         : longint;
begin
   if DBFActive = nil then
      LUpdate := ''
   else
   begin
      GSFileDateTime(DBFActive^.dfFileHndl,yy,mm,dd,hh,mn,ss);
      fd := GS_Date_MDY2Jul(mm,dd,yy);
      LUpdate := GS_Date_View(fd);
   end;
end;

Function MemoryIndexAdd(const tag, keyexpr, forexpr: String;
            uniq: gsIndexUnique; ascnd: gsSortStatus): boolean;
begin
   MemoryIndexAdd := false;
   if CheckUsedArea then
   MemoryIndexAdd := DBFActive^.gsMemoryIndexAdd(Tag, keyexpr, forexpr,
                      GSsetIndexUnique(uniq), GSsetSortStatus(ascnd));
end;

}
Procedure Pack;
begin
   if CheckUsedArea then
      DBFActive^.gsPack;
end;

Procedure Recall;
begin
   if CheckUsedArea then
      DBFActive^.gsUndelete;
end;

Function RecCount : longint;
begin
   if CheckUsedArea then
      RecCount := DBFActive^.NumRecs
   else
      RecCount := 0;
end;

Function RecNo : longint;
begin
   if CheckUsedArea then
      RecNo := DBFActive^.RecNumber
   else
      RecNo := 0;
end;

Function RecSize : word;
begin
   if CheckUsedArea then
      RecSize := DBFActive^.RecLen
   else
      RecSize := 0;
end;

{!
Procedure Reindex;
begin
   if CheckUsedArea then
      DBFActive^.gsReindex;
end;
}

Procedure Replace;
begin
   if CheckUsedArea then
      DBFActive^.gsReplace;
end;
{!
Function RLock : boolean;
begin
   if CheckUsedArea then
      RLock := DBFActive^.gsLokRcrd
   else
      RLock := false;
end;

procedure ReturnDateTimeUser(var dt, tm, us: longint);
begin
   dt := 0;
   tm := 0;
   us := 0;
   if CheckUsedArea then
      DBFActive^.gsReturnDateTimeUser(dt, tm, us);
end;

Function SearchDBF(const s: String; var FNum : word;
                   var fromrec: longint; torec: longint): word;
begin
   if CheckUsedArea then
      SearchDBF := DBFActive^.gsSearchDBF(s,FNum,fromrec,torec)
   else
      SearchDBF := 0;
end;
}
Function Select(FAlias:String12{Obj : byte}): boolean;
Var
   i:integer;
   Obj:byte;
begin
   Select := false;
   Obj := 0;
   for i := 1 to AreaLimit do
      if (DBFAreas[i] <> nil) then begin
         If DBFAreas[i]^.DbfAlias = FAlias then begin
            Obj:=i;
            Break;
         end;
      end;

   if (Obj < 1) or (Obj > AreaLimit) then exit;
   DBFUsed := Obj;
   DBFActive := DBFAreas[Obj];
   Select := true;
end;

Function SelectArea(Obj : byte): boolean;
Var
   i:integer;
begin
   SelectArea := false;
   if (Obj < 1) or (Obj > AreaLimit) then exit;
   DBFUsed := Obj;
   DBFActive := DBFAreas[Obj];
   SelectArea := true;
end;


{!
Function SelectAsDBF(pDBF: pDBFObject): boolean;
begin
   DBFActive := pDBF;
   SelectAsDBF := pDBF <> nil;
end;

Function SelectedDBF: pDBFObject;
begin
   SelectedDBF := DBFActive;
end;
}

Procedure SetCentury(tf: boolean);
begin
   GSblnUseCentury := tf;
end;

procedure SetCenturyWrap(CenYear: byte);
begin
   GSbytNextCentury := CenYear;
end;

Procedure SetDateStyle(dt : gsDateTypes);
begin
   GSsetDateType := GSsetDateTypes(dt);
end;
{!
Procedure SetDBFCacheAllowed(tf: boolean);
begin
   if CheckUsedArea then
      DBFActive^.gsSetDBFCacheAllowed(tf);
end;

Procedure SetDBFCache(tf: boolean);
begin
   if not CheckUsedArea then exit;
   if tf and (DBFActive^.IndexMaster <> nil) then exit;
   DBFActive^.gsSetDBFCache(tf);
end;

Procedure SetErrorCapture(UserRoutine : CaptureError);
begin
   CapError := UserRoutine;
end;
}
Procedure SetExact(tf: boolean);
begin
   if DBFActive <> nil then
      DBFActive^.gsvExactMatch := tf;
end;
{!
Procedure SetFileHandles(hndls : byte);
begin
   GS_ExtendHandles(hndls);
end;

Procedure SetFilterThru(UserRoutine : FilterCheck);
begin
   if not CheckUsedArea then exit;
   DBFActive^.FilterRecord := not (@UserRoutine = @defFilterCk);
   DBFActive^.DBFFilter := UserRoutine;
end;

Procedure SetFlush(fs: gsFlushAction);
begin
   if CheckUsedArea then
      DBFActive^.dfFileFlsh := GSsetFlushStatus(fs);
end;

Procedure SetFormulaProcess(UserRoutine1 : FormulaProc);
begin
   if CheckUsedArea then
      DBFActive^.DBFFormula := UserRoutine1;
end;
}
{!
Procedure SetLock(tf: boolean);
begin
   if DBFActive <> nil then
      DBFActive^.dfAutoShare := tf;
end;

Procedure SetLockProtocol(LokProtocol: gsLokProtocol);
begin
   if DBFActive <> nil then
      DBFActive^.gsSetLockProtocol(GSsetLokProtocol(LokProtocol));
end;

Procedure SetNear(tf: boolean);
begin
   if DBFActive <> nil then
      DBFActive^.gsvFindNear := tf;
end;
}
Procedure SetOrderTo(order : integer);
begin
   if CheckUsedArea then
      DBFActive^.gsIndexOrder(order);
end;
{!
Procedure SetRange(RLo, RHi: string);
begin
   if CheckUsedArea then
      DBFActive^.gsSetRange(RLo,RHi,true,true);
end;

Procedure SetStatusCapture(UserRoutine : CaptureStatus);
begin
   if CheckUsedArea then
      DBFActive^.DBFStatus := UserRoutine;
end;
}

Procedure SetTagTo(TName: string);
begin
   if CheckUsedArea then
      DBFActive^.gsSetTagTo(TName,true);
end;

{!
Procedure SetTempDirectory(const Value: String);
var
   tb: array[0..260] of char;
begin
   if not CheckUsedArea then exit;
   FillChar(tb[0],SizeOf(tb),#0);
   if length(Value) > 0 then
   begin
      StrPCopy(tb,Value);
      if Value[length(Value)] <> '\' then
         tb[StrLen(tb)] := '\';
      StrGSDispose(DBFActive^.gsvTempDir);
      DBFActive^.gsvTempDir := StrGSNew(tb);
   end;
end;
}
Procedure SetDeleted(tf: boolean);
begin
   if CheckUsedArea then
      DBFActive^.UseDeletedRec := not tf;
end;
{!
Procedure SetUseDeleted(tf: boolean);
begin
   if CheckUsedArea then
      DBFActive^.UseDeletedRec := tf;
end;
}
Procedure Skip(n : longint);
begin
   if CheckUsedArea then
      DBFActive^.gsSkip(n);
end;
{!
Procedure SortTo(filname, formla: string; sortseq : gsSortStatus);
begin
   if CheckUsedArea then
      DBFActive^.gsSortFile(filname, formla, GSsetSortStatus(sortseq));
end;

Procedure Unlock;
begin
   if CheckUsedArea then
     DBFActive^.gsLokOff;
end;

Procedure UnlockAll;
var i : integer;
begin
   for i := 1 to AreaLimit do
      if DBFAreas[i] <> nil then
         while DBFAreas[i]^.dfLockRec do DBFAreas[i]^.gsLokOff;
   GS_ClearLocks;
end;
}
Function Use(FName : string;FALias:string12;IsNewArea:boolean): boolean;
begin
   Use := UseEx(FName,FAlias,IsNewArea,true,true);
end;

{!
function UseCreateDBF(const fname: string; ftype: char;
                                        fproc: dbInsertFieldProc): boolean;
var
   cf: GSP_DiskFile;
begin
   cf := gsCreateDBFEx(fname,ftype,fproc);
   UseCreateDBF := cf <> nil;
   if cf <> nil then
   begin
      UseCreateDBF := UseEx(fname,true,false);
      cf^.Free;
   end;
end;
}
Function UseEx(FName : string; FAlias:String12;InNewArea,ReadWrite, Shared: boolean): boolean;
var
  FMode: byte;
  i:integer;
begin
   UseEx := true;
   If (FName = '') or (not InNewArea) then begin
      if DBFActive <> nil then
         DBFActive^.Free;
      DBFActive := nil;
      DBFAreas[DBFUsed] := DBFActive;
      If FName = '' then
         exit;
   end;
   {Search for new empty area}
   If InNewArea then begin
      for i := 1 to AreaLimit do
         if (DBFAreas[i] = nil) then begin
            DBFActive := nil;
            DBFUsed := i;
            break;
         end;
   end;
{
   if DBFActive <> nil then
      DBFActive^.Free;
   DBFActive := nil;
   DBFAreas[DBFUsed] := DBFActive;
   if FName = '' then exit;
}
   if ReadWrite then
      FMode := fmOpenReadWrite
   else
      FMode := fmOpenRead;
   if Shared then
      FMode := FMode + fmShareDenyNone;

   DBFActive := New(pDBFObject, Create(FName,FMode));

   if (DBFActive <> nil) and (DBFActive^.ObjType = GSobtDBaseSys) then begin
      DBFActive^.gsOpen;
      DBFAreas[DBFUsed] := DBFActive;
      If FAlias <> '' then
         DBFActive^.DBFAlias := UPPER(FAlias)
      else
         DBFActive^.DBFAlias := ExtractFileNameOnly(StrPas(DBFActive^.dfFileName));
   end
   else begin
      if DBFActive <> nil then
         DBFActive^.Free;
      DBFActive := nil;
   end;
   UseEx := DBFActive <> nil;
end;

Procedure Zap;
begin
   if CheckUsedArea then
      DBFActive^.gsZap;
end;

{------------------------------------------------------------------------------
                           Field Access Routines
------------------------------------------------------------------------------}
(*
Procedure AssignMemo(st, nm : string);
var
   i,
   ml   : integer;
   Txfile : Text;
begin
   System.Assign(TxFile,nm);
   System.Rewrite(TxFile);
   DBFActive^.gsMemoGet(st);
   ml := DBFActive^.gsMemoLines(st);
   if ml <> 0 then
      for i := 1 to ml do
         Writeln(TxFile,DBFActive^.gsMemoGetLine(st,i));
   System.Close(TxFile);
end;

procedure SaveMemo(st, nm : string);
var
   s   : string;
   m1,
   m2  : string[10];
   Txfile : Text;
begin
   m1 := DBFActive^.gsFieldGet(st);
   DBFActive^.gsMemoClear(st);
   System.Assign(TxFile,nm);
   System.Reset(TxFile);
   while not EOF(TxFile) do
   begin
      Readln(TxFile,s);
      DBFActive^.gsMemoInsLine(st,-1,s);
   end;
   System.Close(TxFile);
   DBFActive^.gsMemoPut(st);
   m2 := DBFActive^.gsFieldGet(st);
            {If the memo field number has changed, save the DBF record}
   if m1 <> m2 then
      DBFActive^.gsPutRec(DBFActive^.RecNumber);
end;
*)

Procedure  MemoRead(const fname: string;buf: Pointer; var cb: longint);
var
   F: integer;
   n: word;
begin
   F:=gsFileOpen(fName,fmOpenRead);
   If F <> 0 then
      n:=gsFileRead(F,buf^,cb);
   gsFileClose(F);
   if cb <> n then
      cb:=n;
end;


Procedure MemoClear(st: string);
begin
   DBFActive^.gsMemoClear(st);
end;
{!
Procedure MemoDelLine(st: string;linenum : integer);
begin
   DBFActive^.gsMemoDelLine(st,linenum);
end;

function MemoGetLine(st: string;linenum : integer) : string;
begin
   MemoGetLine := DBFActive^.gsMemoGetLine(st,linenum);
end;

Procedure MemoInsLine(st: string;linenum : integer; stx : string);
begin
   DBFActive^.gsMemoInsLine(st,linenum, stx);
end;

procedure MemoGet(st : string);
begin
   DBFActive^.gsMemoGet(st);
end;

procedure MemoGetN(n : integer);
begin
   DBFActive^.gsMemoGetN(n);
end;

Procedure MemoWidth(st: string;l : integer);
begin
   DBFActive^.gsMemoWidth(st,l);
end;

function MemoLines(st: string) : integer;
begin
   MemoLines := DBFActive^.gsMemolines(st);
end;

procedure MemoPut(st : string);
begin
   DBFActive^.gsMemoPut(st);
end;

procedure MemoPutN(n : integer);
begin
   DBFActive^.gsMemoPutN(n);
end;
}

Function MemoSize(fnam: string): longint;
begin
   MemoSize := DBFActive^.gsMemoSize(fnam);
end;

Function MemoSizeN(fnum: integer): longint;
begin
   MemoSizeN := DBFActive^.gsMemoSizeN(fnum);
end;


{!
Function MemoLinesN(fnum: integer): integer;
begin
   MemoLinesN := DBFActive^.gsMemoLinesN(fnum);
end;

Function MemoGetLineN(fnum: integer;linenum: integer): string;
begin
   MemoGetLineN := DBFActive^.gsMemoGetLineN(fnum, linenum);
end;

Procedure MemoDelLineN(fnum: integer;linenum: integer);
begin
   DBFActive^.gsMemoDelLineN(fnum, linenum);
end;

Procedure MemoInsLineN(fnum: integer;linenum: integer;st: string);
begin
   DBFActive^.gsMemoInsLineN(fnum, linenum, st);
end;

Procedure MemoWidthN(fnum: integer;l: integer);
begin
   DBFActive^.gsMemoWidthN(fnum, l);
end;
}
Procedure MemoClearN(fnum: integer);
begin
   DBFActive^.gsMemoClearN(fnum);
end;

Procedure MemoLoad(fnam: string;buf: PChar; var cb: longint);
begin
   DBFActive^.gsMemoLoad(fnam,buf,cb);
end;

Procedure  MemoLoadN(fnum: integer;buf: PChar; var cb: longint);
begin
   DBFActive^.gsMemoLoadN(fnum,buf,cb);
end;

Function MemoSave(fnam: string;buf: PChar; var cb: longint): longint;
begin
   MemoSave := DBFActive^.gsMemoSave(fnam,buf,cb);
end;

Function   MemoSaveN(fnum: integer;buf: PChar; var cb: longint): longint;
begin
   MemoSaveN := DBFActive^.gsMemoSaveN(fnum,buf,cb);
end;


Procedure Memo2File(const fieldname,filename:string);
{Extract Attachment}
begin
   dbfactive^.gsMemo2File(fieldname,FileName);
end;

Procedure File2Memo(const fieldname,filename:string);
{Import Attachment }
begin
   dbfactive^.gsFile2Memo(fieldname,FileName);
{   MemoUpdated := True;}
{  DBFActive^.gsReplace;}
end;







Function DateGet(st : string) : GS_Date_StrTyp;
begin
   DateGet := DBFActive^.gsDateGet(st);
end;

Function DateGetN(n : integer) : GS_Date_StrTyp;
begin
   DateGetN := DBFActive^.gsDateGetN(n);
end;

Procedure DatePut(st : string; dte : GS_Date_StrTyp);
begin
   DBFActive^.gsDatePut(st, dte);
end;

Procedure DatePutN(n : integer; dte : GS_Date_StrTyp);
begin
   DBFActive^.gsDatePutN(n, dte);
end;

Function DateValid(s:GS_Date_StrTyp):boolean;
begin
   DateValid:=False;
   If (s[1] in ['0'..'3',' ']) then
    If (s[2] in ['0'..'9',' ']) then
     if (s[3] in ['/','-','.']) then
      If (s[4] in ['0'..'1',' ']) then
       If (s[5] in ['0'..'9',' ']) then
        if (s[6] in ['/','-','.'])then
         If (s[7] in ['0'..'9',' ']) then
          If (s[8] in ['0'..'9',' ']) then
           If (copy(s,1,2) <= '31') then
            If (copy(s,4,2) <= '12') then
             DateValid:=True
             else Beep;
end;

Function FieldGet(fnam : string) : string;
begin
   FieldGet := DBFActive^.gsFieldGet(fnam);
end;

Function FieldGetN(fnum : integer) : string;
begin
   FieldGetN := DBFActive^.gsFieldGetN(fnum);
end;

Procedure FieldPut(fnam, st : string);
begin
   DBFActive^.gsFieldPut(fnam, st);
end;

Procedure FieldPutN(fnum : integer; st : string);
begin
   DBFActive^.gsFieldPutN(fnum, st);
end;
{!
Function FloatGet(st : string) : FloatNum;
begin
   FloatGet := DBFActive^.gsNumberGet(st);
end;

Function FloatGetN(n : integer) : FloatNum;
begin
   FloatGetN := DBFActive^.gsNumberGetN(n);
end;

Procedure FloatPut(st : string; r : FloatNum);
begin
   DBFActive^.gsNumberPut(st, r);
end;

Procedure FloatPutN(n : integer; r : FloatNum);
begin
   DBFActive^.gsNumberPutN(n, r);
end;
}
Function LogicGet(st : string) : boolean;
begin
   LogicGet := DBFActive^.gsLogicGet(st);
end;

Function LogicGetN(n : integer) : boolean;
begin
   LogicGetN := DBFActive^.gsLogicGetN(n);
end;

Procedure LogicPut(st : string; b : boolean);
begin
   DBFActive^.gsLogicPut(st, b);
end;

Procedure LogicPutN(n : integer; b : boolean);
begin
   DBFActive^.gsLogicPutN(n, b);
end;

Function IntegerGet(st : string) : LongInt;
var
   r : FloatNum;
begin
   r := DBFActive^.gsNumberGet(st);
   IntegerGet := Trunc(r);
end;

Function IntegerGetN(n : integer) : LongInt;
var
   r : FloatNum;
begin
   r := DBFActive^.gsNumberGetN(n);
   IntegerGetN := Trunc(r);
end;

Procedure IntegerPut(st : string; i : LongInt);
var
   r : FloatNum;
begin
   r := i;
   DBFActive^.gsNumberPut(st, r);
end;

Procedure IntegerPutN(n : integer; i : LongInt);
var
   r : FloatNum;
begin
   r := i;
   DBFActive^.gsNumberPutN(n, r);
end;
{!
Function NumberGet(st : string) : FloatNum;
begin
   NumberGet := DBFActive^.gsNumberGet(st);
end;

Function NumberGetN(n : integer) : FloatNum;
begin
   NumberGetN := DBFActive^.gsNumberGetN(n);
end;

Procedure NumberPut(st : string; r : FloatNum);
begin
   DBFActive^.gsNumberPut(st, r);
end;

Procedure NumberPutN(n : integer; r : FloatNum);
begin
   DBFActive^.gsNumberPutN(n, r);
end;


Function StringGet(fnam : string) : string;
begin
   StringGet := DBFActive^.gsStringGet(fnam);
end;

Function StringGetN(fnum : integer) : string;
begin
   StringGetN := DBFActive^.gsStringGetN(fnum);
end;

Procedure StringPut(fnam, st : string);
begin
   DBFActive^.gsStringPut(fnam, st);
end;

Procedure StringPutN(fnum : integer; st : string);
begin
   DBFActive^.gsStringPutN(fnum, st);
end;
}

{------------------------------------------------------------------------------
                             Special Routines
------------------------------------------------------------------------------}
(*
Function TableOpen(const FName : string; FMode: byte): pDBFObject;
var
   p: pDBFObject;
begin
   p := nil;
   if FName <> '' then
      p := New(pDBFObject, Create(FName, FMode));
   if p <> nil then
      p^.gsOpen;
   TableOpen := p;
end;

Function TableFileName(TPtr: pDBFObject): String;
begin
   if TPtr <> nil then
      TableFileName := StrPas(TPtr^.dfFileName);
end;

Function TableDeletedOn(TPtr: pDBFObject): Boolean;
begin
   TableDeletedOn := false;
   if TPtr <> nil then
      TableDeletedOn := TPtr^.UseDeletedRec;
end;

Function TableGetRecordBuf(TPtr: pDBFObject): Pointer;
begin
   TableGetRecordBuf := nil;
   if TPtr <> nil then
      TableGetRecordBuf := TPtr^.CurRecord;
end;

Procedure TableSetRecordBuf(TPtr: pDBFObject; RPtr: Pointer);
begin
   if TPtr <> nil then
      TPtr^.CurRecord := RPtr;
end;


Function TableToBeginning(TPtr: pDBFObject): Boolean;
begin
   if TPtr <> nil then
   begin
      TableToBeginning := true;
      ClearRecord;
      TPtr^.RecNumber := 0;
      TPtr^.File_TOF := true;
   end
   else TableToBeginning := false;
end;

Function TableToEnding(TPtr: pDBFObject): Boolean;
begin
   if TPtr <> nil then
   begin
      TableToEnding := true;
      ClearRecord;
      TPtr^.RecNumber := TPtr^.NumRecs+1;
      TPtr^.File_EOF := true;
   end
   else TableToEnding := false;
end;

Function TableFieldOffset(TPtr: pDBFObject; iField: word): longint;
begin
   TableFieldOffset := 0;
   if TPtr <> nil then
      TableFieldOffset := TPtr^.gsFieldOffset(iField);
end;

Function TableSetTag(TPtr: pDBFObject; const IName, TName: string;
                     SameRec: boolean): integer;
begin
   if TPtr <> nil then
   begin
      if IName <> '' then
         TPtr^.gsIndexRoute(IName);
      TableSetTag := TPtr^.gsSetTagTo(TName,SameRec);
   end
   else
      TableSetTag := -1;
end;

Function TableExtractKey(TPtr: pDBFObject; RBuf, RKey: Pointer): boolean;
var
   rcur: pointer;
   chg: boolean;
   typ: char;
begin
   TableExtractKey := false;
   PChar(RKey)[0] := #0;
   if TPtr = nil then exit;
   if TPtr^.IndexMaster = nil then exit;
   rcur := TPtr^.CurRecord;
   if RBuf <> nil then
      TPtr^.CurRecord := RBuf;
   SolveExpression(TPtr^.IndexMaster,TPtr^.IndexMaster^.TagName,
                   TPtr^.IndexMaster^.KeyExpr,PChar(RKey),typ,chg);
   TPtr^.CurRecord := rcur;
   TableExtractKey := true;
end;

Function TableSetRange(TPtr: pDBFObject; RLo, RHi: Pointer;
                       IsKey, LoIn, HiIn: boolean): boolean;
var
   LoStr: string;
   HiStr: string;
   wPChar: array[0..255] of char;
begin
   TableSetRange := false;
   if TPtr = nil then exit;
   if TPtr^.IndexMaster = nil then exit;
   if RLo = nil then
      LoStr := ''
   else
   begin
      if IsKey then
         StrCopy(wPChar,PChar(RLo))
      else
         TableExtractKey(TPtr,RLo,@wPChar);
      LoStr := StrPas(wPChar);
   end;
   if RHi = nil then
      HiStr := ''
   else
   begin
      if IsKey then
         StrCopy(wPChar,PChar(RHi))
      else
         TableExtractKey(TPtr,RHi,@wPChar);
      HiStr := StrPas(wPChar);
   end;
   TPtr^.gsSetRange(LoStr,HiStr,LoIn,HiIn);
   TableSetRange := true;
end;

Function TableResetRange(TPtr: pDBFObject): boolean;
begin
   TableResetRange := false;
   if TPtr = nil then exit;
   if TPtr^.IndexMaster = nil then exit;
   TPtr^.gsResetRange;
   TableResetRange := true;
end;

Function TableFindKey(TPtr: pDBFObject; RKey, RBuf: Pointer;
                      IsKey: boolean): boolean;
var
   FindStr: string;
   wPChar: array[0..255] of char;
   Fnd: boolean;
begin
   TableFindKey := false;
   if TPtr = nil then exit;
   if TPtr^.IndexMaster = nil then exit;
   if RKey = nil then exit;
   if IsKey then
      StrCopy(wPChar,PChar(RKey))
   else
      TableExtractKey(TPtr,RKey,@wPChar);
   FindStr := StrPas(wPChar);
   Fnd := TPtr^.gsFind(FindStr);
   if Fnd then
   begin
      if RBuf <> nil then
         move(TPtr^.CurRecord^,RBuf^,TPtr^.RecLen);
   end;
   TableFindKey := Fnd;
end;

Function TableHasIndex(TPtr: pDBFObject): boolean;
begin
   TableHasIndex := false;
   if TPtr = nil then exit;
   if TPtr^.IndexMaster = nil then exit;
   TableHasIndex := true;
end;

 {$F+}
Procedure TableHereOnError(Code, Info: integer; StP: PChar);
var
   s : string;
begin
   if Info < 0 then RunError(Code);
   s := gsFCapErr+IntToStr(Code)+', SubCode '+IntToStr(Info)+'.'+#13;
   if StP <> nil then
      s := s + StrPas(StP) + #13;
   {$IFDEF ISGUI}
      {$IFDEF DELPHI}
        MessageDlg(s,mtWarning, [mbOk], 0);
      {$ELSE}
         s := s+#0;
         MessageBox(0, @s[1], gsFCapErr, MB_ICONSTOP+MB_OK);
      {$ENDIF}
   {$ELSE}
   if info = gsfMsgOnly then
   begin
       writeln(#7);
       writeln(s);
       WaitForKey;
   end;
   {$ENDIF}
end;
{$F-}

procedure TableTrapErrors;
begin
   CapError := TableHereOnError;
end;
*)

{------------------------------------------------------------------------------
                           Setup and Exit Routines
------------------------------------------------------------------------------}

var
   ExitSave      : pointer;

{$F+}
procedure ExitHandler;
begin
   CloseDatabases;
   ExitProc := ExitSave;
end;
{$F-}

begin
   ExitSave := ExitProc;
   ExitProc := @ExitHandler;
   DBFActive := nil;
   for DBFUsed := 0 to AreaLimit do
   begin
      DBFAreas[DBFUsed] := nil;
   end;
   DBFUsed := 1;
end.

