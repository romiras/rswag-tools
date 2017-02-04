unit gsF_Indx;
{-----------------------------------------------------------------------------
                          Basic Index File Routine

       gsF_Indx Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit contains the base objects to manage database index
       files.

   Changes:
      13 Dec 96 - fixed error in JulDateStr that would treat a date
                  string as Julian date if less than 8 characters in
                  length.  This caused dates without leading zeros in
                  the month or day (e.g. 4/11/96) to fail the conversion
                  and cause the Find on these dates to fail.
    !!RFG 081397  Changed Clipper lock for index to the correct location
                  for 'old' Clipper index lock position
    !!RFG 082097  Added HuntDuplicate method to GSobjIndexTag.  This
                  lets the programmer check to see if the hunted key already
                  exists in the index.  Return value is a longint that holds
                  0 if the key does not duplicate one already in the index,
                  or the record number of the first record with a duplicate
                  key.

                  Modified RetrieveKey to return BOF/EOF information.  The
                  return integer will have bit 0 set for BOF, and bit 1 set
                  for EOF.  This is used in TagOpen to set TagBOF and TagEOF.
                  Main use is on KeySync to get the position of the record
                  being synchronized.

    !!RFG 090297  added argument to CmprOEMBufr() to define the substitute
                  character to use for unequal field length comparisons.
                  Numeric fields in CDX indexes could fail.

    !!RFG 091197  Added testing for corrupted indexes.

    !!RFG 091297  Added ExternalChange to test if the index has been
                  changed by another program.

    !!RFG 091597  Corrected error in GetChild that caused an error on a
                  TagUpdate if Next Avail was -1.  This fixes an error
                  introduced on 091197 in testing for corrupted indexes.
    !!RFG 091797  Corrected KeyFind to return 0 if a matched key is not
                  in the current range.

    !!RFG 103197  Corrected bug in JulDateStr that could cause a date to
                  be flagged as empty.

    !!RFG 120897  Corrected potential problem with filtered index updates in
                  TagUpdate, where filtered records might not be added to the
                  index.
------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}
interface
uses
   Strings,
   gsF_DBF,
   gsF_DOS,
   gsF_Date,
   gsF_Disk,
   gsF_Eror,
   gsF_Glbl,
{   gsF_Sort,}
   vString,
   gsF_Xlat;

{private}

type

   GSsetPageType = (Unknown, Root, Node, Leaf, RootLeaf);

   GSptrIndexKey = ^GSobjIndexKey;
   GSptrIndexTag = ^GSobjIndexTag;
   GSptrIndexFile = ^GSobjIndexFile;

   GSptrIndexKeyData = ^GSobjIndexKeyData;
   GSobjIndexKeyData = Object(GSobjString)
      Xtra: longint;
      Tag: longint;
      constructor Create(Size: word);
      function AssignLinks(AGSptrLinks: GSptrIndexKeyData): boolean;
      function CloneLinks: GSptrIndexKeyData;
   end;

   GSobjIndexKey = object(GSobjCollection)
      Page       : longint;
      Left       : longint;
      Right      : longint;
      Owner      : GSptrIndexKey;
      Child      : GSptrIndexKey;
      TagParent  : GSptrIndexTag;
      PageType   : GSsetPageType;
      CurKey     : integer;
      Changed    : boolean;
      NewRoot    : boolean;
      LastEntry  : boolean;
      Reload     : boolean;
      Space      : word;
      RNMask     : longint;
      DCMask     : byte;
      TCMask     : byte;
      RNBits     : byte;
      DCBits     : byte;
      TCBits     : byte;
      ReqByte    : byte;
      ChkBOF     : boolean;          {!!RFG 082097}
      ChkEOF     : boolean;          {!!RFG 082097}

      constructor Create(PIT: GSptrIndexTag; PIK: GSptrIndexKey;
                       FilePosn: longint);
      destructor  Destroy; virtual;
      procedure   AddNodeKey(Key: GSptrIndexKeyData);
      procedure   DeleteKey;
      procedure   DeleteNodeKey;
      function    GetChild(Tag: longint): boolean;
      procedure   InsertKey(Key: GSptrIndexKeyData; AddAfter: boolean);
      function    PageLoad: boolean;
      function    PageStore: boolean;
      function    ReadBottomKey: boolean;
      function    ReadCurrentKey: boolean;
      function    ReadNextKey: boolean;
      function    ReadPreviousKey: boolean;
      function    ReadTopKey: boolean;
  (*    function    ReadPercent(APct: integer) : LongInt;*)
      procedure   ReplaceNodeKey(Key: GSptrIndexKeyData);
      function    RetrieveKey(Key: GSptrIndexKeyData): integer;
      function    SeekKey(Tag: longint; Key: GSptrIndexKeyData; Exact: boolean): integer;
      function    SeekNodeTag(Tag: longint): integer;
   end;

   GSobjIndexTag = object(GSobjBaseObject)
      TagSig     : string[3];
      TagName    : PChar;
      KeyExpr    : PChar;
      KeyLength  : SmallInt;
      DefaultLen : SmallInt;
      EntryLength: SmallInt;
      MaxKeys    : SmallInt;
      MinKeys    : SmallInt;
      ForExpr    : PChar;
      RangeLo    : GSptrIndexKeyData;
      RangeHi    : GSptrIndexKeyData;
      LoInRange  : boolean;
      HiInRange  : boolean;
      Owner      : GSptrIndexFile;
      TagBlock   : longint;
      RootBlock  : longint;
      RootPage   : GSptrIndexKey;
      TagChanged : boolean;
      AscendKey  : boolean;
      UniqueKey  : boolean;
      Conditional: boolean;
      KeyType    : char;
      CurKeyInfo : GSptrIndexKeyData;
      TagBOF     : boolean;
      TagEOF     : boolean;
      KeyUpdated : boolean;    {set for update via KeyUpdate}
      InvertCmpr : boolean;
      InvertRead : boolean;

      constructor Create(PIF: GSptrIndexFile; ITN: PChar; TagHdr: longint);
      destructor  Destroy; virtual;
      procedure   AdjustValue(AKey: GSptrIndexKeyData); virtual;
      function    HuntDuplicate(Key: GSptrIndexKeyData): longint;
      function    IndexTagNew(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                           boolean; virtual;
      function    KeyAdd(Key: GSptrIndexKeyData): boolean; virtual;
      function    KeyByPercent(APct: integer) : LongInt;
      function    KeyFind(Key: GSptrIndexKeyData) : longint;
      function    KeyInRange: boolean;
      function    KeyIsAscending: boolean;
      function    KeyIsPercentile: integer;
      function    KeyIsUnique: boolean;
      procedure   KeySync(ATag: longint; DoReload: boolean);
      function    KeyRead(TypRead: longint) : longint;
      function    KeyUpdate(AKey: longint; IsAppend: boolean): boolean;
      procedure   GetRange(var RLo, RHi: GSptrString);
      function    GetRangeCount: longint;
      function    NewRoot: longint; virtual;
      procedure   SetRange(RLo: GsptrString;LoIn: Boolean;
                           RHi: GSptrString; HiIn: Boolean);
      procedure   SetRoot(PIK: GSptrIndexKey);
      function    PageLoad(PN: longint; PIK: GSptrIndexKey): Boolean; virtual;
      function    PageStore(PN: longint; PIK: GSptrIndexKey): Boolean; virtual;
      function    TagLoad: Boolean; virtual;
      function    TagStore: Boolean; virtual;
      procedure   TagClose;
      procedure   TagOpen(Posn: integer); {0=top, 1=current}
      procedure   JulDateStr(stot, stin: PChar; var Typ: char); virtual;
   end;

   GSobjIndexFile = object(GSobjBaseObject)
      IndexName   : PChar;
      TagList     : GSptrCollection;
      TagRoot     : longint;
      Owner       : GSP_dBaseFld;
      DiskFile    : GSP_DiskFile;
      KeyWithRec  : boolean;
      Dictionary  : boolean;
      NextAvail   : longint;
      Exact       : boolean;
      CreateOK    : boolean;
      Corrupted   : boolean;                 {!!RFG 091197}

      constructor Create(PDB: GSP_dBaseFld);
      destructor  Destroy; virtual;
      function    IndexFileOpen(PDB: GSP_dBaseFld; const FN, EX: string;
                                FM: word; Overwrite: boolean): GSP_DiskFile;
      function    AddTag(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                         boolean; virtual;
      function    DeleteTag(ITN: PChar): boolean; virtual;
      procedure   FoundError(Code, Info: integer; StP: PChar); virtual;
      function    GetAvailPage: longint; virtual;
      function    ResetAvailPage: longint; virtual;
      function    IndexLock: boolean;
      function    IsFileName(const IName: string): boolean;
      function    KeyByName(AKey: PChar; AFor: boolean): GSptrIndexTag;
      function    PageRead(Blok: longint; var Page; Size: integer):
                         boolean; virtual;
      function    PageWrite(Blok: longint; var Page; Size: integer):
                         boolean; virtual;
      procedure   Reindex; virtual;
      function    GetFileName: string;
      function    TagCount: integer;
      function    TagByName(ITN: PChar): GSptrIndexTag;
      function    TagByNumber(N: integer): GSptrIndexTag;
      function    TagUpdate(AKey: longint; IsAppend: boolean): boolean; virtual;
      function    ExternalChange: boolean; virtual;          {!!RFG 091297}
   end;

implementation
uses
   gsF_Expr;


{----------------------------------------------------------------------------
                        GSobjIndexKeyData
----------------------------------------------------------------------------}

constructor GSobjIndexKeyData.Create(Size: word);
begin
   inherited Create(Size);
   Tag := 0;
   Xtra := 0;
end;

function GSobjIndexKeyData.AssignLinks(AGSptrLinks: GSptrIndexKeyData): boolean;
begin
   AssignString(AGSptrLinks);
   Tag := AGSptrLinks^.Tag;
   Xtra := AGSptrLinks^.Xtra;
   AssignLinks := true;
end;

function GSobjIndexKeyData.CloneLinks: GSptrIndexKeyData;
var
   cl: GSptrIndexKeyData;
begin
   cl := New(GSptrIndexKeyData, Create(0));
   cl^.AssignLinks(@Self);
   CloneLinks := cl;
end;


{----------------------------------------------------------------------------
                        GSobjIndexKey
----------------------------------------------------------------------------}

Constructor GSobjIndexKey.Create(PIT: GSptrIndexTag; PIK: GSptrIndexKey;
                               FilePosn: longint);
begin
   inherited Create(16,16);
   Page := FilePosn;
   Left := -1;
   Right := -1;
   Owner := PIK;
   Child := nil;
   TagParent := PIT;
   PageType := Unknown;
   CurKey := -1;
   Changed := false;
   NewRoot := false;
   LastEntry := false;
   Reload := false;
   if Page > 0 then
      if not PageLoad then exit;
   ObjType := GSobtIndexKey;
end;

destructor GSobjIndexKey.Destroy;
begin
   if Child <> nil then
      Child^.Free;
   Child := nil;
   if Changed then PageStore;
   Changed := false;
   if NewRoot and (Owner <> nil) then
   begin
      Owner^.Child := nil;
      Owner^.Free;
      Owner := nil;
   end;
   NewRoot := false;
   if Owner <> nil then
      Owner^.Child := nil;
   Owner := nil;
   inherited Destroy;
end;

procedure GSobjIndexKey.AddNodeKey(Key: GSptrIndexKeyData);
begin
   if Owner = nil then
   begin
      TagParent^.SetRoot(@Self);
      NewRoot := true;
   end;
   Owner^.CurKey := Owner^.SeekNodeTag(Page);
   Owner^.Child := nil;
   Owner^.InsertKey(Key, false);
   inc(Owner^.CurKey);
   Owner^.Child := @Self;
   Reload := true;
end;

procedure GSobjIndexKey.DeleteKey;
var
   p: GSptrIndexKeyData;
   Lastone: boolean;
   TempTag: longint;
begin
   Changed := true;
   if Child <> nil then
      Child^.DeleteKey
   else
   begin
      lastone := CurKey >= pred(Count);
      p := At(CurKey);
      FreeOne(p);
      if (CurKey >= Count) then
         CurKey := pred(Count);
      if (CurKey < 0) then CurKey := 0;
      if lastone and (Owner <> nil) then
      begin
         if Count > 0 then
         begin
            p := At(CurKey);
            TempTag := p^.Tag;
            p^.Tag := Page;
            ReplaceNodeKey(p);
            p^.Tag := TempTag;
         end
         else
            DeleteNodeKey;
      end;
   end;
end;

procedure GSobjIndexKey.DeleteNodeKey;
var
   OldCurKey: integer;
begin
   if (Owner <> nil) then
   begin
      OldCurKey := Owner^.CurKey;
      Owner^.CurKey := Owner^.SeekNodeTag(Page);
      if Owner^.CurKey <> -1 then
      begin
         Owner^.Child := nil;
         Owner^.DeleteKey;
         Owner^.Child := @Self;
      end;
      Owner^.CurKey := OldCurKey;
   end;
end;

function GSobjIndexKey.GetChild(Tag: longint): boolean;
begin
   GetChild := false;
   if Tag = 0 then exit;                              {!!RFG 091197}
   if (TagParent^.Owner^.NextAvail > 0) and           {!!RFG 091509}
      (Tag > TagParent^.Owner^.NextAvail) then exit;  {!!RFG 091197}
   if PageType < Leaf then
   begin
      if Child <> nil then
      begin
         if (Child^.Page <> Tag) or (Child^.Reload) then
         begin
            Child^.Free;
            Child := nil;
         end;
      end;
      if Child = nil then
         Child := New(GSptrIndexKey, Create(TagParent,@Self,Tag));
   end;
   GetChild := Child <> nil;
end;

procedure GSobjIndexKey.InsertKey(Key: GSptrIndexKeyData; AddAfter: boolean);
var
   p: GSptrIndexKeyData;
begin
   if Child <> nil then
      Child^.InsertKey(Key, AddAfter)
   else
   begin
      p := Key^.CloneLinks;
      if AddAfter then inc(CurKey);
      if CurKey > Count then CurKey := Count;
      if CurKey < 0 then CurKey := 0;
      if (Owner <> nil) and (CurKey >= Count) then
      begin
         p^.Tag := Page;
         ReplaceNodeKey(p);
         p^.Tag := Key^.Tag;
      end;
      AtInsert(CurKey,p);
      Changed := true;
   end;
end;

function GSobjIndexKey.PageLoad: boolean;
begin
   FreeAll;
   PageLoad := TagParent^.PageLoad(Page,@Self);
   Changed := false;
end;

function GSobjIndexKey.PageStore: boolean;
begin
   if Page = 0 then
   begin
      Page := TagParent^.Owner^.GetAvailPage;
   end;
   PageStore := TagParent^.PageStore(Page,@Self);
   Changed := false;
end;

function GSobjIndexKey.ReadBottomKey: boolean;
var
   p: GSptrIndexKeyData;
begin
   ReadBottomKey := false;
   if (Count = 0) then exit;
   CurKey := pred(Count);
   p := At(CurKey);
   if PageType < Leaf then
   begin
      if GetChild(p^.Tag) then
         ReadBottomKey := Child^.ReadBottomKey;
   end
   else
   begin
      ReadBottomKey := true;
      TagParent^.CurKeyInfo^.AssignString(p);
      TagParent^.CurKeyInfo^.Tag := p^.Tag;
   end;
end;

function GSobjIndexKey.ReadCurrentKey: boolean;
var
   p: GSptrIndexKeyData;
begin
   ReadCurrentKey := false;
   if (Count = 0) or (CurKey >= Count) or (CurKey < 0) then exit;
   p := At(CurKey);
   if PageType < Leaf then
   begin
      if GetChild(p^.Tag) then
         ReadCurrentKey := Child^.ReadCurrentKey;
   end
   else
   begin
      ReadCurrentKey := true;
      TagParent^.CurKeyInfo^.AssignString(p);
      TagParent^.CurKeyInfo^.Tag := p^.Tag;
   end;
end;

function GSobjIndexKey.ReadNextKey: boolean;
var
   p: GSptrIndexKeyData;
   b: boolean;
begin
   ReadNextKey := false;
   if (Count = 0) then exit;
   b := false;
   if PageType < Leaf then
   begin
      while (not b) and (CurKey < Count) do
      begin
         p := At(CurKey);
         if GetChild(p^.Tag) then
         begin
            if Child^.CurKey = -1 then
            begin
               if Child^.PageType < Leaf then
                  Child^.CurKey := 0;
            end;
            b := Child^.ReadNextKey;
         end
         else
            b := false;
         if (not b) then inc(CurKey);
      end;
      if (not b) then CurKey := pred(Count);
      ReadNextKey := b;
   end
   else
   begin
      inc(CurKey);
      if CurKey < Count then
      begin
         p := At(CurKey);
         ReadNextKey := true;
         TagParent^.CurKeyInfo^.AssignString(p);
         TagParent^.CurKeyInfo^.Tag := p^.Tag;
      end
      else
         ReadNextKey := false;
   end;
end;

function GSobjIndexKey.ReadPreviousKey: boolean;
var
   p: GSptrIndexKeyData;
   b: boolean;
begin
   ReadPreviousKey := false;
   if (Count = 0) then exit;
   b := false;
   if PageType < Leaf then
   begin
      if CurKey >= Count then exit;
      while (not b) and (CurKey >= 0) do
      begin
         p := At(CurKey);
         if GetChild(p^.Tag) then
         begin
            if Child^.CurKey = -1 then
            begin
               Child^.CurKey := Child^.Count;
               if Child^.PageType < Leaf then
                  dec(Child^.CurKey);
            end;
            b := Child^.ReadPreviousKey;
         end
         else
            b := false;
         if (not b) then dec(CurKey);
      end;
      if (not b) then CurKey := 0;
      ReadPreviousKey := b;
   end
   else
   begin
      dec(CurKey);
      if CurKey >= 0 then
      begin
         p := At(CurKey);
         ReadPreviousKey := true;
         TagParent^.CurKeyInfo^.AssignString(p);
         TagParent^.CurKeyInfo^.Tag := p^.Tag;
      end
      else
         ReadPreviousKey := false;
   end;
end;

function GSobjIndexKey.ReadTopKey: boolean;
var
   p: GSptrIndexKeyData;
begin
   ReadTopKey := false;
   if (Count = 0) then exit;
   CurKey := 0;
   p := At(CurKey);
   if PageType < Leaf then
   begin
      if GetChild(p^.Tag) then
         ReadTopKey := Child^.ReadTopKey;
   end
   else
   begin
      CurKey := 0;
      ReadTopKey := true;
      TagParent^.CurKeyInfo^.AssignString(p);
      TagParent^.CurKeyInfo^.Tag := p^.Tag;
   end;
end;

procedure GSobjIndexKey.ReplaceNodeKey(Key: GSptrIndexKeyData);
var
   lastone: boolean;
   OldCurKey: integer;
begin
   if (Owner <> nil) then
   begin
      OldCurKey := Owner^.CurKey;
      Owner^.CurKey := Owner^.SeekNodeTag(Page);
      lastone := Owner^.CurKey >= pred(Owner^.Count);
      Owner^.Child := nil;
      if Owner^.CurKey <> -1 then
         Owner^.DeleteKey
      else
      begin
         Owner^.CurKey := pred(Owner^.Count);
         lastone := true;
      end;
      Owner^.InsertKey(Key, lastone);
      Owner^.Child := @Self;
      Owner^.CurKey := OldCurKey;
   end;
end;


function GSobjIndexKey.RetrieveKey(Key: GSptrIndexKeyData): integer;
var
   p: GSptrIndexKeyData;
   rkey: integer;
begin
   if Owner = nil then      {!!RFG 082097}
   begin                    {If at root, initialize EOF/BOF flags}
      ChkBOF := true;
      ChkEOF := true;
   end;
   ChkBOF := ChkBOF and (CurKey = 0);  {Testing thru links for BOF}
   ChkEOF := ChkEOF and (CurKey = pred(Count)); {Testing for EOF}
   if Child <> nil then
      RetrieveKey := Child^.RetrieveKey(Key)
   else
   begin
      p := At(CurKey);
      Key^.AssignString(p);
      Key^.Tag := p^.Tag;
      rkey := 0;
      if ChkBOF then rkey := 1;           {!!RFG 082097}
      if ChkEOF then rkey := rkey + 2;    {!!RFG 082097}
      RetrieveKey := rkey;                {!!RFG 082097}
   end;
end;

function GSobjIndexKey.SeekKey(Tag: longint; Key: GSptrIndexKeyData;
                               Exact: boolean): integer;
var
   k: integer;
   p: GSptrIndexKeyData;
   dv: longint;
   sc: char;
begin
   k := 1;
   Exact := Exact or (TagParent^.KeyType <> 'C');
   if TagParent^.KeyType = 'C' then                   {!!RFG 090297}
      sc := ' '
   else
      sc := #0;
   CurKey := 0;
   if Count > 0 then
   begin
      while (k > 0) and (CurKey < Count) do
      begin
         p := At(CurKey);
         k := CmprOEMBufr(Key,p,pCompareTbl,dv, sc);    {!!RFG 090297}
         if TagParent^.InvertCmpr then k := -k;
         if (k = 0) and (Tag = MaxRecNum) then k := ValueHigh;
         if (k = 0) and (Tag <> IgnoreRecNum) then
         begin
            if GSptrIndexFile(TagParent^.Owner)^.KeyWithRec then
            begin
               if Tag > p^.Xtra then k := ValueHigh
               else
                  if Tag < p^.Xtra then k := ValueLow;
            end;
         end;
         if (k <= 0) or (CurKey = pred(Count)) then
         begin
            if PageType < Leaf then
            begin
               GetChild(p^.Tag);
               k := Child^.SeekKey(Tag, Key, Exact);
            end
            else
               if (k = 0) and (Tag <> IgnoreRecNum) then
               begin
                  if GSptrIndexFile(TagParent^.Owner)^.KeyWithRec then
                  begin
                     if Tag > p^.Tag then k := ValueHigh
                        else
                           if Tag < p^.Tag then k := ValueLow;
                  end
                  else
                     if Tag <> p^.Tag then k := ValueHigh;
               end;
               if k < 0 then
                  if (not Exact) and (dv > Key^.SizeStr) then {!RFG 080497}
                     k := ValueEqual;  {Non-Exact match test}
         end;
         if k > 0 then inc(CurKey);
      end;
   end;
   SeekKey := k;
end;

function GSobjIndexKey.SeekNodeTag(Tag: longint): integer;
var
   i: integer;
   p: GSptrIndexKeyData;
   FoundIt: integer;
begin
   FoundIt := -1;
   i := 0;
   if Count > 0 then
   begin
      while (FoundIt < 0) and (i < Count) do
      begin
         p := At(i);
         if p^.Tag = Tag then
            FoundIt := i;
         inc(i);
      end;
   end;
   SeekNodeTag := FoundIt;
end;

{----------------------------------------------------------------------------
                              GSobjIndexTag
----------------------------------------------------------------------------}

constructor GSobjIndexTag.Create(PIF: GSptrIndexFile; ITN: PChar;
                                                    TagHdr: longint);
begin
   inherited Create;
   TagSig := 'UNK';
   TagName := StrGSNew(ITN);
   KeyExpr := nil;
   ForExpr := nil;
   KeyLength := 0;
   DefaultLen := 0;
   EntryLength := 0;
   MaxKeys := 0;
   MinKeys := 0;
   RangeLo := New(GSptrIndexKeyData, Create(0));
   RangeHi := New(GSptrIndexKeyData, Create(0));
   Owner:= PIF;
   TagBlock := TagHdr;
   TagChanged := false;
   RootBlock := 0;
   RootPage := nil;
   AscendKey := true;
   UniqueKey := false;
   InvertCmpr := false;
   InvertRead := false;
   Conditional := false;
   KeyType := 'C';
   CurKeyInfo := New(GSptrIndexKeyData, Create(0));
   TagBOF := false;
   TagEOF := false;
   KeyUpdated := false;
   ObjType := GSobtIndexTag;
end;

destructor GSobjIndexTag.Destroy;
begin
   if RootPage <> nil then
      RootPage^.Free;
   RootPage := nil;
   if TagChanged then TagStore;
   StrGSDispose(TagName);
   StrGSDispose(KeyExpr);
   StrGSDispose(ForExpr);
   RangeLo^.Free;
   RangeHi^.Free;
   if RootPage <> nil then
      RootPage^.Free;
   RootPage := nil;
   CurKeyInfo^.Free;
   inherited Destroy;
end;

procedure GSobjIndexTag.AdjustValue(AKey: GSptrIndexKeyData);
begin
end;

function GSobjIndexTag.HuntDuplicate(Key: GSptrIndexKeyData): longint;
var
   RP: GSptrIndexKey;
   LK: GSptrIndexKeyData;
begin                                   {!!RFG 082097}
   Owner^.Exact := true;
   RP := RootPage;
   RootPage := nil;
   LK := CurKeyInfo^.CloneLinks;
   HuntDuplicate := KeyFind(Key);
   TagClose;
   RootPage := RP;
   CurKeyInfo^.AssignLinks(LK);
end;

function GSobjIndexTag.IndexTagNew(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                                boolean;
begin
   IndexTagNew := false;
   KeyExpr := StrGSNew(KeyExp);
   ForExpr := StrGSNew(ForExp);
   AscendKey := Ascnd;
   UniqueKey := Uniq;
   Conditional := (ForExpr <> nil) and (StrLen(ForExpr) > 0);
end;

procedure GSobjIndexTag.GetRange(var RLo, RHi: GSptrString);
begin
   RangeLo^.AssignString(RLo);
   RangeHi^.AssignString(RHi);
end;

function GSobjIndexTag.GetRangeCount: longint;
var
   cky: GSptrIndexKeyData;
   rc: longint;
begin
      if (Conditional) or
         (RangeLo^.SizeStr > 0) or (RangeHi^.SizeStr > 0) then
      begin
         RootPage^.RetrieveKey(CurKeyInfo);
         cky := CurKeyInfo^.CloneLinks;
         rc := 0;
         KeyRead(Top_Record);
         while not TagEOF do
         begin
            KeyRead(Prev_Record);
            inc(rc);
         end;
         KeyFind(cky);
         RootPage^.RetrieveKey(CurKeyInfo);
         cky^.Free;
      end
      else
         rc := Owner^.Owner^.NumRecs;
   GetRangeCount := rc;
end;



function GSobjIndexTag.KeyAdd(Key: GSptrIndexKeyData): boolean;
var
   K : integer;
   fp: integer;
   stot: GSptrIndexKeyData;
   FRN: longint;
begin
   KeyAdd := false;
   TagOpen(0);
   if (RootPage = nil) then exit;
   stot := Key^.CloneLinks;
   AdjustValue(stot);
   TagBOF := false;
   TagEOF := false;                   {End-of-File initially set false}
   K := 1;
   if Owner^.KeyWithRec then
      FRN := stot^.Tag
   else
      if InvertCmpr then
         FRN := MinRecNum
      else
         FRN := MaxRecNum;
   if UniqueKey then
   begin
      K := RootPage^.SeekKey(IgnoreRecNum, stot, True);
      FRN := stot^.Tag;
   end;
   if K <> 0 then         {If unique and no match...}
   begin
      K := RootPage^.SeekKey(FRN, stot, True);
      case K of
         ValueEqual,
         ValueLow : begin
                       RootPage^.InsertKey(stot, false);
                       TagOpen(0);
                       RootPage^.SeekKey(FRN, stot, True);
                       if (FRN = MaxRecNum) then
                          RootPage^.ReadPreviousKey;
                       fp := RootPage^.RetrieveKey(CurKeyInfo);
                       if InvertRead then             {Descending index}
                       begin
                          TagEOF := (fp and 1) > 0;   {!!RFG 082097}
                          TagBOF := (fp and 2) > 0;   {!!RFG 082097}
                       end
                       else
                       begin
                          TagBOF := (fp and 1) > 0;   {!!RFG 082097}
                          TagEOF := (fp and 2) > 0;   {!!RFG 082097}
                       end;
                       KeyAdd := True;
                    end;
         ValueHigh: begin;
                       if InvertRead then
                          KeyRead(Top_Record)
                       else
                          KeyRead(Bttm_Record);
                       RootPage^.InsertKey(stot, true);    {!RFG 080297}
                       TagOpen(0);
                       if InvertRead then
                       begin
                          KeyRead(Top_Record);
                          TagBOF := true;
                       end
                       else
                       begin
                          KeyRead(Bttm_Record);  {get new bottom record}
                          TagEOF := true;
                       end;
                       KeyAdd := True;
                    end;
      end;
   end;
   stot^.Free;
end;

function GSobjIndexTag.KeyFind(Key: GSptrIndexKeyData) : longint;
var
   K: integer;
   stot: GSptrIndexKeyData;
begin
   if Owner^.Owner <> nil then
      Owner^.Exact := Owner^.Owner^.gsvExactMatch;
   KeyFind := 0;
   CurKeyInfo^.Tag := 0;
   TagOpen(0);
   if (RootPage = nil) then exit;
   stot := Key^.CloneLinks;
   AdjustValue(stot);
   TagBOF := false;
   TagEOF := false;                   {End-of-File initially set false}
   K := RootPage^.SeekKey(stot^.Tag, stot, Owner^.Exact);
   case K of
      ValueEqual : begin
                      RootPage^.RetrieveKey(CurKeyInfo);
                      if KeyInRange then
                         KeyFind := CurKeyInfo^.Tag     {!!RFG 091797}
                      else                              {!!RFG 091797}
                         TagEOF := true;                {!!RFG 091797}
                   end;
      ValueLow   : begin
                      RootPage^.RetrieveKey(CurKeyInfo);
                      if not KeyInRange then
                         TagEOF := true;
                   end;
      ValueHigh  : begin
                      TagEOF := true;
                   end;
   end;
   stot^.Free;
end;

Function GSobjIndexTag.KeyByPercent(APct: integer) : LongInt;
begin
   KeyByPercent := 0;
   RunError(5);
(*
   if APct > 100 then APct := 100;
   KeyByPercent := 0;
   CurTagValue := 0;
   if (RootPage = nil) then exit;
   TagBOF := false;
   TagEOF := false;                   {End-of-File initially set false}
   case APct of
        0 : KeyByPercent := KeyRead(Top_Record);
      100 : KeyByPercent := KeyRead(Bttm_Record);
      else  begin
            end;
   end;
*)
end;

Function GSobjIndexTag.KeyInRange: boolean;
var
   h: integer;
   d: longint;
   sc: char;
begin
   KeyInRange := true;
   if (RangeLo^.SizeStr = 0) and (RangeHi^.SizeStr = 0) then exit;
   KeyInRange := false;
   if (TagBOF) or (TagEOF) then exit;
   if KeyType = 'C' then                   {!!RFG 090297}
      sc := ' '
   else
      sc := #0;
   h := 0;
   if RangeHi^.SizeStr > 0 then
      h := CmprOEMBufr(CurKeyInfo, RangeHi, pCompareTbl,d, sc);  {!!RFG 090297}
   if InvertCmpr then h := -h;
   if HiInRange and (h = 0) then h := -1;
   if h < 0 then
   begin
      if RangeLo^.SizeStr > 0 then
         h := CmprOEMBufr(RangeLo, CurKeyInfo, pCompareTbl,d, sc);
      if InvertCmpr then h := -h;
      if LoInRange and (h = 0) then h := -1;
      inc(h);
   end;
   KeyInRange := h = 0;
end;

Function GSobjIndexTag.KeyIsAscending: boolean;
begin
   KeyIsAscending := AscendKey;
end;

Function GSobjIndexTag.KeyIsPercentile: integer;
begin
   KeyIsPercentile := -1;
end;

Function GSobjIndexTag.KeyIsUnique: boolean;
begin
   KeyIsUnique := UniqueKey;
end;

function GSobjIndexTag.KeyRead(TypRead: longint) : longint;
var
   KeyStatus: integer;
   XofFile: boolean;

   function TestRange: integer;
   var
      h: integer;
      l: integer;
      d: longint;
      sc: char;
   begin
      TestRange := 0;
      if (RangeLo^.SizeStr = 0) and (RangeHi^.SizeStr = 0) then exit;
      if (TagBOF) or (TagEOF) then exit;
      if KeyType = 'C' then                   {!!RFG 090297}
         sc := ' '
      else
         sc := #0;
      h := 0;
      l := 0;
      if RangeHi^.SizeStr > 0 then
      begin
         h := CmprOEMBufr(CurKeyInfo, RangeHi, pCompareTbl,d, sc);
         if InvertCmpr then h := -h;
         TagEOF := h = 1;
      end;
      if h <= 0 then
      begin
         if RangeLo^.SizeStr > 0 then
         begin
            l := CmprOEMBufr(RangeLo, CurKeyInfo, pCompareTbl,d, sc);
            if InvertCmpr then l := -l;
            TagBOF := l = 1;
         end;
         if l < 0 then l := 0;
         TestRange := l;
      end
      else
      begin
         TestRange := h;
      end;
      if (TagBOF) or (TagEOF) then TestRange := 0;
   end;

begin
   KeyRead := 0;
   CurKeyInfo^.Tag := 0;
   if (RootPage = nil) then exit;
   if InvertRead then             {Descending index}
   begin
      case TypRead of
         Next_Record : TypRead := Prev_Record;
         Prev_Record : TypRead := Next_Record;
         Top_Record  : TypRead := Bttm_Record;
         Bttm_Record : TypRead := Top_Record;
      end;
   end;
   TagBOF := false;
   TagEOF := false;                   {End-of-File initially set false}
   case TypRead of                    {Select KeyRead Action}

      Next_Record : begin
                       Repeat
                          TagEOF := not RootPage^.ReadNextKey;
                       until TestRange = 0;
                    end;

      Prev_Record : begin
                       Repeat
                          TagBOF := not RootPage^.ReadPreviousKey;
                       until TestRange = 0;
                    end;

      Top_Record  : begin
                       TagOpen(2);
                       if RangeLo^.SizeStr > 0 then
                       begin
                          TagEOF :=
                             RootPage^.SeekKey(IgnoreRecNum, RangeLo, false) = 1;
                          if not TagEOF then
                             RootPage^.RetrieveKey(CurKeyInfo);
                       end
                       else
                          TagBOF := not RootPage^.ReadTopKey;
                       TestRange;
                       if TagEOF then TagBOF := true;
                       TagEOF := TagBOF;
                    end;

      Bttm_Record : begin
                      TagOpen(2);
                      if RangeHi^.SizeStr > 0 then
                       begin
                          KeyStatus := RootPage^.SeekKey(MaxRecNum,RangeHi,true);
                          case KeyStatus of
                             1 : TagEOF := not RootPage^.ReadBottomKey;
                             0 : RootPage^.RetrieveKey(CurKeyInfo);
                            -1 : TagBOF := not RootPage^.ReadPreviousKey;
                          end;
                       end
                       else
                          TagEOF := not RootPage^.ReadBottomKey;
                       if TestRange <> 0 then
                       Repeat
                          TagBOF := not RootPage^.ReadPreviousKey;
                       until TestRange = 0;
                       if TagBOF then TagEOF := true;
                       TagBOF := TagEOF;
                    end;

      Same_Record : begin
                       TagEOF := not RootPage^.ReadCurrentKey;
                       TagBOF := TagEOF;
                       TestRange;
                    end;

      else          CurKeyInfo^.Tag := 0;   {if no valid action, return zero}
   end;
   if TagEOF or TagBOF then
   begin
      CurKeyInfo^.Tag := 0;
      if InvertRead then             {Descending index}
      begin
         XofFile := TagEOF;
         TagEOF := TagBOF;
         TagBOF := XofFile;
      end;
   end;
   KeyRead := CurKeyInfo^.Tag;
end;

procedure GSobjIndexTag.KeySync(ATag: longint; DoReload: boolean);
begin
   if (CurKeyInfo^.Tag = ATag) and (not DoReload) then exit;
   TagOpen(1);
   if (CurKeyInfo^.Tag <> ATag) then
      Owner^.FoundError(dbsIndexFileBad,inxRetrieveKeyError, nil);
end;

function GSobjIndexTag.KeyUpdate(AKey: longint; IsAppend: boolean): boolean;
var
   Rsl: PChar;
   Typ: char;
   Chg: boolean;
   Rsl2: PChar;
   Rsl3: PChar;
   Rsl4: PChar;
   Typ2: char;
   Chg2: boolean;
   Fnd: boolean;
   withFor: boolean;
   testFor: boolean;
   Hld: GSptrCharArray;
   isActive: boolean;
   RslStr: GSptrIndexKeyData;
begin
   KeyUpdate := false;
   KeyUpdated := false;
   if Owner^.Owner^.OrigRec = nil then exit;  {no changes}
         RslStr := New(GSptrIndexKeyData, Create(0));
         RslStr^.Tag := AKey;
         RslStr^.Xtra := AKey;
   GetMem(Rsl,256);
   FillChar(Rsl[0],256,#0);
   StrCopy(Rsl,'T');
   withFor := Conditional and (ForExpr <> nil);
   testFor := withFor;
   if withFor then
      SolveExpression(@Self, TagName, ForExpr, Rsl, Typ, Chg);
   withFor := Rsl[0] = 'T';
   Chg := true;
   SolveExpression(@Self, TagName, KeyExpr, Rsl, Typ, Chg);
   isActive := RootPage <> nil;
   if IsAppend then
   begin
      if WithFor then
      begin
         RslStr^.PutPChar(Rsl);
         KeyAdd(RslStr);
         KeyUpdated := true;
         if not isActive then TagClose;
      end;
   end
   else
   begin
      if Chg or testFor then
      begin
         GetMem(Rsl2,256);
         FillChar(Rsl2[0],256,#0);
         GetMem(Rsl3,256);
         GetMem(Rsl4,256);
         RslStr^.PutPChar(Rsl);
         AdjustValue(RslStr);
         RslStr^.GetPChar(rsl3);
         Hld := Owner^.Owner^.CurRecord;
         Owner^.Owner^.CurRecord := Owner^.Owner^.OrigRec;
         SolveExpression(@Self, TagName, KeyExpr, Rsl2, Typ2, Chg2);
         RslStr^.PutPChar(Rsl2);
         AdjustValue(RslStr);
         RslStr^.GetPChar(rsl4);

         RslStr^.PutPChar(Rsl2);                 {!!RFG 120897}
         Fnd := KeyFind(RslStr) > 0;             {!!RFG 120897}

         if (StrComp(Rsl3,Rsl4) <> 0) or ((not withFor) and testFor) then
         begin
            if Fnd then RootPage^.DeleteKey;
         end
         else
            withFor := not Fnd;  {Don't add key, it matches the old}
                                                {!!RFG 120897}
         Owner^.Owner^.CurRecord := Hld;
         FreeMem(Rsl2,256);
         FreeMem(rsl3,256);
         FreeMem(rsl4,256);
         if withFor then
         begin
            RslStr^.PutPChar(Rsl);
            KeyAdd(RslStr);
         end;
         KeyUpdated := true;
         if not isActive then TagClose;
      end;
   end;
   KeyUpdate := KeyUpdated;
   FreeMem(Rsl,256);
   RslStr^.Free;
end;


procedure GSobjIndexTag.SetRange(RLo: GSptrString; LoIn: Boolean;
                                 RHi: GSptrString; HiIn: Boolean);
var
   s1: PChar;
   s2: PChar;
begin
   RangeLo^.ClearString;
   RangeHi^.ClearString;
   LoInRange := LoIn;
   HiInRange := HiIn;
   GetMem(s1,256);
   GetMem(s2,256);
   s1[0] := #0;
   s2[0] := #0;
   if (RLo <> nil) and (RLo^.SizeStr > 0) then
   begin
      if KeyType = 'D' then
      begin
         JulDateStr(s1,RLo^.CharStr^,KeyType);
         RangeLo^.PutPChar(s1);
      end
      else
         RangeLo^.AssignString(RLo);
      AdjustValue(RangeLo);
   end;
   if (RHi <> nil) and (RHi^.SizeStr > 0) then
   begin
      if KeyType = 'D' then
      begin
         JulDateStr(s2,RHi^.CharStr^,KeyType);
         RangeHi^.PutPChar(s2);
      end
      else
         RangeHi^.AssignString(RHi);
      AdjustValue(RangeHi);
   end;
   FreeMem(s2,256);
   FreeMem(s1,256);
   KeyRead(Top_Record);
end;

procedure GSobjIndexTag.SetRoot(PIK: GSptrIndexKey);
var
   NRN: longint;
   p: GSptrIndexKeyData;
   TmpTag: longint;
   TmpStr: GSptrIndexKeyData;
begin
   PIK^.Owner := New(GSptrIndexKey, Create(@Self, nil, 0));
   NRN := Owner^.GetAvailPage;
   PIK^.Owner^.Page := NRN;
   PIK^.Owner^.PageType := Root;
   if PIK^.Count > 0 then
   begin
      p := PIK^.At(pred(PIK^.Count));
      TmpTag := p^.Tag;
      P^.Tag := PIK^.Page;
      PIK^.Owner^.InsertKey(p,true);
      p^.Tag := TmpTag;
   end
   else
   begin
      TmpStr := New(GSptrIndexKeyData, Create(0));
      TmpStr^.Tag := PIK^.Page;
      PIK^.Owner^.InsertKey(TmpStr,true);
      TmpStr^.Free;
   end;
   PIK^.Owner^.Child := PIK;
   RootPage := PIK^.Owner;
   RootBlock := NRN;
   TagChanged := true;
end;

function GSobjIndexTag.PageLoad(PN: longint; PIK: GSptrIndexKey): Boolean;
begin
   PageLoad := false;
end;

function GSobjIndexTag.PageStore(PN: longint; PIK: GSptrIndexKey): Boolean;
begin
   PageStore := false;
end;

function GSobjIndexTag.TagLoad: boolean;
begin
   TagLoad := false;
   TagChanged := false;
end;

function GSobjIndexTag.TagStore: Boolean;
begin
   TagStore := false;
   TagChanged := false;
end;

procedure GSobjIndexTag.TagClose;
begin
   if RootPage <> nil then
   begin
      RootPage^.Free;
      RootPage := nil;
   end;
   if TagChanged then TagStore;
end;

function GSobjIndexTag.NewRoot: longint;
begin
   NewRoot := RootBlock;
end;

procedure GSobjIndexTag.TagOpen(Posn: integer);
var
   Rsl: array[0..255] of char;
   Typ: char;
   Sek: integer;
   Chg: boolean;
   Fnd: boolean;
   nrb: longint;
   TmpStr: GSptrIndexKeyData;
   XofFile: boolean;
begin
   TagClose;
   nrb := NewRoot;
   if nrb <> RootBlock then
   begin
      RootBlock := nrb;
   end;
   RootPage := New(GSptrIndexKey, Create(@Self, nil, RootBlock));
   if Posn = 2 then exit;
   if (Posn = 0) or (KeyExpr = nil) or (KeyExpr[0] = #0) or
      (Owner^.Owner^.RecNumber = 0) or
      (Owner^.Owner^.RecNumber > Owner^.Owner^.NumRecs) or
      (RootPage = nil) or (RootPage^.Count = 0) then
      KeyRead(Top_Record)
   else
   begin
      rsl[0] := #0;
      Fnd := SolveExpression(@Self, TagName, KeyExpr, Rsl, Typ, Chg);
      if Fnd then
      begin
         TmpStr := New(GSptrIndexKeyData, Create(0));
         TmpStr^.PutPChar(rsl);
         AdjustValue(TmpStr);
         Sek := RootPage^.SeekKey(Owner^.Owner^.RecNumber, TmpStr, true);
         TmpStr^.Free;
         if Sek = 0 then
         begin
            Sek := RootPage^.RetrieveKey(CurKeyInfo);
            TagBOF := (Sek and 1) > 0;     {!!RFG 082097}
            TagEOF := (Sek and 2) > 0;     {!!RFG 082097}
            if InvertRead then             {Descending index}
            begin
               XofFile := TagEOF;
               TagEOF := TagBOF;
               TagBOF := XofFile;
            end;
         end
         else
            KeyRead(Top_Record);
      end
      else
         KeyRead(Top_Record);
   end;
end;

procedure GSobjIndexTag.JulDateStr(stot, stin: PChar; var Typ: char);
var
   jd: longint;
   sx: string[15];
   sl: integer;
   r: integer;
begin
   sx := LTrim(StrPas(stin));
   sl := length(sx);
   if (sl > 7) then {could already be a julian date (7 digits)} {!!RFG 103197}
   begin
      jd := GS_Date_Juln(sx);
      if jd < 0 then jd := 0;
   end
   else
   begin
      val(sx,jd,r);
      if r <> 0 then jd := 0;
   end;
   if jd = 0 then
      sx := '        '
   else
      str(jd:8, sx);
   StrPCopy(stot,sx);
end;


{----------------------------------------------------------------------------
                              GSobjIndexFile
----------------------------------------------------------------------------}

constructor GSobjIndexFile.Create(PDB: GSP_dBaseFld);
begin
   inherited Create;
   if PDB <> nil then
      Exact := PDB^.gsvExactMatch
   else
      Exact := true;
   DiskFile := nil;
   IndexName := nil;
   Corrupted := false;                           {!!RFG 091197}
   TagList := New(GSptrCollection, Create(8,8));
   TagRoot := 0;
   Owner := PDB;
   NextAvail := -1;
   KeyWithRec := false;
   Dictionary := false;
   ObjType := GSobtIndexFile;
   CreateOK := false;
end;

destructor GSobjIndexFile.Destroy;
begin
   if TagList <> nil then
      TagList^.Free;
   if DiskFile <> nil then
      DiskFile^.Free;
   StrGSDispose(IndexName);
   inherited Destroy;
end;

function GSobjIndexFile.IndexFileOpen(PDB: GSP_dBaseFld; const FN, EX: string;
                                  FM: word; Overwrite: boolean): GSP_DiskFile;
var
   PcAr: array[0..259] of char;
   Pth: string;
   dFile: GSP_DiskFile;
begin
   Pth := CapClip(FN,[' ','"']);
   Pth := ChangeFileExtEmpty(Pth, EX);
   StrPCopy(PcAr,ExtractFileName(Pth));
   IndexName := StrGSNew(PcAr);
   if PDB <> nil then
      if ExtractFilePath(Pth) = '' then
         Pth := ExtractFilePath(StrPas(PDB^.dfFileName))+Pth;
   if (FM = dfCreate) and not Overwrite then
   begin
      if GSFileExists(Pth) then
         FM := fmOpenReadWrite+fmShareDenyNone;    {!!RFG 091397}
   end;
   if FM = dfCreate then
   begin
      dFile := New(GSP_DiskFile, Create(Pth, fmOpenReadWrite));
      dFile^.gsRewrite;
   end
   else
   begin
      dFile := New(GSP_DiskFile, Create(Pth, FM));
      if not dFile^.dfFileExst then
      begin
         dFile^.Free;
         dFile := nil;
      end;
   end;
   if dFile <> nil then
   begin
      dFile^.gsReset;
      if PDB <> nil then
         dFile^.gsSetLockProtocol(PDB^.dfLockStyle);
      dFile^.gsSetFlushCondition(NeverFlush);
   end;
   IndexFileOpen := dFile;
end;

function GSobjIndexFile.AddTag(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                                                                     boolean;
begin
   AddTag := false;
end;

function GSobjIndexFile.DeleteTag(ITN: PChar): boolean;
begin
   DeleteTag := false;
end;

Procedure GSobjIndexFile.FoundError(Code, Info: integer; StP: PChar);
begin
   if Owner <> nil then
      Owner^.FoundError(Code,Info,StP)
   else
      FoundPgmError(Code,Info,StP);
end;



function GSobjIndexFile.GetAvailPage: longint;
begin
   GetAvailPage := -1;
end;

function GSobjIndexFile.ResetAvailPage: longint;
begin
   ResetAvailPage := -1;
end;

Function GSobjIndexFile.IndexLock : boolean;
var
   rsl: boolean;
begin
   IndexLock := false;
   if DiskFile = nil then exit;
   with DiskFile^ do
   begin
      if not dfFileShrd then
      begin
         IndexLock := true;
         exit;
      end;
      rsl := false;
      case dfLockStyle of
         DB4Lock  : begin
                       rsl := gsLockRecord(dfDirtyReadMax - 1, 2);
                    end;
         ClipLock : begin
                       rsl := gsLockRecord(dfDirtyReadMin, 1);  {!!RFG 081397}
                    end;
         Default,
         FoxLock  : begin
                       rsl := gsLockRecord(dfDirtyReadMax - 1, 1);
                    end;
      end;
      IndexLock := rsl;
      if not rsl then gsTestForOk(dfFileErr,dskLockError);
   end;
end;

function GSobjIndexFile.IsFileName(const IName: string): boolean;
var
   PcAr: PChar;
   PcWk: PChar;
   d: integer;
begin
   GetMem(PcAr,260);
   StrPCopy(PcAr,IName);
   PcWk := StrEnd(PcAr);
   while (not (PcWk[0] in ['\',':'])) and (PcWk > PcAr) do dec(PcWk);
   if (PcWk[0] in ['\',':']) then inc(PcWk);
   IsFileName := CmprOEMPChar(PcWk, IndexName, pCtyUpperCase, d) = 0;
   FreeMem(PcAr,260);
end;

function GSobjIndexFile.KeyByName(AKey: PChar; AFor: boolean): GSptrIndexTag;
var
   i: integer;
   m: integer;
   d: integer;
   p: GSptrIndexTag;
begin
   if TagList^.Count = 0 then
   begin
      KeyByName := nil;
   end
   else
   begin
      i := 0;
      repeat
         p := TagList^.At(i);
         inc(i);
         m := CmprOEMPChar(AKey, p^.KeyExpr,pCtyUpperCase,d);
         if AFor and p^.Conditional then m := 1;
      until (m=0) or (i = TagList^.Count);
      if m = 0 then
         KeyByName := p
      else
         KeyByName := nil;
   end;
end;

function GSobjIndexFile.PageRead(Blok: longint; var Page; Size: integer):
                                 boolean;
begin
   PageRead := false;
   if DiskFile = nil then exit;
   PageRead := DiskFile^.gsRead(Blok, Page, Size);
end;

function GSobjIndexFile.PageWrite(Blok: longint; var Page; Size: integer):
                                  boolean;
begin
   PageWrite := false;
   if DiskFile = nil then exit;
   PageWrite := DiskFile^.gsWrite(Blok, Page, Size);
end;

procedure GSobjIndexFile.ReIndex;
begin
end;

function GSobjIndexFile.GetFileName: string;
begin
   GetFileName := StrPas(IndexName);
end;

function GSobjIndexFile.TagCount: integer;
begin
   TagCount := TagList^.Count;
end;

function GSobjIndexFile.TagByName(ITN: PChar): GSptrIndexTag;
var
   i: integer;
   m: integer;
   d: integer;
   p: GSptrIndexTag;
begin
   if TagList^.Count = 0 then
   begin
      TagByName := nil;
   end
   else
   begin
      i := 0;
      repeat
         p := TagList^.At(i);
         inc(i);
         m := CmprOEMPChar(ITN, p^.TagName,pCtyUpperCase,d);
      until (m=0) or (i = TagList^.Count);
      if m = 0 then
         TagByName := p
      else
         TagByName := nil;
   end;
end;

function GSobjIndexFile.TagByNumber(N: integer): GSptrIndexTag;
begin
   if (N < 0) or (N >= TagList^.Count) then
      TagByNumber := nil
   else
      TagByNumber := TagList^.At(N);
end;

function GSobjIndexFile.TagUpdate(AKey: longint; IsAppend: boolean): boolean;
var
   p: GSptrIndexTag;
   i: integer;
begin
   NextAvail := -1;
   for i := 0 to pred(TagList^.Count) do
   begin
      p := TagList^.At(i);
      p^.KeyUpdate(AKey,IsAppend);
   end;
   TagUpdate := true;
end;

function GSobjIndexFile.ExternalChange: boolean;   {!!RFG 091297}
begin
   ExternalChange := false;
end;

end.


