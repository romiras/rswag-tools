unit gsF_CDX;
{-----------------------------------------------------------------------------
                          Basic Index File Routine

       gsF_CDX Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          18 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit contains the objects to manage dBase CDX index
       files.

   Changes:

      !!RFG 083097 In DoIndex, within the routine for memory indexing, added
                   code to set flag gsvIndexState in the DBF object to reduce
                   the record read activity when there are many records that
                   are rejected.

      !!RFG 090597 Restored variable sp in several methods. This var is needed
                   when the FOXGENERAL conditional define is on.

      !!RFG 090597 Tightened code in the SortCDX routines to pack more keys on
                   a page.  Key sizes beyond 160 bytes would cause range error
                   problems because only one would fit on an internal node.
                   CDX must handle up to 240 character keys.

      !!RFG 091197 Added testing for corrupted indexes.

      !!RFG 091297 Added ExternalChange to test if the index has been
                   changed by another program.

      !!RFG 091397 Added test to recreate the index if filesize was less than
                   or equal to CDXBlokSize.  This allows the file to be
                   recreated by truncation to 0 bytes and using IndexOn in
                   a shared environment.

      !!RFG 100797 Corrected error in calculating MaxKeys that could cause
                   a Range Error on certain key lengths.

      !!RFG 012298 Corrected problem where index files greater than 16MB can
                   cause a Range Error.
------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}
interface
uses
   Strings,
   gsF_DBF,
   gsF_DOS,
   gsF_Disk,
   gsF_Eror,
   gsF_Expr,
   gsF_Glbl,
   gsF_Indx,
   gsF_Sort,
   vString,
   gsF_Xlat;

{private}

const
   CDXBlokSize = 512;
   CDXSigDefault = $01;
   CDXSigGeneral = $02;

{public}

{$IFDEF FOXGENERAL}

   {Code Page - 1252 (WINDOWS ANSI)}
   {COLLATE=GENERAL}
   GSaryCDXCollateTable : Array[0..255] of Byte = (
            {00  01  02  03  04  05  06  07  08  09  0A  0B  0C  0D  0E  0F}
      {00}  $10,$10,$10,$10,$10,$10,$10,$10,$10,$11,$10,$10,$10,$10,$10,$10,
      {01}  $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,
      {02}  $11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$20,
      {03}  $56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F,$21,$22,$23,$24,$25,$26,
      {04}  $27,$60,$61,$62,$64,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6F,$70,$72,
      {05}  $73,$74,$75,$76,$77,$78,$7A,$7B,$7C,$7D,$7E,$28,$29,$2A,$2B,$2C,
      {06}  $2D,$60,$61,$62,$64,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6F,$70,$72,
      {07}  $73,$74,$75,$76,$77,$78,$7A,$7B,$7C,$7D,$7E,$2E,$2F,$30,$31,$10,
      {08}  $10,$10,$18,$32,$13,$33,$34,$35,$36,$37,$76,$18,$00,$10,$10,$10,
      {09}  $10,$18,$18,$13,$13,$38,$1E,$1E,$39,$3A,$76,$18,$00,$10,$10,$7D,
      {0A}  $20,$3B,$3C,$3D,$3E,$3F,$40,$41,$42,$43,$44,$13,$45,$1E,$46,$47,
      {0B}  $48,$49,$58,$59,$4A,$4B,$4C,$4D,$4E,$57,$4F,$13,$50,$51,$52,$53,
      {0C}  $60,$60,$60,$60,$60,$60,$06,$62,$66,$66,$66,$66,$6A,$6A,$6A,$6A,
      {0D}  $65,$70,$72,$72,$72,$72,$72,$54,$81,$78,$78,$78,$78,$7D,$12,$0C,
      {0E}  $60,$60,$60,$60,$60,$60,$06,$62,$66,$66,$66,$66,$6A,$6A,$6A,$6A,
      {0F}  $65,$70,$72,$72,$72,$72,$72,$55,$81,$78,$78,$78,$78,$7D,$12,$7D);

   GSaryCDXCollateMask : Array[0..255] of Byte = (
            {00  01  02  03  04  05  06  07  08  09  0A  0B  0C  0D  0E  0F}
      {00}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
      {01}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
      {02}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
      {03}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
      {04}  $00,$20,$00,$20,$00,$20,$00,$00,$00,$20,$00,$00,$00,$00,$20,$20,
      {05}  $00,$00,$00,$20,$00,$20,$00,$00,$00,$20,$00,$00,$00,$00,$00,$00,
      {06}  $00,$20,$00,$20,$00,$20,$00,$00,$00,$20,$00,$00,$00,$00,$20,$20,
      {07}  $00,$00,$00,$20,$00,$20,$00,$00,$00,$20,$00,$00,$00,$00,$00,$00,
      {08}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$28,$00,$80,$00,$00,$00,
      {09}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$28,$00,$80,$00,$00,$24,
      {0A}  $21,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
      {0B}  $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,
      {0C}  $22,$21,$23,$25,$24,$26,$80,$27,$22,$21,$23,$24,$22,$21,$23,$24,
      {0D}  $00,$25,$22,$21,$23,$25,$24,$00,$00,$22,$21,$23,$24,$21,$80,$80,
      {0E}  $22,$21,$23,$25,$24,$26,$80,$27,$22,$21,$23,$24,$22,$21,$23,$24,
      {0F}  $00,$25,$22,$21,$23,$25,$24,$00,$00,$22,$21,$23,$24,$21,$80,$24);

   GSaryCDXCollateLigature : Array[0..31] of Byte = (
            {00  01  02  03  04  05  06  07  08  09  0A  0B  0C  0D  0E  0F}
      {00}  $00,$02,$72,$20,$66,$20,$00,$02,$60,$20,$66,$20,$00,$02,$76,$20,
      {01}  $76,$20,$00,$02,$77,$00,$69,$00,$00,$00,$00,$00,$00,$00,$00,$00);

{$ENDIF}

{private}

type

   GSsetCDXCollateType = (NoCollate, Machine, General);

   GSptrCDXHeader  = ^GSrecCDXHeader;
   GSrecCDXHeader  = packed Record
      Root       : LongInt;                {byte offset to root node}
      FreePtr    : LongInt;                {byte offset to next free block}
      ChgFlag    : Longint;                {Increments on modification}
      Key_Lgth   : Word;                   {length of key}
      IndexOpts  : Byte;
                         {bit field :   1 = unique
                                        8 = FOR clause
                                       32 = compact index
                                       64 = compound index}
      IndexSig   : Byte;
      Reserve3   : array [0..477] of Byte;
      Col8Kind   : array[0..7] of Char;
      AscDesc    : Word;     {0 = ascending; 1=descending}
      Reserve4   : Word;
      ForExpLen  : Word;     {length of FOR clause}
      Reserve5   : Word;
      KeyExpLen  : Word;     {length of index expression}
      KeyPool    : array[0..pred(CDXBlokSize)] of char;
   end;

   GSptrCDXDataBlk  = ^GSrecCDXDataBlk;
   GSrecCDXDataBlk  = packed Record
      Node_Atr     : word;
      Entry_Ct     : word;
      Left_Ptr     : longint;
      Rght_Ptr     : Longint;
         case byte of
            0   :  (
                    FreeSpace  : Word;    {free space in this key}
                    RecNumMask : LongInt; {bit mask for record number}
                    DupCntMask : Byte;    {bit mask for duplicate byte count}
                    TrlCntMask : Byte;    {bit mask for trailing bytes count}
                    RecNumBits : Byte;    {num bits used for record number}
                    DupCntBits : Byte;    {num bits used for duplicate count}
                    TrlCntBits : Byte;    {num bits used for trail count}
                    ShortBytes : Byte;    {bytes needed for recno+dups+trail}
                    ExtData    : array [0..CDXBlokSize - 25] of Char;
                   );
            1    : (IntData  : array [0..CDXBlokSize - 13] of Char;)
   end;

   GSptrCDXElement = ^GSrecCDXElement;
   GSrecCDXElement = packed Record
      Block_Ax  : Longint;
      Recrd_Ax  : Longint;
      Char_Fld  : array [0..255] of char;
   end;

   GSptrCDXTag = ^GSobjCDXTag;
   GSobjCDXTag = object(GSobjIndexTag)
      OptFlags    : byte;
      CollateType : GSsetCDXCollateType;
      ChgIndicator: longint;
      constructor Create(PIF: GSptrIndexFile; ITN: PChar; TagHdr: longint);
      destructor  Destroy; virtual;
      procedure   AdjustValue(AKey: GSptrIndexKeyData); virtual;
      function    IndexTagNew(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                           boolean; virtual;
      function    KeyAdd(st: GSptrIndexKeyData): boolean; virtual;
      function    PageLoad(PN: longint; PIK: GSptrIndexKey): Boolean; virtual;
      function    PageStore(PN: longint; PIK: GSptrIndexKey): Boolean; virtual;
      function    TagLoad: Boolean; virtual;
      function    TagStore: Boolean; virtual;
      function    NewRoot: longint; virtual;
      procedure   DoIndex;

      procedure   ExtNodeBuild(DataBuf: GSptrCDXDataBlk; PIK: GSptrIndexKey);
      procedure   ExtNodeWrite(PN: longint; DataBuf: GSptrCDXDataBlk;
                               PIK: GSptrIndexKey);
      procedure   IntNodeBuild(DataBuf: GSptrCDXDataBlk; PIK: GSptrIndexKey);
      procedure   IntNodeWrite(PN: longint; DataBuf: GSptrCDXDataBlk;
                               PIK: GSptrIndexKey);
   end;


   GSptrCDXFile = ^GSobjCDXFile;
   GSobjCDXFile = object(GSobjIndexFile)
      CDXOpening  : boolean;
      CompoundTag : GSptrCDXTag;
      constructor Create(PDB: GSP_dBaseFld; const FN: string; FM: word);
      destructor  Destroy; virtual;
      function    AddTag(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                         boolean; virtual;
      function    DeleteTag(ITN: PChar): boolean; virtual;
      function    GetAvailPage: longint; virtual;
      function    ResetAvailPage: longint; virtual;
      function    PageRead(Blok: longint; var Page; Size: integer):
                           boolean; virtual;
      function    PageWrite(Blok: longint; var Page; Size: integer):
                            boolean; virtual;
      procedure   Reindex; virtual;
      function    TagUpdate(AKey: longint; IsAppend: boolean): boolean; virtual;
      function    ExternalChange: boolean; virtual;          {!!RFG 091297}
   end;

var
   GSbytCDXCollateInfo : GSsetCDXCollateType;

implementation

const
   ExtSpace = CDXBlokSize-24;

type

   GSptrSortCDX = ^GSobjSortCDX;
   GSobjSortCDX = object(GSobjSort)
      curFile: GSP_dBaseFld;
      curTag: GSptrCDXTag;
      KeyWork: GSptrIndexKeyData;
      KeyCnt: longint;
      KeyTot: longint;
      LastKey: GSptrIndexKeyData;
      LastTag: longint;
      Closing: boolean;
      NodeList: array[0..31] of GSptrCDXDataBlk;

      constructor  Create(ATag: GSptrCDXTag; Uniq, Ascnd: Boolean; WorkDir: PChar);
      destructor   Destroy; virtual;
      procedure    AddToNode(Lvl: integer; Tag, Link: Longint;
                             Value: GSptrIndexKeyData);
      procedure    OutputWord(Tag: longint; Value: PChar); virtual;
   end;

{------------------------------------------------------------------------------
                    Conversion/Comparison of Number Fields
------------------------------------------------------------------------------}

function FlipLongint(LVal: longint): longint;
var
   LValAry : array[0..3] of byte absolute LVal;
   NVal    : longint;
   NValAry : array[0..3] of byte absolute NVal;
begin
   NValAry[0] := LValAry[3];
   NValAry[1] := LValAry[2];
   NValAry[2] := LValAry[1];
   NValAry[3] := LValAry[0];
   FlipLongint := NVal;
end;

function FindDupLength(s1, s2: GSptrIndexKeyData): word;
var
   i : integer;
begin
   i := 0;
   if (s1^.SizeStr > 0) and (s2^.SizeStr > 0) then
      while (i < s2^.SizeStr) and
            (s1^.CharStr^[i] = s2^.CharStr^[i]) do inc(i);
   FindDupLength := i;
end;

function MakeMask(bc: byte):longint;
var
   i: integer;
   m: longint;
begin
   m := 0;
   for i := 1 to bc do m := (m shl 1) + 1;
   MakeMask := m;
end;

{-----------------------------------------------------------------------------
                                 GSobjSortCDX
-----------------------------------------------------------------------------}

constructor GSobjSortCDX.Create(ATag: GSptrCDXTag; Uniq, Ascnd: boolean; WorkDir: PChar);
begin
   inherited Create(Uniq, true, WorkDir);  {always an ascending sort}
   CurTag := ATag;
   CurFile := ATag^.Owner^.Owner;
   KeyTot := CurFile^.NumRecs;
   KeyCnt := 0;
   Closing := false;
   KeyWork := New(GSptrIndexKeyData, Create(256));
   LastKey := New(GSptrIndexKeyData, Create(256));
   LastTag := 0;
   FillChar(NodeList, SizeOf(NodeList), #0);
end;

destructor GSobjSortCDX.Destroy;
var
   i: integer;
   pa: longint;
begin
   Closing := true;
   for i := 0 to 30 do
      if NodeList[i] <> nil then
      begin
         pa := NodeList[i]^.Rght_Ptr;
         NodeList[i]^.Rght_Ptr := -1;
         if NodeList[i]^.Entry_Ct > 0 then
         begin
            if NodeList[i+1]  = nil then
            begin
               CurTag^.RootBlock := pa;
               inc(NodeList[i]^.Node_Atr);
            end;
            CurTag^.Owner^.PageWrite(pa, NodeList[i]^, CDXBlokSize);
            if NodeList[i+1] <> nil then
               AddToNode(i+1, pa, LastTag, KeyWork);
         end;
         FreeMem(NodeList[i],CDXBlokSize);
      end;
   LastKey^.Free;
   KeyWork^.Free;
   inherited Destroy;
end;

procedure GSobjSortCDX.AddToNode(Lvl: integer; Tag, Link: Longint;
                                 Value: GSptrIndexKeyData);

   procedure SetMask;
   var
      i: integer;
      bitcnt: integer;
      sr: longint;
   begin
      sr := KeyTot;
      i := CurTag^.KeyLength;
      bitcnt := 0;
      repeat
         inc(bitcnt);
         i := i shr 1;
      until i = 0;
      with NodeList[0]^ do
      begin
         ShortBytes := 3;
         RecNumBits := 24 - (bitcnt*2);
         RecNumMask := MakeMask(RecNumBits);
         while sr > RecNumMask do
         begin
            inc(ShortBytes);
            inc(RecNumBits,8);
            RecNumMask := (RecNumMask shl 8) or $FF;
         end;
         FreeSpace := ExtSpace;
         DupCntBits := bitcnt;
         TrlCntBits := bitcnt;
         DupCntMask := MakeMask(DupCntBits);
         TrlCntMask := MakeMask(TrlCntBits);
      end;
   end;

   procedure AddExternal;
   var
      v: integer;
      r: longint;
      k: integer;
      pa: Longint;
      m : longint;
      c: word;
      ct: word;
      cd: word;
      sp: integer;                           {!!RFG 090597}
   begin
      if NodeList[Lvl]^.Entry_Ct = 0 then
      begin
         FillChar(NodeList[Lvl]^.ExtData,SizeOf(NodeList[Lvl]^.ExtData),#0);
         NodeList[Lvl]^.FreeSpace := ExtSpace;
         LastKey^.SizeStr := 0;
      end;
      m := not NodeList[Lvl]^.RecNumMask;

      ct := CurTag^.KeyLength - Value^.SizeStr;
      cd := FindDupLength(Value, LastKey);
      v := (NodeList[Lvl]^.Entry_Ct*NodeList[Lvl]^.ShortBytes);
      k := NodeList[Lvl]^.FreeSpace + v;

      NodeList[Lvl]^.FreeSpace := NodeList[Lvl]^.FreeSpace -
                     ((CurTag^.KeyLength+NodeList[Lvl]^.ShortBytes)-(cd+ct));
      c := (ct shl (16-NodeList[Lvl]^.TrlCntBits)) or
           (cd shl (16-(NodeList[Lvl]^.TrlCntBits+NodeList[Lvl]^.DupCntBits)));
      move(c, NodeList[Lvl]^.ExtData[(v+NodeList[Lvl]^.ShortBytes)-2], 2);
      move(NodeList[Lvl]^.ExtData[v], r, 4);
      r := r and m;
      r := r or Tag;
      move(r, NodeList[Lvl]^.ExtData[v], 4);
      k := k - CurTag^.KeyLength + cd + ct;
      if CurTag^.KeyLength-(cd+ct) > 0 then
         move(Value^.CharStr^[cd], NodeList[Lvl]^.ExtData[k], CurTag^.KeyLength -(cd+ct));
      {$IFDEF FOXGENERAL}
      if (CurTag^.CollateType = General) and (CurTag^.KeyType = 'C') then
      begin
         sp := CurTag^.KeyLength -(cd+ct) - 1;
         while (sp >= 0) and (NodeList[Lvl]^.ExtData[k+sp] >= chr($F0)) do
         begin
            NodeList[Lvl]^.ExtData[k+sp] :=
                       chr(ord(NodeList[Lvl]^.ExtData[k+sp]) and $0F);
            dec(sp);
         end;
      end;
      {$ENDIF}
      inc(NodeList[Lvl]^.Entry_Ct);
      if (NodeList[Lvl]^.FreeSpace <
         (CurTag^.EntryLength+NodeList[Lvl]^.ShortBytes)
{!!RFG 090597}    {$IFDEF FOXGENERAL}*2{$ENDIF}) then  {a little slack}
      begin
         pa := NodeList[Lvl]^.Rght_Ptr;
         if KeyCnt < KeyTot then
            NodeList[Lvl]^.Rght_Ptr := CurTag^.Owner^.GetAvailPage
         else
            NodeList[Lvl]^.Rght_Ptr := -1;
         NodeList[Lvl]^.Node_Atr := 2;
         CurTag^.Owner^.PageWrite(pa,NodeList[Lvl]^, CDXBlokSize);
         NodeList[Lvl]^.Left_Ptr := pa;
         AddToNode(Lvl+1,pa,Link,Value);
         NodeList[Lvl]^.Entry_Ct := 0;
      end;
   end;

   procedure AddInternal;
   var
      v: integer;
      r: longint;
      pa: Longint;
      sp: integer;                        {!!RFG 090597}
   begin
      if NodeList[Lvl]^.Entry_Ct = 0 then
         FillChar(NodeList[Lvl]^.IntData,SizeOf(NodeList[Lvl]^.IntData),#0);
      v := (NodeList[Lvl]^.Entry_Ct*CurTag^.EntryLength);
      if CurTag^.KeyType = 'C' then
         FillChar(NodeList[Lvl]^.IntData[v], CurTag^.KeyLength, #32);
      move(Value^.CharStr^[0], NodeList[Lvl]^.IntData[v], Value^.SizeStr);
      {$IFDEF FOXGENERAL}
      if (CurTag^.CollateType = General) and (CurTag^.KeyType = 'C') then
      begin
         sp := Value^.SizeStr - 1;
         while (sp >= 0) and (NodeList[Lvl]^.IntData[v+sp] >= chr($F0)) do
         begin
            NodeList[Lvl]^.IntData[v+sp] :=
                       chr(ord(NodeList[Lvl]^.IntData[v+sp]) and $0F);
            dec(sp);
         end;
      end;
      {$ENDIF}
      v := v+CurTag^.KeyLength;
      r := FlipLongint(Link);
      move(r, NodeList[Lvl]^.IntData[v], 4);
      v := v+4;
      r := FlipLongint(Tag);
      move(r, NodeList[Lvl]^.IntData[v], 4);
      inc(NodeList[Lvl]^.Entry_Ct);
      if (NodeList[Lvl]^.Entry_Ct  >= {pred}(CurTag^.MaxKeys)) then  {!!RFG 090597}
      begin
         pa := NodeList[Lvl]^.Rght_Ptr;
         if not Closing then
            NodeList[Lvl]^.Rght_Ptr := CurTag^.Owner^.GetAvailPage
         else
            NodeList[Lvl]^.Rght_Ptr := -1;
         NodeList[Lvl]^.Node_Atr := 0;
         CurTag^.Owner^.PageWrite(pa,NodeList[Lvl]^, CDXBlokSize);
         NodeList[Lvl]^.Left_Ptr := pa;
         AddToNode(Lvl+1,pa,Link,Value);
         NodeList[Lvl]^.Entry_Ct := 0;
      end;
   end;

begin
   if NodeList[Lvl] = nil then
   begin
      GetMem(NodeList[Lvl],CDXBlokSize);
      FillChar(NodeList[Lvl]^,CDXBlokSize,#0);
      if Lvl = 0 then SetMask;
      with NodeList[Lvl]^ do
      begin
         Left_Ptr := -1;
         Rght_Ptr := CurTag^.Owner^.GetAvailPage;
         if Lvl = 0 then
            Node_Atr := 2
         else
            Node_Atr := 0;
      end;
   end;
   if Lvl = 0 then
      AddExternal
   else
      AddInternal;
end;

procedure GSobjSortCDX.OutputWord(Tag: longint; Value: PChar);
begin
   inc(KeyCnt);
   curFile^.gsStatusUpdate(StatusIndexWr,KeyCnt,0);
   KeyWork^.ReplacePChar(Value);
   if CurTag^.KeyType <> 'C' then
      CurTag^.AdjustValue(KeyWork);
   AddToNode(0,Tag,Tag,KeyWork);
   LastTag := Tag;
   LastKey^.ReplaceBufr(KeyWork^.CharStr, KeyWork^.SizeStr);
end;

{-----------------------------------------------------------------------------
                                 GSobjCDXTag
-----------------------------------------------------------------------------}

constructor GSobjCDXTag.Create(PIF: GSptrIndexFile; ITN: PChar; TagHdr: longint);
begin
   inherited Create(PIF, ITN, TagHdr);
   DefaultLen := 10;
   TagSig := 'CDX';
   StrUpperCase(TagName, StrLen(TagName));
   if TagHdr <> -1 then
   begin
     Owner^.Corrupted := not TagLoad;             {!!RFG 091197}
     if Owner^.Corrupted then exit;               {!!RFG 091197}
   end
   else
   begin
      TagBlock := Owner^.GetAvailPage;
      Owner^.GetAvailPage;           {Need two blocks allocated for header}
      TagChanged := true;
   end;
   OptFlags := $60;
end;

destructor GSobjCDXTag.Destroy;
begin
   inherited Destroy;
end;

procedure GSobjCDXTag.AdjustValue(AKey: GSptrIndexKeyData);
var
   numwk: double;
   numar: array[0..7] of char absolute numwk;
   rsl: integer;
   v: integer;
   ps: array[0..255] of char;
   psc: longint;
   {$IFDEF FOXGENERAL}
   ps2: array[0..255] of char;
   byt: byte;
   msk: byte;
   psp: pchar;
   stw: array[0..255] of char;
   stwp: PChar;
   {$ENDIF}

begin
   AKey^.GetPChar(ps);
   psc := AKey^.SizeStr;

{$IFDEF FOXGENERAL}
   stwp := stw;
   if KeyType = 'C' then
   begin
      ps[psc] := #0;
      while (psc > 0) and (ps[pred(psc)] in [#32,#0]) do
      begin
         ps[pred(psc)] := #0;
         dec(psc);
      end;
      if (ps[0] = #0) or (CollateType < General) or
         ((OptFlags and 128) <> 0) then
      begin
         AKey^.SizeStr := psc;
         exit;
      end;
      FillChar(ps2[0],256,#0);
      psp := ps2;
      v := 0;
      repeat
         byt := GSaryCDXCollateTable[ord(ps[v])];
         msk := GSaryCDXCollateMask[ord(ps[v])];
         if (not (byt in [$00,$06,$12,$18])) or
            (GSaryCDXCollateLigature[byt+1] = 0) then
            stwp[0] := chr(byt)
         else
         begin
            stwp[0] := chr(GSaryCDXCollateLigature[byt+2]);
            stwp := stwp+1;
            stwp[0] := chr(GSaryCDXCollateLigature[byt+4]);
         end;
         stwp := stwp+1;
         if (not (msk = 0)) then
         begin
            if msk <> $80 then
            begin
               psp[0] := chr(msk or $F0);
               psp := psp+1;
            end
            else
            begin
               msk := GSaryCDXCollateLigature[byt+3];
               if msk <> $00 then
               begin
                  psp[0] := chr(msk or $F0);
                  psp := psp+1;
               end;
               msk := GSaryCDXCollateLigature[byt+5];
               if msk <> $00 then
               begin
                  psp[0] := chr(msk or $F0);
                  psp := psp+1;
               end;
            end;
         end;
         inc(v);
      until ps[v] = #0;
      stwp[0] := #0;
      psp := psp-1;
      while (psp >= ps2) and (psp[0] = chr($F0)) do psp := psp-1;
      psp := psp+1;
      psp[0] := #0;
      StrCat(stw,ps2);
      AKey^.PutPChar(stw);
      exit;
   end;
{$ELSE}
   if KeyType = 'C' then
   begin
      ps[psc] := #0;
      while (psc > 0) and (ps[pred(psc)] in [#32,#0]) do
      begin
         ps[pred(psc)] := #0;
         dec(psc);
      end;
      AKey^.SizeStr := psc;
      exit;
   end;
{$ENDIF}
                          {convert to double and flip bytes for compare}
   if ps[0] <> #0 then
   begin
      val(ps,numwk,rsl);
      if rsl <> 0 then
        numwk := 0.0;
   end
   else
      numwk := 0.0;
   if numar[7] > #127 then      {if negative number}
   begin
      for v := 0 to 7 do
         ps[7-v] := char(byte(numar[v]) xor $FF);
   end
   else
   begin
      ps[0] := char(byte(numar[7]) or $80);
      for v := 0 to 6 do
         ps[7-v] := numar[v];
   end;
   v := SizeOf(Double);
   while (v > 0) and (ps[pred(v)] = #0) do dec(v);
   AKey^.ReplaceBufr(@ps,v);
end;

procedure GSobjCDXTag.DoIndex;
var
   withFor: boolean;
   ixColl: GSptrSortCDX;
   ps: GSptrIndexKeyData;
   fchg: boolean;
   ftyp: char;

   procedure EmptyIndex;
   var
      ix: word;
      bc: word;
      CDXData: GSptrCDXDataBlk;
   begin
      GetMem(CDXData, CDXBlokSize);
      FillChar(CDXData^, CDXBlokSize, #0);
      RootBlock := Owner^.GetAvailPage;
      CDXData^.Node_Atr := 3;
      CDXData^.Left_Ptr := -1;
      CDXData^.Rght_Ptr := -1;
      ix := KeyLength;
      bc := 0;
      repeat
         inc(bc);
         ix := ix shr 1;
      until ix = 0;
      with CDXData^ do
      begin
         ShortBytes := 3;
         RecNumBits := 24 - (bc*2);
         RecNumMask := MakeMask(RecNumBits);
         FreeSpace := ExtSpace;
         DupCntBits := bc;
         TrlCntBits := bc;
         DupCntMask := MakeMask(DupCntBits);
         TrlCntMask := MakeMask(TrlCntBits);
      end;
      Owner^.PageWrite(RootBlock, CDXData^, CDXBlokSize);
      FreeMem(CDXData, CDXBlokSize);
   end;

   procedure ProcessRecord;
   begin
      StrCopy(ps^.CharStr^,'T');
      withFor := Conditional and (ForExpr <> nil);
      if withFor then
         SolveExpression(@Self, TagName, ForExpr, ps^.CharStr^, ftyp, fchg);
      withFor := ps^.CharStr^[0] = 'T';
      if withFor then
      begin
         SolveExpression(@Self, TagName, KeyExpr, ps^.CharStr^, ftyp, fchg);
         if KeyType = 'C' then AdjustValue(ps);
         ixColl^.InsertWord(Owner^.Owner^.RecNumber, ps^.CharStr^);
      end;
   end;

begin
   if ((OptFlags and 128) <> 0) then
   begin
      EmptyIndex;
   end
   else
   begin
      ps := New(GSptrIndexKeyData, Create(256));
      with Owner^.Owner^ do
      begin
         ixColl := New(GSptrSortCDX, Create(@Self, UniqueKey, AscendKey, gsvTempDir));
         gsStatusUpdate(StatusStart,StatusIndexTo,Owner^.Owner^.NumRecs);
         if Owner^.DiskFile <> nil then
         begin
            RecNumber := 1;            {Read all dBase file records}
            while RecNumber <= NumRecs do
            begin
               gsRead(HeadLen+((RecNumber-1) * RecLen), CurRecord^, RecLen);
               ProcessRecord;
               gsStatusUpdate(StatusIndexTo,RecNumber,0);
               inc(RecNumber);
            end;
         end
         else
         begin
            gsvIndexState := true;            {!!RFG 083097}
            gsGetRec(Top_Record);    {Read all dBase file records}
            while not File_EOF do
            begin
               ProcessRecord;
               gsStatusUpdate(StatusIndexTo,RecNumber,0);
               gsGetRec(Next_Record);
            end;
            gsvIndexState := false;          {!!RFG 083097}
         end;
         gsStatusUpdate(StatusStop,0,0);
      end;
      ixColl^.KeyTot := ixColl^.WordCount;
      Owner^.Owner^.gsStatusUpdate(StatusStart,StatusIndexWr,ixColl^.KeyTot);
      if ixColl^.WordCount > 0 then
         ixColl^.DisplayWord
      else
         EmptyIndex;
      Owner^.Owner^.gsStatusUpdate(StatusStop,0,0);
      ixColl^.Free;
      ps^.Free;
   end;
   TagChanged := true;
   TagStore;
end;

procedure GSobjCDXTag.ExtNodeBuild(DataBuf: GSptrCDXDataBlk; PIK: GSptrIndexKey);
var
   i : integer;
   v : integer;
   s : array[0..255] of char;
   d : byte;
   t : byte;
   r : longint;
   c : word;
   k: integer;
   p: GSptrIndexKeyData;
   sp: integer;                               {!!RFG 090597}
begin
   k := ExtSpace;
   with PIK^, DataBuf^ do
   begin
      Space := FreeSpace;
      RNMask := RecNumMask;
      DCMask := DupCntMask;
      TCMask := TrlCntMask;
      RNBits := RecNumBits;
      DCBits := DupCntBits;
      TCBits := TrlCntBits;
      ReqByte:= ShortBytes;
      FillChar(s,SizeOf(s),' ');
      i := 0;
      while i < DataBuf^.Entry_Ct do
      begin
         v := (i*ReqByte);
         move(ExtData[(v+ReqByte)-2], c, 2);
         t := (c shr (16-TCBits)) and TCMask;
         d := (c shr (16-(TCBits+DCBits))) and DCMask;
         move(ExtData[v], r, 4);
         r := r and RNMask;
         k := k - KeyLength + d + t;
         if KeyLength -(d+t) > 0 then
            move(ExtData[k],s[d], KeyLength -(d+t));
         s[KeyLength-t] := #0;
         if KeyType = 'C' then
         begin
            {$IFDEF FOXGENERAL}
            if (CollateType = General) and (KeyType = 'C') then
            begin
               sp := KeyLength - t - 1;
               while (sp > 0) and (s[sp] < #16) do
               begin
                  s[sp] := chr(ord(s[sp]) or $F0);
                  dec(sp);
               end;
            end;
            {$ENDIF}
            StrTrimR(s);
         end;
         p := New(GSptrIndexKeyData, Create(0));
         p^.Tag := r;
         p^.Xtra := r;
         p^.PutBufr(@s,KeyLength - t);
         Insert(p);
         inc(i);
      end;
   end;
end;

procedure GSobjCDXTag.ExtNodeWrite(PN: longint; DataBuf: GSptrCDXDataBlk;
                                   PIK: GSptrIndexKey);
var
   v : integer;
   r : longint;
   m : longint;
   kcnt : integer;
   c: word;
   ct: word;
   cd: word;
   p : GSptrIndexKeyData;
   q : GSptrIndexKeyData;
   k : integer;
   NPN: longint;
   na: word;
   rp: longint;
   lp: longint;
   ck: integer;
   TmpTag: longint;
   sp: integer;                       {!!RFG 090597}
   procedure SetMask;
   var
      i: integer;
      bitcnt: integer;
      sr: longint;
   begin
      if OptFlags > 128 then       {Tag List?}
         sr := Owner^.DiskFile^.gsFileSize
      else
         sr := Owner^.Owner^.NumRecs;
      i := KeyLength;
      bitcnt := 0;
      repeat
         inc(bitcnt);
         i := i shr 1;
      until i = 0;
      with PIK^ do
      begin
         ReqByte := 3;
         RNBits := 24 - (bitcnt*2);
         RNMask := MakeMask(RNBits);
         while sr > RNMask do
         begin
            inc(ReqByte);
            inc(RNBits,8);
            RNMask := (RNMask shl 8) or $FF;
            if RNMask < 0 then                   {!!RFG 012298}
            begin
               RNMask := $7FFFFFFF;
               RNBits := 31;
            end;
         end;
         Space := ExtSpace;
         DCBits := bitcnt;
         TCBits := bitcnt;
         DCMask := MakeMask(DCBits);
         TCMask := MakeMask(TCBits);
      end;
   end;

   function KeysSuggested: word;
   var
      sr : longint;
      i  : integer;
      cd : integer;
      mp : integer;
      lm : integer;
   begin
      with PIK^ do
      begin
         sr := 0;
         cd := 0;
         mp := 0;
         lm := SizeOf(DataBuf^.IntData) div 2;
         q := nil;
         for i := 0 to Count-1 do
         begin
            p := At(i);
            if q <> nil then
               cd := FindDupLength(p, q);
            q := p;
            cd := (p^.SizeStr-cd);
            sr := sr + cd + ReqByte;
            if sr < lm then inc(mp);
         end;
         if sr < ExtSpace then mp := Count;
      end;
      KeysSuggested := mp;
   end;

   procedure FillBuffer;
   var
      i: integer;
   begin
      FillChar(DataBuf^.ExtData,SizeOf(DataBuf^.ExtData),#0);
      with DataBuf^, PIK^ do
      begin
         FreeSpace := Space;
         RecNumMask := RNMask;
         DupCntMask := DCMask;
         TrlCntMask := TCMask;
         RecNumBits := RNBits;
         DupCntBits := DCBits;
         TrlCntBits := TCBits;
         ShortBytes := ReqByte;
         m := not RNMask;
         q := nil;
         Space := ExtSpace;
      end;
      i := 0;
      k := ExtSpace;
      q := nil;
      with PIK^ do
      begin
         while (i < kcnt) and (ck < PIK^.Count) do
         begin
            p := At(ck);
            ct := KeyLength - p^.SizeStr;
            if q <> nil then
               cd := FindDupLength(p, q)
            else
               cd := 0;
            q := p;
            Space := Space - ((KeyLength+ReqByte)-(cd+ct));
            v := (i*ReqByte);
            c := (ct shl (16-TCBits)) or (cd shl (16-(TCBits+DCBits)));
            move(c, DataBuf^.ExtData[(v+ReqByte)-2], 2);
            move(DataBuf^.ExtData[v], r, 4);
            r := r and m;
            r := r or p^.Tag;
            move(r, DataBuf^.ExtData[v], 4);
            k := k - KeyLength + cd + ct;
            if KeyLength-(cd+ct) > 0 then
            move(p^.CharStr^[cd], DataBuf^.ExtData[k], KeyLength -(cd+ct));
            {$IFDEF FOXGENERAL}
            if (CollateType = General) and (KeyType = 'C') then
            begin
               sp := KeyLength - (cd+ct) - 1;
               while (sp >= 0) and (DataBuf^.ExtData[k+sp] >= chr($F0)) do
               begin
                  DataBuf^.ExtData[k+sp] :=
                     chr(ord(DataBuf^.ExtData[k+sp]) and $0F);
                  dec(sp);
               end;
            end;
            {$ENDIF}
            inc(i);
            inc(ck);
            inc(DataBuf^.Entry_Ct);
         end;
      end;
   end;

begin
   SetMask;
   kcnt := KeysSuggested;
   ck := 0;
      DataBuf^.Entry_Ct := 0;
      if kcnt < PIK^.Count then
      begin
         FillBuffer;
         if odd(DataBuf^.Node_Atr) then dec(DataBuf^.Node_Atr);
         na := DataBuf^.Node_Atr;
         rp := DataBuf^.Rght_Ptr;
         lp := DataBuf^.Left_Ptr;
         DataBuf^.Rght_Ptr := PN;
         DataBuf^.FreeSpace := PIK^.Space;
         NPN := Owner^.GetAvailPage;
         TmpTag := p^.Tag;
         p^.Tag := NPN;
         PIK^.AddNodeKey(p);
         p^.Tag := TmpTag;
         if PIK^.PageType = Root then PIK^.PageType := Node;
         Owner^.PageWrite(NPN, DataBuf^, CDXBlokSize);
         if lp > 0 then
         begin
            Owner^.PageRead(lp, DataBuf^, CDXBlokSize);
            DataBuf^.Rght_Ptr := NPN;
            Owner^.PageWrite(lp, DataBuf^, CDXBlokSize);
         end;
         FillChar(DataBuf^, CDXBlokSize, #0);
         DataBuf^.Node_Atr := na;
         DataBuf^.Left_Ptr := NPN;
         DataBuf^.Rght_Ptr := rp;
         DataBuf^.Entry_Ct := 0;
         kcnt := PIK^.Count;
      end;
      FillBuffer;
      DataBuf^.FreeSpace := PIK^.Space;
   Owner^.PageWrite(PN, DataBuf^, CDXBlokSize);
end;



procedure GSobjCDXTag.IntNodeBuild(DataBuf: GSptrCDXDataBlk; PIK: GSptrIndexKey);
var
   i : integer;
   v : integer;
   s : array[0..255] of char;
   n : longint;
   r : longint;
   p: GSptrIndexKeyData;
   sp: integer;                            {!!RFG 090597}
begin
   i := 0;
   while i < DataBuf^.Entry_Ct do
   begin
      v := (i*EntryLength);
      move(DataBuf^.IntData[v], s[0], KeyLength);
      s[KeyLength] := #0;
      {$IFDEF FOXGENERAL}
      if (CollateType = General) and (KeyType = 'C') then
      begin
         sp := KeyLength - 1;
         while (sp > 0) and (s[sp] < #16) do
         begin
            s[sp] := chr(ord(s[sp]) or $F0);
            dec(sp);
         end;
      end;
      {$ENDIF}
      v := v+KeyLength;
      move(DataBuf^.IntData[v], r, 4);
      r := FlipLongint(r);
      v := v+4;
      move(DataBuf^.IntData[v], n, 4);
      n := FlipLongint(n);
      if KeyType = 'C' then
      begin
         StrTrimR(s);
         v := StrLen(s);
      end
      else
      begin
         v := SizeOf(Double);
         while (v > 0) and (s[pred(v)] = #0) do dec(v);
      end;
      p := New(GSptrIndexKeyData, Create(0));
      p^.Tag := n;
      p^.Xtra := r;
      p^.PutBufr(@s,v);
      PIK^.Insert(p);
      inc(i);
   end;
end;

procedure GSobjCDXTag.IntNodeWrite(PN: longint; DataBuf: GSptrCDXDataBlk;
                                   PIK: GSptrIndexKey);
var
   i: integer;
   Cnt: integer;
   kcnt: integer;
   p: GSptrIndexKeyData;
   v: integer;
   r: longint;
   NPN: longint;
   na: word;
   rp: longint;
   lp: longint;
   ck: integer;
   TmpTag: longint;
   kt: char;
   sp: integer;                        {!!RFG 090597}

   procedure FillBuffer;
   begin
      i := 0;
      if KeyType = 'C' then
         kt := ' '
      else
         kt := #0;
      FillChar(DataBuf^.IntData,SizeOf(DataBuf^.IntData),kt);
      while (i < kcnt) and (ck < PIK^.Count) do
      begin
         p := PIK^.At(ck);
         v := (i*EntryLength);
         move(p^.CharStr^[0], DataBuf^.IntData[v], p^.SizeStr);
         {$IFDEF FOXGENERAL}
         if (CollateType = General) and (KeyType = 'C') then
         begin
            sp := p^.SizeStr;
            dec(sp);
            while (sp >= 0) and (DataBuf^.IntData[v+sp] >= chr($F0)) do
            begin
               DataBuf^.IntData[v+sp] :=
                  chr(ord(DataBuf^.IntData[v+sp]) and $0F);
               dec(sp);
            end;
         end;
         {$ENDIF}
         v := v+KeyLength;
         r := FlipLongint(p^.Xtra);
         move(r, DataBuf^.IntData[v], 4);
         v := v+4;
         r := FlipLongint(p^.Tag);
         move(r, DataBuf^.IntData[v], 4);
         inc(i);
         inc(ck);
         inc(DataBuf^.Entry_Ct);
      end;
   end;

begin
   if PIK^.Count > MaxKeys then
   begin
      Cnt := Pik^.Count div 2;
      Cnt := Pik^.Count - Cnt;  {Get odd extra key}
   end
   else
   begin
      Cnt := PIK^.Count;
   end;
   ck := 0;
   kcnt := Cnt;
   if PIK^.Count > 0 then
   begin
      DataBuf^.Entry_Ct := 0;
      if kcnt < PIK^.Count then
      begin
         FillBuffer;
         if odd(DataBuf^.Node_Atr) then dec(DataBuf^.Node_Atr);
         na := DataBuf^.Node_Atr;
         rp := DataBuf^.Rght_Ptr;
         lp := DataBuf^.Left_Ptr;
         DataBuf^.Rght_Ptr := PN;
         NPN := Owner^.GetAvailPage;
         TmpTag := p^.Tag;
         p^.Tag := NPN;
         PIK^.AddNodeKey(p);
         p^.Tag := TmpTag;
         if PIK^.PageType = Root then PIK^.PageType := Node;
         Owner^.PageWrite(NPN, DataBuf^, CDXBlokSize);
         if lp > 0 then
         begin
            Owner^.PageRead(lp, DataBuf^, CDXBlokSize);
            DataBuf^.Rght_Ptr := NPN;
            Owner^.PageWrite(lp, DataBuf^, CDXBlokSize);
         end;
         FillChar(DataBuf^, CDXBlokSize, #32);
         DataBuf^.Node_Atr := na;
         DataBuf^.Left_Ptr := NPN;
         DataBuf^.Rght_Ptr := rp;
         DataBuf^.Entry_Ct := 0;
         kcnt := MaxKeys;
      end;
      FillBuffer;
   end;
   Owner^.PageWrite(PN, DataBuf^, CDXBlokSize);
end;

function GSobjCDXTag.IndexTagNew(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                                boolean;
var
   ps: PChar;
   chg: boolean;
   i: integer;
   CDXFill: GSptrByteArray;
begin
   IndexTagNew := inherited IndexTagNew(ITN,KeyExp,ForExp,Ascnd,Uniq);
   InvertRead := not AscendKey;
   GetMem(ps, 256);
   FillChar(ps[0],256,#0);
   if not SolveExpression(@Self, TagName, KeyExp, ps, KeyType, chg) then exit;
   if KeyType = 'C' then
   begin
      KeyLength := StrLen(ps);
      if CollateType = General then KeyLength := KeyLength *2;
   end
   else
      KeyLength := 8;
   i := KeyLength+8;
(*   while (i mod 4) <> 0 do i := i + 1;*)
   MaxKeys := ((CDXBlokSize-12) div i);          {!!RFG 100797}
   EntryLength := i;
   FreeMem(ps,256);
   GetMem(CDXFill, SizeOf(GSrecCDXHeader));
   FillChar(CDXFill^, SizeOf(GSrecCDXHeader), #0);
   Owner^.PageWrite(TagBlock, CDXFill^, SizeOf(GSrecCDXHeader));
   FreeMem(CDXFill, SizeOf(GSrecCDXHeader));
   DoIndex;
   IndexTagNew := true;
end;

function GSobjCDXTag.KeyAdd(st: GSptrIndexKeyData): boolean;
var
   tt: longint;
begin
   tt := st^.Xtra;
   st^.Xtra := st^.Tag;
   KeyAdd := inherited KeyAdd(st);
   st^.Xtra := tt;
end;

function GSobjCDXTag.PageLoad(PN: longint; PIK: GSptrIndexKey): Boolean;
var
   CDXData: GSptrCDXDataBlk;
   Cnt: integer;
   IsLeaf: boolean;
begin
   GetMem(CDXData, CDXBlokSize);
   Owner^.PageRead(PN, CDXData^, CDXBlokSize);
   Cnt := CDXData^.Entry_Ct;
   if Cnt > 16 then
      PIK^.SetLimit(Cnt+1);
   if CDXData^.Node_Atr > 1 then
   begin
      PIK^.PageType := Leaf;
      IsLeaf := true;
   end
   else
   begin
      PIK^.PageType := Node;
      IsLeaf := false;
   end;
   PIK^.Left := CDXData^.Left_Ptr;
   PIK^.Right := CDXData^.Rght_Ptr;
   if Cnt > 0 then
   begin
      if IsLeaf then
         ExtNodeBuild(CDXData, PIK)
      else
         IntNodeBuild(CDXData, PIK);
   end;
   FreeMem(CDXData, CDXBlokSize);
   PageLoad := true;
end;

function GSobjCDXTag.PageStore(PN: longint; PIK: GSptrIndexKey): Boolean;
var
   CDXData: GSptrCDXDataBlk;
begin
   GetMem(CDXData, CDXBlokSize);
   FillChar(CDXData^, CDXBlokSize, #0);
   With CDXData^ do
   begin
      if PIK^.PageType < Leaf then
         Node_Atr := 0
      else
         Node_Atr := 2;
      if PIK^.Owner = nil then inc(Node_Atr);
      Left_Ptr := PIK^.Left;
      Rght_Ptr := PIK^.Right;
      if Node_Atr < 2 then
         IntNodeWrite(PIK^.Page, CDXData, PIK)
      else
         ExtNodeWrite(PIK^.Page, CDXData, PIK);
   end;
   FreeMem(CDXData, CDXBlokSize);
   PageStore := true;
end;

function GSobjCDXTag.TagLoad: Boolean;
var
   CDXHdr: GSptrCDXHeader;
   ps: PChar;
   chg: boolean;
begin
   TagLoad := false;                      {!!RFG 091197}
   GetMem(CDXHdr, CDXBlokSize*2);
   Owner^.PageRead(TagBlock, CDXHdr^, CDXBlokSize*2);
   RootBlock := CDXHdr^.Root;
   if RootBlock = 0 then exit;                      {!!RFG 091197}
   if (Owner^.DiskFile <> nil) then                 {!!RFG 091197}
   begin
      if RootBlock mod CDXBlokSize <> 0 then exit;  {!!RFG 091197}
      if (RootBlock > Owner^.DiskFile^.gsFileSize) then exit;    {!!RFG 091197}
   end;
   KeyLength := CDXHdr^.Key_Lgth;
   if KeyLength > 240 then exit;                    {!!RFG 091197}
   MaxKeys := (CDXBlokSize-12) div (KeyLength+8);
   EntryLength := KeyLength+8;
   OptFlags := CDXHdr^.IndexOpts;
   ChgIndicator := CDXHdr^.ChgFlag;
   UniqueKey := (OptFlags and 1) = 1;
   Conditional := (OptFlags and 8) <> 0;
   AscendKey := CDXHdr^.AscDesc = 0;
   InvertRead := not AscendKey;
   ps := CDXHdr^.Col8Kind;
   if (StrIComp(ps,'GENERAL') = 0) then
   begin
      {$IFNDEF FOXGENERAL}
         Owner^.FoundError(cdxNoCollateGen,cdxInitError,'General Collate Invalid');
      {$ENDIF}
      CollateType := General;
   end
   else
      if (StrIComp(ps,'MACHINE') = 0) then
         CollateType := Machine
      else
         CollateType := NoCollate;
   ps := CDXHdr^.KeyPool;
   if (OptFlags < 128) and (StrLen(ps) = 0) then exit;      {!!RFG 091197}
   KeyExpr := StrGSNew(ps);
   CompressExpression(KeyExpr);
   if Conditional then
   begin
      ps := StrEnd(CDXHdr^.KeyPool)+1;
      ForExpr := StrGSNew(ps);
      CompressExpression(ForExpr);
   end;
   ps[0] := #0;
   SolveExpression(@Self, TagName, KeyExpr, ps, KeyType, chg); {get KeyType}
   FreeMem(CDXHdr, CDXBlokSize*2);
   TagChanged := false;
   TagLoad := true;                       {!!RFG 091197}
end;

function GSobjCDXTag.TagStore: Boolean;
var
   CDXHdr: GSptrCDXHeader;
   se: PChar;
begin
   TagStore := true;
   if TagChanged then
   begin
      if UniqueKey then
         OptFlags := OptFlags or $01;
      if Conditional then
         OptFlags := OptFlags or $08;
      GetMem(CDXHdr, SizeOf(GSrecCDXHeader));
      FillChar(CDXHdr^,SizeOf(GSrecCDXHeader),#0);
      CDXHdr^.Root := RootBlock;
      CDXHdr^.Key_Lgth := KeyLength;
      CDXHdr^.IndexOpts := OptFlags;
      CDXHdr^.ChgFlag := ChgIndicator;
      CDXHdr^.IndexSig := CDXSigDefault;
      if not AscendKey then
         CDXHdr^.AscDesc := 1;

      if ((OptFlags and 128) = 0) then
      begin
         if CollateType = General then
         begin
            StrCopy(CDXHdr^.Col8Kind,'GENERAL');
            CDXHdr^.IndexSig := CDXSigGeneral;
         end;
      end;

      if KeyExpr <> nil then
      begin
         CDXHdr^.Reserve4 := succ(StrLen(KeyExpr));
         CDXHdr^.KeyExpLen := succ(StrLen(KeyExpr));
         StrCopy(CDXHdr^.KeyPool, KeyExpr);
      end
      else
         CDXHdr^.KeyExpLen := 1;

      if (ForExpr <> nil) and Conditional then
      begin
         CDXHdr^.ForExpLen := succ(StrLen(ForExpr));
         se := StrEnd(CDXHdr^.KeyPool) + 1;
         StrCopy(se, ForExpr);
      end
      else
         CDXHdr^.ForExpLen := 1;

      Owner^.PageWrite(TagBlock, CDXHdr^, SizeOf(GSrecCDXHeader));
      FreeMem(CDXHdr, SizeOf(GSrecCDXHeader));
   end;
   TagChanged := false;
end;

function GSobjCDXTag.NewRoot: longint;
var
   CDXHdr: GSptrCDXHeader;
begin
   GetMem(CDXHdr, SizeOf(GSrecCDXHeader));
   Owner^.PageRead(TagBlock, CDXHdr^, SizeOf(GSrecCDXHeader));
   NewRoot := CDXHdr^.Root;
   FreeMem(CDXHdr, SizeOf(GSrecCDXHeader));
end;

{-----------------------------------------------------------------------------
                                 GSobjCDXFile
-----------------------------------------------------------------------------}

constructor GSobjCDXFile.Create(PDB: GSP_dBaseFld; const FN: string; FM: word);
var
   p: array[0..259] of char;
   ps: array[0..15] of char;
   extpos: integer;
begin
   inherited Create(PDB);
   DiskFile := IndexFileOpen(PDB,FN,'.CDX',FM, false);
   if DiskFile = nil then exit;
   KeyWithRec := true;
   CDXOpening := true;
   if (DiskFile^.dfFileExst) and (DiskFile^.gsFileSize > CDXBlokSize) then {!!RFG 091397}
   begin
      StrPCopy(p,ExtractFileNameOnly(StrPas(DiskFile^.dfFileName)));
      CompoundTag := New(GSptrCDXTag, Create(@Self,p,0));
      if not Corrupted then                       {!!RFG 091197}
      begin
         GSptrCDXTag(CompoundTag)^.OptFlags := $E0;
         ResetAvailPage;
         with CompoundTag^ do
         begin
            TagOpen(0);
            while (not TagEOF) and (not Corrupted) do     {!!RFG 091197}
            begin
               CurKeyInfo^.StringUpper;
               TagList^.Insert(New(GSptrCDXTag, Create(@Self,
                               CurKeyInfo^.GetPChar(ps),CurKeyInfo^.Tag)));
               KeyRead(Next_Record);
            end;
         end;
      end;
   end
   else
   begin
      NextAvail := 0;
      StrPCopy(p,ExtractFileNameOnly(StrPas(DiskFile^.dfFileName)));
      CompoundTag := New(GSptrCDXTag, Create(@Self,p,-1));
      GSptrCDXTag(CompoundTag)^.OptFlags := $E0;
      CompoundTag^.IndexTagNew(p,'','',true,false);
      CompoundTag^.TagOpen(0);
   end;
   GSbytCDXCollateInfo := Machine;
   if (not Corrupted) and (PDB <> nil) and (PDB^.IndexFlag = $00) then {!!RFG 091197}
   begin
      extpos := StrLen(DiskFile^.dfFileName);
      while DiskFile^.dfFileName[extpos] <> '.' do dec(extpos);
      if (StrLIComp(PDB^.dfFileName,DiskFile^.dfFileName,extpos) = 0) then
      begin
         PDB^.IndexFlag := $01;
         PDB^.WithIndex := true;
         PDB^.dStatus := Updated;
         PDB^.gsHdrWrite(false);
      end;
   end;
   CDXOpening := false;
   ObjType := GSobtCDXFile;
   CreateOK := not Corrupted;             {!!RFG 091197}
end;

destructor GSobjCDXFile.Destroy;
begin
   if CompoundTag <> nil then
   begin
      CompoundTag^.TagClose;
      CompoundTag^.Free;
      CompoundTag := nil;
   end;
   inherited Destroy;
end;

function GSobjCDXFile.AddTag(ITN,KeyExp,ForExp: PChar; Ascnd,Uniq: boolean):
                                                                     boolean;
var
   p: GSptrCDXTag;
   i: integer;
   j: integer;
   ps: GSptrIndexKeyData;
begin
   CompoundTag^.TagOpen(0);
   ps := New(GSptrIndexKeyData, Create(0));
   ps^.PutPChar(ITN);
   ps^.StringUpper;
   j := -1;
   for i := 0 to pred(TagList^.Count) do
   begin
      p := TagList^.At(i);
      if StrIComp(p^.TagName, ps^.CharStr^) = 0 then j := i;
   end;
   if j <> -1 then
   begin
      p := TagList^.At(j);
      ps^.Tag := p^.TagBlock;
      if CompoundTag^.KeyFind(ps) > 0 then
         CompoundTag^.RootPage^.DeleteKey;
      TagList^.FreeOne(p);
   end;
   p := New(GSptrCDXTag, Create(@Self,ps^.CharStr^,-1));
   p^.CollateType := GSbytCDXCollateInfo;
   TagList^.Insert(p);
   ps^.Tag := p^.TagBlock;
   AddTag := p^.IndexTagNew(ps^.CharStr^,KeyExp,ForExp,Ascnd,Uniq);
   CompoundTag^.KeyAdd(ps);
   ps^.Free;
   CompoundTag^.RootPage^.Changed := true;
   CompoundTag^.TagClose;
end;

function GSobjCDXFile.DeleteTag(ITN: PChar): boolean;
var
   p: GSptrCDXTag;
   i: integer;
   j: integer;
   ps: GSptrIndexKeyData;
begin
   DeleteTag := false;
   if TagList^.Count = 0 then exit;
   ps := New(GSptrIndexKeyData, Create(0));
   ps^.PutPChar(ITN);
   ps^.StringUpper;
   j := -1;
   for i := 0 to pred(TagList^.Count) do
   begin
      p := TagList^.At(i);
      if StrIComp(p^.TagName, ps^.CharStr^) = 0 then j := i;
   end;
   if j <> -1 then
   begin
      CompoundTag^.TagOpen(0);
      p := TagList^.At(j);
      ps^.Tag := p^.TagBlock;
      if CompoundTag^.KeyFind(ps) > 0 then
         CompoundTag^.RootPage^.DeleteKey;
      TagList^.FreeOne(p);
      CompoundTag^.RootPage^.Changed := true;
      CompoundTag^.TagClose;
      if TagList^.Count = 0 then Reindex;
   end;
   ps^.Free;
   DeleteTag := j <> -1;
end;

function GSobjCDXFile.GetAvailPage: longint;
begin
   if NextAvail = -1 then ResetAvailPage;
   GetAvailPage := NextAvail;
   inc(NextAvail,CDXBlokSize);
end;

function GSobjCDXFile.ResetAvailPage: longint;
begin
   NextAvail := DiskFile^.gsFileSize;
   ResetAvailPage := NextAvail;
end;

function GSobjCDXFile.PageRead(Blok: longint; var Page; Size: integer):
                               boolean;
begin
   PageRead := inherited PageRead(Blok, Page, Size);
end;

function GSobjCDXFile.PageWrite(Blok: longint; var Page; Size: integer):
                                  boolean;
begin
   PageWrite := inherited PageWrite(Blok, Page, Size);
end;

procedure GSobjCDXFile.Reindex;
var
   p: GSptrCDXTag;
   ps: GSptrIndexKeyData;
   i: integer;
begin
   DiskFile^.gsLockFile;
   with CompoundTag^ do
   begin
      TagOpen(0);
      while not TagEOF do
      begin
         RootPage^.DeleteKey;
         KeyRead(Bttm_Record);
      end;
   end;
   for i := 0 to pred(TagList^.Count) do
   begin
      p := TagList^.At(i);
      p^.TagClose;
   end;
   DiskFile^.gsTruncate(CDXBlokSize*3);
   NextAvail := CDXBlokSize*3;   {Room for tag index}
   CompoundTag^.RootPage^.Page := CDXBlokSize*2;
   CompoundTag^.RootBlock := CDXBlokSize*2;
   CompoundTag^.ChgIndicator := 0;
   CompoundTag^.TagChanged := true;
   CompoundTag^.RootPage^.Changed := true;
   CompoundTag^.TagClose;
   for i := 0 to pred(TagList^.Count) do
   begin
      p := TagList^.At(i);
      p^.TagBlock := GetAvailPage;
      GetAvailPage;                {Need two blocks for tag header}
      p^.TagChanged := true;
      p^.ChgIndicator := 0;
      p^.TagStore;
      p^.DoIndex;
      ps := New(GSptrIndexKeyData, Create(0));
      ps^.PutPChar(p^.TagName);
      ps^.Tag := p^.TagBlock;
      CompoundTag^.KeyAdd(ps);
      ps^.Free;
   end;
   CompoundTag^.TagClose;
   DiskFile^.gsUnLock;
end;

function GSobjCDXFile.TagUpdate(AKey: longint; IsAppend: boolean): boolean;
begin
   inc(CompoundTag^.ChgIndicator);
   CompoundTag^.TagChanged := true;
   CompoundTag^.TagStore;
   TagUpdate := inherited TagUpdate(AKey, IsAppend);
end;

function GSobjCDXFile.ExternalChange: boolean;   {!!RFG 091297}
var
   CDXHdr: GSptrCDXHeader;
   chg: boolean;
begin
   ExternalChange := false;
   if (DiskFile = nil) or (not DiskFile^.dfFileShrd) then exit;
   GetMem(CDXHdr, CDXBlokSize);
   PageRead(0, CDXHdr^, CDXBlokSize);
   chg := CompoundTag^.ChgIndicator <> CDXHdr^.ChgFlag;
   FreeMem(CDXHdr, CDXBlokSize);
   ExternalChange := chg;
end;

end.


