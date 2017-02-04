unit vKBd;
{-----------------------------------------------------------------------------
                           Keyboard Input Routines

------------------------------------------------------------------------------}

interface
{$I GSF_FLAG.PAS}

uses
   CRT,
   DOS,
   vScreen,
   gsf_date,
   vString;

const
   BeepTime = 200;
   BeepFreq = 600;

   K_Null = #0;                     {Null Character}
   K_Bs   = #8;                     {Backspace}
   K_Tab  = #9;                     {Tab}
   K_LF   = #10;                    {Line Feed}
   K_CR   = #13;                    {Return}
   K_Shift_Tab = #15;               {Shift-Tab}
   K_Esc  = #27;                    {Escape}
   K_Space= #32;                    {Space}
   K_LeftSign  = '<';
   K_RightSign = '>';
   K_LeftRus   = 'Б';
   K_RightRus  = 'Ю';

   K_Alt_A  = #30;                    {Alt-A}
   K_Alt_B  = #48;                    {Alt-B}
   K_Alt_C  = #46;                    {Alt-C}
   K_Alt_D  = #32;                    {Alt-D}
   K_Alt_E  = #18;                    {Alt-E}
   K_Alt_F  = #33;                    {Alt-F}
   K_Alt_G  = #34;                    {Alt-G}
   K_Alt_H  = #35;                    {Alt-H}
   K_Alt_I  = #23;                    {Alt-I}
   K_Alt_J  = #36;                    {Alt-J}
   K_Alt_K  = #37;                    {Alt-K}
   K_Alt_L  = #38;                    {Alt-L}
   K_Alt_M  = #50;                    {Alt-M}
   K_Alt_N  = #49;                    {Alt-N}
   K_Alt_O  = #24;                    {Alt-O}
   K_Alt_P  = #25;                    {Alt-P}
   K_Alt_Q  = #16;                    {Alt-Q}
   K_Alt_R  = #19;                    {Alt-R}
   K_Alt_S  = #31;                    {Alt-S}
   K_Alt_T  = #20;                    {Alt-T}
   K_Alt_U  = #22;                    {Alt-U}
   K_Alt_V  = #47;                    {Alt-V}
   K_Alt_W  = #17;                    {Alt-W}
   K_Alt_X  = #45;                    {Alt-X}
   K_Alt_Y  = #21;                    {Alt-Y}
   K_Alt_Z  = #44;                    {Alt-Z}
   K_F1   = #59;                    {F1}
   K_F2   = #60;                    {F2}
   K_F3   = #61;                    {F3}
   K_F4   = #62;                    {F4}
   K_F5   = #63;                    {F5}
   K_F6   = #64;                    {F6}
   K_F7   = #65;                    {F7}
   K_F8   = #66;                    {F8}
   K_F9   = #67;                    {F9}
   K_F10  = #68;                    {F10}
   K_Home = #71;                    {Home}
   K_Up   = #72;                    {Up Arrow}
   K_PgUp = #73;                    {Page Up}
   K_Left = #75;                    {Left Arrow}
   K_Right= #77;                    {Right Arrow}
   K_End  = #79;                    {End}
   K_Down = #80;                    {Down Arrow}
   K_PgDn = #81;                    {Page Down}
   K_Ins  = #82;                    {Insert}
   K_Del  = #83;                    {Delete}
{   K_SH_F1  = #84;                    {Shift-F1}
{   K_SH_F2  = #85;                    {Shift-F2}
{   K_SH_F3  = #86;                    {Shift-F3}
{   K_SH_F4  = #87;                    {Shift-F4}
{   K_SH_F5  = #88;                    {Shift-F5}
{   K_SH_F6  = #89;                    {Shift-F6}
{   K_SH_F7  = #90;                    {Shift-F7}
{   K_SH_F8  = #91;                    {Shift-F8}
{   K_SH_F9  = #92;                    {Shift-F9}
{   K_SH_F10  = #93;                    {Shift-F10}
{   K_CTRL_F1  = #94;                    {Ctrl-F1}
{   K_CTRL_F2  = #95;                    {Ctrl-F2}
{   K_CTRL_F3  = #96;                    {Ctrl-F3}
{   K_CTRL_F4  = #97;                    {Ctrl-F4}
{   K_CTRL_F5  = #98;                    {Ctrl-F5}
{   K_CTRL_F6  = #99;                    {Ctrl-F6}
{   K_CTRL_F7  = #100;                   {Ctrl-F7}
{   K_CTRL_F8  = #101;                   {Ctrl-F8}
{   K_CTRL_F9  = #102;                   {Ctrl-F9}
{   K_CTRL_F10  = #103;                   {Ctrl-F10}
{   K_Alt_F1  = #104;                   {Alt-F1}
{   K_Alt_F2  = #105;                   {Alt-F2}
{   K_Alt_F3  = #106;                   {Alt-F3}
{   K_Alt_F4  = #107;                   {Alt-F4}
{   K_Alt_F5  = #108;                   {Alt-F5}
{   K_Alt_F6  = #109;                   {Alt-F6}
{   K_Alt_F7  = #110;                   {Alt-F7}
{   K_Alt_F8  = #111;                   {Alt-F8}
{   K_Alt_F9  = #112;                   {Alt-F9}
{   K_Alt_F0  = #113;                   {Alt-F10}
   K_Ctrl_Ins = #4;                    {Ctrl-Ins}
   K_Ctrl_G  = #7;                     {Ctrl-G}
   K_Ctrl_L  = #12;                    {Ctrl-L}
   K_Ctrl_Y  = #25;                    {Ctrl-Y}
   K_Ctrl_Q  = #17;                    {Ctrl-Q}
{   K_Ctrl_PrScr = #114;                   {Ctrl-PrtSc}
   K_Ctrl_Left = #115;                   {Ctrl-Left Arrow}
   K_Ctrl_Right = #116;                   {Ctrl-Right Arrow}
   K_Ctrl_End = #117;                   {Ctrl-End}
   K_Ctrl_PgDn = #118;                   {Ctrl-Page Down}
   K_Ctrl_Home = #119;                   {Ctrl-Home}
   K_Ctrl_PgUp = #132;                   {Ctrl-Page up}
{   K_Alt_1  = #120;                   {Alt-1}
{   K_Alt_2  = #121;                   {Alt-2}
{   K_Alt_3  = #122;                   {Alt-3}
{   K_Alt_4  = #123;                   {Alt-4}
{   K_Alt_5  = #124;                   {Alt-5}
{   K_Alt_6  = #125;                   {Alt-6}
{   K_Alt_7  = #126;                   {Alt-7}
{   K_Alt_8  = #127;                   {Alt-8}
{   K_Alt_9  = #128;                   {Alt-9}
{   K_Alt_0  = #129;                   {Alt-0}
{   K_Alt_Hy = #130;                   {Alt-Hyphen}
{   K_Alt_Eq = #131;                   {Alt-Equal}

type
    ConvertType  = (NotConvert,ToUpper,ToLower);
var
   Key_Pos:byte;
   Key_Flag:byte;
   Key_Func,
   Key_Ret,
   Key_Esc,
   Key_Ins   : boolean;
   Key_Modified : boolean;
   LastKey    : char;
   Key_Str   : string;

Procedure CheckKeys;
Function InKey(n:integer) : char;     {Any program can call this to read a}
                                      {character and test for function keys}
Function EditDate (x,y:byte;cStr:string12):string12;
Function EditString (x,y:byte;cStr:string;l:byte;ConvertTo:ConvertType):string;
Function EditBoxString (x1,y1,x2,y2:byte; cStr,cTitle,cLeftStr:string;ConverTo:ConvertType):string;
{procedure SoundBell( t,h : word);}
procedure Beep;


{----------------------------------------------------------------------}
implementation


{----------------------------------------------------------------------}
Procedure CheckKeys;
var
   ch:char;
begin
   clrscr;
   While ch <> K_ESC do begin
      ch:=Inkey(0);
      writeln('Key_func=',Key_Func,byte(Key_func),'  Ch=',Ch,' (',Ord(ch),')');
   end;
   Writeln('Press Enter to exit...');
   readln;
   Halt;
end;


{-----------------------------------------------}
procedure Beep;
begin
   Sound(100); Delay(20);
{   Sound(1000); Delay(100);
   Sound(2000); Delay(100);
   Sound(1000); Delay(100);}
   NoSound;
end;

{***********************************************************************}
Function EditBoxString (x1,y1,x2,y2:byte; cStr,cTitle,cLeftStr:string;ConverTo:ConvertType):string;
{ ──── Get the File Name ──── }
var
   OldScreen:ScreenPtr;
   OldColor :byte;
begin
   OldScreen:=SaveScreen;
   OldColor:=TextAttr;

{   cStr:=PadR(cStr,40);}

   TextAttr:=Red;
   Box(x1,y1,x2,y2, Mixed,Shadow);
   TextAttr:=Yellow;
   SAY(x1+2,y1,cTitle);
   SAY(x1+1,y1+1,cLeftStr);
   TextAttr:=LightGray;
   SetCursorOn;
   cStr:=EditString(x1+Length(cLeftStr)+1,y1+1, cStr, x2-x1-1-Length(cLeftStr),ConverTo);
{   HideCursor;}

   TextAttr:=OldColor;
   RestScreen(OldScreen);

   EditBoxString:= cStr;
end;




Function EditString (x,y:byte;cStr:string;l:byte;ConvertTo:ConvertType):string;
var ch:char;
    s:string;

   procedure Check_Func_Keys(ch:char);
   {var i : integer;}
   begin
   {   for i := 1 to length(AdditionalKeys) do
         if AdditionalKeys[i] = ch then ch := K_Ret;
   }
    If Key_Func then begin
      case ch of
       K_Home  : Key_Pos := 1;
       K_End   : Key_Pos := Succ(Length(cStr));
       K_Ins   : Key_Ins := not Key_Ins;
       K_Left  : if Key_Pos > 1 then Dec(Key_Pos);
       K_Right : if Key_Pos <= Length(cStr) then Inc(Key_Pos);
       K_Del   : begin
                    if Key_Pos <= Length(cStr) then
                            Delete(cStr, Key_Pos, 1);
                 end;
       K_Shift_Tab,            {Shift-Tab key}
       K_Up,                   {Up Arrow}
       K_Down,                 {Down Arrow}
       K_Ctrl_End,             {Ctrl-End}
       K_Ctrl_Home:            {Ctrl-Home}
                   begin         {Return}
                      Key_Ret := true;   {Set Return Flag true}
   {                   Ch := K_CR;}
                   end;
      end;
    end else begin
      case ch of
       K_Bs    : begin
                    Delete(cStr, Pred(Key_Pos), 1);
                    if Key_Pos > 1 then Dec(Key_Pos);
                 end;
       K_Tab,                  {Tab Key}
       K_CR   : begin         {Return}
                      Key_Ret := true;   {Set Return Flag true}
   {                   Ch := K_CR;}
                   end;
       K_Esc   : begin         {Escape Key causes an exit with the}
                                 {original default value returned}
                      Key_Esc := True;
                   end;
      end;
    end;
   end;

begin
   S := cStr;
   Key_Modified := false;  {Flag for field not modified}
   If Key_Ins then
      Key_Pos := Length(s)+1 {Set cursor position to end of line}
   else
      Key_Pos := 1;          {Set cursor position to end of line}
   Key_Ret:=False;
   Key_Esc:=False;
   SetCursorOn;

   repeat

      SAY(x,y,cStr);              {Display the work string}
      fill_char(x+Length(cStr),y,'░',l-length(cStr)); {Display the work string}

      GotoXY(Key_Pos+x-1, y);        {Go to current position in the string}

      Ch := InKey(0);                 {Get the next keyboard entry}

      if Key_Func or (Ch < ' ') then begin
                                      {See if function key or control char}
         Check_Func_Keys(ch);         {If it is, go process it.}
         end
      else begin                      {Otherwise add character to the string}
            If ConvertTo = ToUpper then
               Ch := UpCase(Ch)
            else
               If ConvertTo = ToLower then
                 Ch := LoCase(Ch);
            if (Key_Ins) then Insert(Ch, cStr, Key_Pos)
               else if Key_Pos > Length(cStr) then
                  cStr := cStr + Ch
                     else cStr[Key_Pos] := Ch;
            Inc(Key_Pos);             {Step to the next location in the string}
      end;

      if length(cStr) > l then begin {If string is longer than allowed}
{         SoundBell(BeepTime,BeepFreq);}
         system.delete(cStr,length(cStr),1);
                                     {Remove the last character in the string}
         dec(Key_Pos);              {Back up one position}
      end;

      if (Key_Pos > l) then
         Key_Pos := l;

   until Key_Ret or Key_Esc;
                                      {Continue until Return or Escape pressed}
   gotoxy(x,y);                        {Go to proper location on screen}
{   system.write(cStr,'':l-length(cStr)); {Display the work string}
   SAY(x,y,PadR(cStr,l)); {Display the work string}

   if S = cStr then Key_Modified := false else Key_Modified := true;

   if Key_Esc then EditString := S else
                   EditString := cStr;
                                      {If Escape key pressed, then return the}
                                      {default value.  Otherwise return work}
                                      {string}
   SetCursorOff;
end; { EditString }


{----------------------------------------------------------------------}
Function EditDate (x,y:byte;cStr:string12):string12;
var
   ch:char;
   s:string;
   InsState:Boolean;

   procedure Check_Func_Keys(ch:char);
   begin
    If Key_Func then begin
      case ch of
       K_Home  : Key_Pos := 1;
       K_End   : Key_Pos := Succ(Length(cStr));
       K_Left  : begin
                    if Key_Pos > 1 then Dec(Key_Pos);
                    if Key_Pos in [3,6] then Dec(Key_Pos);
                 end;
       K_Right : begin
                    if Key_Pos <= Length(cStr) then Inc(Key_Pos);
                    if Key_Pos in [3,6] then Inc(Key_Pos);
                 end;
       K_Del   : begin
                    cStr[Key_Pos] := K_SPACE;
                 end;
       K_Shift_Tab,            {Shift-Tab key}
       K_Up,                   {Up Arrow}
       K_Down,                 {Down Arrow}
       K_Ctrl_End,             {Ctrl-End}
       K_Ctrl_Home:            {Ctrl-Home}
                   begin         {Return}
                      Key_Ret := true;   {Set Return Flag true}
   {                   Ch := K_CR;}
                   end;
      end;
    end else begin
      case ch of
       K_Bs    : If Key_Pos > 1 then begin
                    If Key_Pos in [4,7] then Dec(Key_Pos);
                    cStr[Pred(Key_Pos)]:=' ';
                    Dec(Key_Pos);
                 end;
       K_Tab,                 {Tab Key}
       K_CR   : begin         {Return}
                      Key_Ret := true;   {Set Return Flag true}
   {                   Ch := K_CR;}
                   end;
       K_Esc   : begin         {Escape Key causes an exit with the}
                                 {original default value returned}
                      Key_Esc := True;
                   end;
      end;
    end;
   end;

begin

   InsState := Key_Ins;

   Key_Ins := False;
   Key_Pos := 1;          {Set cursor position to end of line}
   Key_Ret:=False;
   Key_Esc:=False;
   Key_Modified := false;  {Flag for field not modified}

   SetCursorOn;
   S := cStr;

   repeat

      SAY(x,y,cStr);              {Display the work string}
{      fill_char(x+Length(cStr),y,'░',8-length(cStr)); {Display the work string}

      GotoXY(Key_Pos+x-1, y);        {Go to current position in the string}

      Ch := InKey(0);                 {Get the next keyboard entry}

      if Key_Func or (Ch < ' ') then begin
                                      {See if function key or control char}
         Check_Func_Keys(ch);         {If it is, go process it.}
         end
      else begin                      {Otherwise add character to the string}
         if not (Ch in ['0'..'9',' ']) then beep
         else begin
            cStr[Key_Pos] := Ch;
            Inc(Key_Pos);             {Step to the next location in the string}
            If Key_Pos in [3,6] then
               Inc(Key_Pos);          {Step to the next location in the string}
         end;
      end;

      if length(cStr) > 8 then begin {If string is longer than allowed}
{         SoundBell(BeepTime,BeepFreq);}
         system.delete(cStr,length(cStr),1);
                                     {Remove the last character in the string}
         dec(Key_Pos);              {Back up one position}
      end;

      if (Key_Pos > 8) then
         Key_Pos := 8;

   until Key_Ret or Key_Esc;           {Continue until Return or Escape pressed}


   If (Not Key_Esc) then
      If not DateStrOk(cStr) then beep;

   gotoxy(x,y);                        {Go to proper location on screen}
   SAY(x,y,PadR(cStr,8));          {Display the work string}

   if S = cStr then Key_Modified := false else Key_Modified := true;

   if Key_Esc then EditDate := S else
                   EditDate := cStr;
                                      {If Escape key pressed, then return the}
                                      {default value.  Otherwise return work}
                                      {string}
   Key_Ins:=InsState;
   SetCursorOff;
end; { EditString }




procedure SoundBell( t,h : word);
begin
   Sound(h);
   Delay(t);
   NoSound;
end;

(*
procedure WaitForKey;
var
   c  : char;
begin
   c := InKey(0);
end;

*)

{

                               GS_KEYI_GETKEY

     ╔══════════════════════════════════════════════════════════════════╗
     ║                                                                  ║
     ║   The GS_KeyI_GetKey function is used to read a character from   ║
     ║   Keyboard.  It can be called from any program.                  ║
     ║                                                                  ║
     ║       Calling the Function:                                      ║
     ║                                                                  ║
     ║           Ch := GS_KeyI_GetKey                                   ║
     ║                                                                  ║
     ║               ( where Ch is of type char. )                      ║
     ║                                                                  ║
     ║       Result:                                                    ║
     ║                                                                  ║
     ║           A character is returned.  If it is a function key,     ║
     ║           GS_KeyI_Func is set true.  The character is also       ║
     ║           saved in GS_KeyI_Chr, a global variable (just in       ║
     ║           case it is needed at a later date)                     ║
     ║                                                                  ║
     ╚══════════════════════════════════════════════════════════════════╝

}


Function InKey(n:Integer):Char;Assembler;
asm
   mov [Key_Func],0
   xor ax,ax;
   int 16h;
   cmp al,0
   jne @1
   mov [Key_Func],1
   xchg ah,al
@1:
   mov [Key_Flag],ah
   mov [LastKey],al
end;

(*
Function InKey(n:Integer) : char;
var
   ch: char;
begin
  Ch := ReadKey;                      {Use TP ReadKey Function}
  Key_Ret := (Ch = K_CR);            {Set function flag}
  Key_Esc := (Ch = K_Esc);           {Set function flag}
  Key_Func := false;

  If (Ch = #0) then begin             {It must be a function key }
    Ch := ReadKey;                    {So read the function code}
    Key_Func := true;                 {Set function flag}
  end
  else Key_Func := Ch < K_SPACE;

  LastKey := Ch;                      {Save in a global variable for general}
                                      {principle.}
  InKey := Ch;               {Return character}
end;

*)

(*
constructor GS_KeyI_Objt.Init;
begin
   Wait_CR := true;                   {Wait for Carriage Return on field edit}
end;

destructor GS_KeyI_Objt.Done;
begin
end;

{

                                 EDITSTRING

     ╔══════════════════════════════════════════════════════════════════╗
     ║                                                                  ║
     ║   The EDITSTRING method will allow onscreen editing of a data    ║
     ║   string.  It allows use of cursor keys and tabs as well.        ║
     ║                                                                  ║
     ║       Calling the Method:                                        ║
     ║                                                                  ║
     ║           objectname.EditString(St,x,y,lgth)                     ║
     ║                                                                  ║
     ║               ( where objectname is of type GS_KeyI_Objt         ║
     ║                       St is a string default value,              ║
     ║                       x is the screen column position to start,  ║
     ║                       y is the screen row position to start,     ║
     ║                       lgth is the maximum field length )         ║
     ║                                                                  ║
     ║       Result:                                                    ║
     ║                                                                  ║
     ║           An edited string is returned.  If Escape is pressed,   ║
     ║           the original default value is returned.                ║
     ║                                                                  ║
     ╚══════════════════════════════════════════════════════════════════╝

}
{
         ┌──────────────────────────────────────────────────────────┐
         │  ********        Function Key Processor        *******   │
         │                                                          │
         │  This routine processes any function key that is pressed │
         │  during edit mode.  If it is one ether insert is on or   │
         │  off.  BIOS calls are used.                              │
         └──────────────────────────────────────────────────────────┘
}


procedure GS_KeyI_Objt.Check_Func_Keys;
begin
   case Ch of
   K_Home  : CPos := 1;    {Home key sets cursor to start}
   K_End   : CPos := Succ(Length(KeyI_Str));
                           {End key sets cursor to string length + 1}

   K_Ins   : begin         {Insert Key switches insert flag}
                KeyI_Ins := not KeyI_Ins;
                           {Set insert flag to opposite}
                SetCursor(KeyI_Ins);
                           {Go set cursor to line or large based on}
                           {insert flag true/false}
             end;
   K_Left  : if CPos > 1 then Dec(CPos);
                           {Left Arrow will backup cursor 1 position}
   K_Right : if CPos <= Length(KeyI_Str) then Inc(CPos);
                           {Right Arrow will advance cursor}
   K_Bs    :               {Backspace will delete char to the left}
             if CPos > 1 then begin
                Delete(KeyI_Str, Pred(CPos), 1);
                Dec(CPos);
             end;
   K_Del   :               {Delete will delete char at cursor}
             if CPos <= Length(KeyI_Str) then
                Delete(KeyI_Str, CPos, 1);
{
         ┌──────────────────────────────────────────────────────────┐
         │  The following keys will simulate the Return key being   │
         │  pressed.  The actual key pressed can be tested by the   │
         │  calling program using the character in GS_KeyI_Chr,     │
         │  using the Kbd_xxx constant values.                      │
         └──────────────────────────────────────────────────────────┘
}
   K_Tab,                  {Tab Key}
   K_Shift_Tab,            {Shift-Tab key}
   K_Up,                   {Up Arrow}
   K_Down,                 {Down Arrow}
   K_PgUp,                 {Page Up}
   K_PgDn,                 {Page Down}
   K_Ctrl_End,             {Ctrl-End}
   K_Ctrl_Home,            {Ctrl-Home}
   K_CR    : begin         {Return}
                KeyI_Ret := true;  {Set Return Flag true}
                Ch := K_CR;
             end;


   K_Esc   : begin         {Escape Key causes an exit with the}
                           {original default value returned}
                KeyI_Str := '';
                KeyI_Esc := True;
             end;
   end;
end;
{
         ┌──────────────────────────────────────────────────────────┐
         │  ********        Edit String Procedure         *******   │
         │                                                          │
         │  This is the main method to edit an input string.  The   │
         │  usual cursor keys are processed through a method that   │
         │  may be replaced by a child object's virtual method.     │
         │  The Escape key will terminate and return the default    │
         │  value to the calling program.                           │
         └──────────────────────────────────────────────────────────┘
}


function GS_KeyI_Objt.EditString(T : string; x, y, l : integer) : string;
begin
   KeyI_Ins := True;               {Start in insert mode}
   KeyI_Esc := False;              {Set the Escape flag false}
   KeyI_Ret := false;              {Set Return flag false}
   Modified := false;                 {Flag for field not modified}
   First := True;                     {Flag set for no characters yet entered}
   KeyI_Str := T;                  {Store default value in work string}
   SetCursor(KeyI_Ins);    {Go set cursor size}
   CPos := 1;                         {Set cursor position on line to start}
   repeat
      gotoxy(x,y);                    {Go to proper location on screen}
      write(KeyI_Str,'':l-length(KeyI_Str));
                                      {Display the work string}
      GotoXY(CPos+x-1, y);            {Go to current position in the string}
      Ch := InKey(0);                 {Get the next keyboard entry}
      if (KeyI_Fuc) or (Ch in [#0..#31]) then begin
                                      {See if function key or control char}
         Check_Func_Keys;             {If it is, go process it.  Note this is}
                                      {a virtual method that may go to a child}
                                      {object's method}
      end
      else                            {Otherwise add character to the string}
      begin

{
              ┌─────────────────────────────────────────────┐
              │  If this is the very first character to     │
              │  be pressed, clear the work string first.   │
              │  This allows editing of the work string     │
              │  if cursor keys are used before a character │
              │  is entered, or total replacement by        │
              │  pressing a character key first.            │
              └─────────────────────────────────────────────┘
}

         if First then KeyI_Str := '';
{
              ┌─────────────────────────────────────────────┐
              │  If insert is on then insert the character. │
              │  Otherwise, if at the end of the string,    │
              │  just add the new character.  If insert is  │
              │  off and not at the end of the string,      │
              │  replace the existing character.            │
              └─────────────────────────────────────────────┘
}
         if (KeyI_Ins) then Insert(Ch, KeyI_Str, CPos)
            else if CPos > Length(KeyI_Str) then
               KeyI_Str := KeyI_Str + Ch
                  else KeyI_Str[CPos] := Ch;

         Inc(CPos);                   {Step to the next location in the string}
      end;
      First := False;                 {Set first character flag to false}
      if length(KeyI_Str) > l then begin
                                      {If string is longer than allowed}
         SoundBell(BeepTime,BeepFreq);
         delete(KeyI_Str,length(KeyI_Str),1);
                                      {Remove the last character in the string}
         dec(CPos);                   {Back up one position}
      end;
      if (CPos > l) then
         if (not Wait_CR) and (Ch <> K_End) then begin
            Ch := K_CR;
            KeyI_Ret := true;      {If field is full and no need to wait}
         end                          {for a carriage return, simulate one}
         else CPos := l;
   until (Ch = K_CR) or (Ch = K_Esc);
                                      {Continue until Return or Escape pressed}
   SetCursor(False);          {Set cursor size to small cursor}
   if T = KeyI_Str then Modified := false else Modified := true;
   if KeyI_Esc then EditString := T else
                       EditString := KeyI_Str;
                                      {If Escape key pressed, then return the}
                                      {default value.  Otherwise return work}
                                      {string}
end; { EditString }
*)


begin
   Key_Esc := false;
   Key_Func := false;
   Key_Ins:=True;                     {Start in insert mode}
   Key_Ret := false;
   LastKey  := #0;                 {Initialize character to null}
end.

