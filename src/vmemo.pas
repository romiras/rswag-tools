{----------------------------------------------------------}
{      Unit vMemo - Memo Handling Routines                 }
{      for    Russian SWAG Msg Base Reader                 }
{                    v.4.0 beta H                          }
{      written 1993-2000 by Valery Votintsev 2:5021/22     }
{                             E-Mail: rswag@sources.ru     }
{----------------------------------------------------------}
unit vMemo;
{$I GSF_FLAG.PAS}
interface

uses
  CRT,
{  Reader_C,}
  Gsf_DOS,
  gsf_shel,
  gsf_dbf,
  gsf_memo,
  vString,
  vscreen,
  vkbd,
  vMenu,
  ZipUnit;

Const
   MaxMemoSize   = $FFF0;
   MaxMemoSize2  = $FFF2;
   CutLine   : String[ 9] ='þþþþþþþþþ';
   CutLine2  : String[20] ='Cut here. FileName= ';

type
   FileOfByte  = File of byte;
   TripletType = Array[0..2] of Byte;
   KwartetType = Array[0..3] of Byte;

   MemoType    = array [0..MaxMemoSize2] of char;
   MemoPtr     = ^MemoType;

var
   ExtractDir,                     {Extract Directory}
   ImportDir    : string;          {Import Directory }
{   MemoObj      : GsPtrMemo;       {Pointer to MEMO object}

   Memo         : MemoPtr;         {Pointer to UnPacked MEMO }
   Memo_Pack    : MemoPtr;         {Pointer to Packed MEMO }
   Memo_Size    : Word;
   Memo_PackSize: LongInt;         {Packed MEMO size}
   MemoEditOn   : boolean;
   MemoUpdated  : boolean;
   MemoDropped  : Boolean;
   MemoHelpProc : Procedure;
   FileToWrite,
   TmpFileName,
   MemoFileName : String;
   Memo_pgBase,
   Memo_nxBase,
   Memo_lnBase   : LongInt;
   Memo_y        : Integer;
   Attached      : boolean;

  FindUp,                   {Search Parameters           }
  FindTmp,
  FindStr  : string80;
  FindRec  : MemoPtr;
  FindLen  : integer;
  FindCount: LongInt;
  FindText : Boolean;
  quoted:boolean;

{Procedure UUDecode(lProcessBar:boolean);}
{Procedure DecodeLine(var nHandle:FileOfByte; Buffer:string);}

Function scanCrDn(i:longint):longint; {put cursor on next CR or endF}
Procedure BrowseHelp;
Procedure MemoEditHelp;
Procedure ReadMemo(fnam: string);
Procedure WriteMemo(fnam: string);
Procedure MemoDelLine(linenum : integer);
function  MemoGetLine(linenum : integer) : String;
Function  MemoLines : integer;
Procedure MemoSay(ColLeft,RowTop,ColRight,RowBottom:byte);
{Procedure MemoEdit(ColLeft,RowTop,ColRight,RowBottom:byte);}
Procedure MemoEdit(xLeft,yTop,xRight,yBottom:byte);
Procedure DrawInsMode;
Procedure ChangeCutters;
Procedure RemoveSoftCR;
Procedure ReplaceInMemo(const Search,Repl:string);
Procedure ConvertMemo(Table:pCodeTable);
Procedure AttExtract(const filename:string); {Extract Attachment}
Procedure AttImport(const filename:string);  {Import Attachment }
Procedure MemoDelChars(p,n:longint); {Delete n chars from "p" in MEMO buffer}
Procedure MemoInsString(p:longint;const S:string);{Insert the S string into the Memo buffer}

{------------------------------------------------------------------------------
                            IMPLEMENTATION SECTION
------------------------------------------------------------------------------}


implementation
Var
  update: Boolean;
  crs   : LongInt;
   Source,
   Target:MemoPtr;
   BytesLeft,
   SourceAddr,
   TargetAddr,
   SourceLen,
   TargetLen : LongInt;
   M:MenuType;
   Ans:Integer;
   OldColor:byte;
   RowTop:byte;
   RowBottom:byte;
   ColLeft:byte;
   ColRight:byte;


Procedure AttExtract(const filename:string);
{Extract Attachment}
begin
   Memo2File('ATTACHME',FileName);
end;

Procedure AttImport(const filename:string);
{Import Attachment }
var
  j:integer;
  s:string;
begin
   File2Memo('ATTACHME',FileName);
   j:=RAT('\',FileName);
   If j = 0 then S:=FileName
            else S:=SubStr(FileName,j+1,255);
   DBFActive^.gsFieldPut('PROJECT', Upper(S));
   Attached:=True; {flag about new attachment!}
end;



{--------------------------------------------------}
Procedure delChar;
begin
  if crs = memo_size then Exit;
  if (memo^[crs] = ^M) and (memo^[crs+1] = ^J)then begin
     move(memo^[crs+2], memo^[crs], memo_size - crs - 1);
     dec(memo_size);
  end else
    move(memo^[crs+1], memo^[crs], memo_size - crs);

  dec(memo_size);
  update:=true;
  MemoUpdated := True;
{  checkWrap(crs);}
end;




Procedure ConvertMemo(Table:pCodeTable);
var
   n:longint;
begin
   For n:=0 to Pred(Memo_Size) do
      Memo^[n]:=Table^[Byte(Memo^[n])];

end;


{--------------------------------------------------}
Procedure MemoDelChars(p,n:longint);
{Delete from MEMO buffer "n" chars from position "p"}
var
  i:longint;
begin

  If p < Memo_Size then begin
     If p+n > Memo_Size then
        n:=p + n - Memo_Size;  {Correct properly number of bytes}
    if n > 0 then begin
       crs:=p;
       For i:=1 to n do
          DelChar;
    end;
  end;

{  dec(Memo_Size, n);}
  update := true;
  MemoUpdated := True;
end;


{--------------------------------------------------}
Procedure MemoInsString(p:longint;const S:string);
{Insert the S string into the Memo buffer}
var
   j,l : longint;
begin

   l := Length(S);

   If l + Memo_Size > MaxMemoSize then begin
      Beep;
      WaitForOk('Memo too big to insert chars !','Ok',LightGray*16,Cyan*16)
      {!!! à¥¤«®¦¨âì à §¡¨âì ­  ­¥áª®«ìª® á¥ªæ¨©!!!}
   end else begin
      for j:=Pred(Memo_Size) downto p do  {‘¤¢¨­ãâì •¢®áâ Memo ¢¯à ¢®}
         memo^[j+l]:=memo^[j];

      {¢áâ ¢¨âì ­ èã áâà®ªã ¢ ®á¢®¡®¦¤¥­­®¥ ¬¥áâ®}
      move(S[1], memo^[p], Length(S));  {Put the string to Memo  }
      Inc(Memo_Size,Length(S));         {Increase Memo_Size}

      update := true;
      MemoUpdated := True;
   end;

end;


{-----------------------------------------------}
Procedure ReplaceInMemo(const Search,Repl:string);
var
  p,l:longint;
  m:MemoPtr;
begin
   Repeat
      p:=BinAT(Search,Memo^,Memo_Size);
      If p>0 then begin
         Dec(p);
         m:=Memo;
         inc(m,p);
         l:=Length(Search);
         MemoDelChars(p,l);
         MemoInsString(p,Repl);
         Inc(p);
      end;
   until (p=0);
end;




{-------------------------------------------------}
{put cursor on next CR or endF}
Function scanCrDn(i:longint):longint;
var j:longint;
begin
  quoted:=false;
  j:=i;
  while (i < Memo_Size) and (memo^[i]<>K_LF) do begin
     if memo^[i] = '>' then begin
        if i-j <=5 then Quoted := true;
     end;
     inc(i);
  end;

  if i<Memo_Size then inc(i);
  scancrdn :=i;
end;



{----------------------------------------------------------------}
{display current string or all the screen}
Procedure display(RowTop,RowBottom,Memo_Y:Integer;update:boolean);
Var
  i, j, k,l : longint;
begin
  If MemoEditOn then
     DrawInsMode;

  if update then begin

    j := Memo_pgBase;    {Page addr}
    i := RowTop;    {Row counter}

    While (j < Memo_Size) and (i <= RowBottom) do begin
      k := scanCrDn(j);
      l:=k-j;
      If (l > 1) and (Memo^[k-1]=K_LF) and  (Memo^[k-2]=K_CR) then
         Dec(l,2);

      If quoted then SetColor('GR+/N')
                else SetColor('W/N');
      say_bytes(1,i,memo^[j],l);
      If l < 80 then
         fill_char(l+1,i,' ',80-l);
      j := k;
      inc(i);
    end;

    Memo_nxbase:=j;
    While (i <= RowBottom) do begin
      fill_char(1,i,' ',80);
      inc(i);
    end
  end
  else begin
    i := scanCrDn(Memo_lnBase)-Memo_lnbase;
    If (i > 1) and (memo^[Memo_lnbase+i-2]=K_CR) and (memo^[Memo_lnbase+i-1]=K_LF)
       then dec(i,2);
    If quoted then SetColor('GR+/N')
              else SetColor('W/N');
    say_bytes(1,Memo_y+RowTop,memo^[Memo_lnBase],i);
    If i<80 then
       fill_char(i+1,Memo_y+RowTop,' ',80-i);
  end;
  update := False;
end;




{----------------------------------------------------------------}
{Standartize the File Cutters}
Procedure ChangeCutters;
begin
  MemoEditOn := True;
  Crs   := 0;

  While (crs < Memo_Size) do begin
{    crs := scanCrDn(crs);}
    If (Memo^[crs]='{') and  (Memo^[crs+1]='þ') then begin
       Memo^[crs+1]:='>';
       MemoUpdated:=True;
    end else begin
       If (Memo^[crs]='þ') and  (Memo^[crs+1]='>')  and  (Memo^[crs+2]='}') then begin
          Memo^[crs+1]:='þ';
       MemoUpdated:=True;
       end;
    end;
    Inc(crs);
  end;

  crs := 0;
{  display(RowTop,RowBottom,Memo_Y,update);
  SetCursorOn;
}
end;


{----------------------------------------------------------------}
{Remove Soft CR from All the Memo}
Procedure RemoveSoftCR;
begin
  MemoEditOn := True;
  update:=True;
  Crs   := 0;

  While (crs < Memo_Size) do begin
    crs := scanCrDn(crs);
    If (Memo^[crs-1]=K_LF) and  (Memo^[crs-2]='') then begin
       Dec(crs,2);
       DelChar;
       DelChar;
       MemoUpdated:=True;
    end;
  end;

  crs := 0;
{  display(RowTop,RowBottom,Memo_Y,update);
  SetCursorOn;
}
end;






{----------------------------------------------------------------------}
Procedure DrawInsMode;
var
   OldColor:byte;
begin
   OldColor:=TextAttr;
   TextAttr:=Yellow;
   If Key_Ins then
      SAY(75,5,'[Ins]')
   else
      SAY(75,5,'[Ovr]');
   TextAttr:=OldColor;
end;

{----------------------------------------------------------------------}
Procedure ClearInsMode;
var
   OldColor:byte;
begin
   OldColor:=TextAttr;
   SetColor('B+/N');
   SAY(75,5,'ÄÄÄÄÄ');
   TextAttr:=OldColor;
end;




{---------------------------------------------------------}
Procedure BrowseHelp;
Const
   x = 3;
Var
   ch:char;
   OldScreen:ScreenPtr;

begin
   OldColor:=TextAttr;
   OldScreen:=SaveScreen;
   SetColor('GR+/N');
   Box(1,1,80,24,Single,NoShadow);
   SAY(2,24,' ESC ');

  If Alias = 'AREAS' then begin
   SAY(2,1,' Area Lister ');
   SAY(74,1,' Help ');

   SetColor('W/N');
   SAY(x, 2,'Area Keys                                        Reader Help');
   SAY(x, 3,'ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

   SAY(x, 5,'Home, C-PgUp  Move selection bar to first area');
   SAY(x, 6,'End,  C-PgDn  Move selection bar to last area');
   SAY(x, 7,'Enter         Enter the reader for the selected area');
   SAY(x, 8,'Space         Toggle mark on the selected area');
   SAY(x, 9,'Ins           Add a new area');
   SAY(x,10,'Del           Delete the selected area[s]');
   SAY(x,11,'Alt-C         Change Area ID & Description');
   SAY(x,12,'Ctrl-G, num   Go to a specific area number');
   SAY(x,13,'Alt-O         Select Area Order');
   SAY(x,14,'Alt-P         Pack main base (remove deleted records)');
   SAY(x,15,'Alt-L         Make all snipets list');
   SAY(x,16,'Alt-X         Exit, prompt for final decision');
   SAY(x,17,'Ctrl-Q        Exit immediately, no questions asked');
{   SetColor(DarkGray);
   SAY(x,16,'Alt-S         Scan areas - all or marked');
   SAY(x,17,'Alt-O         Shell to DOS');
   SetColor(LightGray);
}
   end else begin
   SAY(2,1,' Message Lister ');
   SAY(74,1,' Help ');
   SetColor('W/N');
   SAY(x, 2,'Message Lister Keys                              Reader Help');
   SAY(x, 3,'ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

   SAY(x, 5,'Esc            Abort message lister');
   SAY(x, 6,'Home, C-PgUp   First message');
   SAY(x, 7,'End, C-PgDn    Last message');
   SAY(x, 8,'Down           Next message');
   SAY(x, 9,'Up             Previous message');
   SAY(x,10,'Ctrl-G, num    Go to a specific message number');
   SAY(x,11,'Enter          Go to reader at the selected message');
   SAY(x,12,'Space          Toggle Mark on the selected message');
   SAY(x,13,'Ins            Enter a new message');
   SAY(x,14,'Del            Delete the selected message[s]');
   SAY(x,15,'Alt-P          Pack current base (remove deleted records)');
   SAY(x,16,'Alt-O          Select Message Order');
   SAY(x,17,'Alt-X          Exit - ask first');
   SAY(x,18,'Ctrl-Q         Quit immediately');
{
   SetColor(DarkGray);
   SAY(x,17,'Alt-S          Go to Marking menu');
   SAY(x,18,'Alt-O          Shell to DOS');
   SetColor(LightGray);
}
   end;

   Repeat
      Ch:=Inkey(0);
   until (ch = K_ESC) or (ch = K_CTRL_Q);

   RestScreen(OldScreen);
   TextAttr:=OldColor;
end;



{---------------------------------------------------------}
Procedure MemoEditHelp;
Const
   x = 3;
Var
   ch:char;
   ScreenNum,LastNum:integer;
   OldScreen:ScreenPtr;
begin
   ScreenNum:=1;
   OldColor:=TextAttr;
   OldScreen:=SaveScreen;
   SetCursorOff;
   If MemoEditOn then LastNum := 4
                 else LastNum := 3;

 Repeat
   SetColor('GR+/N');
   Box(1,1,80,24,Single,NoShadow);
   SAY(2,24,' ESC ');

   If    ScreenNum = 1       then SAY(69,24,'ÄÄÄÄÄ PgDn ')
   else
      If ScreenNum = LastNum then SAY(69,24,'ÄÄÄÄÄ PgUp ')
   else                           SAY(69,24,' PgUp/PgDn ');

   If MemoEditOn then begin
     SAY(2,1,' Internal Editor ');
     SAY(74,1,' Help ');
     SetColor('W/N');
     SAY(x, 2,'Internal Editor Cursor Movements                 Editor Help');
     SAY(x, 3,'ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
{    SAY(x, 4,'');}
   Case ScreenNum of
   1:begin
     SAY(x, 5,'Enter          Terminate paragraph and/or add a new line');
     SAY(x, 6,'Up, Down       Move cursor up/down one line');
     SAY(x, 7,'Left, Right    Move cursor one position left/right');
     SAY(x, 8,'Home           Move cursor to beginning of line');
     SAY(x, 9,'End            Move cursor to the end of the line');
     SAY(x,10,'PgDn           Move cursor one page of lines down');
     SAY(x,11,'PgUp           Move cursor one page of lines up');
     SAY(x,12,'Ctrl-Home      Move cursor to the top line in the display');
     SAY(x,13,'Ctrl-End       Move cursor to the bottom line in the display');
     SAY(x,14,'Ctrl-PgUp      Move cursor to the first line in the message');
     SAY(x,15,'Ctrl-PgDn      Move cursor to the last line in the message');
     SAY(x,16,'Ctrl-Left      Move cursor to the previous word');
     SAY(x,17,'Ctrl-Right     Move cursor to the next word');
     end;
   2:begin
     SAY(x, 5,'Ins            Toggle insert mode');
     SAY(x, 6,'Del            Delete character at the cursor position');
     SAY(x, 7,'BackSpace      Delete character to the left of the cursor');

     SetColor('N+/N');
     SAY(x, 8,'Tab            Add spaces to the next tab-stop');
     SAY(x, 9,'Alt-K, Alt-Y   Delete from cursor position to end of line');
     SAY(x,10,'C-BckSp C-F5   Delete the word to the left of the cursor');
     SAY(x,11,'Ctrl-T,Ctrl-F6 Delete the word to the right of the cursor');
     SAY(x,12,'F4             Duplicates the current line');
     SAY(x,13,'Alt-D, Ctrl-Y  Delete the current line. (Move to Killbuffer)');
     SAY(x,14,'Ctrl-U         Undelete previously deleted lines');
     SAY(x,15,'Alt-1          Change cursor character to uppercase');
     SAY(x,16,'Alt-2          Change cursor character to lowercase');
     SAY(x,17,'Alt-3          Toggle case of the cursor character');

     end;

   3:begin
     SetColor('N+/N');
     SAY(x, 5,'Alt-A          Set a block "anchor" on the current line');
     SAY(x, 6,'Alt-C          Cut current block to Cut''n''Paste buffer');
     SAY(x, 7,'Alt-P          Paste a prev. Cut block at cursor position');
     end;
   4:begin
     SAY(x, 5,'Esc            Abort editing this message - ask first');
     SAY(x, 6,'Alt-S, F2      Save this message');
     SAY(x, 7,'Alt-I, F3      Import file(s) into the message');
     SAY(x, 8,'Alt-X          Exit - ask first');
     SAY(x, 9,'Ctrl-Q         Quit immediately - no asking');
{     SetColor(DarkGray);
     SAY(x, 7,'(no default)   Drop this message - NO ASKING! DANGEROUS!');
     SAY(x, 8,'Alt-H          Change attributes');
     SAY(x, 9,'Alt-O          Shell to DOS');
     SAY(x,11,'Alt-W          Export block to a file');
     SAY(x,12,'F7             Saves the current message as a file');
     SAY(x,13,'F8             Loads the message file saved with F7');
     SAY(x,14,'F9             Calls external spellchecker with message');
}
     end;
   end {case}

   {=========================================}
   end else begin {--- For Message Reader ---}

   SAY(2,1,' Reader Keys ');
   SAY(74,1,' Help ');
   SetColor('W/N');
   SAY(x, 2,'Reader Keys                                      Reader Help');
   SAY(x, 3,'ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');

   Case ScreenNum of
   1:begin
     SAY(x, 5,'Esc            Exit the message reader');
     SAY(x, 6,'Home           Display first part of current message');
     SAY(x, 7,'End            Display last part of current message');
     SAY(x, 8,'Up             Scroll message display');
     SAY(x, 9,'Down           Scroll message display');
     SAY(x,10,'PgUp           Display previous page of message');
     SAY(x,11,'PgDn           Display next page of message');
     SAY(x,12,'Right          Next message');
     SAY(x,13,'Left           Previous message');
     SAY(x,14,'Ctrl-Home, <   First message in the area');
     SAY(x,15,'Ctrl-End,  >   Last message in the area');
{    SAY(x,14,'Ctrl-Home, Ctrl-Left, <   First message in the area');
     SAY(x,15,'Ctrl-End, Ctrl-Right, >   Last message in the area');
}
     SAY(x,16,'Ctrl-G, num    Go to a specific message number');
     end;
   2:begin
     SAY(x, 5,'Alt-C          Change message');
     SAY(x, 6,'Del            Delete current/marked message(s), ask first');
     SAY(x, 7,'Ins            Enter a new message');

     SetColor('N+/N');
     SAY(x, 9,'Ctrl-N         Go directly to the next area');
     SAY(x,10,'Ctrl-P         Go directly to the previous area');
     end;
   3:begin
     SAY(x, 5,'Alt-F          Find string(s) in message header and text');
     SAY(x, 6,'Alt-Z          Find string(s) in message header');
     SAY(x, 7,'Alt-M          Enter the Copy/Move function menu');
     SAY(x, 8,'Alt-W          Write/export message(s) to file or printer');
     SAY(x, 9,'Alt-U          UuDecode all .UUEs in the message');
     SAY(x,10,'Alt-E          Extract all the files from the message');
     SAY(x,11,'Alt-X          Exit, prompt for final decision');
     SAY(x,12,'Ctrl-Q         Exit immediately, no questions asked');
{
     SetColor(DarkGray);
     SAY(x,13,'Alt-S          Enter the marking menu');
     SAY(x,14,'Alt-O, Ct-F10  Shell to DOS');
}
     end;

   end; {case}
   end;

   Ch:=Inkey(0);
   If (Ch = K_PgDn) and (ScreenNum<LastNum) then Inc(ScreenNum);
   If (Ch = K_PgUp) and (ScreenNum>1) then Dec(ScreenNum);

 Until (LastKey = K_ESC) or (LastKey = K_CTRL_Q);

 RestScreen(OldScreen);
 TextAttr:=OldColor;

 If MemoEditOn then
    SetCursorOn;

end;




(*
Procedure FileErase(Fname : string);
var dF : file;
begin
   If FileExist(FName) then begin
      Assign(dF,FName);
      Erase(df);
   end;
end;

*)

{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Procedure UUEncode(InFileName,OutFileName:String);
Const
  SP = Byte(' ');

var
   Triplets: Array[1..15] of TripletType;
   kwar: KwartetType;
   FName: String;
   i,j: Integer;
   InF: File;
   OutF: Text;


    procedure Triplet2Kwartet(Triplet: TripletType; var Kwartet: KwartetType);
    var i: Integer;
    begin
      Kwartet[0] := ( Triplet[0] SHR 2);
      Kwartet[1] := ((Triplet[0] SHL 4) AND $30) +
                    ((Triplet[1] SHR 4) AND $0F);
      Kwartet[2] := ((Triplet[1] SHL 2) AND $3C) +
                    ((Triplet[2] SHR 6) AND $03);
      Kwartet[3] := (Triplet[2] AND $3F);

      for i:=0 to 3 do begin
        if Kwartet[i] = 0 then Kwartet[i] := $40;
        Inc(Kwartet[i],SP)
      end
    end; {Triplet2Kwartet}


begin

   IF Pos('.', Outfilename) = 0 THEN Outfilename := Outfilename + '.uue';

   FName:=InFileName;
   i:=RAT('\',FName);
   If i>0 then FName:=Right(FName,Length(FName)-i);
   i:=Pos(':',FName);
   If i>0 then FName:=Right(FName,Length(FName)-i);

   system.Assign(InF,InFileName);
   FileMode := $40;
   system.reset(InF,1);
   if system.IOResult <> 0 then begin
      WaitForOk('Error: could not open file '+InFileName,'Ok',White+Red*16,White);
   end else begin

     system.Assign(OutF,OutFileName);
     system.rewrite(OutF);
     if system.IOResult <> 0 then begin
       WaitForOk('Error: could not create file '+OutFileName,'Ok',White+Red*16,White);
     end else begin

        writeln(OutF,'begin 644 ',FName);

        repeat
          FillChar(Triplets,SizeOf(Triplets),#0);
          BlockRead(InF,Triplets,SizeOf(Triplets),i);
          system.write(OutF,Char(SP+i));
          for j:=1 to (i+2) div 3 do begin
            Triplet2Kwartet(Triplets[j],kwar);
            system.write(OutF,Char(kwar[0]),Char(kwar[1]),Char(kwar[2]),Char(kwar[3]))
          end;
          system.writeln(OutF)
        until (i < SizeOf(Triplets));

        system.writeln(OutF,'`');
        system.writeln(OutF,'end');
        system.writeln(OutF,'');
        system.close(InF);
        system.Flush(OutF);
        system.close(OutF);
      end;
   end;
end;

(*
Function CheckBinary(var M:MemoType;Mlen:word):boolean;
var
   i:word;
   lBin:boolean;
begin
   lBin := false;

   for i:=0 to MLen-1 do begin
      If M[i] in [#0..#8,#11..#12,#14..#31] then begin
         lBin := true;
         break;
      end;
   end;

   CheckBinary := lBin;
end;

*)


(*

procedure Kwartet2Triplet(Kwartet: KwartetType; var Triplet: TripletType);
var i:integer;
begin
   For i:=0 to 3 do
      Kwartet[i]:=(Kwartet[i]-32) and $3F;
   Triplet[0] := (Kwartet[0] SHL 2) +
                 (Kwartet[1] SHR 4);
   Triplet[1] := Lo((Kwartet[1] SHL 4) +
                 (Kwartet[2] SHR 2));
   Triplet[2] := Lo((Kwartet[2] SHL 6) +
                 Kwartet[3])

end; {Kwartet2Triplet}

Procedure DecodeLine(var nHandle:FileOfByte; Buffer:string);
var
   i:integer;
   Kwartets: record
                StrLen: Byte;
                UUStrLen: Byte;
                kwart: Array[1..64] of KwartetType;
              end absolute Buffer;
   Trip: TripletType;
begin
   for i:=1 to (Kwartets.UUStrLen-32) div 3 do begin
      Kwartet2Triplet(Kwartets.kwart[i],Trip);
      system.write(nHandle,Trip[0],Trip[1],Trip[2])
   end;
   if ((Kwartets.UUStrLen-32) mod 3) > 0 then begin
      Kwartet2Triplet(Kwartets.kwart[i+1],Trip);
      for i:=1 to ((Kwartets.UUStrLen-32) mod 3) do
         system.write(nHandle,Trip[i-1])
   end
end;


{************** UUDECODE **********************************************}
Procedure UUDecode(lProcessBar:boolean);
var
   nHandle:FileOfByte;
   FileName:String[12];
   Buffer:string;
   OldScreen:ScreenPtr;
   LineNum,
   MaxLines,
   i,lMode:Integer;

begin
   FileName:=Spaces(12);
   lMode:=0;
   LineNum:=1;
{!   MaxLines := MLCount;}

   If lProcessBar then begin
      DrawScale(12,19,'Wait a minute! It''s UUdecoding now...',Red,Yellow,LightGray);
      OldScreen:=SaveScreen;
      OldColor:=TextAttr;
   end;

   While LineNum <= MaxLines do begin

      If lProcessBar then
         Scale(MaxLines,LineNum);

{!      Buffer:=MemoLine(LineNum); { Read Next Line }
      Inc(LineNum);

      Case lMode of
      0: begin { Search 'begin' }
            If Left(Buffer,6) = 'begin ' then begin
               system.Delete(Buffer,1,10);
               FileName := AllTrim(Copy(Buffer,1,12));
               i:=Pos(' ',FileName);
               If i > 0 then FileName:=Left(FileName,i-1);
               If not EmptyStr(FileName) then begin
                  System.Assign(nHandle,ExtractDir+'\'+FileName);
                  system.Rewrite(nHandle);
                  lMode:=1;
               End;
            End;
         end;

      1: begin { Decode Current Line if # 'end' }
         If (Buffer = 'end') or (Buffer[1] = '`') then begin
            lMode:=0;
            system.Close (nHandle);
         end else begin
            If buffer[1] <> 'M' then
               lMode:=1;
            DecodeLine(nHandle,Buffer);
            end;
         end;
      end;

   end;

   If lProcessBar then begin
      Scale(MaxLines,MaxLines);
      Delay(1000);
      RestScreen (OldScreen);
      TextAttr:=OldColor;
   End;

end;
*)

{-----------------------------------------}
Procedure MemoEdit(xLeft,yTop,xRight,yBottom:byte);
Var
  c     : Char;
  n,i,
  nLines:Integer;
{  crs   : LongInt;}
  x     : Integer;
  stop  : Boolean;
{  update: Boolean;}



{--------------------------------------------------}
{put cursor after preceding CR or at 0}
Function scanCrUp(i : longint) : longint;
begin
  while (i > 0) do begin
     dec(i);
     If memo^[i{-1}]=K_LF {#$0A} then break;
  end;

  if i > 0 then begin
    dec(i);
    while (i > 0) and (memo^[i]<>K_LF {#$0A}) do dec(i);
  end;
  if i > 0 then inc(i);
  scancrup := i;
end;

Procedure insChar(c : Char); forward;
{Procedure delChar; forward;}
Procedure backChar; forward;

{--------------------------------------------------}
Procedure trimLine;
Var
  i, t, b : longint;
begin
  i   := crs;
  b   := scanCrDn(crs);
  t   := scanCrUp(crs);
  crs := b;

  While memo^[crs] = ' ' do begin
    delChar;
    if i > crs then dec(i);
    if crs > 0 then dec(crs);
  end;
  crs := i;
end;

{--------------------------------------------------}
Procedure checkWrap(c : longint);
Var
  i, t, b : longint;
begin
  b := scanCrDn(c);
  t := scanCrUp(c);
  i := b;
  if i - t >= 79 then begin
    i := t + 79;
    Repeat
      dec(i);
    Until (memo^[i] = ' ') or (i = t);
    if i = t then
      backChar   {just disallow lines that long With no spaces}
    else begin
      memo^[i] := ^M;  {change sp into cr, to wrap}
      update := True;
      if (b < Memo_Size) and (memo^[b] = ^M) and (memo^[succ(b)] <> ^M) then begin
        memo^[b] := ' '; {change cr into sp, to append wrapped part to next
                         line}
        checkWrap(b);  {recursively check next line since it got stuff
                        added}
      end;
    end;
  end;
end;

{--------------------------------------------------}
Procedure changeLines;
begin
  trimLine;
  update := True;  {signal to display to redraw}
end;

{--------------------------------------------------}
Procedure goLeft;
begin
  if (crs > 0) and (crs > Memo_lnbase) then begin
    dec(crs);
    dec(x);
  end
  else Beep;
end;

{--------------------------------------------------}
Procedure goRight;
begin
  if crs >= memo_size then Beep
  else
    if memo^[crs] = K_CR then Beep
    else begin
      inc(crs);
      inc(x);
    end;
end;

{--------------------------------------------------}
Procedure goCtrlLeft;
begin
   While (crs > 0) and (memo^[crs-1] in [#9,' ']) do
      goLeft;

   While (crs > 0) and (memo^[crs-1] > ' ') do
      goLeft;

end;

{--------------------------------------------------}
Procedure goCtrlRight;
begin
  while (memo^[crs] > ' ') and (x<79) and (crs < memo_size) do
    goRight;
  While (x<79) and (memo^[crs] in [' ',#9]) and (crs < memo_size) do
    goRight;
end;

{--------------------------------------------------}
Procedure goHome;
begin
  crs := Memo_lnbase;
  x:=0;
end;

{--------------------------------------------------}
Procedure goEnd;
var
   i:longint;
begin
  i:=scancrdn(crs);
  If ((i - crs ) > 1) and (memo^[i-1]=K_LF) and (memo^[i-2]=K_CR) then
     Dec(i,2);
  Inc(x,i-crs);

  If x > 79 then begin
     x:=79;
     i:=Memo_lnbase+79;
  end;
  inc(crs,i-crs);
end;


{--------------------------------------------------}
Procedure goTop;
begin
  Memo_pgbase := 0;
  Memo_lnBase := 0;
  crs := Memo_lnBase;
  x:=0;
  Memo_y:=0;
  update:=true;
end;

{--------------------------------------------------}
Procedure goBottom;
begin
  Memo_lnBase := memo_size;
  While (Memo_lnBase>1) and (Memo^[Memo_lnBase-1]<>K_LF) and (Memo^[Memo_lnBase-2]<>K_CR) do
     dec(Memo_lnBase);

  Memo_pgbase:=memo_size;
  Memo_y:=0;
  while (Memo_pgbase > 0) and (Memo_y < nLines-1) do begin
     Memo_pgbase:= scanCrUp(Memo_pgbase);
     inc(Memo_y);
  end;
  crs := Memo_lnBase;
  x:=0;
  if Memo_y=nLines then dec(Memo_y);
  update:=true;
end;

{--------------------------------------------------}
Procedure goUp;
Var
  i : longint;
begin
  If not MemoEditOn then begin
     Memo_LnBase := Memo_PgBase;
     crs := Memo_LnBase;
     Memo_y:=0;
  end;
  if Memo_lnBase > 0 then begin
    Memo_lnBase := scanCrUp(Memo_lnBase);
    crs := Memo_lnBase;
    i := scanCrDn(crs) - crs-2;
    if i >= x then
      inc(crs, x)
    else
      inc(crs,i);
    if Memo_y > 0 then dec(Memo_y)
    else begin
      If Memo_pgbase > 0 then begin
        Memo_pgbase:=scancrup(Memo_pgbase);
        Memo_nxbase:=scancrup(Memo_nxbase);
        Scroll(ColLeft,RowTop,ColRight,RowBottom,Down);
      end;
    end;
  end;
end;


{--------------------------------------------------}
Procedure goDown;
Var
  i : longint;
begin
  If not MemoEditOn then begin
     Memo_lnBase := scanCrUp(Memo_NxBase);
     crs := Memo_LnBase;
     Memo_y := nLines-1;
  end;

{SetCursorOn;}
  i := scanCrDn(crs);
  if (i - crs) < 2 then Exit;
  If (Memo^[i-1]<>K_LF) and (Memo^[i-2]<>K_CR) then Exit;
  If (not MemoEditOn) and (Memo_nxBase =Memo_Size) then Exit;
  crs:=i;

  Memo_lnBase := crs;
  i := scanCrDn(crs) - crs;
  If i > 0 then
    If (Memo^[crs+i-1]=K_LF) and (Memo^[crs+i-2]=K_CR) then dec(i,2);

  if i >= x then
    inc(crs, x)
  else begin
    inc(crs, i);
    x:=i;
 end;

  if Memo_y < nLines-1 then inc(Memo_y)
  else begin
        Memo_nxbase:=scancrdn(Memo_nxbase);
        Memo_pgbase:=scancrdn(Memo_pgbase);
        Scroll(ColLeft,RowTop,ColRight,RowBottom,Up);
  end;

end;

{--------------------------------------------------}
Procedure goPgUp;
Var
  i : Integer;
begin
  If Memo_pgbase = 0 then beep
  else begin
     For i := RowTop to RowBottom do begin
        Memo_pgbase:=scancrup(Memo_pgbase);
        If Memo_pgbase = 0 then break;
     end;
     x:=0;
     Memo_y:=0;
     Memo_lnbase := Memo_pgbase;
     crs:=Memo_lnbase;
     update :=true;
  end;
end;

{--------------------------------------------------}
Procedure Mybreak;
begin
  x:=x;
end;

{--------------------------------------------------}
Procedure goPgDn;
Var
  i : integer;
begin
  if Memo_nxbase < memo_size then begin
     For i := RowTop to RowBottom do begin
        Memo_nxbase:=scancrdn(Memo_nxbase);
        Memo_pgbase:=scancrdn(Memo_pgbase);
        If Memo_nxbase >= memo_size then break;
     end;
     Memo_lnbase := Memo_pgbase;
     crs:=Memo_lnbase;
     x:=0;
     Memo_y:=0;
     update :=true;
  end;
end;

{--------------------------------------------------}
Procedure insChar(c : Char);
begin

  If Key_Ins then begin { Insert Mode }
     if memo_size = maxMemoSize then begin
       Beep;
       RunError(999); {'Memo Field too big'}
       exit;
     end;
     move(memo^[crs], memo^[succ(crs)], memo_size - crs);
     memo^[crs] := c;
     inc(crs);
     inc(x);
     inc(Memo_nxbase);
     inc(memo_size);

     if c = K_CR then begin
        move(memo^[crs], memo^[crs+1], memo_size - crs);
        memo^[crs] := K_LF;
        dec(crs);
        inc(memo_size);
        goDown;
        goHome;
        update := true;
     end;

     MemoUpdated := True;
  end else begin  { OverWrite Mode }
     if c = K_CR then begin
        goDown;
        goHome;
     end else begin
        If (memo^[crs]=K_CR) or (crs=Memo_Size) then
           move(memo^[crs], memo^[succ(crs)], memo_size - crs);
        memo^[crs] := c;
        inc(crs);
        inc(x);
        inc(Memo_nxbase);
        inc(memo_size);
        MemoUpdated := True;
     end;
  end;

{  checkWrap(crs);}
end;

{--------------------------------------------------}
Procedure backChar;
begin
  if (crs > 0) then begin
    goLeft;
    delChar;
{    MemoUpdated := True;}
  end;
end;

{--------------------------------------------------}
Procedure deleteLine;
Var
  i : longint;
begin
  i := scanCrDn(crs);
  crs := Memo_lnbase;

  if i < memo_size then begin
    move(memo^[i], memo^[crs], memo_size - i);
{    dec(endF);}
  end;
  dec(memo_size, i - crs);
  update := true;
  MemoUpdated := True;
end;


{--------------------------------------------------}
Function FormCutter(const fname:String):string80;
{ Form Cut Line with FileName }
var cLine:string80;
begin
  cLine := '{>'+CutLine+' '+CutLine2+UPPER(FName)+' ';
  cLine := cLine+ Replicate('þ',77-Length(cLine))+'}'+CRLF;
  FormCutter := cLine;
end;


{--------------------------------------------------}
Procedure MemoInsert;
{Insert the file into the Msg }
var
   StartDir,cCutter :String80;
   FileName,
   TmpFileName,
   cFName:String;
   cFExt :String[4];
   IsBinary: boolean;
   j,l : longint;
begin

   StartDir:=GsGetExpandedFile(ImportDir);

   M.Init(3,7,28,12, ' Import ',
            LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
   M.Add(mnFileAsText);    {1}
   M.Add(mnBinaryAsUUE);   {2}
   M.Add(mnBinaryAttach);  {3}
   M.Add(mnNothing_Quit);  {4}

   Ans:=M.ReadMenu(1);
   M.Done;

   If Ans = 4 then Exit;
   If Ans = 0 then Exit;

   IsBinary := (Ans = 2);
   FileName:=SelectFile(3,5,28,22, ' Import: ',
             LightGray,White+Blue*16,Yellow,LightRed,White,
             StartDir,AllTheFiles,True);

   If FileName <> '' then begin

      TmpFileName:=FileName;
      If IsBinary then begin
         TmpFileName:=ChangeFileExt(FileName,'.UUE');
         UuEncode(FileName,TmpFileName);
      end;

      l := GsFileSize(TmpFileName);

      If Ans = 3 then begin {Work with Attachment}
         AttImport(FileName);
      end else begin        {Work with TEXT and UUE}
         If l+80+ Memo_Size > MaxMemoSize then begin
            Beep;
            WaitForOk('File "'+FileName+'" too big!','Ok',LightGray*16,Cyan*16)
            {!!! à¥¤«®¦¨âì à §¡¨âì ­  ­¥áª®«ìª® á¥ªæ¨©!!!}
         end else begin
            MemoRead(TmpFileName,Memo_Pack,l);
            If IsBinary then
               GsFileDelete(TmpFileName);

            cCutter:=FormCutter(ExtractFileName(TmpFileName));

   {      for j:=1 to Memo_Size-crs do
            memo^[Memo_Size-j+l]:=memo^[Memo_Size-j];
   }
            If Memo_Size > 0 then begin
               for j:=Memo_Size-1 downto crs do
                  memo^[j+l+Length(cCutter)]:=memo^[j];
            end;

            move(cCutter[1], memo^[crs], Length(cCutter));  {Put Cutter   }
            Inc(Memo_Size,Length(cCutter));

            move(Memo_Pack^[0], memo^[crs+Length(cCutter)], l);     {Put the File }
            Inc(Memo_Size,l);

            update := true;
{           dStatus := Updated;}
            MemoUpdated := True;
         end;
      end;
   end;
end;





{--------------------------------------------------}
Procedure CheckForDrop;
begin
   If MemoEditOn then begin
       If AskYesNo(3,6, 'Drop This Msg?') then begin
         stop := True;
         MemoDropped:=True;
         MemoUpdated:=False;
      end;
   end else begin
      Stop:=True;
   end;
end;
{--------------------------------------------------}
Procedure CheckForSave;
begin
   If MemoEditOn then begin
       M.Init(3,6,28,10, 'Save This Msg?',
                LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
       M.Add(mnYesPlease);
       M.Add(mnNoDropIt);
       M.Add(mnContinueEditing);

       Ans:=M.ReadMenu(1);
       M.Done;

       If Ans = 1 then begin
          MemoDropped:=False;
          WriteMemo('TEXT');
          stop:=True;
       end;

       If Ans = 2 then begin
          stop:=True;
          MemoUpdated:=False;
          MemoDropped:=True;
       end;
   end;
end;

Procedure FileAttach;
begin
end;

{----------------------------------------------}
{------------------ MEMOEDIT ------------------}
{----------------------------------------------}
{Procedure MemoEdit(xLeft,yTop,xRight,yBottom:byte);}
begin
  ColLeft:=xLeft;
  ColRight:=xRight;
  RowTop:=yTop;
  RowBottom:=yBottom;
  x:=0;
  Memo_y:=0;
  crs:= 0;
  Memo_pgbase := 0;
  Memo_lnbase := 0;
  nLines := RowBottom-RowTop +1;
  update := True;
  Stop   := false;

  If MemoEditOn then
     SetCursorOn;

  MemoDropped:=False;
  MemoUpdated:=False;

  If MemoEditOn then
     DrawInsMode;

  While not Stop do begin
    display(RowTop,RowBottom,Memo_Y,update);

    SAY(30,1,PadR(InsCommas(IntToStr(MemAvail)),12));

    GotoXY(x+1,Memo_y+RowTop);

    c := InKey(0);

    if Key_Func then begin
{      c := InKey(0);}
      Case LastKey of
      K_Ins        : if not MemoEditOn then Stop:=True
                     else begin
                        Key_Ins := not Key_Ins;
                        DrawInsMode;
                     end;
      K_F1         : begin                             { Help            }
                        MemoHelpProc;
                        If LastKey = K_CTRL_Q then
                           Stop:=True;
                     end;
      K_F2         : if MemoEditOn then CheckForSave;  {                 }
(*{test}  K_F5         : if (MemoEditOn) then begin
                          dbfactive^.gsMemo2File('ATTACHME','TMP.OUT');
                       end;                            {                 }
{test}  K_F6         : if (MemoEditOn) then begin
                          dbfactive^.gsFile2Memo('ATTACHME','TMP.INP');
                          DBFActive^.gsFieldPut('PROJECT', 'TMP.INP');
                          MemoUpdated := True;
{                          DBFActive^.gsReplace;}
                       end;                            {                 }
*)
      K_F3,
      K_Alt_H      : begin {Remove '-LF'    }
                        RemoveSoftCR;
                        If MemoUpdated then
                           SetCursorOn;
                     end;
      K_Alt_K      : begin {Remove '-LF'    }
                        ChangeCutters;
                        If MemoUpdated then
                           SetCursorOn;
                     end;
      K_Alt_I      : if MemoEditOn then MemoInsert;    {Insert File      }
      K_Alt_C      : if not MemoEditOn then Stop:=True;{Change Rec       }
{      K_Alt_A      : if not MemoEditOn then Stop:=True;{Attach the File  }
      K_Alt_A      : if MemoEditOn then begin          {Insert $About}
                        MemoInsString(crs,'{>$About}');
                    end;
      K_Alt_D      : if MemoEditOn then begin         {Insert $Description}
                        MemoInsString(crs,'{>$Description}');
                    end;
      K_Alt_E      : if not MemoEditOn then Stop:=True;{Extract          }
      K_Alt_F      : if not MemoEditOn then Stop:=True;{Find in msg text }
      K_Alt_M      : if not MemoEditOn then Stop:=True;{Copy/Move Rec    }
      K_Alt_S      : if MemoEditOn then CheckForSave;  {                 }
      K_Alt_U      : if not MemoEditOn then Stop:=True;{UUDecode         }
      K_Alt_W      : if not MemoEditOn then Stop:=True;{WriteToFile      }
      K_Alt_X      : if not MemoEditOn then Stop:=True;{Ask & Quit       }
      K_Alt_Z      : if not MemoEditOn then Stop:=True;{Find in a header }
      K_Left       : if MemoEditOn then goLeft
                                   else Stop := true;
      K_Right      : if MemoEditOn then goRight
                                   else Stop := true;
      K_Ctrl_Left  : if MemoEditOn then goCtrlLeft;
{                                   else Stop := true;}
      K_Ctrl_Right : if MemoEditOn then goCtrlRight;
{                                   else Stop := true;}
      K_Ctrl_Home  : if not MemoEditOn then Stop := True;
      K_Ctrl_End   : if not MemoEditOn then Stop := True;
      K_Up         : goUp;
      K_PgUp       : goPgUp;
      K_Ctrl_PgUp  : goTop;
      K_Down       : goDown;
      K_PgDn       : goPgDn;
      K_Ctrl_PgDn  : goBottom;
      K_Ctrl_End   : mybreak;
      K_Home       : if MemoEditOn then goHome
                                   else goTop;
      K_End        : if MemoEditOn then goEnd
                                   else goBottom;
      K_Del        : if MemoEditOn then delChar
                                   else Stop:=True;
      end
    end
    else  { not Functional Keys}

      Case LastKey of
        K_SPACE  : if not MemoEditOn then Stop:=True {Mark Current rec }
                    else insChar(c);
        K_Ctrl_L : if not MemoEditOn then Stop:=True;{Find Next rec    }
        K_Ctrl_G : if not MemoEditOn then Stop:=True;{Go to the N rec  }
        K_Ctrl_Q : if not MemoEditOn then Stop:=True;{Quit Immediatelly}
        K_BS     : if MemoEditOn then backChar;
        K_CTRL_Y : if MemoEditOn then deleteLine;
        K_CR     : if MemoEditOn then InsChar(c);
        K_Esc    :    CheckForDrop;
        K_LeftSign,
        K_LeftRus: if not MemoEditOn then Stop := true
                   else insChar(c);
        K_RightSign,
        K_RightRus: if not MemoEditOn then Stop := true
                   else insChar(c);
        '0'..'9'  : if not MemoEditOn then Stop:=True
                    else insChar(c);
        K_TAB     : if MemoEditOn then begin
                       For n:=1 to 8-(x mod 8) do
                          insChar(K_Space);
                    end;
      else
        If MemoEditOn then
          insChar(c);
      end;
  end;

  If LastKey <> K_CTRL_Q then begin
     ClearInsMode;
     SetCursorOff;
  end;
  MemoEditOn   := False;
  SetCursorOff;
end;


{----------------------------------------------}
{------------------ MEMOSAY  ------------------}
{----------------------------------------------}
Procedure MemoSay(ColLeft,RowTop,ColRight,RowBottom:byte);
begin
  Memo_pgbase := 0;
  Memo_lnbase := 0;
  MemoEditOn := False;
  display(RowTop,RowBottom,Memo_Y,True);

end;







Procedure MemoDelLine(linenum : integer);
begin
   MemoUpdated := True;
{   dStatus := Updated;}
{VV   if MemoCollect^.Count = 0 then exit;
   if linenum < 0 then MemoCollect^.AtFree(MemoCollect^.Count-1)
      else if linenum < MemoCollect^.Count then
          MemoCollect^.AtFree(linenum);
}
end;



function MemoGetLine(linenum : integer) : String;
var
   i,j: word;
   s:string;
begin
   j:=0;
   s:='';
   For i:= 1 to LineNum-1 do begin
      j:=ScanCrDn(j);
   end;

   If j >= Memo_Size then
      s:=''
   else begin
      i:=ScanCrDn(j);
      move(memo^[j],s[1],i-j);
      s[0]:=chr(i-j);
      If Right(s,2) =#$0D#$0A then s[0] := chr(i-j-2);
   end;

   MemoGetLine := s;
end;


Function MemoLines : integer;
var
   i:word;
   l:integer;
begin
   i:=0;
   l:=0;
   While i < Memo_Size do begin
      i:=scancrdn(i);
      If i < Memo_Size then Inc(l);
   end;
   MemoLines := l;
end;

Procedure ReadMemo(fnam: string);
begin
   Memo_PackSize:=MaxMemoSize;
   MemoLoad(fnam, Memo_Pack^, Memo_PackSize);
   Memo_Size := UnZip(Memo_Pack,Memo,Memo_PackSize);
   MemoUpdated:=False;
end;

Procedure WriteMemo(fnam: string);
begin
   Memo_PackSize := Zip(Memo,Memo_Pack,Memo_Size);
   MemoSave(fnam, Memo_Pack^, Memo_PackSize);
{   MemoUpdated:=False;}
end;


(*
{---------------LzPack/LzUnPack Routines-------------------------------}
Procedure GetBlock(Var Targ; NoBytes: Word; Var Actual_Bytes: Word); Far;
begin
 if NoBytes > (SourceLen-SourceAddr) then
   Actual_Bytes:=SourceLen-SourceAddr
 else
   Actual_Bytes:=NoBytes;

If SourceAddr > 3900 then begin
   NoBytes:=TargetLen;
end;

 move(Source^[SourceAddr],Targ,Actual_Bytes);
 Inc(SourceAddr,Actual_Bytes);
{ Dec(BytesLeft, Actual_Bytes);}
end;

Procedure PutBlock(Var Sourc; NoBytes: Word; Var Actual_Bytes: Word); Far;
begin
If SourceAddr > 3900 then begin
   NoBytes:=NoBytes;
end;
  move(Sourc,Target^[TargetAddr],NoBytes);
  Inc(TargetAddr,NoBytes);
  Actual_Bytes:=NoBytes;
end;

Procedure GSO_FXMemo20.LZPack(Var Src, Trg:MemoPtr; var SrcLen, TrgLen:longint);
begin
   Source:=src;
   Target:=trg;
   SourceLen := SrcLen;
{   TargetLen := TrgLen;}
   TargetLen := 0;
   BytesLeft  := SrcLen;
   SourceAddr := 0;
   TargetAddr := 0;
   LZHPack(SrcLen,GetBlock,PutBlock);
   TrgLen := TargetAddr;
end;

Procedure LZUnPack(Var Src, Trg:MemoPtr; var SrcLen, TrgLen:longint);
begin
   Source:=src;
   Target:=trg;
   SourceLen := SrcLen;
   BytesLeft := SrcLen;
   TargetLen := 0{TrgLen};
   SourceAddr := 0;
   TargetAddr := 0;
   LZHUnPack(TrgLen{SrcLen},GetBlock,PutBlock);
   TrgLen := TargetAddr;
end;
*)




{============ Unit Initialization ========================}
begin
   ExtractDir  := '';         { Project Extract Directory }
   ImportDir   := '';         { Project Import Directory }
   MemoFileName:= '';
   TmpFileName := '';
   FileToWrite := '';

   New(Memo_Pack);
   New(Memo);

   MemoEditOn   := False;
   MemoUpdated  := False;
   MemoHelpProc := MemoEditHelp;
   Memo_Size:=0;
   Memo_PackSize:=0;
end.
