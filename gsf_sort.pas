unit gsf_Sort;
{-----------------------------------------------------------------------------
                              Sort Routine

       gsf_Sort Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit contains the object to sort any number of key values

   Changes:
      !!RFG 081897  Fixed error in sorting unique indexes where the key was
                    blank.
------------------------------------------------------------------------------}
{$I gsf_FLAG.PAS}
interface
uses
   Strings,
   gsf_Glbl,
   vString,
   gsf_Xlat;

{private}

type
   GSsetSortUse = (ActiveList, EndOfKey, EndOfWord, StackOfChar);

   GSptrSortRec = ^GSrecSortRec;
   GSrecSortRec = packed record
         Case byte of
            0 : (Character : char;
                 NUse      : GSsetSortUse;
                 WordArray : word;
                 Fill02    : word;
                 LevelLink : word;);
            1 : (Fill03    : array[0..3] of byte;
                 ChrStack  : array[0..3] of char;);
            2 : (Fill04    : longint;
                 ChrFill   : longint;);
   end;

   GSptrSortArray = ^GSarySortArray;
   GSarySortArray = array[0..4095] of GSrecSortRec;

   GSptrSort = ^GSobjSort;

   GSptrSortPage = ^GSobjSortPage;
   GSobjSortPage = object(GSobjBaseObject)
      Buffer: GSptrByteArray;
      CurBlock: longint;
      LmtBlock: longint;
      PageOwner: GSptrSort;
      PrvPage: GSptrSortPage;
      NxtPage: GSptrSortPage;
      TagPage: longint;
      PChPage: PChar;
      PChSize: integer;
      WordPos: integer;

      constructor Create(AOwner: GSptrSort; ABlock: longint);
      destructor  Destroy; virtual;
      procedure   MatchWord(var P: GSptrSortPage);
      procedure   NextWord;
   end;

   GSobjSort = Object(GSobjBaseObject)
      SortChunk: word;
      ChunkLimit: word;
      NodeLimit: word;
      NodeShift: word;
      NodeMask: word;
      ChunkList : GSptrPointerArray;
      RootLink: longint;
      ChunkCur: word;
      NodeCur: word;
      ChunkSize: word;
      SortBuffer: GSptrByteArray;
      SortBufPos: integer;
      WPch: array[0..255] of char;
      WPos: integer;
      WCur: integer;
      WAdr: GSptrSortRec;
      WorkFileName: array[0..259] of char;
      WorkFile: file;
      WithFile: boolean;
      FilePos: longint;
      FirstPage: GSptrSortPage;
      LevelPtr: longint;
      PriorPtr: longint;
      WordCount: longint;
      KeySize: integer;
      Unique: Boolean;
      Ascend: Boolean;
      procedure GetNode(Character: char; var NewLink: longint);
      function  LinkGet(Value: longint): GSptrSortRec;
      procedure LinkNew(var NewLink: longint);
      procedure GetNewChunk;
      procedure RecurseDict(WPtr, WBgn: word);
      procedure PushKey(Cnt: longint; Value: PChar);
      function  FlushChunks: GSptrSortArray;

      constructor  Create(Uniq, Ascnd: Boolean; SortDir: PChar);
      destructor   Destroy; virtual;
      function     DisplayWord: boolean;
      procedure    InsertWord(Tag: Longint; Value: PChar);
      procedure    OutputWord(Tag: Longint; Value: PChar); virtual;
      procedure    SendWord(Value: PChar);
      procedure    SetWorkPath(WP: PChar);
   end;


implementation

const
   SortChunkLimit = 16384;
   WorkBlockSize = 1024;

function GenHexString(HV: longint; PC: PChar): PChar;
var
   s: array[0..12] of char;
   h: longint;
   i: integer;
begin
   FillChar(s,13,#0);
   for i := 7 downto 0 do
   begin
      h := HV shr (i * 4);
      h := h and $0000000F;
      if h > 9 then
         s[7-i] := chr(65 + (h-10))
      else
         s[7-i] := chr(48 + h);
   end;
   StrCat(s,'.CPL');
   StrCopy(PC,s);
   GenHexString := PC;
end;

constructor GSobjSortPage.Create(AOwner: GSptrSort; ABlock: longint);
begin
   PageOwner := AOwner;
   GetMem(pointer(Buffer), WorkBlockSize);
   CurBlock := ABlock;
   System.Seek(PageOwner^.WorkFile, CurBlock);
   BlockRead(PageOwner^.WorkFile, Buffer^, WorkBlockSize);
   Move(Buffer^, LmtBlock, SizeOf(longint));
   if LmtBlock > 0 then
   begin
      NxtPage := New(GSptrSortPage, Create(AOwner, LmtBlock));
      NxtPage^.PrvPage := @Self;
   end
   else
   begin
      NxtPage := nil;
      LmtBlock := System.FileSize(PageOwner^.WorkFile);
   end;
   PChSize := AOwner^.KeySize + 32;
   GetMem(PChPage,PChSize);
   StrCopy(PChPage,'');
   WordPos := 4;
   NextWord;
end;

destructor GSobjSortPage.Destroy;
begin
   FreeMem(PChPage,PChSize);
   FreeMem(pointer(Buffer), WorkBlockSize);
   if NxtPage <> nil then
      NxtPage^.Free;
   inherited Destroy;
end;

procedure GSobjSortPage.MatchWord(var P: GSptrSortPage);
var
   dv: integer;
   dr: integer;
begin
   if TagPage <> 0 then
   begin
     if P = nil then
        P := @Self
     else
     begin
        dr := CmprOEMPChar(PChPage,P^.PChPage, pCompareTbl, dv);
        if (not PageOwner^.Ascend) then dr := -dr;
        if dr < 0 then
           P := @Self;
      end;
   end;
   if NxtPage <> nil then
      NxtPage^.MatchWord(P);
end;

procedure GSobjSortPage.NextWord;
var
   lb: byte;
   ChrLead: integer;
begin
   Move(Buffer^[WordPos], TagPage, SizeOf(longint));
   if TagPage = 0 then
   begin
      CurBlock := CurBlock + WorkBlockSize;
      if CurBlock < LmtBlock then
      begin
         System.Seek(PageOwner^.WorkFile, CurBlock);
         BlockRead(PageOwner^.WorkFile, Buffer^, WorkBlockSize);
         WordPos := 4;
         Move(Buffer^[WordPos], TagPage, SizeOf(longint));
      end;
   end;
   if TagPage <> 0 then
   begin
      lb := Buffer^[WordPos];
      ChrLead := lb;
      inc(WordPos);
      lb := Buffer^[WordPos];
      inc(WordPos);
      Move(Buffer^[WordPos], PChPage[ChrLead], lb);
      PChPage[ChrLead + lb] := #0;
      WordPos := WordPos + lb;
   end;
end;


constructor GSobjSort.Create(Uniq, Ascnd: Boolean; SortDir: PChar);
var
   P: GSptrSortArray;
begin
   WordCount := 0;
   ChunkList := nil;
   SortBuffer := nil;
   SortChunk := SortChunkLimit;
   NodeLimit := SortChunk div SizeOf(GSrecSortRec);
   NodeMask := 1;
   NodeShift := 1;
   ChunkLimit := $8000;
   while NodeMask < pred(NodeLimit) do
   begin
      NodeMask := (NodeMask shl 1) + 1;
      ChunkLimit := ChunkLimit shr 1;
      inc(NodeShift);
   end;
{   ChunkLimit := 4;}
   ChunkSize := ChunkLimit;
   GetMem(pointer(ChunkList),ChunkSize*SizeOf(Pointer));
   FillChar(ChunkList^,ChunkSize*SizeOf(Pointer),#0);
   GetMem(pointer(P),SortChunk);
   FillChar(P^,SortChunk,#0);
   ChunkList^[0] := P;
   ChunkCur := 0;
   NodeCur := 1;
   LinkNew(RootLink);
   SortBuffer := nil;
   WithFile := false;
   if SortDir <> nil then
      SetWorkPath(SortDir)
   else
      WorkFileName[0] := #0;
   KeySize := 0;
   Unique := Uniq;
   Ascend := Ascnd;
end;

destructor GSobjSort.Destroy;
var
   i: integer;
begin
   If SortBuffer <> nil then
      FreeMem(pointer(SortBuffer),WorkBlockSize);
   SortBuffer := nil;
   if ChunkList <> nil then
   begin
      for i := 0 to pred(ChunkLimit) do
      begin
         if ChunkList^[i] <> nil then
            FreeMem(ChunkList^[i],SortChunk);
         ChunkList^[i] := nil;
      end;
      FreeMem(pointer(ChunkList),ChunkSize*SizeOf(Pointer));
      ChunkList := nil;
   end;
   if WithFile then
   begin
      system.Close(WorkFile);
      system.Erase(WorkFile);
   end;
   inherited Destroy;
end;

procedure GSobjSort.SetWorkPath(WP: PChar);
var
   sl: integer;
begin
   if not WithFile then
   begin
      StrCopy(WorkFileName,WP);
      sl := StrLen(WorkFileName);
      if sl > 0 then
         if WorkFileName[pred(sl)] <> '\' then
         begin
            WorkFileName[sl]:= '\';
            WorkFileName[succ(sl)] := #0;
         end;
   end;
end;

function GSobjSort.FlushChunks: GSptrSortArray;
var
   P: GSptrSortArray;
   i: integer;
   FPos: longint;
   PC: array[0..15] of char;
begin
   if not WithFile then
   begin
      GetMem(pointer(SortBuffer),WorkBlockSize);
      StrCat(WorkFileName,GenHexString(longint(SortBuffer),PC));
      system.Assign(WorkFile,WorkFileName);
      system.Rewrite(WorkFile,1);
      WithFile := true;
   end;
   FilePos := system.FileSize(WorkFile);
   System.Seek(WorkFile,FilePos);
   WPch[0] := #0;
   FillChar(SortBuffer^,WorkBlockSize,#0);
   SortBufPos := 4;
   RecurseDict(RootLink,0);
   if SortBufPos > 4 then
   begin
      BlockWrite(WorkFile,SortBuffer^,WorkBlockSize);
      FillChar(SortBuffer^,WorkBlockSize,#0);
      SortBufPos := 4;
   end;
   System.Seek(WorkFile,FilePos);
   FPos := system.FileSize(WorkFile);
   BlockWrite(WorkFile,FPos,4);
   P := ChunkList^[0];
   ChunkList^[0] := nil;
   for i := 1 to pred(ChunkLimit) do
   begin
      if ChunkList^[i] <> nil then
         FreeMem(ChunkList^[i],SortChunk);
      ChunkList^[i] := nil;
   end;
   FillChar(P^,SortChunk,#0);
   ChunkList^[0] := P;
   ChunkCur := 0;
   NodeCur := 1;
   LinkNew(RootLink);
   FlushChunks := P;
end;

procedure GSobjSort.GetNewChunk;
var
   P: GSptrSortArray;
begin
   inc(ChunkCur);
   if ChunkCur = ChunkLimit then
   begin
      FlushChunks;
   end
   else
   begin
      P := ChunkList^[ChunkCur];
      if P = nil then
      begin
         if (MaxAvail > SortChunk*2) then
         begin
           GetMem(P,SortChunk);
         end
         else
         begin
           P := FlushChunks;
         end;
      end;
      if ChunkCur <> 0 then
      begin
         FillChar(P^,SortChunk,#0);
         ChunkList^[ChunkCur] := P;
         NodeCur := 0;
      end;
   end;
end;

function GSobjSort.LinkGet(Value: longint): GSptrSortRec;
var
   P: GSptrSortArray;
begin
   if Value > 0 then
   begin
      P := ChunkList^[Value shr NodeShift];
      if P <> nil then
      LinkGet := Addr(P^[Value and NodeMask])
      else
        LinkGet := nil;
   end
   else
      LinkGet := nil;
end;

procedure GSobjSort.LinkNew(var NewLink: longint);
begin
   if NodeCur >= NodeLimit then GetNewChunk;
   NewLink := (ChunkCur shl NodeShift) + NodeCur;
   inc(NodeCur);
end;

procedure GSobjSort.GetNode(Character: char; var NewLink: longint);
var
   p: longint;
   q: longint;
   r: longint;
   df: integer;
   px: GSptrSortRec;
   qx: GSptrSortRec;
   rx: GSptrSortRec;
   c: char;

   procedure ExpandStack;
   begin
      LinkNew(r);
      c := px^.Character;
      qx := LinkGet(q);
      qx^.WordArray := r;
      rx := LinkGet(r);
      rx^.Character := c;
      rx^.WordArray := p;
      px := LinkGet(p);
      px^.Character := px^.ChrStack[0];
      Move(px^.ChrStack[1],px^.ChrStack[0],3);
      px^.ChrStack[3] := #0;
      if px^.ChrFill <> 0 then
         px^.NUse := StackOfChar
      else
         px^.NUse := ActiveList;
      p := r;
      px := LinkGet(p);
   end;


begin
   if LevelPtr = 0 then
   begin
      LinkNew(NewLink);
      px := LinkGet(NewLink);
      px^.Character := Character;
   end
   else
   begin
      p := levelptr;
      px := LinkGet(levelptr);
      q := priorptr;
      if (px^.NUse = StackOfChar) then
         ExpandStack;
      df := CmprOEMChar(Character, px^.Character,pCtyStandard);
      if (not Ascend) and
         (Character > #0) and (px^.Character > #0) then df := -df;
      while (px^.LevelLink <> 0) and
            (df > 0) do
      begin
         q := p;
         p := px^.LevelLink;
         px := LinkGet(p);
         if (px^.NUse = StackOfChar) then
            ExpandStack;
         df := CmprOEMChar(Character, px^.Character,pCtyStandard);
         if (not Ascend) and
            (Character > #0) and (px^.Character > #0) then df := -df;
      end;
      if (df = 0) then
      begin
         NewLink := p;
      end
      else
      begin
         LinkNew(r);
         if df = -1 then
         begin
            qx := LinkGet(q);
            if q = priorptr then
               qx^.WordArray := r
            else
               qx^.LevelLink := r;
            rx := LinkGet(r);
            rx^.LevelLink := p;
         end
         else
         begin
            p := px^.LevelLink;
            px^.LevelLink := r;
            rx := LinkGet(r);
            rx^.LevelLink := p;
         end;
         rx^.Character := Character;
         NewLink :=r;
      end; {if}
   end; { if }
end;

procedure GSobjSort.InsertWord(Tag: Longint; Value: PChar);
var
   p1: longint;
   wx: GSptrSortRec;
   x: GSptrSortRec;
   v: integer;
   cc: integer;
   nc: integer;
   s: string[31];
   EOK: integer;

   procedure StuffKey;
   begin
      getnode(WPch[WCur],p1);
      wx := LinkGet(p1);
      inc(WCur);
      if LevelPtr = 0 then
      begin
         if PriorPtr > 0 then
         begin
            x := LinkGet(PriorPtr);
            x^.WordArray := p1;
         end;
         v := pred(StrLen(WPch) - WCur);
         if v > 0 then
         begin
            if v > 4 then v := 4;
            Move(WPch[WCur],wx^.ChrStack[0],v);
            wx^.NUse := StackOfChar;
            WCur := WCur + v;
         end;
      end;
      PriorPtr := p1;
      LevelPtr := wx^.WordArray;
   end;

begin
   Str(Tag, s);
   if (NodeLimit-NodeCur) < (StrLen(Value) + succ(length(s))) then
   begin
      cc := ChunkCur;
      nc := NodeCur;
      GetNewChunk;
      if ChunkCur > 0 then
      begin
         ChunkCur := cc;
         NodeCur := nc;
      end;
   end;
   inc(WordCount);
   StrCopy(WPch,Value);
   v := (StrLen(WPch));
   if v > 0 then
   begin
      if v > KeySize then
         KeySize := v;
      dec(v);
   end;
   while (v >= 0) and (WPch[v] = #32) do
   begin
      WPch[v] := #0;
      dec(v);
   end;
   inc(v);
   EOK := v;
   if not Unique then
   begin
      move(s,WPch[v], succ(length(s)));
      v := v + succ(length(s));
      WPch[v] := #0;
   end;
   LevelPtr := RootLink;
   PriorPtr := 0;
   WCur := 0;
   repeat
      StuffKey;
   until WPch[WCur] = #0;
   if Unique then
   begin
      if wx^.NUse = EndOfKey then exit;
      wx^.NUse := EndOfKey;
      if EOK = 0 then inc(EOK);          {!!RFG 081897}
      move(s,WPch[EOK], succ(length(s)));
      v := EOK + succ(length(s));
      WPch[v] := #0;
      repeat
         StuffKey;
      until WPch[WCur] = #0;
   end;
   wx^.NUse := EndOfWord;
end;

procedure GSobjSort.PushKey(Cnt: longint; Value: PChar);
var
   lc: byte;
   sc: byte;
begin
   lc := Cnt;
   sc := StrLen(Value) - lc;
   if (SortBufPos + sc + 2) > (WorkBlockSize-5) then
   begin
      BlockWrite(WorkFile,SortBuffer^,WorkBlockSize);
      FillChar(SortBuffer^,WorkBlockSize,#0);
      SortBufPos := 4;
   end;
   Move(lc,SortBuffer^[SortBufPos],1);
   Move(sc,SortBuffer^[SortBufPos+1],1);
   Move(Value[lc],SortBuffer^[SortBufPos+2],sc);
   SortBufPos := SortBufPos + sc + 2;
end;

procedure GSobjSort.RecurseDict(WPtr, WBgn: word);
var
   WCnt: word;
begin
   if WPtr = 0 then exit;
   WCnt := StrLen(WPch);
   WAdr := LinkGet(WPtr);
   if WAdr^.Character <> #0 then
   begin
      WPch[WCnt] := WAdr^.Character;
      WPch[succ(WCnt)] := #0;
   end;
   if WAdr^.NUse = StackOfChar then
   begin
       Move(WAdr^.ChrStack,WPch[StrLen(WPch)],4);
       WPch[WCnt+5] := #0;
   end;
   if WAdr^.NUse = EndOfWord then
   begin
      if WithFile then
         PushKey(WBgn,WPch)
      else
         SendWord(WPch)
   end
   else
   begin
      if WAdr^.WordArray <> 0 then
         RecurseDict(WAdr^.WordArray, WBgn);
      WAdr := LinkGet(WPtr);
   end;
   WPch[WCnt] := #0;
   if (WAdr^.LevelLink <> 0) and (WAdr^.NUse <> StackOfChar) then
      RecurseDict(WAdr^.LevelLink,WCnt);
end;

procedure GSobjSort.OutputWord(Tag: Longint; Value: PChar);
begin
end;

procedure GSobjSort.SendWord(Value: PChar);
var
   Tag: longint;
   pce: PChar;
   v: integer;
   s: string[31];
begin
   s := '';
   pce := StrEnd(Value) - 1;
   while pce[0] > #31 do
   begin
      s := pce[0] + s;
      dec(pce);
   end;
   Val(s,Tag,v);
   pce[0] := #0;
   OutPutWord(Tag, Value);
   pce[0] := chr(length(s));
end;

function GSobjSort.DisplayWord: boolean;
var
   FPos: longint;
   PP: GSptrSortPage;
   i: integer;
begin
   if WithFile then
   begin
      FlushChunks;
      if ChunkList <> nil then
      begin
         for i := 0 to pred(ChunkLimit) do
         begin
            if ChunkList^[i] <> nil then
               FreeMem(ChunkList^[i],SortChunk);
            ChunkList^[i] := nil;
         end;
         FreeMem(pointer(ChunkList),ChunkSize*SizeOf(Pointer));
         ChunkList := nil;
      end;
      System.Seek(WorkFile,FilePos);
      FPos := 0;
      BlockWrite(WorkFile,FPos,4);
      FirstPage := New(GSptrSortPage, Create(@Self, 0));
      PP := FirstPage;
      repeat
         PP := nil;
         FirstPage^.MatchWord(PP);
         if PP <> nil then
         begin
            SendWord(PP^.PChPage);
            PP^.NextWord;
         end;
      until PP = nil;
      FirstPage^.Free;
   end
   else
   begin
      StrCopy(WPch,'');
      RecurseDict(RootLink,0);
   end;
   DisplayWord := true;
end;

end.

