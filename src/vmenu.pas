{---------------------------------}
{Menu Unit for Russian SWAG Reader}
{---------------------------------}
{written 1996-2000 by Valery Votintsev 2:5021/22}
{                  E-Mail: rswag@sources.ru     }
{corrected 29/09/2000 for Windows NT by
 Alexander Grischenko <gralex@mailbox.riga.lv>}

{$i Gsf_Flag.pas}
UNIT vMenu;

Interface

USES
   vKbd,
   vScreen,
   vString,
   strings,
   Gsf_GLBL,
   Gsf_xLat,
   Dos,
   Crt;

Const
  MaxMenuWidth  = 78;

Const
  AllTheFiles        : String[ 3] ='*.*';
  mnAllAreas         : String[23] ='All Areas';
  mnCurrentArea      : String[23] ='Current Area';
  mnMarkedAreas      : String[23] ='Marked Areas';
  mnQuit_ESC         : String[23] ='Quit  / ESC';
  mnCancel_ESC       : String[23] ='Cancel / ESC';
  mnAppendToEndOfFile: String[23] ='Append to end of file';
  mnOverWriteTheFile : String[23] ='Overwrite the file';
  mnDiskFile         : String[23] ='Disk File';
  mnHtmlFile         : String[23] ='HTML File';
  mnPrintDevice      : String[23] ='Print device';
  mnClipboard        : String[23] ='Clipboard';
  mnUseHeader_Yes    : String[23] ='Use Header: YES';
  mnUseHeader_No     : String[23] ='Use Header:  NO';
  mnCurrentMsg       : String[23] ='Current Msg';
  mnAllMsgs          : String[23] ='All Messages';
  mnMarkedMsgs       : String[23] ='Marked Msgs';
  mnMoveMsg          : String[23] ='Move    Msg';
  mnCopyMsg          : String[23] ='Copy    Msg';
  mnYesPlease        : String[23] ='Yes Please.';
  mnNo               : String[23] ='No!';
  mnDescription      : String[23] ='Description';
  mnAreaID           : String[23] ='AreaID';
  mnFrom             : String[23] ='From';
  mnSubject          : String[23] ='Subject';
  mnNoOrder          : String[23] ='No Order';
  mnFileAsText       : String[23] ='File as Text';
  mnBinaryAsUue      : String[23] ='Binary as UUE';
  mnBinaryAttach     : String[23] ='Binary Attach';
  mnNothing_Quit     : String[23] ='Nothing / Quit';
  mnNoDropIt         : String[23] ='No! Drop It!';
  mnContinueEditing  : String[23] ='Continue editing.';


Type
   CenterType = (NotCentered,Centered);
   MenuLineType = String[MaxMenuWidth];

   MenuLinePnt = ^MenuLine;
   MenuLine = Object
    Prev,
    Next    : MenuLinePnt;
    Message : MenuLineType;
    Procedure Draw(x,Row:integer;Color: Byte);
  END;

  MenuType = Object
    FirstEntry: MenuLinePnt;
    TopEntry  : MenuLinePnt;
    CurEntry  : MenuLinePnt;
    Count: Integer;
    Title      : MenuLineType;
    xLeft,xRight : byte;
    yTop,yBttm : byte;
    width,high: byte;
    TitleColor,
    MainColor,
    HighColor,
    BorderColor,
    FirstCharColor: byte;
    OldX,OldY: byte;
    OldColor: byte;
    ReDraw:boolean;
    CenterMode:CenterType;
    OldMenuScreen: ScreenPtr;
    {Initializes the menu to empty before starting a new menu}
    Constructor Init (x1,y1,x2,y2:byte;const sTitle:MenuLineType;
                      MainAttr,HiAttr,TtlAttr,BrdAttr,FirstAttr:Byte;
                      CenterIt:CenterType);
    {Adds a new line entry to the menu being built}
    Procedure   Add(S: MenuLineType);
    Procedure   SetMenuItem(ItemNumber:integer;S: MenuLineType);
    Destructor  Done;
    Procedure   Draw;
    Function    ReadMenu(First:integer): Integer;
  END;

Var
   DriveCount : word;
   DriveTable : array[0..127] of char;
   M: MenuType;

Procedure Warning (const cTitle:string;SayColor,GetColor:byte);
Procedure WaitforOk (const cTitle,cAnswer:string;SayColor,GetColor:byte);
Function  AskYesNo(x1,y1:byte;Title:string):Boolean;
Procedure MakeFileTable(Var FileList:MenuType; path,mask:string; LookElseWhere : boolean);
{Function FileMenu(DirName:PathStr):String;}
{Function FMenu(const DirName:PathStr; var Attr:byte):NameStr;}
function  SelectFile(x1,y1,x2,y2:byte;const sTitle:MenuLineType;
                    MainAttr,HiAttr,TtlAttr,BrdAttr,FirstAttr:Byte;
                    path, mask : string; LookElseWhere : boolean): string;
{function  FindFiles(pth, fname : string; LookElseWhere : boolean): string;}

IMPLEMENTATION


{---------------- MenuType Object --------------------------------------}
Constructor MenuType.Init (x1,y1,x2,y2:byte;const sTitle:MenuLineType;
                  MainAttr,HiAttr,TtlAttr,BrdAttr,FirstAttr:Byte;
                  CenterIt:CenterType);
{Initializes the menu to empty before starting a new menu}
begin
   OldColor  :=TextAttr;
   OldX:=WhereX;
   OldY:=WhereY;

   Title     := sTitle;
   xLeft     := x1;
   xRight    := x2;
   yTop      := y1;
   yBttm     := y2;
   CenterMode:= CenterIt;
   TitleColor:= TtlAttr;
   MainColor := MainAttr;
   HighColor := HiAttr;
   BorderColor := BrdAttr;
   FirstCharColor := FirstAttr;

   FirstEntry:= NIL;
   TopEntry  := NIL;
   Count     := 0;
   ReDraw    := True;
   width     := xRight-xLeft-1;
   high      := yBttm-yTop-1;

   OldMenuScreen:= SaveScreen;

end;

Destructor MenuType.Done;
begin
   IF FirstEntry <> NIL then begin
      FirstEntry^.Prev^.Next:= NIL;
      REPEAT
         CurEntry:= FirstEntry;
         FirstEntry:= FirstEntry^.Next;
         Dispose(CurEntry);
      UNTIL FirstEntry = NIL;
   end;

   RestScreen(OldMenuScreen);
   TextAttr:=OldColor;
   GotoXY(OldX,OldY);
end;

Procedure MenuType.Add(S: MenuLineType);
begin
   INC(Count);
{   If Length(s) > Width then s[0]:=Chr(Width);}
   If CenterMode = Centered then
      S:=PadC(S,Width)
   else
      S:= PadR(S,Width);
{   FillChar(s[Length(s) + 1], Width - Length(s), ' ' );
   s[0]:= Char(Width);
}
   CurEntry:= NEW(MenuLinePnt);
   CurEntry^.Message:=S;

   IF FirstEntry = NIL then begin
      CurEntry^.Next:= CurEntry;
      CurEntry^.Prev:= CurEntry;
      FirstEntry:=CurEntry;
      TopEntry:=FirstEntry;
   end else begin
      CurEntry^.Prev := FirstEntry^.Prev;
      CurEntry^.Next := FirstEntry;
      FirstEntry^.Prev^.Next:= CurEntry;
      FirstEntry^.Prev:= CurEntry;
   end;
end;

Procedure MenuType.SetMenuItem(ItemNumber:integer;S: MenuLineType);
begin
   If CenterMode = Centered then
      S:=PadC(S,Width)
   else
      S:= PadR(S,Width);
   CurEntry^.Message:=S;
   redraw:=True;
   Draw;
end;

(*
Procedure MenuType.Add(S: MenuLineType);
begin
   INC(Count);
{   If Length(s) > Width then s[0]:=Chr(Width);}
   If CenterMode = Centered then
      S:=PadC(S,Width)
   else
      S:= PadR(S,Width);
{   FillChar(s[Length(s) + 1], Width - Length(s), ' ' );
   s[0]:= Char(Width);
}
   CurEntry:= NEW(MenuLinePnt);
   CurEntry^.Message:=S;

   IF FirstEntry = NIL then begin
      CurEntry^.Next:= CurEntry;
      CurEntry^.Prev:= CurEntry;
      FirstEntry:=CurEntry;
      TopEntry:=FirstEntry;
   end else begin
      CurEntry^.Prev := FirstEntry^.Prev;
      CurEntry^.Next := FirstEntry;
      FirstEntry^.Prev^.Next:= CurEntry;
      FirstEntry^.Prev:= CurEntry;
   end;
end;
*)
Procedure MenuType.Draw;
var
   Row:integer;
   p:MenuLinePnt;
   EmptyStr:MenuLineType;
begin
   EmptyStr:=Spaces(width);
   Row:=yTop+1;
   p:=TopEntry;

   Repeat
      p^.Draw(xLeft+1,Row,MainColor);
      p:=p^.next;
      Inc(Row);
   until (p = FirstEntry) or (row = yBttm);

   While (row < yBttm) do begin
      SAY(xLeft+1,Row,EmptyStr);
      inc(Row);
   end;
   redraw:=False;
end;



Function MenuType.ReadMenu(First:integer): Integer;
VAR
{   SaveX, SaveY: Integer;}
   Row     : integer;
   Finished: Boolean;
   InChar  : Char;
   i,
   Index   : Integer;
BEGIN
{   SaveX:= WhereX;
   SaveY:= WhereY;
}
   Finished:= False;
   Row     := YTop+1;
   Index   := 1;
   CurEntry:= TopEntry;

   {Adjust the row for the first Menu Item}
   If First > Count then
      First := 1;

   TextAttr := BorderColor;
   Box(xLeft,yTop,xRight,yBttm,Mixed,Shadow);

   TextAttr:=TitleColor;
   SAY(xLeft+(Width+2-Length(Title)) div 2,yTop,Title);
{   TextAttr:=OldColor;}


   While index <> First do begin
      Inc(Index);
      CurEntry:=CurEntry^.next;
      Inc(Row);
      If Row = yBttm then begin
         TopEntry:=CurEntry;
         Row:=succ(yTop);
      end;
   end;

   REPEAT  {For Each Key Loop}

      If Redraw then Draw;      { ReDraw full Menu screen }

      CurEntry^.Draw(xLeft+1,Row,HighColor);    {}

      InChar:= InKey(0);

      CurEntry^.Draw(xLeft+1,Row,MainColor);    {Highlight current line}

      CASE InChar OF
        K_Up  : begin
                   If CurEntry = FirstEntry then begin
                      Index := Count;
                      Row := yTop+1;
                      Redraw := True;
                      TopEntry := FirstEntry^.prev;
                      While (TopEntry <> FirstEntry) and
                            (row < Pred(yBttm)) do begin
                         Inc(Row);
                         TopEntry := TopEntry^.prev;
                      end;
                   end else begin
                      Dec(Row);
                      If Row > yTop then begin
                         Dec(Index);
                      end else begin
                         Row := yTop +1;
                         TopEntry := TopEntry^.prev;
                         ReDraw:=True;
                      end;
                   end;
                   CurEntry:= CurEntry^.Prev;
                end;

        K_PgUp: begin
                   While CurEntry <> TopEntry do begin
                      CurEntry := CurEntry^.prev;
                      Dec(Index);
{                      Dec(Row);}
                   end;

                   If TopEntry <> FirstEntry then begin
                      i:=1;
                      Repeat
                         TopEntry := TopEntry^.prev;
                         Dec(Index);
                         Inc(i);
                      until (TopEntry = FirstEntry) or
                            (i > High);

                   end;
                   Row := yTop+1;
                   Redraw := True;
                   CurEntry:= TopEntry;
                end;

        K_Down: begin
                If CurEntry = FirstEntry^.prev then begin {If Last Item}
                   Row := yTop + 1;
                   Index := 1;
                   TopEntry := FirstEntry;
                   ReDraw:=True;
                end else begin
                   Inc(Row);
                   Inc(Index);
                   If Row = yBttm then begin
                      TopEntry:=TopEntry^.next;
                      Row := yBttm -1;
                      Redraw := True;
                   end;
                end;
                CurEntry:= CurEntry^.Next;
                end;

        K_PgDn: begin
                   While (Row <> Pred(yBttm)) and
                         (CurEntry <> FirstEntry^.prev) do begin
                      CurEntry := CurEntry^.next;
                      Inc(Index);
                      Inc(Row);
                   end;

                   If CurEntry <> FirstEntry^.prev then begin
                      CurEntry := CurEntry^.next;
                      TopEntry := CurEntry;
                      Inc(Index);
                      Row := yTop+1;
                      Redraw := True;
                   end;
                end;

        K_Home,
        K_CTRL_PgUp : begin
                         CurEntry:= FirstEntry;
                         Row := yTop + 1;
                         Index := 1;
                         TopEntry:=FirstEntry;
                         Redraw := True;
                      end;
        K_End,
        K_CTRL_PgDn:  begin
                         CurEntry:= FirstEntry^.Prev;
                         Index := Count;
                         Row := yTop+1;
                         Redraw := True;
                         TopEntry := FirstEntry^.prev;
                         While (TopEntry <> FirstEntry) and
                               (row < Pred(yBttm)) do begin
                            Inc(Row);
                            TopEntry := TopEntry^.prev;
                         end;
                      end;
        K_Esc         : BEGIN
                         Finished:= True;
                         Index:= 0;
                       END;
        K_CR       : BEGIN
                         Finished:= True;
                       END;
      END;
    UNTIL Finished;
    ReadMenu:= Index;
END;

Procedure MenuLine.Draw(x,Row:integer;Color: Byte);
BEGIN
   TextAttr:= Color;
   SAY(X,Row,Message);
END;

{*ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ*}
Function AskYesNo(x1,y1:byte;Title:string):Boolean;
{ Yes - No Menu }
Var
   l,lm,x2,y2:byte;
   ans:integer;
begin
   l :=Length(Title);
   lm:=Length(mnYesPlease);
   If l < lm then
      l:= lm;

   { Place Menu To the Screen Center }
   If y1=0 then y1:=11;

   If x1=0 then begin
      x1:=((80-l) div 2)-1;
      If x1 <1 then x1:=1;
   end;

   x2:=x1+l+2;
   If x2 >80 then x2:=80;

   M.Init(x1,y1,x2,y1+3, Title,
                 LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
   M.Add(mnYesPlease);
   M.Add(mnNo);

   Ans:=M.ReadMenu(1);
   M.Done;

   AskYesNo := (Ans = 1);

end;



Procedure Warning (const cTitle:string;SayColor,GetColor:byte);
Var
{   OldScreen:ScreenPtr;}
   l,x1,x2,y2,
   OldColor:byte;
begin
   OldColor:=TextAttr;
{   OldScreen:=SaveScreen;}
   l:=Length(cTitle);
   x1:=((80-l) div 2)-1;
   If x1 <1 then x1:=1;
   x2:=x1+l+2;
   If x2 >80 then x2:=80;
   y2:=14;

   TextAttr:=SayColor;
   Box(x1,12,x2,y2, Mixed,Shadow);
   SAY(x1+1,13, PadC(cTitle,x2-x1-1));
{   If cAnswer<>'' then begin
      TextAttr:=GetColor;
      SAY((80-length(cAnswer)) div 2,14, cAnswer);
      Inkey(0);
      RestScreen(OldScreen);
   end;
}
   TextAttr:=OldColor;
end;


Procedure WaitforOk (const cTitle,cAnswer:string;SayColor,GetColor:byte);
Var
   OldScreen:ScreenPtr;
   l,x1,x2,y2,
   OldColor:byte;
begin
   OldColor:=TextAttr;
   OldScreen:=SaveScreen;
   l:=Length(cTitle);
   x1:=((80-l) div 2)-1;
   If x1 <1 then x1:=1;
   x2:=x1+l+2;
   If x2 >80 then x2:=80;

   y2:=15;

   TextAttr:=SayColor;
   Box(x1,12,x2,y2, Mixed,Shadow);
   SAY(x1+1,13, PadC(cTitle,x2-x1-1));

   TextAttr:=GetColor;
   SAY((80-length(cAnswer)) div 2,14, cAnswer);
   Inkey(0);

   RestScreen(OldScreen);
   TextAttr:=OldColor;
end;


(*************************************)
{ NT only code by Alexander Grischenko}

function CheckNT:boolean;
var OS:String;
Begin
   OS := upper(GetEnv('OS'));
   CheckNT := OS='WINDOWS_NT'
End;

(*************************************)


Procedure BuildDriveTable;
{---Build Drive Table---}
var
   drv           : byte;
   CurDrive      : byte;
   TmpDrive      : byte;
{   DriveName     : Char;}
begin
   Asm
   mov bx,ds
   xor ax,ax
   mov ds, ax
   mov es, ax
   mov ah, 19h
   Int 21h
   mov CurDrive,al

   mov dl,al
   mov ah, 0Eh
   Int 21h
   xor ah,ah
   mov ds,bx
   mov DriveCount, ax
   end;

{ AG: Doesn't work properly under NT! }
{ AG:   TmpDrive := 0;                }

{AG: ==>}
{ if NT presents, then start drive checking from C:, not from A: }
{ ·™†≠®‡Æ¢†≠®• §®·™Æ¢ ¢ ·´„Á†• · çí ≠†Á®≠†•‚·Ô · ë:, 
  † A ® B ¢ Ì‚Æ¨ ·´„Á†• ≠†§Æ Ø‡Æ·‚Æ ØÆ¨•‚®‚Ï ™†™ Ø‡®·„‚·‚¢„ÓÈ®•}
   if CheckNT then begin
      DriveTable[0] := 'P';   {Assume that Drive 'A' presents}
      DriveTable[1] := 'P';   {Assume that Drive 'B' presents}
      TmpDrive := 2;
   end
      else TmpDrive := 0;
{AG:}

   while TmpDrive < DriveCount do begin
      Asm
         mov bx,ds
         xor ax,ax
         mov ds, ax
         mov es, ax
         mov dl, TmpDrive
         mov ah, 0Eh
         Int 21h

         mov ah, 19h
         Int 21h
         mov ds,bx
         mov drv, al
      end;

{      DriveName := Char (Ord('A')+reg);}

      if TmpDrive = drv then DriveTable[TmpDrive] := 'P'
         else DriveTable[TmpDrive] := ' ';
      inc(TmpDrive);
   end;

   Asm
      mov bx,ds
      xor ax,ax
      mov ds, ax
      mov es, ax
      mov dl, CurDrive
      mov ah, 0Eh
      Int 21h
      mov ds,bx
   end;
end;


Procedure MakeFileTable(Var FileList:MenuType; path,mask:string; LookElseWhere : boolean);
var
   i : integer;
   OldDir : string;
   wname   : string;
{   v : char;
   u : byte absolute v;
   b : byte;}
   ParentExist: boolean;
   DirInfo : SearchRec;
   DirList : GSptrStringCollection;
   spc:pChar;


   Procedure MakeDirTable(Var FileList:MenuType);
   var
      i:integer;
   begin
      DirList:= New(GSptrStringCollection, Create(32,32));

      FindFirst(path+'*.*', Directory, DirInfo);
      while DosError = 0 do begin
         if DirInfo.Name = '..' then ParentExist := true;
         if (DirInfo.Attr = Directory) and (DirInfo.Name[1] <> '.') then begin
            GetMem(spc,128);
            StrPCopy(spc,DirInfo.Name+'\');
            DirList^.Insert(StrGSNew(spc));
            FreeMem(spc,128);
         end;
         FindNext(DirInfo);
      end;

      If ParentExist then
         FileList.Add('..\');

      For i:= 0 to Pred(DirList^.Count) do begin
         wname:=StrPas(DirList^.AT(i));
         FileList.Add(wname);
      end;

      Dispose(DirList, Destroy);

      for i := 0 to pred(DriveCount) do begin
         if DriveTable[i] = 'P' then begin
            FileList.Add(chr(i+65)+':\');
         end;
      end;
   end;

begin
   GetDir(0,OldDir);
   If Path = '' then path := OldDir;
   if path[length(path)] <> '\' then path := path + '\';

   DirList:= New(GSptrStringCollection, Create(32,32));

   wname := mask;
   while wname <> '' do begin
      i := pos(',',wname);
      if i = 0 then i := succ(length(wname));

      FindFirst(path+system.copy(wname,1,pred(i)), Archive, DirInfo);
      while DosError = 0 do begin
         GetMem(spc,128);
         StrPCopy(spc,Lower(DirInfo.Name));
         DirList^.Insert(StrGSNew(spc));
         FreeMem(spc,128);
         FindNext(DirInfo);
      end;
      system.delete(wname,1,i);
   end;

   For i:= 0 to Pred(DirList^.Count) do begin
      wname:=StrPas(DirList^.AT(i));
      FileList.Add(wname);
   end;

   Dispose(DirList, Destroy);

   if LookElseWhere then begin
      MakeDirTable(FileList);
   end;

end;


function SelectFile(x1,y1,x2,y2:byte;const sTitle:MenuLineType;
                    MainAttr,HiAttr,TtlAttr,BrdAttr,FirstAttr:Byte;
                    path, mask : string; LookElseWhere : boolean): string;
Var
   DirNow,
   DirName,
   fn:string;
   i,
   Choice: Integer;
BEGIN
   Path := Upper(Path);

   GetDir(0,DirNow);
   If path = '' then
      DirName := DirNow
   else
      DirName := path;

   If Right(DirName,1) <> '\' then DirName:=DirName+'\';

   While True do begin

      M.Init(x1,y1,x2,y2, sTitle,MainAttr,HiAttr,TtlAttr,BrdAttr,FirstAttr,
             NotCentered);
      TextAttr:=TtlAttr;
      SAY(Succ(x1),y2,DirName);

      MakeFileTable(M,DirName,mask,LookElseWhere);

      Choice:= M.ReadMenu(1);
      fn:=RTrim(M.CurEntry^.Message);

      M.Done;

      If Choice = 0 then begin
         fn :='';
         break;
      end else begin
      If Right(fn,1) <> '\' then begin              {Exit if any file}
         fn:=DirName + fn;
         break;
      end else begin
         If fn = '..\' then begin                   {Parent Directory}
            i:=RAT('\',DirName);
            If (i=Length(DirName)) and (i>3) then
               System.Delete(DirName,i,255);
            i:=RAT('\',DirName);
               If i>=3 then System.Delete(DirName,i+1,255);

         end else If copy(fn,2,2) = ':\' then begin {Another Disk    }
            DirName := fN;
         end else begin                             {SubDirectory    }
            DirName:=DirName + fN;
         end;
      end;
      end;
   end;
   SelectFile := fn;
end;



begin
   BuildDriveTable;
END.
