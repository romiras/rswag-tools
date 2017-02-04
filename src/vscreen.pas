unit vScreen;
{-----------------------------------------------------------------------------
                           Screen Handler Routines
------------------------------------------------------------------------------}
{$I GSF_FLAG.PAS}
interface

uses
    Crt,
    Dos,
    vString;

Type

   ScreenPtr  = ^ScreenType;
   ScreenType = array [1..25,1..80] of word;
   FrameChars = array [1..8] of Char; { Window frame characters }
   Char128    = array [1..128] of char;

BoxType    = (NoFrame,Single,Double,Mixed);
ShadowType = (NoShadow,Shadow);
ScrollType = (Up,Down);
(*
   WinState = record    { Window state record }
     WindMin, WindMax: Word;
     WhereX, WhereY: Byte;
     TxtAttr: Byte;
     CurShape:Word;
   end;

   TitleStr = string80;   { Window title string }
   TitleStrPtr = ^TitleStr;

   WinRecPtr = ^WinRec;
   WinRec = record
      Next: WinRecPtr;
      State: WinState;
      Title: TitleStrPtr;
      TxtAttr, FrameAttr,TitleAttr, Frame,ShadType: Byte;
      Buffer: Pointer;
   end;
*)

Const

   { Standard frame character sets }
   Frames:Array[0..3] of FrameChars = (
               '        ',   {NoFrame}
               'ÚÄ¿³ÙÄÀ³',   {Single}
               'ÉÍ»º¼ÍÈº',   {Double}
               'ÚÄ·º¼ÍÔ³');   {Mixed }


var
   GetTextAttr: byte;
   Scrn_p     : ScreenPtr;
   Scrn_ScB   : Boolean;
   Scrn_Segmt : word;
   Scrn_Mode  : integer;
   ScaleX,ScaleY,ScaleColor:byte;
{   TopWindow: WinRecPtr;
   WindowCount: Integer;
}
Function  SaveScreen: ScreenPtr;
procedure RestScreen(Var Scr :ScreenPtr);
procedure SaveBox(xLeft,Top,xRight,Bottom:byte;Var Scr :ScreenPtr);
procedure RestBox(xLeft,Top,xRight,Bottom:byte;Var Scr :ScreenPtr);
procedure Paint(cx,cy,bx,by,color : integer);    {Set Box Color}
procedure Say_Char(cx,cy : integer; ch : char);  {Write char}
procedure Fill_Char(cx,cy : integer; ch : char;n:integer);  {Write n char}
procedure SAY(cx,cy : integer; S : String);      {write string}
procedure Say_Bytes(cx,cy : integer; var S;n:word);  {write string}
Procedure SetColor (ColorStr:string);
Procedure RestColor (nColor:byte);
Procedure SaveColor (Var nColor:byte);
Procedure SetCursorOff;
Procedure SetCursorOn;
Procedure Box(x1,y1, x2, y2:integer; Box: BoxType;Shadow:ShadowType);
Procedure ClearLine(y:byte);
Procedure Scroll(Left,Top,Right,Bottom:byte;UpDown:ScrollType);
Procedure DrawScale (X,Y:byte;Title:string;BoxColor,TitleColor,ColorScale:Byte);
Procedure Scale (ColAll,Col :LongInt);
{Function  ColorNum ( cColor: String12 ):Byte;}


implementation

var
   reg    : Registers;

Const
                        {0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 }
                        {123123123123123123123123123123123123123123123123}
  ColorName:String[48] = 'N  B  G  BG R  RB GR W  N+ B+ G+ BG+R+ RB+GR+W+ ';

{************************************************************
 *                         ColorNum                         *
 ************************************************************}
{Convert ONE Clipper Character Color String to Pascal TextAttr}
{          f.e. "GR+/BG" -> Yellow + Cyan * 16            }
Function ColorNum ( cColor: String12 ):byte;
Var
  colorSAY,colorFON:String[4];
  NcolorSAY,NcolorFON,slash,star,Blink:byte;
begin
  {Check for blinking}
  blink     :=0;
  star     := Pos('*',cColor);
  If star <> 0 then begin
    Delete(cColor,star,1);
    blink:=$80;
  end;
  {Divide cColor to Text Color & Background color}
  cColor    := UPPER( AllTrim(cColor));
  slash     := Pos('/',cColor);

  colorSAY  := Copy (cColor,1,slash - 1);
  colorFON  := Copy (cColor,slash + 1,Length(cColor)-slash);
  NcolorSAY := (Pos(colorSAY,ColorName )-1) div 3;
  NcolorFON := (Pos(colorFON,ColorName )-1) div 3;

  ColorNum  := (NcolorSAY + NcolorFON*16) or blink;
end;


Procedure RestColor (nColor:byte);
begin
   TextAttr:=nColor;
end;

Procedure SaveColor (Var nColor:byte);
begin
   nColor:=TextAttr;
end;

Procedure SetColor (ColorStr:string);
var
  n,comma:byte;
  cColor:String[12];
begin
  ColorStr:=AllTrim(ColorStr);
  comma := Pos(',',ColorStr);
  If comma = 0 then comma:=Length(ColorStr)+1;

  TextAttr:=ColorNum(Copy(ColorStr,1,comma-1));
  Delete(ColorStr,1,comma);
  GetTextAttr:=ColorNum(ColorStr);
end;

{********************************************************}
{ ÄÄÄÄ à¨áã¥â èª «ã ¯à®æ¥áá    ÄÄÄÄ }
Procedure DrawScale (X,Y:byte;Title:string;BoxColor,TitleColor,ColorScale:Byte);
var
   OldColor:byte;
begin
   OldColor:=TextAttr;

   ScaleX:=7{x};
   ScaleY:=12{y};
   ScaleColor:=ColorScale;

   Title:=AllTrim(Title);
   If Length(Title)>60 then
         Title:=Left(Title,60);

   TextAttr:=BoxColor;
   Box(ScaleX,ScaleY,ScaleX+68,ScaleY+2,Mixed,Shadow);
   TextAttr:=Yellow;
   SAY(ScaleX+(61-Length(Title)) div 2, ScaleY, Title);

   TextAttr:=ScaleColor;
{   SAY(X+1, Y+2, 'ÆÍÍÍÏÍÍÍØÍÍÍÏÍÍÍØÍÍÍÏÍÍÍØÍÍÍÏÍÍÍØÍÍÍÏÍÍÍµ  0.0%');}
   SAY(ScaleX+1, ScaleY+1,
   '°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°   0.0%');

   TextAttr:=OldColor;

end;

{---------------------------------------------------------------}
Procedure Scale (ColAll,Col :LongInt);
{ ÄÄÄÄ ‡ ¯®«­ï¥â èª «ã ¯à®æ¥áá    ÄÄÄÄ }
var
   Max,
   Current,
   Percent:Real;
   ScaleLength,
   OldColor:byte;

begin
   OldColor:=TextAttr;

   Current := Col;
   Max := ColAll;
   If Max = 0 then Max := 1;
   Percent := Current / Max;

   If Percent > 1.00 then Percent:=1.00;

   ScaleLength :=Trunc(Percent * 60 + 1);

   TextAttr:=ScaleColor;
   SAY(ScaleX+1, ScaleY+1, Replicate('Û',ScaleLength));
   SAY(ScaleX+62,ScaleY+1, Real2Str(Percent * 100,5,1));

   TextAttr:=OldColor;
end;



{-------------------------------------------------}
{----- ‘®åà ­¨âì íªà ­ -------------------------- }
Function SaveScreen: ScreenPtr;
var scr:ScreenPtr;
begin
   New(Scr);
   move(Scrn_p^,Scr^,4000);
   SaveScreen:=Scr;
end;

{-------------------------------------------------}
{----- ‚®ááâ ­®¢¨âì ¢¥áì íªà ­ ------------------ }
procedure RestScreen(Var Scr :ScreenPtr);
begin
   move(Scr^,Scrn_p^,4000);
   Dispose(Scr);
end;


{-------------------------------------------------}
procedure SaveBox(xLeft,Top,xRight,Bottom:byte;Var Scr :ScreenPtr);
{----- ‘®åà ­¨âì ç áâì íªà ­  ------------------- }
Var
   lstr,i:integer;
begin
   lStr:=(xRight-xLeft+1) shl 2; {Box width}

   For i:=Top to Bottom do
      move(Scrn_p^[i,xLeft],Scr^[i,xLeft],lstr);
{     For j:=xLeft to xRight do begin
        move(Scrn_p^[i,j],Scr^[i,j],lstr);
     end;
}

end;

procedure RestBox(xLeft,Top,xRight,Bottom:byte;Var Scr :ScreenPtr);
{----- ‚®ááâ ­®¢¨âì ç áâì íªà ­  ------------------ }
Var
   lstr,i,j:byte;
	Index:Integer;
begin
   lStr:=(xRight-xLeft+1) shl 2;

   For i:=Top to Bottom do
      move(Scr^[i,xLeft],Scrn_p^[i,xLeft],lstr);
{
   For i:=Top to Bottom do
      For j:=xLeft to xRight do begin
         move(Scr^[i,j],Scrn_p^[i,j],lstr);
      end;
}
end;



(**********************************************)
Procedure ClearLine(y: byte);
begin
{   GotoXY(1,y);}
   SAY(1,y,Spaces(80));
end;


{ ---------------------------------------------------------- }
Procedure Box(x1,y1, x2, y2:integer; Box: BoxType;Shadow:ShadowType);
{ ÄÄÄÄ à¨áã¥â ¯àï¬®ã£®«ì­¨ª   ÄÄÄÄ}

var
   i : Integer;
   Frame:FrameChars;

Begin
   Frame:=Frames[integer(box)];

   SAY(x1,y1,Frame[1]+Replicate(Frame[2],x2-x1-1)+Frame[3]);
   For i:=y1+1 to y2-1 do
      SAY(x1,i,Frame[8]+Spaces(x2-x1-1)+Frame[4]);
   SAY(x1,y2,Frame[7]+Replicate(Frame[6],x2-x1-1)+Frame[5]);

   If Boolean(Shadow) then begin
      Paint(x2+1,y1+1,x2+2,y2,  DarkGray);
      Paint(x1+1,y2+1,x2+2,y2+1,DarkGray);
   end;

End;


PROCEDURE SetCursorOff;Assembler;
(*BEGIN
   reg.ah := $03;              { Service 3 }
   INTR($10,reg);              { Intr 10. Get scan lines}
   reg.cx := reg.cx OR $2000;  { Set bit 5 to 1}
   reg.ah := $01;              { Service 1 }
   INTR($10,reg);              { Intr 10 resets cursor}
*)
Asm
   mov ah,1
   mov ch,32
   mov cl,0
   int 10h
end;
{END;}

PROCEDURE SetCursorOn;Assembler;
(*BEGIN
   reg.ah := $03;               { Service 3 }
   INTR($10,reg);               { Intr 10. Get scan lines}
   reg.cx := reg.cx AND $DFFF;  { Set bit 5 to 0}
   reg.ah := $01;               { Service 1 }
   INTR($10,reg);               { Intr 10 resets cursor}
*)
ASM
   mov ah,1
   mov ch,6
   mov cl,7
   int 10h

END;

{ ---------------------------------------------------------- }
Procedure Scroll(Left,Top,Right,Bottom:byte;UpDown:ScrollType);Assembler;
(*
begin
  if UpDown >0 then Reg.AH := 7
               else Reg.AH := 6;
  Reg.AL := Lo(Abs(UpDown));
  Reg.CH := Top - 1;
  Reg.CL := Left - 1;
  Reg.DH := Bottom - 1;
  Reg.DL := Right - 1;
  Reg.BH := TextAttr;
  Intr($10,Reg);
*)
Asm
  Mov AH,6
  CMP UpDown,UP
  JZ  @1
  Mov AH,7
@1:
  Mov AL,1
  mov CH, Top
  dec CH
  mov CL, Left
  dec CL
  mov DH, Bottom
  dec DH
  mov DL, Right
  dec DL
  mov BH, TextAttr
  Int 10h

end; { Scroll }


procedure Say_Char(cx,cy : integer; ch : char);
var
   valu : word;
BEGIN
   valu := (TextAttr shl 8) + byte(ch);
   If (cx <= lo(WindMax)+1) and (cy <= hi(WindMax)+1) then
      scrn_p^[cy+hi(WindMin),cx+lo(WindMin)] := valu;
END;

procedure SAY(cx,cy : integer; S : String);
var
   i:byte;
begin
   For i:=1 to length(S) do
     Say_Char(cx+i-1,cy,S[i]);
end;

procedure Say_Bytes(cx,cy : integer; var S ;n:word);  {write string}
var
   i,x:byte;
begin
   i:=1;
   x:=cx+i-1;
   while (i <= n) and (x <= lo(windmax)+1) do begin
     Say_Char(x,cy,char128(S)[i]);
     inc(x);
     inc(i);
   end;
end;


procedure Fill_Char(cx,cy : integer; ch : char;n:integer);  {Write n char}
var
   i:byte;
begin
   For i := 1 to n do begin
     If i > lo(WindMax)+1 then break;
     Say_Char(cx+i-1,cy,ch);
   end;
end;

procedure Paint(cx,cy,bx,by,color : integer);
var
   i,j,x,y : integer;
   x1, y1, x2, y2  : word;
begin
   color := color shl 8;

   x1 := cx + lo(WindMin);
   y1 := cy + hi(WindMin);
   x2 := bx + lo(WindMin);
   y2 := by + hi(WindMin);
   for y := y1 to y2 do begin
      for x := x1 to x2 do begin
         scrn_p^[y,x] := color + lo(scrn_p^[y,x]);
      end;
   end;
end;

function Dos_Mode : integer;
begin
   Scrn_Mode := LastMode;
   if Scrn_Mode = Mono then begin
      TextMode(Mono);
      Scrn_Segmt := SegB000;
   end
   else begin
      TextMode(CO80);
      Scrn_Segmt := SegB800;
   end;
   Dos_Mode := Scrn_Mode;
end;



begin
   GetTextAttr:= TextAttr;
   Scrn_ScB   := false;
   Scrn_Mode  := Dos_Mode;
   TextAttr   := LightGray;
   scrn_p     := ptr(Scrn_Segmt,0);
   ScaleX     := 0;
   ScaleY     := 0;
   ScaleColor := LightGray;

end.
