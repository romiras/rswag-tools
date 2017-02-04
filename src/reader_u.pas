{----------------------------------------------------------}
{             Russian SWAG Msg Base Reader                 }
{                    v.4.0 beta H                          }
{      Unit Reader_U - User Interface utilities            }
{      written 1993-2000 by Valery Votintsev 2:5021/22     }
{                          E-Mail: rswag AT sources.ru     }
{----------------------------------------------------------}
Unit Reader_U;
{$i GSF_FLAG.PAS}
Interface
Uses
   vMEMO,
   vMenu,
   vScreen,
   Reader_C,
   vKBd,
   vString,
   GSF_Shel,
   gsf_date,
   GSF_DOS,
   CRT;


Var
  ExitSave: pointer;       {Old Exit Procedure Address}
  ConfigFile:String;
  IndexHeader:string;      {For the List of Areas "Sources.htm"}
  IndexFooter:string;
  IndexRecord:string;

  AreaHeader:string;       {For the Area MsgList (area/Index1.htm)}
  AreaFooter:string;
  AreaRecord:string;
  MsgHeader:string;        { the Msg Body Template }

  AreaList:string;


Procedure SetPublicVar(const IniFile:string); {Setup Start Parameters}
{Procedure ReZip;}
Procedure Browse ({AreaID:String12;AreaDesc:String80;}
                  ColLeft,RowTop,ColRight,RowBottom:byte;
                  cTitle:String80;EnterExit:Boolean);
Procedure Extract(AskNeed:Boolean);


Implementation
Uses RSWAGHTM;

{--------------------------------------------------------------}
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

{--------------------------------------------------------------}
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
      for i:=1 to ((Kwartets.UUStrLen-32) mod 3) do begin
         Kwartet2Triplet(Kwartets.kwart[i],Trip); {i+1}
         system.write(nHandle,Trip[i-1])
      end;
   end
end;


{************** UUDECODE **********************************************}
Procedure UUDecode(lProcessBar:boolean);
var
   nHandle:FileOfByte;
   FRec:TFileRec absolute nHandle;
   FileName:String[12];
   Buffer:string;
   LineNum,
   MaxLines,
   i,lMode:Integer;
   OldScreen:ScreenPtr;
   OldColor:byte;

begin
   FileName:=Spaces(12);
   lMode:=0;
   LineNum:=1;
   MaxLines := MemoLines;
   OldScreen:=SaveScreen;
   SaveColor(OldColor);

   If lProcessBar then
      DrawScale(12,19,'Wait a minute! It''s UUdecoding now...',LightRed,Yellow,LightGray);

   While LineNum <= MaxLines do begin

      If lProcessBar then
         Scale(MaxLines,LineNum);

      Buffer:=AllTrim(MemoGetLine(LineNum)); { Read Next Line }
      Inc(LineNum);

      If Buffer <> '' then
      Case lMode of
      0: begin { Search 'begin' }
            If Left(Buffer,5) = 'begin' then begin
               system.Delete(Buffer,1,9);
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

   If FRec.Mode <> DOS.fmClosed then begin
      system.Close (nHandle);
      WaitForOk(' Sorry, "end" sequence not found :-( ','Ok',White+Red*16,White);
   end;

   If lProcessBar then begin
      Scale(MaxLines,MaxLines);
      Delay(1000);
      RestScreen (OldScreen);
      RestColor(OldColor);
   End;

end;




{************** EXTRACT ALL THE FILES *********************************}
Procedure Extract(AskNeed:Boolean);
var
   fUue:FileOfByte;
   fText:Text;
   OldScreen:ScreenPtr;
   OldColor:byte;
   OldRec:LongInt;
   LineNum,
   NumOfLines:LongInt;
   i,nExt:integer;
   cLine,
   cFileName,
   cExt:string;
   FileOpened,
   UuStarted,
   ItIsUUE:Boolean; { Признак UUEncoded Stuff }
begin
{   If AskNeed then begin}
      OldScreen:=SaveScreen;
      SaveColor(OldColor);
{   end;}
   OldRec:=RecNo;
   nExt:=1;
   LineNum:=1;
   NumOfLines:=MemoLines+1;
   cFileName:='';
   cLine:='';
   UuStarted:=False;
   FileOpened:=False;
   ItIsUUE:=False; { Признак UUEncoded Stuff}

   If AskNeed then begin
      ExtractDir:=EditBoxString(8,13,70,15,ExtractDir,'Extract to the Directory:','',NotConvert);
   end;

   If LastKey <> K_ESC then begin
      { Toghch the ExtractDir }
      ExtractDir:=AllTrim(ExtractDir);
      If not EmptyStr(ExtractDir) then
         If Right(ExtractDir,1) = '\' then
            Dec(Byte(ExtractDir[0]));

{      If AskNeed then begin}
         DrawScale(19,12,'Wait a minute! It''s Extracting now...',LightRed,Yellow,LightGray);
{      end;}

      While LineNum <= NumOfLines do begin

{         If AskNeed then begin}
            Scale(NumOfLines,LineNum);
{         end;}

         cLine:=RTrim(MemoGetLine(LineNum)); { Read Next Line }
         Inc(LineNum);

         { Search the CutLine }
         If (pos(CutLine,cLine) <> 0) and
            (pos(CutLine2,cLine) <> 0) then begin
            {Close Old File if opened}
            If FileOpened then begin
               If ItIsUue then
                  system.close(fUue)
               else
                  system.close(fText);
               FileOpened:=False;
            end;

            { Form new FileName }
            i:=Pos(CutLine2,cLine);
            cFileName := AllTrim(Copy(cLine,i+Length(CutLine2),13));
            i:=Pos(' ',cFileName);
            If i > 0 then
               cFileName := Left(cFileName,i-1);
            { Check for UUEncode }
            If UPPER(Right(cFileName,4))='.UUE' then begin
               ItisUUE:=True;
            end else begin
               ItisUUE:=False;
               system.assign(fText,ExtractDir+'\'+cFileName);
               {$i-} system.rewrite(fText); {$i+}
               FileOpened:=True;
            end
         end else begin

            If ItIsUue then begin
               If UuStarted then begin { Decode Current Line if # 'end' }
                  If (cLine = 'end') or (cLine[1] = '`') then
                     UuStarted:=False
                  else begin
                     If cLine[1] <> 'M' then
                        UuStarted:=True;
                     DecodeLine(fUue,cLine);
                  end;

               end else begin { Search 'begin' }
                  If Left(cLine,5) = 'begin' then begin
                     system.Delete(cLine,1,10);
                     cFileName := AllTrim(Copy(cLine,1,13));
                     i:=Pos(' ',cFileName);
                     If i > 0 then cFileName:=Left(cFileName,i-1);
                     If not EmptyStr(cFileName) then begin
                        system.assign(fUue,ExtractDir+'\'+cFileName);
                        {$i-} system.rewrite(fUue); {$i+}
                        FileOpened:=True;
                        UuStarted:=True;
                     End;
                  end;
               end;

            end else begin
               If not FileOpened then begin
                  Repeat
                     cExt:=IntToSTR(nExt{,3});
                     Inc(nExt);
                     While Length(cExt) < 3 do
                        cExt:='0'+cExt;
                     cFileName:='MESSAGE.'+cExt;
                  until not GsFileExists(cFileName);

                  system.assign(fText,ExtractDir+'\'+cFileName);
                  {$i-} system.rewrite(fText); {$i+}
                  FileOpened:=True;
                  ItisUUE:=False;
               end;
               system.writeln(fText,cLine);
            end
         end;
      end;

      If FileOpened then begin
         If ItIsUue then
            system.close(fUue)
         else
            system.close(fText);
         FileOpened:=False;
      end;

      Scale(NumOfLines,NumOfLines);  {All the TEXT extracted}

      NumOfLines:=MemoSize('ATTACHME');  {Check the Attachment Size}
      If NumOfLines<>0 then begin        {If any file Attached...  }
         cFileName:=ExtractDir+'\'+RTrim(FieldGet('PROJECT'));
         AttExtract(cFileName);          {  then extract this      }
      end;

      If AskNeed then begin
         Delay(500);
      end;
   end;

{   If AskNeed then begin}
      RestScreen(OldScreen);
      RestColor(OldColor);
{   end;}
end;


{--------------------------------}
Procedure ZipCurrentSnipet(const AreaId: string);
Var
  cZipFileName:string80;
  nErr:integer;
   OldScreen:ScreenPtr;
   x,y,
   OldColor:byte;

begin
{      Inc(MsgCounter);}
   x:=WhereX;
   y:=WhereY;
   OldColor := TextAttr;
   OldScreen:=SaveScreen;
   TextAttr:=LightGray;

{   ClrScr;}
{   SetCursorOn;}

   If FieldExists('PROJECT') then
      Project:=Lower(RTrim(FieldGet('PROJECT')))
   else
      Project:='';

   If Project = '' then begin
      Project:=IntToStr(RecNo);
      If FieldExists('PROJECT') then begin
         FieldPut('PROJECT',Project);  {Put the project name if empty}
         Replace;
      end;
   end;

   cZipFileName:=ListDir+'\'+AreaId+'\'+Project+'.zip';
   FileDeleteByMask(ExtractDir,'*.*');

   ReadMemo('TEXT');
   Extract(DontAsk);    {Extract the snipet to EXTRACT Dir}

   {PkZip extracted to List Dir}
   nErr:=DosShell('c:\arc\pkzip.exe',{'-m '+}cZipFileName+' '+ExtractDir+'\*.*');

   RestScreen(OldScreen);
{   SetCursorOn;}
   TextAttr:=OldColor;
   GotoXY(x,y);

   If nErr <> 0 then begin
      WaitForOk('Archiving Error (code='+IntToStr(nErr)+')','Ok',White+Red*16,White);
   end;
end;





{--------------------------------------------------------------}
Procedure DrawBottomLine;
var
   s:string80;
begin
   S:=AllTrim(AreaBase)+' '+Version;
   SetColor('W/B');
   ClearLine(25);
   SAY(Length(S)+2,25, CopyRight);
   SAY(47,25,'│ OrderBy:');
   SAY(70,25,'│');

   SetColor('W+/B');
   SAY(1,25,S);
end;

{---------------------------------------------------------}
{$F+}
Procedure ExitReader;
var x,y:byte;
begin
   x:=WhereX;
   y:=WhereY;
   DirectVideo :=FALSE;
   SetColor('W/N');
   System.write(' ');
   gotoxy(x,y);
{   RestScreen(DosScreen);}
   ExitProc := ExitSave;
   SetCursorOn;
   Halt;

end;

{$F-}


{---------------------------------------------------------}
Procedure DoQuit;
begin
   If AskYesNo(3,2,' Quit '+AreaBase+'? ') then begin
      Halt;
   end;
end;


{---------------------------------------------------------}
Procedure SayOrder;
Var
   cOrdered:string[12];
   OldColor:byte;
begin
   SaveColor(OldColor);

   Case IndexCurrentOrder of
   0:                        cOrdered:=mnNoOrder; { No Order}
   1: If Alias='AREAS'  then cOrdered:=mnDescription
                        else cOrdered:=mnFrom;
   2: If Alias='AREAS'  then cOrdered:=mnAreaID
                        else cOrdered:=mnSubject;
   end;

   SetColor('W+/B');
   SAY(58,25,cOrdered);

   RestColor(OldColor);
end;




{*────────────────────────────────────────────────────────────────────*}
Procedure Browse ({AreaID:String12;AreaDesc:String80;}
                  ColLeft,RowTop,ColRight,RowBottom:byte;
                  cTitle:String80;EnterExit:Boolean);
Var
   OldArea,
   OldColor : Byte;
   OldScreen: ScreenPtr;

   SkipRecs,                    {Max Number of records on screen}
   FullLen,
   Row      : Integer;          {Current Screen Row for Browse}
   RecNumTOP,                   {First Upper Record in the screen}
   RecNum   : LongInt;          {Current Record Number}
   cKey     : Char;             { Keystroke }
   fn       : String;
   ar       : String80;
   Escaped,                     {Escaped Flag}
   PagePaint: Boolean;          {ReDraw Screen Flag}

   MarkArray: Array[1..1024] of LongInt; {Array of marked records}
   MarkCount: LongInt;                   {Number of marked records}




{------------------------------------------}
{ReCalc new row position for current record}
Procedure AdjustRow;
var
   i:integer;
begin
   RecNum    :=RecNo;
   If dEOF then GoBottom;

   For i:= 1 to (SkipRecs div 2) do begin
      Skip (-1);
      If dBOF then Break;
   end;

   RecNumTop:=RecNo;
   Row :=RowTop;

   While (RecNo <> RecNum) and (not dEOF) do begin
      Skip (1);
      Inc(Row);
   end;
{
   Row:=i + RowTop -1;}
   Go (RecNum);

end;

{--------------------------------------------------------------}
Procedure SetAreaTag(TagNum:integer);
begin
      If Alias = 'AREAS' then begin
         Case TagNum of
         0: SetTagTo('');
         1: SetTagTo('AreaDescr');
         2: SetTagTo('AreaID');
         end;
         AreaOrder:=TagNum;
      end else begin
         Case TagNum of
         0: SetTagTo('');
         1: SetTagTo('From');
         2: SetTagTo('Subj');
         end;
         MsgOrder:=TagNum;
      end;
end;


{-----------------------------------------------------}
Procedure MarkRecord;
{ Mark the Current Record }
Var
   i,nRec:longint;
begin
   nRec:=0;
   For i:=1 to MarkCount do
      If MarkArray[i]=RecNo then begin
         nRec:=i;
         break;
      end;

   If nRec = 0 then begin
      Inc(MarkCount);
      MarkArray[MarkCount]:=RecNo;
   end else begin
      For i:=nRec+1 to MarkCount do
         MarkArray[i-1]:=MarkArray[i];
      Dec(MarkCount);
   end;

end;

Function Marked:Boolean;
{ Check the Current Record for Marked }
Var
   i,nRec:longint;
begin
   nRec:=0;
   If MarkCount < 0 then begin
      nRec:=1;
   end
   else
   For i:=1 to MarkCount do
      If MarkArray[i]=RecNo then begin
         nRec:=i;
         break;
      end;

   Marked := nRec > 0;
end;

{---------------------------}
Procedure PaintRecord(RowNum:integer;HighLight:Boolean);
Var
   Color:Byte;

begin

   If Marked then
      If HighLight then Color := 30  {Yellow on Blue}
                   else Color := 14  {Yellow}
   else

      If HighLight then
         Color:=31                   {White on Blue}
      else
         Color:=7;                   {Light Gray}

   Paint(ColLeft,RowNum,ColRight,Row,Color); { N/BG or BG+/B }
end;


{------------------------------------------------}
Procedure OrderBy;
Var
   Ans:byte;
   OldRec:LongInt;
{   S:string;          {for testing only}
begin
   OldRec:=RecNo;
   If not FullScreen then
      PaintRecord(Row,True);

   M.Init(3,2,28,6, ' Order By: ',
                 LightGray,White+Blue*16,Yellow,LightRed,White,Centered);

   If Alias = 'AREAS' then begin
      M.Add(mnDescription);
      M.Add(mnAreaID);
   end else begin
      M.Add(mnFrom);
      M.Add(mnSubject);
   end;
   M.Add(mnNoOrder);

{   S:=IndexTagName(1);
   S:=IndexTagName(2);
   S:=IndexCurrent;
}
   Ans := IndexCurrentOrder;

{   S:=IndexExpression(Ans);}

   If Ans = 0 then Ans :=3;

   Ans:=M.ReadMenu(Ans);
   M.Done;

   If LastKey <> K_ESC then begin

      If Ans = 3 then Ans :=0;

      SetAreaTag(Ans);
{      SetOrderTo(Ans mod 3);}
{
   S:=IndexTag(1);
   S:=IndexTag(2);
   Ans := IndexCurrentOrder;
}
      Go (OldRec);

   End;
   AdjustRow;
   PagePaint:=True;
   SayOrder;

end;





{---------------------------------------------------------}
Procedure SayRecord(y:Integer);
Var
{   NameLen,}
   OldColor,
   SepPos,
   Len1,
   Len2:Byte;
   Str0:String[6];
   Str1,Str2:String80;
begin

   SaveColor(OldColor);
   If Alias='AREAS' then begin
      SepPos:=26;
      Len1  :=11;
      Len2  :=54;
      Str1  :=PadR(FieldGet('FILENAME'),Len1);
      Str2  :=PadR(FieldGet('AREA'),Len2);
      end
   else begin
      SepPos:=31;
      Len1  :=25;
      Len2  :=49;
      Str1  :=PadR(FieldGet('FROM'),Len1);
      Str2  :=PadR(FieldGet('SUBJ'),Len2);

   end;

   If Deleted then begin
      Str1:=PadR('DELETED',Len1);
      Str2:=PadR('DELETED',Len2);
   end;

   If Marked then
      SetColor('GR+/N')
   else
      SetColor('W/N');

   If dEOF then begin
      SAY(ColLeft, y, Spaces(ColRight+1-ColLeft));
      end
   else begin
      SAY(ColLeft, y, PadR(IntToStr(RecNo),6));
      SAY(ColLeft+6,  y, PadR(Str1,Len1));

      If Alias='AREAS' then begin
         Str0:= PadL(FieldGet('MSGCOUNT'),5)+' ';
         If Str0  = '      ' then begin
            Str0 := '    0 ';
         end;
         SAY(ColLeft+17, y, Str0);
      end;

      SAY(SepPos, y,PadR(Str2,Len2));

      Say_Char(SepPos-1, y,' ');
      If Alias <> 'AREAS' then
         If LogicGet('NEW') then
            Say_Char(SepPos-1,y, '√');

   end;

   RestColor(OldColor);
end;



{*------------------------------------------}
Procedure DrawScreen;
{Var
   cID:NameStr;
   cArea:String;
   nLen:Byte Absolute cID;
   OldArea:byte;}
begin
   SetColor('W/N');
{   ClrScr;}
(*   OldArea:=DbfUsed;
   Select(1);
   cID:=AllTrim(FieldGet('FILENAME'));
   cArea:=AllTrim(FieldGet('AREA'));
   Select(OldArea);
*)
   SetColor('B+/N');
   Box(1,RowTop-1, 80, RowBottom+1,Single,NoShadow);

   DrawBottomLine;

   If Alias='AREAS' then begin
      SetColor('W/N');
      ClearLine(RowTop-2);
      SAY(1,RowTop-2,cTitle);

      SetColor('GR+/N');
      SAY( 3, RowTop-1, '#');
      SAY( 9, RowTop-1, 'AreaID');
      SAY(20, RowTop-1, 'Msgs');
      SAY(26, RowTop-1, 'Description');
      end
   else begin
      SetColor('B+/N');
      SAY(1, 1, Replicate('─',80));

      SetColor('GR+/N');
      SAY(2,1,' ' + AreaDescr+' ');
      SAY(80-Length(AreaID),1, AreaID);
      SAY( 8, RowTop-1,'From');
      SAY(31, RowTop-1,'Subj');
{      Select(2);}
   end;

   SayOrder;

   SetColor('W/N');

End;

{***********************************************************************}
Procedure DrawRecord;
{ ──── Draw the Record to Full Screen ──── }
{Var
   cID:PathStr;
   nLen:byte Absolute cId;
   cArea:string;
}
begin
{   Select(1);
   cID:=AllTRim(FieldGet('FILENAME'));
   cArea:=AllTrim(FieldGet('AREA')+' ');
   Select(2);
{   nLen:=Length(cID);}

   SetColor('B+/N');
   Box(1,1,80,5,NoFrame,NoShadow);
   SAY(1,1, Replicate('─',80));
   SAY(1,5, Replicate('─',80));

   SetColor('GR+/N');
   SAY(2,1,' '+ AreaDescr {cArea} +' ');
   SAY(80-Length(AreaID),1, AreaID {cID});

   SetColor('W/N');

   SAY( 1, 2,' Msg  : ');
   SAY( 1, 3,' From : ');
   SAY( 1, 4,' Subj : ');
   SAY(41, 2, 'Addr'   );
   SAY(74, 2, 'Date'   );

   SetColor('W/N');

   Box(ColLeft-1,RowTop+3,ColRight+1,RowBottom+1,NoFrame,NoShadow);
{   Box(1,5,80,RowBottom,NoFrame,NoShadow);}

end;

{***********************************************************************}
Procedure DrawHeader;
{ ──── Draw the Record Header to Full Screen ──── }

begin

   SetColor('W+/N');
   If Marked then
      Say_Char(8,2,'')
   else
      Say_Char(8,2,' ');

   SetColor('W/N');

   SAY( 9, 2, PadR(IntToStr({!Index}RecNo),6));
   SAY( 9, 3, PadR(FieldGet('FROM'),25));
   SAY(36, 3, PADR(FieldGet('ADDR'),35));
   SAY(72, 3, DateGet ('DATE'));
   SAY( 9, 4, PADR(FieldGet('SUBJ'),52));

{   If MemoEditOn then begin}
      SetColor('N+/N');
      SAY(65, 4, 'ApDate:');
      SetColor('W/N');
      SAY(72, 4, DateGet ('APDATE'));
{   end;}

   If FieldExists('PROJECT') then begin  {Skip this if old DBF format}
      SetColor('B+/N');
      SAY(52,5, '─────────────────────');
      SetColor('W/N');
      If AllTrim(FieldGet('PROJECT')) <> '' then begin
         SAY(59, 5, '[            ]');
         SetColor('GR+/N');
         SAY(60, 5, FieldGet('PROJECT'));
         If MemoSize('ATTACHME') <> 0 then begin
            SetColor('W/N');
            SAY(52, 5, 'Attach:');
         end;
      end;
   end;

   SetColor('B+/N');
   SAY(2,5, '──────────');
   SetColor('GR+/N');
   SAY(2,5,IntToStr(Memo_Size));     {Say the Message Length}
{
   SAY(12,5,Long2Str(IndexRecNo));
   SAY(22,5,Long2Str(dbfActive^.MemoFile^.Memo_Loc));
}
   SetColor('W/N');

{//   MemoSay(TEXT,5,0,23,79)}

{   SetColor(OldColor);}
end;

{-------------------------------------}
Procedure GoToNextArea;
Var
   Stop: Boolean;
   Ans:Integer;
begin

   If AskYesNo(3,6,' Goto Next Area? ') then begin
      Escaped := True
(*
      Stop := False;
      Use('','',False);  { Close Current WORK DataBase }
      Select('AREAS');

      While not stop do begin
         Skip(1);
         If dEOF then
            GoTOP;
         AreaID:=AllTRim(FieldGet('FILENAME'));

         If AreaID <> '' then begin
            If GsFileExists(BaseDir+'\'+AreaID+'.dbf') then begin
               AreaDesc:=AllTrim(FieldGet('AREA'));
               OpenWorkBase(AreaID,'WORK',DontAsk);
               GoTop;
               AdjustRow;
               MarkCount := 0;
               PagePaint:=True;
               Stop:=True;
               DrawScreen;
               DrawRecord;
            end;
         end;
      end;
*)
   end;
end;


{-------------------------------------}
Procedure GoToPrevArea;
Var
   Stop: Boolean;
begin

   If AskYesNo(3,6,' Goto Prev Area? ') then begin
      Escaped := True
(*
      Stop := False;
      Use('','',False);  { Close Current WORK DataBase }
      Select('AREAS');

      While not stop do begin
         Skip(-1);
         If dBOF then
            GoBOTTOM;
         AreaID:=AllTRim(FieldGet('FILENAME'));

         If AreaID <> '' then begin
            If GsFileExists(BaseDir+'\'+AreaID+'.dbf') then begin
               AreaDesc:=AllTrim(FieldGet('AREA'));
               OpenWorkBase(AreaID,'WORK',DontAsk);
               GoBottom;
               MarkCount := 0;
               AdjustRow;
               PagePaint:=True;
               Stop:=True;
               DrawScreen;
               DrawRecord;
            end;
         end;
      end;
*)
   end;
end;




{**************** DOWNPROC ***********************}
Procedure GoDown(Draw:Boolean);
{Var
   OldRec:LongInt;}
Begin
{   OldRec := RecNo;}
   SKIP(1);
   If dEOF then begin
      GoBottom;
      If (Alias = 'WORK') and FullScreen then
         GoToNextArea
      else begin
         Beep;
      end;
   end else
      If Row < RowBOTTOM then
         Inc(Row)
      else begin
         { ---Adjust top-of-page record pointer.}
         Recnum := RECNO;
         Go(RecNumTop);
         SKIP(1);
         RecnumTOP := RECNO;
         Go (Recnum);
         If Draw then begin
            {* ---Scroll window up.}
            Scroll (ColLeft,RowTop,ColRight,RowBottom,UP);
            SayRecord(Row);
         end;
      end;
End;


{***************** ENDPROC ********************}
Procedure GoEnd;
Begin
   GoBottom;
   recnumTOP := RECNO;
   Row       := RowTop;
   PagePaint := TRUE;
End;



{****************** UPPROC ***********************}
Procedure GoUp(Draw:Boolean);
{var
   OldRec:LongInt;
{   Ans:integer;}
Begin
{   OldRec := RecNo;}
   SKIP(-1);
   If dBOF then begin
      If (Alias = 'WORK') and FullScreen then
         GoToPrevArea
      else begin
         Beep;
         GoTop {Bottom};
      end;
   end else
      If Row > RowTOP then
         Dec(Row)
      else begin
         { ---Adjust top-of-page record pointer.}
         RecnumTOP := RECNO;
         If Draw then begin
            {* ---Scroll window down.}
            Scroll (ColLeft,RowTop,ColRight,RowBottom,Down);
            SayRecord(Row);
         end;
      end;
end;

{***************** PGDOWNPROC ********************}
Procedure GoPgDn;
Begin
   IF not dEOF then begin
      Go( RecnumTOP);
      SKIP (SkipRECS);
      IF dEOF then begin
         Beep;
         GoBottom;
      end;
      recnumTOP := RecNo;
      Row       := RowTop;
      PagePaint := TRUE;
   end;
end;

{****************** PGUPPROC *********************}
Procedure GoPgUp;
Begin

   IF not dBOF then begin
      Go (RecnumTOP);
      SKIP (-SkipRecs);
      IF dBOF then begin
         Beep;
         GoTop;
      end;
      recnumTOP := RECNO;
      Row       := RowTop;
      PagePaint := TRUE;
   end;
end;

{***************** HOMEPROC ********************}
Procedure GoHome;
Begin
   GoTop;
   recnumTOP := RECNO;
   Row       := RowTop;
   PagePaint := TRUE;
End;

{*********************************************************}
Procedure FillScreen;
Var
   i,
   OldColor:byte;
   OldRec  :LongInt;

begin
   SaveColor(OldColor);

   OldRec:=RecNo;

   Go (RecNumTop);

   For i:=RowTop to RowBottom do begin
      SayRecord(i);
      If not dEOF then
         skip(1);
   end;

   Go (OldRec);
   PaintRecord(Row,TRUE);

   PagePaint:=FALSE;
   RestColor(OldColor);
end;

{-------------------------------------------------------------------}
Procedure GoTheRecord(s:String80);
var
   OldRec,
   RecNum:longint;
Begin

   PaintRecord(Row,True);

   SETCOLOR ('W/N');

   If FullScreen then begin
      s:=EditString(9,2,s,6,NotConvert);
   end else begin
      S:=EditBoxString (1,1,23,3,S,
                        ' Enter MsgNo ','Msg :  ',NotConvert);
   end;
{
┌──── Enter msgno ────┐
│ Msg  : ░░░░░ of 293 │
└─────────────────────┘
}
   If LastKey<>K_ESC then begin
      OldRec := RecNo;
      RecNum := StrToInt(S);
      If (RecNum <> 0) and (RecNum <= RecCount) then begin
         Go(RecNum);
         If Deleted then begin
            Beep;
            Go(OldRec);
         end else begin
            AdjustRow;
            PagePaint := TRUE;
         end;
      end
      else Beep;
   end;
End;



{*******************************}
Procedure AreaEdit(y:integer; Var Modified:boolean);
var
   FieldNum:integer;
   OldRec:Longint;
   LastOrder:integer;
   cId:String12;
   cDesc:String80;
begin
   FieldNum:=1;
   OldRec := RecNo;

   SetColor('W/N');

   LastOrder:=IndexCurrentOrder;

   cId   := RTrim(FieldGet('FILENAME'));
   cDesc := RTrim(FieldGet('AREA'));
   While True do begin

      Case FieldNum of
      1: cId  :=RTrim(EditString (ColLeft+6,y,cId,8,ToUpper));
      2: cDesc:=RTrim(EditString (26,y,cDesc, 52,NotConvert));
      end;

      Modified:= (Modified or Key_Modified);

      Case LastKey of
      K_TAB,
      K_CR,
      K_Down     : begin
                   If FieldNum =1 then begin
                      SetTagTo('AREAID');
                      Find(cId);
                      If dEOF then begin
                         If not ValidDosName(cId) then begin
                            Dec(FieldNum);
                            Beep;
                            WaitForOk('Invalid AreaId. Don''t use extra chars !','Ok',White+Red*16,White);
                         end;
                      end else begin
                         If OldRec <> RecNo then begin
                            Dec(FieldNum);
                            Beep;
                            WaitForOk('Area "'+cId+'" allready exists.','Ok',White+Red*16,White);
                         end;
                      end;
                      SetOrderTo(LastOrder);
                      Go(OldRec);
                   end;
                   Inc(FieldNum);
                   end;
      K_SHIFT_TAB,
      K_Up       : Dec(FieldNum);
      K_CTRL_HOME: FieldNum:=1;
      K_CTRL_END : FieldNum:=2;
      K_ESC      : begin
                   Modified := False;
                   break;
                   end;
      end;

      If FieldNum < 1 then FieldNum :=1;
      If FieldNum > 2 then break;
   end;

   PagePaint:=TRUE;
   SetOrderTo(LastOrder);

   If Modified then begin
      FieldPut('FILENAME',cId);
      FieldPut('AREA',cDesc  );
{      Replace;}
   end;
end;

{---------------------------------------------------------}
Function ChangeRecord(AskForChange:Boolean):Boolean;
var
   Ans:byte;
   cTitle:string[25];
   dStr:string[8];
   adStr:string12;
   pStr:string12;
   aStr:string[35];
   fStr:string[25];
   sStr:string[52];
   OldInsKey,
   Modified:boolean;
{   Ch:char;}
   OldScreen:ScreenPtr;


   Procedure HeaderEdit;
   var
      FieldNum:integer;
   begin
      FieldNum:=1;
{      SetCursorON;}
      SetColor('W/N');

      fStr := RTrim(FieldGet('FROM'));     {1 - From}
      aStr := RTrim(FieldGet('ADDR'));     {2 - Addr}
      dStr :=        DateGet('DATE');      {3 - Date}
      sStr := RTrim(FieldGet('SUBJ'));     {4 - Subj}
      adStr:=        DateGet('APDATE');    {5 - Append Date }
      pStr := '';                          {6 - Project Name}
      If FieldExists('PROJECT') then begin
         pStr := RTrim(FieldGet('PROJECT'));  {6 - Project Name}
      end;

      While True do begin           {Edit Loop for All Header fields}

         Case FieldNum of
         1: fStr:=EditString ( 9,3,fStr,25,NotConvert); {Edit FROM field}
         2: aStr:=EditString (36,3,aStr,35,NotConvert); {Edit ADDRESS field}
         3: begin
            Repeat
               dStr:=EditDate (72,3,dStr);              {Edit DATE field}
            Until (LastKey = K_ESC) or DateStrOk(dStr);
            end;
         4: sStr:=EditString ( 9,4,sStr,52,NotConvert); {Edit SUBJ field}
         5: begin
            Repeat
               adStr:=EditDate (72,4,adStr);            {Edit ApDATE field}
            Until (LastKey = K_ESC) or DateStrOk(adStr);
            end;
         6: pStr:=EditString (60,5,pStr,12,NotConvert); {Edit PROJECT field}
         end;

         Modified:= Modified or Key_Modified;

         Case LastKey of
         K_TAB,
         K_CR,
         K_Down     : Inc(FieldNum);
         K_SHIFT_TAB,
         K_Up       : Dec(FieldNum);
         K_CTRL_HOME: FieldNum:=1;
         K_CTRL_END : FieldNum:=4;
         K_ESC      : break;
         end;

         If FieldNum < 1 then FieldNum :=1;
         If FieldNum > 6 then break;
      end;
   end;


begin {---- ChangeRecord ----}
   Modified := False;

   If Not FullScreen then begin
      PaintRecord(Row,TRUE);
   end;

   If AskForChange then begin

      If Alias='AREAS' then cTitle :=' Change this Area? '
                       else cTitle :=' Change this record? ';

      Ans:=0;
      If AskYesNo(3,6, cTitle) then
         Ans := 1;

   end else begin
      Ans:=1;
      {--- Init New Msg Record }
      LogicPut('NEW', True);
   end;

   If Ans = 1 then begin
      If Alias='AREAS' then begin
         AreaEdit(Row,Modified);
         GetAreaParameters;
      end else begin

         If (not FullScreen) and (Alias = 'WORK') then begin
            OldScreen:=SaveScreen;
            ReadMemo('TEXT');
            DrawRecord;
            MemoSay(1,6,80,24);
         end;

         MemoEditOn:=True;
         DrawHeader;
         MemoSay(1,6,80,24);

         HeaderEdit;

         If LastKey <> K_ESC then begin
            MemoEditOn:=True;
            MemoEdit(1,6,80,24);

            If MemoDropped then begin
               Modified := False;
            end else begin
               Modified:=(Modified or MemoUpdated);
               Modified:= (Modified or Attached or dbfActive^.RecModified);
               If Attached then pStr:=FieldGet('PROJECT');
            end;

         end;

         RecNum:=RecNo;

         If Modified then begin
            Attached:=False;
            FieldPut('FROM',fStr);
            FieldPut('ADDR',aStr);
            DatePut ('DATE',dstr);
            DatePut ('APDATE',adstr);
            FieldPut('SUBJ',sStr);
            If FieldExists('PROJECT') then
               FieldPut('PROJECT',pStr);

{            Replace;
            AdjustRow;
            PagePaint:=True;
}
         end;

      end;

      If Modified then begin
         PagePaint:=TRUE;
         Replace;
         AdjustRow;
         PagePaint:=True;
      end;

      If (not FullScreen) and (Alias = 'WORK') then
         RestScreen(OldScreen);

   end;

   ChangeRecord:=Modified;

end;





{*******************************}
Procedure InsertNewRec;
{  Create a New Record }
var
   Ans : integer;
{   LastOrder :integer;}
   OldRec:longint;
   Modified:Boolean;
begin
   OldRec:=RecNo;

{   Go(RecCount+1);}

   InsertRecord;                   {Insert New Empty Record}

   AdjustRow;                      {Adjust Row number for Browse}

   If not FullScreen then begin
      FillScreen;
{      PaintRecord(FALSE);}
   end;

   If Alias = 'AREAS' then begin
      FieldPut('AREA','...New Topic...');
      AreaEdit(Row,Modified);
   end else begin                     {Do for MSG Base:}
      Today:=Gs_Date_Curr;            {Get Current Date}
      FieldPut('APDATE',DTOS(Today)); {Put Current Date to 'ApDate' field}
      FieldPut('NEW','T');            {Mark inserted record as NEW}

      Memo_Size:=0;                   {Clear MEMO size}
                                      {  Memo Location is eq 0 allready}

      Modified:=ChangeRecord(False);  {Draw the Record & Edit it}
   end;

{   RecNum:= RecNo;}

   If not Modified then begin         {If Editing dropped then   }
      ClearRecord;                    {clear & delete...         }
      DeleteRec;                      { the record just inserted }
      Go(OldRec);                     {Return to previous record }

   end else begin
      Replace;                        {Else Save all changes}
      If Alias = 'WORK' then begin
         Select('AREAS');
         UpdateMsgCounter(1);         {and update the Msg Counter}
         Select('WORK');
      end;
   end;
   AdjustRow;                         {Adjust new row for Browse}
   PagePaint:=True;                   {and mark for the Screen redraw}

end;


Function WhatAreasMenu(const Title:String):Integer;
{Ask What Areas to Use: Current (1), All (2), Marked (3)}
var
  ans,ml:integer;
begin
  If MarkCount = 0 then ml := 3
                   else ml := 4;

  M.Init(2,RowTop,16,RowTop+ml+1, Title,
                 LightGray,White+Blue*16,Yellow,LightRed,White,Centered);

  M.Add(mnCurrentArea);
  M.Add(mnAllAreas   );

  If MarkCount <> 0 then
    M.Add(mnMarkedAreas);

  M.Add(mnQuit_ESC);

  If MarkCount = 0 then Ans :=1
                   else Ans :=3;

  Ans:=M.ReadMenu(Ans);
  M.Done;
  WhatAreasMenu:=Ans;
end;

Function WhatMessagesMenu(const Title:String):Integer;
{Ask What Messages to Use: Current (1), All (2), Marked (3)}
var
  ans,ml:integer;
begin
  If MarkCount = 0 then ml := 3
                   else ml := 4;

  M.Init(2,RowTop,16,RowTop+ml+1, Title,
         LightGray,White+Blue*16,Yellow,LightRed,White,Centered);

  M.Add(mnCurrentMsg);
  M.Add(mnAllMsgs   );

  If MarkCount <> 0 then
    M.Add(mnMarkedMsgs);

  M.Add(mnQuit_ESC);

  If MarkCount = 0 then Ans :=1
                   else Ans :=3;

  Ans:=M.ReadMenu(Ans);
  M.Done;
  WhatMessagesMenu:=Ans;
end;





{-------------------------------------------------------------}
{------Delete Selected Record(s)------------------------------}
Procedure DelRecords;
var
   i,ml,
   Ans:integer;
   NewRec,OldRec:LongInt;
   fName:string;
   DelBaseToo:Boolean;
   PostFix:String[1];
begin

   DelBaseToo:=False;      {Don't Delete DataBase Files}
   PostFix:='';
   If not FullScreen then
      PaintRecord(Row,TRUE);

   If MarkCount=0 then ml:=3
                  else ml:=4;

   If Alias = 'AREAS' then begin
      Ans:=WhatAreasMenu(' Delete ');
   end else begin
      Ans:=WhatMessagesMenu(' Delete ');
   end;

   If (LastKey <> K_ESC) and (Ans <> ml) then begin
      RecNum:=RecNo;

      If MarkCount = 0 then begin
         MarkCount := 1;
         MarkArray[1] := RecNo;
      end;

      If Alias = 'AREAS' then begin
         If AskYesNo(0,0,' Kill The DataBase'+PostFix+' too? ') then begin
            DelBaseToo:=True;      {User want to Delete DataBase Files}
         end;
      end;

{      Warning ('Wait a minute!; It''s deleting now...',,White*16);}

      For i:=1 to MarkCount do begin
         Go (MarkArray[i]);
         Skip(1);
         NewRec:=RecNo;               {Remember next Msg Number}
         Skip(-1);

         If (Alias = 'AREAS') and (DelBaseToo) then begin
            fName := BaseDir+'\' + RTrim(FieldGet('FILENAME'));
            GsFileDelete(fName+'.dbf');
            GsFileDelete(fName+'.fpt');
            GsFileDelete(fName+'.cdx');
         end;

         ClearRecord;
         DeleteRec;

      end;

      Go(NewRec);
      If dEOF then begin
         GoBottom;
      end;

      If Alias = 'WORK' then begin
         {--- Update Msg Counter }
         Select('AREAS');
         UpdateMsgCounter(-MarkCount);
{         Ans:=IntegerGet('MSGCOUNT');
         Dec(Ans,MarkCount);
         If Ans < 0 then Ans :=0;
         IntegerPut('MSGCOUNT',Ans);
         Replace;}
         Select('WORK');

      end;

      MarkCount:=0;

      AdjustRow;
      PagePaint:=True;

   end;
end;

{**********************************************************************}
Procedure PackDataBase;
{ Перепаковать Базу Данных (убрать удаленные записи) }
{----------------------------------}
var
  n:longint;
begin

   PaintRecord(Row,True);
   If AskYesNo(3,3,' Pack the MsgBase? ') then begin

      PACK;

      GoBottom;
      n:=RecNo;
      Select('AREAS');
      IntegerPut('MSGCOUNT',n);
      Replace;  { Rewrite Msg Counter }
      Select('WORK');

      GoTop;

      AdjustRow;
      PagePaint:=True;

   end;

end;


{**********************************************************************}
Procedure MoveRecords;
{ Переместить Сообщение (или выделенные ) в другую базу }
{----------------------------------}
Const
   ScaleMsg: String[34] ='Wait a minute! It''s copying now...';
var
   OldScreen :ScreenPtr;
   i         :integer;
   Ans       :integer;
   OldRec    :longint;
   NewRec    :longint;
   TargetArea:longint;
   TargetRec :longint;
   nSize     :longint;
   FSize     :longint;
   OldFile   :String12;
   TargetFile:String12;
   Strn      :string;
   OldColor  :byte;
   MoveIt    :Boolean;
begin

 If Alias = 'WORK' then begin  { Операция возможна только из Msg List }
   SaveColor(OldColor);
   OldScreen:=SaveScreen;

   nSize:=0;
   Ans := 1;

   M.Init(2,RowTop,16,RowTop+4, ' Action ',
                 LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
   M.Add(mnMoveMsg );
   M.Add(mnCopyMsg );
   M.Add(mnQuit_ESC);

   Ans:=M.ReadMenu(Ans);
   M.Done;

   If (LastKey <> K_ESC) and (Ans <> 3) then begin

      If Ans = 1 then begin  {For MOVE}
         strn:='Move';
         MoveIt := True;
         ScaleMsg[21]:=' ';
         ScaleMsg[22]:='m';
         ScaleMsg[23]:='o';
         ScaleMsg[24]:='v';
      end else begin         {For COPY}
         strn:='Copy';
         MoveIt := False;
         ScaleMsg[21]:='c';
         ScaleMsg[22]:='o';
         ScaleMsg[23]:='p';
         ScaleMsg[24]:='y';
      end;

      Ans:=WhatMessagesMenu(' Action ');
(*      M.Init(2,RowTop,16,RowTop+4, ' Action ',
                    LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
      M.Add(mnMarkedMsgs);
      M.Add(mnCurrentMsg);
      M.Add(mnQuit_ESC  );

      If MarkCount = 0 then Ans := 2  {If any marked then place ro "Marked"}
                       else Ans := 1; {Else place to "Current"             }

      Ans:=M.ReadMenu(Ans);
      M.Done;
*)
      If (LastKey <> K_ESC) and (Ans <> 3 {"Quit"}) then begin

         Select('AREAS');    {Switch to Area List}
         OldRec:=RecNo;      {Remember current AREA record number }

         OldFile := AllTrim(FieldGet('FILENAME')); {Remember current AREA FileName}

         { Select the Area to copy }
         Browse({AreaBase,'',}2,3,79,23,'>>Copy To Area:',True);
         {the Browse exits on selected area (if not escaped) }

         If LastKey <> K_ESC then begin

            { Get Area Name to Copy/Move}
            TargetFile := AllTrim(FieldGet('FILENAME'));
            TargetRec  := RecNo;     { Remember New AREA Rec Number}

            Go(OldRec);              { Return to Old Record}

            Select('WORK');          { Return to Msgs List DataBase}

            DrawScale(12,19,ScaleMsg,LightRed,Yellow,LightGray);

(*            If MoveIt then
               DrawScale(12,19,'Wait a minute! It''s moving  now...',LightRed,Yellow,LightGray)
            else
               DrawScale(12,19,'Wait a minute! It''s copying now...',LightRed,Yellow,LightGray);
*)
            If OldFile = TargetFile then  {If Copy to the same Area }
               TargetArea := 2
            else begin                    {If Copy to another Area  }
               TargetArea := 3;
               OpenWorkBase(TargetFile,'TMP',DontAsk); {For Select(3)}
            end;

            Select('WORK');           { Return to Msg List DataBase }
            RecNum:=RecNo;            { Remember current Msg number }

            If MarkCount=0 then begin { If No marked - mark current}
               MarkCount:=1;
               MarkArray[1]:=RecNo;
            end;

            For i:=1 to MarkCount do begin   {For All Marked Msgs}

               Go (MarkArray[i]);

               {Copy the Msg to Another Area}
               Copy1Record(TargetArea);
(*
               If MoveIt then begin
                  If i=MarkCount then begin
                     Skip(1);
                     RecNum:=RecNo;          {Adjust new current msg number}
                     Skip (-1);
                  end;
               end;
*)
               Select('AREAS');
               Go (TargetRec);               { Increase the Msg Counter }
               UpdateMsgCounter(1);          { in target AreaBase       }
               Go (OldRec);

               Select('WORK');               { Msgs list - WORK}

               If MoveIt then begin          { If MOVE mode then     }
                  Skip(1);
                  RecNum:=RecNo;             { Remember next Msg number }
                  Skip(-1);
                  ClearRecord;               { clear just copied rec }
                  DeleteRec;                 { and remove it then    }

                  Select('AREAS');           { AREAS }
                  UpdateMsgCounter(-1);      { Decrement Message Counter}
                  Select('WORK');            { WORK }
               end; {If MoveIt}
            end;    {For i :=1 to MarkCount}

            If OldFile <> TargetFile then begin {Close the Area where to copy}
               Select('TMP'); {  TMP  }
               USE('','',False);
               Select('WORK'); {  WORK }
            end;

            MarkCount:=0;

            Go (RecNum);

            While Deleted do Skip(1);
            If dEOF then GoBOTTOM;

            If MoveIt then begin           {Adjust current msg number}
               AdjustRow;
               PagePaint:=True;
            end;
         end;

      end;
   end;

   RestScreen(OldScreen);
   RestColor(OldColor);
 end;
end;

{------------------ Search Routines ------------------------}
Procedure GetFindString;
begin

   SETCOLOR ('W/N');

   FindStr:=EditBoxString (8,13,70,15,FindStr,
                  ' Enter SearchString (Header+Text) ','',NotConvert);

   If LastKey <> K_ESC then begin
         FindUP:=Upper(FindStr);
   end;
end;

(*!
Procedure MemoUpper;
var i:word;
begin
  For i:=1 to Memo_Size do
     DbfActive^.MemoFile^.memo^[i] := Upcase(DbfActive^.MemoFile^.Memo^[i]);
end;
*)



{--------------------------------------------------------------}
Procedure FindNextRecord;
{ Hаходит в базе следующую запись }
var
   n,m,nr:word;
   OldScreen:ScreenPtr;

   Function CheckInMemo:longint;
   begin
      FindLen := Length(FindStr);
      {Copy Searched String to MemoPack Buffer}
{      move(Memo^,Memo_Pack^,Memo_SiUpper;}
{      CheckInMemo:= BinAT(FindUp,dbfActive^.MemoFile^.Memo^,MemoSize);}
      CheckInMemo:= ScanUpBufr(FindStr,Memo^,Memo_Size);
   end;

   Function CheckInHeader:word;
      begin
         If Alias = 'AREAS' then begin
            FindLen:=FieldLen(FieldNo('FILENAME'))+
                     FieldLen(FieldNo('AREA'));

            FindTmp:=Upper(FieldGet('FILENAME'));
            n:=length(FindTmp);
            move(FindTmp[1],FindRec^,length(FindTmp));

            FindTmp:=Upper(FieldGet('AREA'));
            move(FindTmp[1],FindRec^[n],Length(FindTmp));
         end else begin
            FindLen:=FieldLen(FieldNo('FROM'))+
                     FieldLen(FieldNo('ADDR'))+
                     FieldLen(FieldNo('SUBJ'));

            FindTmp:=Upper(FieldGet('FROM'));
            n:=length(FindTmp);
            move(FindTmp[1],FindRec^,Length(FindTmp));

            FindTmp:=Upper(FieldGet('ADDR'));
            m:=length(FindTmp);
            move(FindTmp[1],FindRec^[n],Length(FindTmp));

            FindTmp:=Upper(FieldGet('SUBJ'));
            move(FindTmp[1],FindRec^[n+m],Length(FindTmp));
         end;

        CheckInHeader:= BinAT(FindUp,FindRec^,FindLen);

      end;

begin

 DBFActive^.gsvFound:=False;

 If FindUp <> '' then begin

   RecNum:=RecNo;
   FindCount:=0;
{   SaveScreen(OldScreen);}

   if MaxAvail < RecSize then begin
      WaitForOk('Not enough memory for the search','Ok',White+Red*16,White);
   end else begin
      OldScreen:=SaveScreen;
      { Allocate memory on heap }
      GetMem(FindRec, RecSize);

      DrawScale(12,19,'Searching for "'+FindStr+'"',LightRed,Yellow,LightGray);
{!      nr := RecCount-IndexRecNo;}

      While not dEOF do begin
         Skip(1);
         Inc(FindCount);
         Scale(RecCount,FindCount);

         If RecNum = RecNo then break;

         n:= CheckInHeader;

         IF n > 0 then begin              {Check for the Header}
            DBFActive^.gsvFound:=True;
            RecNum := RecNo;
            Break;                        {Break While not dEOF}
         end else begin                   {Check for the Memo  }

          If FindText then begin
            ReadMemo('TEXT');
            n:= CheckInMemo;
            IF n > 0 then begin
               DBFActive^.gsvFound:=True;
               RecNum := RecNo;
               Break; {While not dEOF}
            end;
         end;
       end;
      end;

      FreeMem(FindRec, RecSize);
      Delay(200);
      RestScreen(OldScreen);

      IF FOUND then begin
         AdjustRow;
         PagePaint:=True;
      end else begin
         Beep;
         WaitForOk('"'+FindStr+'" Not found','Ok',White+Red*16,White);
      end;
   end;

   Go(RecNum);
 end;
end;

{*******************************************************************}
Procedure FindInHeaders;
{ Hаходит в заголовке и показывает нужную запись }
begin
   FindText:=False;
   GetFindString;       { Get Search string }

   If  LastKey <> K_ESC then begin
      FindNextRecord;   { Find Next Record  }
   end;
end; { FindRecords }


{*******************************************************************}
Procedure FindRecords;
{ Hаходит в базе и показывает нужную запись }
begin
   If Alias = 'AREAS' then
      FindText:=false
   else
      FindText:=True;

   GetFindString;       { Get Search string }

   If  LastKey <> K_ESC then begin
      FindNextRecord;   { Find Next Record  }
   end;
end; { FindRecords }

{----------------------------------------}
Procedure Seek;
Var
   cOrdered:string[12];
   OldColor:byte;
   OldScreen:ScreenPtr;
   lFound:Boolean;
begin
   SaveColor(OldColor);
   OldScreen:=SaveScreen;

   lFound:=dEOF;
   Find('N4');
   lFound:=dEOF;
   cOrdered:=FieldGet('FILENAME');

   Case IndexCurrentOrder of
   0:                        ; { No Order}
   1: If Alias='AREAS'  then begin end  {DEscription}
                        else begin end; {From       }
   2: If Alias='AREAS'  then begin end  {AreaID     }
                        else begin end; {Subject    }
   end;

   RestScreen(OldScreen);
   RestColor(OldColor);
end;

(*
{----------------------------------------}
Procedure SaveMemo;
begin
   If AskYesNo(3,6,' Save this record? ') then begin
      Delay(200);
      {dbfActive^.}{!MemoPut('TEXT');}
   end;
end;
*)

{************** WriteToFile **********************************************}
{Write Current/Marked Messges to a file}
Procedure WriteToFile;
var
   OldScreen:ScreenPtr;
   nHandle:File;
   i:integer;
   WriteType:integer;
   OldRec,
   RealSize:Longint;
{   cStr:string;}
   OnlyCurrent,
   NeedHeader:Boolean;

   Function SelectCurrent:Boolean;
   {Select what message to write: Current/Marked/All}
   begin
      SelectCurrent := True;
      If MarkCount > 0 then begin
         M.Init(1,6,15,10, ' Write ',
                  LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
         M.Add(mnMarkedMsgs);
         M.Add(mnCurrentMsg);
         M.Add(mnQuit_ESC  );

         i:=M.ReadMenu(1);
         M.Done;
         If i = 1 then
            SelectCurrent := False;
         If i = 3 then
            LastKey := K_ESC;
      end;
   end;

   Function WhereToWrite:Integer;
   {Select the Type and File Name for MSG writing}
   begin
         M.Init(1,6,19,12, ' Write to: ',
                  LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
         M.Add(mnDiskFile   ); {1}
         M.Add(mnHtmlFile   ); {2}
         M.Add(mnPrintDevice); {3 - not realized}
         M.Add(mnClipboard  ); {4 - not realized}
         If NeedHeader then
            M.Add(mnUseHeader_YES)  {5}
         else
            M.Add(mnUseHeader_NO ); {5}
         M.Add(mnQuit_ESC);         {0 or Last=6 -> Quit}

         i:=1;

         Repeat

            i:=M.ReadMenu(i); {Select the Write Type}

            If i = 5 then begin  {Change the "Write Header" Type}

               NeedHeader := not NeedHeader;
               If NeedHeader then
                  M.SetMenuItem(5,' Use Header: YES ')
               else
                  M.SetMenuItem(5,' Use Header: NO  ');
               M.ReDraw:=True;
            end;

         Until (LastKey = K_ESC) or (i <> 5);
         M.Done;

      WhereToWrite := i;
   end;

   Procedure OpenFileToWrite;
   {Check Existence for the Output File}
   begin
      If GsFileExists(FileToWrite) then begin
         Warning(FileToWrite,White,White);

         M.Init(1,6,30,10, ' File Exists! ',
                  LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
         M.Add(mnAppendToEndOfFile);
         M.Add(mnOverwriteTheFile );
         M.Add(mnCancel_ESC       );

         i:=M.ReadMenu(1); {Select for Create/Overwrite/Append}
         M.Done;

         System.Assign(nHandle,FileToWrite);

         Case i of
         1: begin
            {$i-}System.Reset(nHandle,1);{$i+}
            {$i-}System.Seek (nHandle,System.FileSize(nHandle));{$i+}
            end;
         2: begin
            {$i-}System.Rewrite(nHandle,1);{$i+}
            end;
         0,
         3: begin
            LastKey:=K_ESC;
            end;
         end; {Case}
      end else begin
         System.Assign(nHandle,FileToWrite);
         {$i-}System.Rewrite(nHandle,1);{$i+}
      end;

      IF System.IoResult <> 0 then begin
         { "Ошибка записи в файл!" }
         WaitForOk('Error opening "'+FileToWrite+'"!','Ok',White+Red*16,White);
         LastKey:=K_ESC;
      end;
   end;

begin   {---- WriteToFile ----}

   If Alias ='WORK' then begin

      NeedHeader  := True;
      OnlyCurrent := SelectCurrent;

      If not FullScreen then
         OldScreen:=SaveScreen;

      If LastKey <> K_ESC then begin
         WriteType := WhereToWrite;
      end;

      If LastKey <> K_ESC then begin
         If WriteType=1 then begin      {Text File}
           FileToWrite:=Project+'.txt';
(*         else If WriteType=2 then     {Html File}
           FileToWrite:=ListDir+'\'+Project+'.htm';
*)
           FileToWrite:=EditBoxString(8,13,70,15,FileToWrite,
                      ' Write Msg(s) to File: ','',NotConvert);
         end;

         If LastKey <> K_ESC then begin
            If WriteType=1 then OpenFileToWrite;
         end;

         If LastKey <> K_ESC then begin

            If WriteType=2 then begin
              DrawScale(12,18,'Writing HTML files...',LightRed,Yellow,LightGray);
              PrepareBuffers;
            end else
              DrawScale(12,18,'Writing to "'+FileToWrite+'"',LightRed,Yellow,LightGray);

            If OnlyCurrent then begin
               If WriteType=1 then {Text File}
                 Write1Message(nHandle,NeedHeader,NIL);

               If WriteType=2 then begin {HTML File}
                  PrepareBuffers;
                  GetMsgParameters;
                  FillMsgBuffers;
                  WriteMsgBody;
                  CloseBuffers;
               end;

               Scale(i,i);

            end else begin {More than one Area}

               OldRec:=RecNo;           {Save current record number}

               For i:=1 to MarkCount do begin    {Do for ALL marked Msgs}
                  Go (MarkArray[i]);

                  If WriteType=2 then begin { for HTML files }
                    GetMsgParameters;
                    FillMsgBuffers;
                    WriteMsgBody;
                  end else begin            { for TEXT files }
                    ReadMemo('TEXT');
                    Write1Message(nHandle,NeedHeader,NIL);
                  end;

                  If MarkCount > 1 then
                     Scale(MarkCount,i);
               end; {For i:=1 to MarkCount}

               If WriteType=2 then begin { for HTML files }
                  CloseBuffers;
               end;

               {MarkCount:=0;}
               Go(OldRec);

               If FullScreen then
                  ReadMemo('TEXT');        {ReRead the last Memo}

               {PagePaint:=True;}

            end;

            If WriteType=1 then System.CLOSE( nHandle );

            Scale(MarkCount,MarkCount);
            Delay(1000);
         end;
      end;

      If not FullScreen then
         RestScreen(OldScreen);
   end;
end;


{***********************************************************************}
Procedure ViewMemo(ColLeft,RowTop,ColRight,RowBottom:byte);
{* ──── Full Screen View ────}
Var
   OldScreen:ScreenPtr;
   cKey:Char;
   s:String;
   nRes:Integer;




{----------ViewMemo------------------------------------}
begin
   FullScreen:=True;
   OldScreen:=SaveScreen;
   SaveColor(OldColor);
   cKey      := #0;
   s:='';

   DrawRecord;

   While (not Escaped) and (cKey <> K_ESC) do begin

      ReadMemo('TEXT');
{      FieldPut('NEW','F');}

      DrawHeader;

      MemoEditOn:=False;
      MemoEdit(1,6,80,24);

      cKey := LastKey;
      If Key_Func then begin
         Case cKey of
         K_DEL      : DelRecords;          {Delete current/marked msg    }
         K_INS      : InsertNewRec;        {Insert new msg               }
         K_LEFT     : GoUp(false);         {Go to previous msg           }
         K_RIGHT    : GoDown(false);       {Go to next msg               }
         K_ALT_A    : DoQuit;              {Exit RSWAG                   }
         K_ALT_C    : ChangeRecord(True);  {Edit current msg             }
         K_ALT_E    : Extract({DontAsk}AskMe);    {Extract the project from msg }
         K_ALT_F    : FindRecords;         {Find msg by body substring   }
         K_ALT_M    : MoveRecords;         {Copy/move current/marked msg }
         K_F2,
         K_ALT_P    : PackDataBase;        {Pack current msg base        }
         K_ALT_R    : {ChangeCutter(.T.)};
{         K_ALT_S    : SaveMemo;            {Save current msg             }
         K_ALT_U    : UUDecode(True);      {UuDecode all UUEs from msg   }
         K_ALT_W    : begin
                         WriteToFile;      {Write current/marked msg    }
(*                      If LastKey <> K_ESC then begin
                         init_spawno('.',swap_all,20,0) ;
                         nRes := spawn(Editor,FileToWrite,0) ;
                         if (nRes = -1) then
                             writeln('Error code = ',spawno_error)
                         else writeln('Return code = ',nRes) ;
(*
                         SwapVectors;
{                         nRes:=DosShell(Editor + ' '+ FileToWrite);}
                         Execute(Editor,FileToWrite);
                         nRes:=DosError;
                         SwapVectors;
                       end;
*)
                      end;
         K_ALT_X    : DoQuit;              {Exit RSWAG                   }
         K_ALT_Z    : FindInHeaders;       {Find msg by header substring }
{         K_Ctrl_Left,}
         K_Ctrl_Home: GoHome;              {Go to first msg              }
{         K_Ctrl_Right,}
         K_Ctrl_End : GoEnd;              {Go to last msg               }
         end;
      end else begin
         Case cKey of
         K_CTRL_L   : FindNextRecord;      {Find next msg                }
         K_CTRL_G   : GoTheRecord('');     {Go to the N msg              }
         K_Esc      : Break;               {Exit msg viewer              }
         K_CTRL_Q   : ExitReader;          {Exit RSWAG immediately       }
         K_LeftRus,
         K_LeftSign : GoHome;              {Go to first msg              }
         K_RightRus,
         K_RightSign: GoEnd;               {Go to last msg               }
         K_Space    : MarkRecord;          {Mark/Unmark the current msg  }
         '0'..'9'   : begin
{                         s:=cKey;}
                         GoTheRecord(cKey);{Go to the N msg              }
                      end;
         end;
      end;

   End;

   RestColor(OldColor);
   RestScreen(OldScreen);
   PagePaint:=TRUE;
   FullScreen:=False;

end;



(*
{-------------------------------------------------------------}
Procedure MakeMsgListOld;
{Build the msgs list (like files.bbs) }
var
   nHandle:text;
   fn,
   cFileName:string80;
   OldScreen:ScreenPtr;
   OldMC,
   OldMA,
   OldRec,
   snipets,
   TotalSize,
   AllSize:LongInt;
   l:longint;
   AllSizeChar:Array[0..3] of char absolute AllSize;
   ListLen,
   AreaCount,
   Ans,
   ml,
   i:integer;
   {--------------------------------}
   Procedure ListCurrentBase;
   begin
      { Say snipet header }
{      fn:=AllTRim(FieldGet('FILENAME'));}
      System.Write( nHandle,PadR(AreaID,9),'- ');
{      Writeln( nHandle,PadR(FieldGet('AREA'),42));}
      Writeln( nHandle,PadR(AreaDescr,42));
      Writeln( nHandle,Replicate('~',50));

      ListLen:=0;
      AllSize:=0;

      If GsFileExists(BaseDir+'\'+RealAreaName+'.DBF') then begin
         OpenWorkBase(RealAreaName,'WORK',DontAsk);
         GoTOP;
         { List snipets in the file }
         While not dEOF do begin
{            ReadMemo('TEXT');}
            GetMsgParameters;
            System.Write( nHandle,PadR(FROM,25),' ');
            l:=MemoSize('ATTACHME');       {Get Attachment Size}
            System.Write( nHandle,({Memo_Size+}l):7,' ');
            Writeln( nHandle,SUBJ);

            Inc(ListLen);
            Inc(AllSize,l);          {Add Attachment Size }
{            Inc(AllSize,Memo_Size);  {Add Description Size}
            Skip(1);
         end;      { While not dEOF in work area}

         Use('','',False);  { Close Current DataBase }
         Inc(Snipets,ListLen);
         Inc(TotalSize,AllSize);

      end; {If FieExist}

      { Say this file totals}
      Writeln(nHandle,'------------------------- -------');
      cFileName:=InsCommas(IntToStr(AllSize));  {Convert Size to STRING}
      Writeln(nHandle,ListLen:18,PadL(cFileName,15),' bytes');
      Writeln( nHandle,'');

      Select('AREAS');
      Inc(AreaCount);
      Scale(RecCount,AreaCount);
   end;

   {--------------------------------}
   Procedure ListTotals;
   { Say totals}
   begin
      Writeln(nHandle,'------------------------- -------');
      cFileName:=InsCommas(IntToStr(TotalSize));  {Convert Size to STRING}
      Writeln(nHandle,'Total: ',Snipets:10,' ',PadL(cFileName,15),' bytes');
      Writeln(nHandle,'');

      System.CLOSE( nHandle );
      Scale(RecCount,RecCount);
      Delay(1000);
   end;

   {--------------------------------}
   Procedure ListHeader;
   begin
      DrawScale(12,19,'Listing to "'+cFileName+'"',LightRed,Yellow,LightGray);

      Writeln(nHandle,'==================== ',AreaBase,' Snipets List =====================');
      Writeln(nHandle,'   (c) 1993-2001 by Valery Votintsev (vot@infolink.tver.su)');
      Writeln(nHandle,'');
      Writeln(nHandle,'From                      Size    Subject');
      Writeln(nHandle,'------------------------- ------- --------------------------');
   end;

   {--------------------------------}
   Function ListOpen:Boolean;
   Var
      Ans:Integer;
   begin
      Ans:=2; { Rewrite the List }
      If GsFileExists(cFileName) then begin
         M.Init(1,6,30,10, ' File Exists! ',
                LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
         M.Add(mnAppendToEndOfFile);
         M.Add(mnOverwriteTheFile );
         M.Add(mnCancel_ESC       );

         Ans:=M.ReadMenu(1);
         M.Done;
      end;

      If Ans = 0 then
         Ans := 3;

      ml :=0;

      System.Assign(nHandle,cFileName);
      If Ans = 1 then begin
         {$i-}System.Append(nHandle);{$i+}
         ml := System.IoResult;
      end;
      If Ans = 2 then begin
         {$i-}System.Rewrite(nHandle);{$i+}
         ml := System.IoResult;
      end;

      If ml <> 0 then
         WaitForOk('Error opening '+cFileName+' !','Ok',White+Red*16,White);

      ListOpen := (Ans <> 3) and (ml = 0);
   end;

begin {Procedure MakeMsgList;}

   If not FullScreen then
      PaintRecord(Row,TRUE);

   If MarkCount = 0 then ml := 3
                    else ml := 4;

   M.Init(2,RowTop,16,RowTop+ml+1, ' List ',
                 LightGray,White+Blue*16,Yellow,LightRed,White,Centered);

   M.Add(mnAllAreas   );
   M.Add(mnCurrentArea);

   If MarkCount <> 0 then
      M.Add(mnMarkedAreas);

   M.Add(mnQuit_ESC);

   If MarkCount = 0 then Ans :=2
                    else Ans :=3;

   Ans:=M.ReadMenu(Ans);
   M.Done;

   If (LastKey <> K_ESC) and (Ans <> ml) then begin

      { Store old MarkArray }
      If Ans = 2 then begin
         OldMC := MarkCount;
         OldMA := MarkArray[1];
         MarkCount := 1;
         MarkArray[1] := RecNo;
      end;

      OldScreen:=SaveScreen;

      OldRec   :=RecNo;
      AreaCount:=0;
      Snipets  :=0;
      TotalSize:=0;
      ListLen  :=0;
      AllSize  :=0;

      cFileName:=AreaBase+'.LST';
      SetColor ('W/N');

      cFileName:=EditBoxString (8,13,70,15,cFileName,
                 ' List Msgs to the File: ','',NotConvert);

      If LastKey<>K_ESC then begin

         {Warning ('Wait a minute!; It''s listing now...',,White*16);}

         If not ListOpen then begin
         end else begin
            ListHeader;

            If Ans = 1 then begin {for ALL areas}
               GoTOP;
               While not dEOF do begin
                  { List Current Base }
                  GetAreaParameters;
                  ListCurrentBase;
                  Skip(1);
               end;      { While not dEOF in work area}
            end else begin        {for current/marked areas}
               For i:=1 to MarkCount do begin
                  Go (MarkArray[i]);
                  { List Current Base }
                  GetAreaParameters;
                  ListCurrentBase;
               end; { For }

            end;

            { Say totals}
            ListTotals;
            Go(OldRec);
         end; {If ListOpen}
      end; {If LastKey <> K_ESC in FileName Edit}

      RestScreen(OldScreen);
      { Restore old MarkArray }
      If Ans = 2 then begin
         MarkCount    := OldMC;
         MarkArray[1] := OldMA;
      end;
   end; {If Lastkey <> K_ESC from Menu}
end;
*)

{-----------------------------------------------}
Procedure MakeMsgList;
{Build the msgs list (like files.bbs) }
var
   nHandle:text;
   fn,
   cFileName:string80;
   OldScreen:ScreenPtr;
   OldMC,
   OldMA,
   OldRec,
   snipets,
   TotalSize,
   AllSize:LongInt;
   l:longint;
   AllSizeChar:Array[0..3] of char absolute AllSize;
   ListLen,
   AreaCount,
   Ans,
   ml,
   i:integer;
  MarkedExists:Boolean;
  menulength,WhatRecords:Integer;

   {--------------------------------}
   Procedure ListCurrentBase;
   begin
      { Say snipet header }
{      fn:=AllTRim(FieldGet('FILENAME'));}
      System.Write( nHandle,PadR(AreaID,9),'- ');
{      Writeln( nHandle,PadR(FieldGet('AREA'),42));}
      Writeln( nHandle,PadR(AreaDescr,42));
      Writeln( nHandle,Replicate('~',50));

      ListLen:=0;
      AllSize:=0;

      If GsFileExists(BaseDir+'\'+RealAreaName+'.DBF') then begin
         OpenWorkBase(RealAreaName,'WORK',DontAsk);
         GoTOP;
         { List snipets in the file }
         While not dEOF do begin
{            ReadMemo('TEXT');}
            GetMsgParameters;
            System.Write( nHandle,PadR(FROM,25),' ');
            l:=0;
            If FieldExists('ATTACHME') then
              l:=MemoSize('ATTACHME');       {Get Attachment Size}
            System.Write( nHandle,({Memo_Size+}l):7,' ');
            Writeln( nHandle,SUBJ);

            Inc(ListLen);
            Inc(AllSize,l);          {Add Attachment Size }
{            Inc(AllSize,Memo_Size);  {Add Description Size}
            Skip(1);
         end;      { While not dEOF in work area}

         Use('','',False);  { Close Current DataBase }
         Inc(Snipets,ListLen);
         Inc(TotalSize,AllSize);

      end; {If FieExist}

      { Say this file totals}
      Writeln(nHandle,'------------------------- -------');
      cFileName:=InsCommas(IntToStr(AllSize));  {Convert Size to STRING}
      Writeln(nHandle,ListLen:18,PadL(cFileName,15),' bytes');
      Writeln( nHandle,'');

      Select('AREAS');
      Inc(AreaCount);
      Scale(RecCount,AreaCount);
   end;

   {--------------------------------}
   Procedure ListTotals;
   { Say totals}
   begin
      Writeln(nHandle,'------------------------- -------');
      cFileName:=InsCommas(IntToStr(TotalSize));  {Convert Size to STRING}
      Writeln(nHandle,'Total: ',Snipets:10,' ',PadL(cFileName,15),' bytes');
      Writeln(nHandle,'');

      System.CLOSE( nHandle );
      Scale(RecCount,RecCount);
      Delay(1000);
   end;

   {--------------------------------}
   Procedure ListHeader;
   begin
      DrawScale(12,19,'Listing to "'+cFileName+'"',LightRed,Yellow,LightGray);

      Writeln(nHandle,'==================== ',AreaBase,' Snipets List =====================');
      Writeln(nHandle,'   (c) 1993-2001 by Valery Votintsev (rswag AT sources.ru)');
      Writeln(nHandle,'');
      Writeln(nHandle,'From                      Size    Subject');
      Writeln(nHandle,'------------------------- ------- --------------------------');
   end;

   {--------------------------------}
   Function ListOpen:Boolean;
   Var
      Ans:Integer;
   begin
      Ans:=2; { Rewrite the List }
      If GsFileExists(cFileName) then begin
         M.Init(1,6,30,10, ' File Exists! ',
                LightGray,White+Blue*16,Yellow,LightRed,White,Centered);
         M.Add(mnAppendToEndOfFile);
         M.Add(mnOverwriteTheFile );
         M.Add(mnCancel_ESC       );

         Ans:=M.ReadMenu(1);
         M.Done;
      end;

      If Ans = 0 then
         Ans := 3;

      ml :=0;

      System.Assign(nHandle,cFileName);
      If Ans = 1 then begin
         {$i-}System.Append(nHandle);{$i+}
         ml := System.IoResult;
      end;
      If Ans = 2 then begin
         {$i-}System.Rewrite(nHandle);{$i+}
         ml := System.IoResult;
      end;

      If ml <> 0 then
         WaitForOk('Error opening '+cFileName+' !','Ok',White+Red*16,White);

      ListOpen := (Ans <> 3) and (ml = 0);
   end;


begin {Procedure MakeMsgList;} {New!}

   If not FullScreen then
      PaintRecord(Row,TRUE);

   MarkedExists:= (MarkCount <> 0);
   If MarkedExists then menulength := 4    {1 - current}
                   else menulength := 3;   {2 - all    }
                                           {3 - marked }
                                           {4 - quit   }
   If Alias='AREAS' then begin
     WhatRecords:=WhatAreasMenu(' List Areas');
   end else begin
     WhatRecords:=WhatMessagesMenu(' List Msgs');
   end;

   If (LastKey <> K_ESC) and (WhatRecords <> menulength) then begin

      { Store old MarkArray }
      If WhatRecords = 1 then begin  {Current}
         OldMC := MarkCount;
         OldMA := MarkArray[1];
         MarkCount := 1;
         MarkArray[1] := RecNo;
      end;

      OldScreen:=SaveScreen;

      OldRec   :=RecNo;
      AreaCount:=0;
      Snipets  :=0;
      TotalSize:=0;
      ListLen  :=0;
      AllSize  :=0;

      cFileName:=AreaBase+'.LST';
      SetColor ('W/N');

      cFileName:=EditBoxString (8,13,70,15,cFileName,
                 ' List Msgs to the File: ','',NotConvert);

      If LastKey<>K_ESC then begin

         {Warning ('Wait a minute!; It''s listing now...',,White*16);}

         If not ListOpen then begin
         end else begin
            ListHeader;

            If WhatRecords = 2 then begin       {for ALL areas}
               GoTOP;
               While not dEOF do begin
                  { List Current Base }
                  GetAreaParameters;
                  ListCurrentBase;
                  Skip(1);
               end;      { While not dEOF in work area}

            end else begin                        {for current/marked areas}
               For i:=1 to MarkCount do begin
                  Go (MarkArray[i]);
                  { List Current Base }
                  GetAreaParameters;
                  ListCurrentBase;
               end; { For }

            end;

            { Say totals}
            ListTotals;
            Go(OldRec);
         end; {If ListOpen}
      end; {If LastKey <> K_ESC in FileName Edit}

      RestScreen(OldScreen);
      { Restore old MarkArray }
      If WhatRecords = 1 then begin
         MarkCount    := OldMC;
         MarkArray[1] := OldMA;
      end;
   end; {If Lastkey <> K_ESC from Menu}
end;

{*──────────────────────────────────────────*}
Procedure ParseFidoAddress(S:String;Var cFrom,cAddr,cDate:String80);
{--- Parse Address Line & Fill Address, Name & Subj Fields }
Var
   n:byte;
begin
   cDate:=Substr(S,61,9);
   cDate:=ParseDateStr(cDate);
   Delete(S,61,255);       {Remove Date & Time}
   S:=RTrim(S);

   n:=Length(S);           {Search Address}
   While (n>0) and (S[n]<>' ') do Dec(n);
   cAddr:=Substr(S,n+1,255);

   Delete(S,n,255);        {Search From Name}
   cFrom:=RTrim(Substr(S, 9,255));
end;

(* Old version
{*──────────────────────────────────────────*}
Procedure ParseRelcomAddress(S:String;Var Name,Address,cFirstStr:String);
{--- Parse Address Line & Fill Address and Name Fields }
Const
   FidoChars:Array[1..4] of Char = ('p','f','n','z');
Var
   i,n,m:Integer;
   FidoAddr:Array[1..4] of integer;

Begin
   S:=AllTrim(S);
   cFirstStr:=cFirstStr+S+CRLF;

   Delete(S,1,Length(RelFromStr));

   n:=Pos('@',S);
   If n=0 then
      n:=Pos('!',S);
   If n=0 then n:=length(S);             {Positioning to end of string}
   While n > 0 do begin          {Search first char fto the left }
      If S[n] = ' ' then break;
      Dec(n);
   end;

   Address:=Substr(S,n+1,255);

   If n <= 1 then begin              {Search for a NAME after ADDR present}
      n:=Pos(' ',Address);
      If n > 0 then begin
         Name   := Substr(Address,n+1,255);
         Address:=Substr(Address,1,n-1);{Strip the address              }
      end
   end else begin                  {Search for a NAME before ADDR present}
      Name   := Substr(S,1,n-1);
{      Address:= Substr(Address,1,n-1); {Strip the address              }
   end;

   Name:=AllTrim(Name);

   If Left(Address,1)='<' then Address:=Substr(Address,2,255);
   If Right(Address,1)='>' then Dec(Byte(Address[0]));
   If Left(Name,1)='"' then Name:=Substr(Name,2,255);
   If Right(Name,1)='"' then Dec(Byte(Name[0]));
   If Left(Name,1)='(' then Name:=Substr(Name,2,255);
   If Right(Name,1)=')' then Dec(Byte(Name[0]));

   {Check for FIDO Address}
   n:=pos('@',Address);
   S:=Substr(Address,n+1,255);

   FidoAddr[1]:=0;
   If S[1]=FidoChars[1] then begin
      n:=pos('.',S);
      Val(Substr(S,2,n-2),FidoAddr[1],m);
      S:=Substr(S,n+1,255);
   end;

   For i:=2 to 4 do begin
      FidoAddr[i]:=0;
      If S[1]=FidoChars[i] then begin
         n:=pos('.',S);
         Val(Substr(S,2,n-2),FidoAddr[i],m);
         S:=Substr(S,n+1,255);
      end;
   end;

   If (FidoAddr[4]<>0) and
      (FidoAddr[3]<>0) and
      (FidoAddr[2]<>0) then begin
      Str(FidoAddr[4],S);
      Address:=S+':';
      Str(FidoAddr[3],S);
      Address:=Address+S+'/';
      Str(FidoAddr[2],S);
      Address:=Address+S;
      If FidoAddr[1] <> 0 then begin
         Str(FidoAddr[1],S);
         Address:=Address+'.'+S;
      end;
   end;

end;
*)

{*──────────────────────────────────────────*}
Procedure ParseRelcomAddress(S:String;Var Name,Address,cFirstStr:String);
{--- Parse Address Line & Fill Address and Name Fields }
Const
   FidoChars:Array[1..4] of Char = ('p','f','n','z');
Var
   i,n,m:Integer;
   FidoAddr:Array[1..4] of integer;

Begin
   S:=AllTrim(S);
   cFirstStr:=cFirstStr+S+CRLF;

   Delete(S,1,Length(RelFromStr));

   n:=Pos('<',S);      {Check for ADDRESS in "<...>"}
   If n>0 then begin
      Address:=Substr(S,n,255);
      Byte(S[0]):=n-1;
      Name:=S;
      n:=Pos('>',Address);
      If n>0 then
        Byte(Address[0]):=n;
   end else begin
     n:=Pos('@',S);
     If n=0 then
       n:=Pos('!',S);
     If n=0 then n:=length(S);             {Positioning to end of string}
     While n > 0 do begin          {Search first char fto the left }
       If S[n] = ' ' then break;
       Dec(n);
     end;

     Address:=Substr(S,n+1,255);

     If n <= 1 then begin              {Search for a NAME after ADDR present}
       n:=Pos(' ',Address);
       If n > 0 then begin
         Name   := Substr(Address,n+1,255);
         Address:=Substr(Address,1,n-1);{Strip the address              }
       end
     end else begin                  {Search for a NAME before ADDR present}
       Name   := Substr(S,1,n-1);
{      Address:= Substr(Address,1,n-1); {Strip the address              }
     end;
   end;

   Address:=AllTrim(Address);
   Name:=AllTrim(Name);

   If Left(Address,1)='<' then Address:=Substr(Address,2,255);
   If Right(Address,1)='>' then Dec(Byte(Address[0]));
   If Left(Name,1)='"' then Name:=Substr(Name,2,255);
   If Right(Name,1)='"' then Dec(Byte(Name[0]));
   If Left(Name,1)='(' then Name:=Substr(Name,2,255);
   If Right(Name,1)=')' then Dec(Byte(Name[0]));

   {Check for FIDO Address}
   n:=pos('@',Address);
   S:=Substr(Address,n+1,255);

   FidoAddr[1]:=0;
   If S[1]=FidoChars[1] then begin
      n:=pos('.',S);
      Val(Substr(S,2,n-2),FidoAddr[1],m);
      S:=Substr(S,n+1,255);
   end;

   For i:=2 to 4 do begin
      FidoAddr[i]:=0;
      If S[1]=FidoChars[i] then begin
         n:=pos('.',S);
         Val(Substr(S,2,n-2),FidoAddr[i],m);
         S:=Substr(S,n+1,255);
      end;
   end;

   If (FidoAddr[4]<>0) and
      (FidoAddr[3]<>0) and
      (FidoAddr[2]<>0) then begin
      Str(FidoAddr[4],S);
      Address:=S+':';
      Str(FidoAddr[3],S);
      Address:=Address+S+'/';
      Str(FidoAddr[2],S);
      Address:=Address+S;
      If FidoAddr[1] <> 0 then begin
         Str(FidoAddr[1],S);
         Address:=Address+'.'+S;
      end;
   end;

end;


{--- Check the Type of Message Text File }
Function CheckMsgStyle(FileName:String):sMsgStyle;
Var
   Stop:Boolean;
   F:Text;
   S:String;
begin
   Stop := False;
   CheckMsgStyle:=UnKnown;
   Assign(F,FileName);
   {$I-} Reset(F); {$I+}
   If IoResult <> 0 then begin
      WaitForOk('Error reading '+FileName+' !','Ok',White,White);
   end else begin
      While not Stop do begin
         If EOF(F) then Stop:=True
         else begin
            Readln(F,S);
            If Left(S,Length(GedStartOfMsg))=GedStartOfMsg then begin
               CheckMsgStyle:= GedStyle;
               Stop:=True;
            end else If Left(S,Length(RelStartOfMsg))=RelStartOfMsg then begin
               CheckMsgStyle:= RelcomStyle;
               Stop:=True;
            end;
         end;
      end;
      Close(F);
   end;
end;

{--------------------------------------------------}
Function RemoveReply(const S:string):string;
{--- Remove "Re:" & "[NEWS]" from Subject }
Var
  i,n:byte;
  S1:string;
begin
  n:=1;
  S1:=Upper(S);
  Repeat
    While S1[1] = ' ' do begin
      Inc(n);
      Delete(S1,1,1);
    end;
    i:=Pos('RE:',S1);
    If i = 1 then begin
      Inc(n,3);
      Delete(S1,1,3);
    end else begin
      i:=Pos('[NEWS]',S1);
      If i = 1 then begin
        Inc(n,6);
        Delete(S1,1,6);
      end;
    end;
  until (i<>1);
  RemoveReply:=Copy(S,n,255);
end;



{--------------------------------------------------}
Procedure AddNews;
{--- Append Msgs from a file into the Base }
var
   StartDir{,
   cCutter} :String80;
   MsgStyle:sMsgStyle;
   FileName, DirName : String;
   EndOfHeader:String80;
   StartOfMsg:String12;
   EndOfMsg:String80;
   FromStr:String12;
   SubjStr:String12;
   cSubj:String;
   cAddr:String80;
   cFrom:String80;
   cDate:String80;
   cArchive:String80;
   S,SFirst:String;
   nSize,FSize : longint;
   F:Text;
   OldScreen:ScreenPtr;
   crs:word;
   MsgCounter:LongInt;

   {--- Get Message Header from the Text File }
   Procedure GetHeader(Var cSubj,
                           cFrom,
                           cAddr:String;
                       Var cDate:String);
   begin
      cSubj:='';
      cFrom:='';
      cAddr:='';
      cArchive:='';
      cDate:='        ';
      S:='123';
      SFirst:='';

      Memo_Size:=0;

      While (not EOF(F)) {and (Left(S,Length(EndOfHeader)) <> EndOfHeader)} do begin
         Readln(F,S);
         Inc (nSize, Length(S)+2);
         Scale(FSize,nSize);
         S:=RTrim(S);

         If (MsgStyle = RelcomStyle) and (S='') then break;

         If (MsgStyle = GedStyle) and
            (Left(S,Length(EndOfHeader)) = EndOfHeader) then begin
            Break;
         end else begin
            { Check for "FROM:" }
            If Left(S,Length(FromStr))=FromStr then begin
               Case MsgStyle of
               RelcomStyle: begin
                              ParseRelcomAddress(S,cFrom,cAddr,sFirst);
                            end;
               GedStyle: begin
                              ParseFidoAddress(S,cFrom,cAddr,cDate);
                            end;
               end; {Case MsgStyle}
            { Check for "SUBJ:" }
            end else If Left(S,Length(SubjStr))=SubjStr then begin
               cSubj:=RTrim(Substr(S,Length(SubjStr)+1,255));
               cSubj:=RemoveReply(cSubj);
            { Check for "Date:" }
            end else If Left(S,Length(RelDateStr))=RelDateStr then begin
               cDate:=Substr(S,Length(RelDateStr)+1,255);
               cDate:=ParseDateStr(cDate);
            { Check for "Organization:" }
            end else If Left(S,Length(RelOrgStr))=RelOrgStr then begin
               sFirst:=sFirst+S+CRLF;
            { Check for "X-Filename: " }
            end else If Left(S,Length(ToFile))=ToFile then begin
               cArchive:=UPPER(Substr(S,Length(ToFile)+1,255));
            end;
         end;
      end;
   end;

   {--- Get Message Body from the Text File }
   Procedure GetMessageBody;
   Var
      S:String;
      EOM : Boolean;
   begin
                  {  NEED: Check for Max Message Size!!!}
      Memo_Size:=0;
      crs:=0;
      EOM := False;

(*      If Length(sFirst) > 0 then begin
         Move(SFirst[1],Memo^[crs],Length(SFirst));
         Inc(crs,Length(SFirst));
         Move(CRLF[1],Memo^[crs],2);
         Inc(crs,2);
      end;
*)
      While (not EOF(F)) and (not EOM) do begin
         Readln(F,S);
         Inc (nSize, Length(S)+2);
         Scale(FSize,nSize);
         S := RTrim(S);

         EOM := Substr(S,1,Length(EndOfMsg)) = EndOfMsg;
         If not EOM then begin
            Move(S[1],Memo^[crs],Length(S));
            Inc(crs,Length(S));
            Move(CRLF[1],Memo^[crs],2);
            Inc(crs,2);
         end else begin
            If MsgStyle = GedStyle then begin
               Move(S[1],Memo^[crs],Length(S));
               Inc(crs,Length(S));
               Move(CRLF[1],Memo^[crs],2);
               Inc(crs,2);
            end;
         end;
      end;
      Memo_Size:=crs;
   end;



   {--- Get Next Message from the Text File }
   Procedure GetNextMessage( MsgStyle: sMsgStyle;
{                             Var Memo:MemoPtr;}
                             Var cSubj,
                                 cFrom,
                                 cAddr:String;
                             Var cDate:String12);
   begin
      GetHeader(cSubj,cFrom,cAddr,cDate);
      GetMessageBody;
      Inc(MsgCounter);

   end;


{------------------ AddNews ------------------------}
begin

   StartDir:=GsGetExpandedFile(ImportDir);

   FileName:=SelectFile(3,5,28,22, ' Append From: ',
             LightGray,White+Blue*16,Yellow,LightRed,White,
             StartDir,AllTheFiles,True);

   If FileName <> '' then begin
      Dos.FSplit(FileName,DirName,S,SFirst);
      FSize := GsFileSize(FileName);
      nSize:=0;

      MsgStyle:=CheckMsgStyle(FileName);

      If MsgStyle=GedStyle then begin
         StartOfMsg   := GedStartOfMsg;
         EndOfHeader  := GedEndOfHeader;
         EndOfMsg     := GedEndOfMsg;
         SubjStr      := GedSubjStr;
         FromStr      := GedFromStr;
      end else If MsgStyle=RelcomStyle then begin
         StartOfMsg   := RelStartOfMsg;
         EndOfHeader  := RelEndOfHeader;
         SubjStr      := RelSubjStr;
         EndOfMsg     := RelEndOfMsg;
         FromStr      := RelFromStr;
      end;

      Assign(F,FileName);
      {$I-} Reset(F); {$I+}
      If IoResult <> 0 then begin
         WaitForOk('Error reading '+FileName+' !','Ok',White,White)
      end else begin

         OldScreen := SaveScreen;
         DrawScale(12,19,'Wait a minute, please...',LightRed,Yellow,LightGray);

         While not EOF(F) do begin
            GetNextMessage(MsgStyle,{Memo,}cSubj,cFrom,cAddr,cDate);
            ClearRecord;
            If not((cSubj='') and (cFrom='') and (Memo_Size=0)) then begin
               Append;
               FieldPut('SUBJ',cSubj);
               FieldPut('FROM',cFrom);
               FieldPut('ADDR',cAddr);
               FieldPut('DATE',cDate);
               FieldPut('APDATE',DTOS(Today)); {Put Current Date to 'ApDate' field}
               WriteMemo('TEXT');
{               If DirName[Length(DirName)]<>'\' then
                 DirName:=DirName+'\';}
               {Add Attachment from X-Filename}
               If cArchive<>'' then
                 FieldPut('PROJECT', cArchive);
                 If gsFileExists(DirName+cArchive) then
                   AttImport(DirName+cArchive); {Attach the Archive}
               Replace;                       {Write with Memo too}
               {Increment MsgCounter}
               Select('AREAS');
               UpdateMsgCounter(1);         {and update the Msg Counter}
               Select('WORK');
            end;
            Inc(nSize);
            Scale(FSize,nSize);
         end;
         Scale(RecCount,FindCount);
         {$I-} Close(F); {$I+}
         If IoResult <> 0 then begin
            WaitForOk('Error closing '+FileName+' !','Ok',White,White)
         end;
         {Correct the Msg Counter in this Echo}
         If MsgCounter <> 0 then begin
         end;

         Delay(500);
         RestScreen(OldScreen);
         AdjustRow;
         PagePaint:=True;
      end;
   end;
end;

{-------------------------------------}
Procedure GrepAreas;
Var
   OldScreen:ScreenPtr;
   OldColor:byte;
   OldRec:longint;
   Ans,ml,i:integer;
   TargetArea:byte;
   cFileName:String[8];
   dStr:Gs_Date_StrTyp;
   OldMC,OldMA,
   nDate:Longint;

   Procedure GrepCurrentBase;
   begin
      GetAreaParameters;
{      AreaID   := AllTRim(FieldGet('FILENAME'));
      AreaDescr:= FieldGet('AREA');
}
      If AreaID <> cFileName then begin
         SAY(29,14,'Scanning area:');
         SAY(43,14,PadR(AreaID,8));

         If AreaID <> '' then begin
            If GsFileExists(BaseDir+'\'+AreaID+'.dbf') then begin
               OpenWorkBase(AreaID,'WORK',DontAsk);
               GoTop;
               While not dEOF do begin
                  If FieldGet('APDATE') >= dStr then begin
                     Copy1Record(TargetArea);

                     Select('TMP');
                     FieldPut('FILENAME',AreaID);
                     FieldPut('AREA',AreaDescr);

                     DbfActive^.RecModified:=True;
                     Replace;

                  end;
                  Select('WORK');
                  Skip(1);
               end; {While}
               Use('','',False);  { Close 'WORK' DataBase }
            end; {If FileExists}
         end;    {If AreaID <> ''}
      end;       {If AreaID <> FileName}
      Select('AREAS');
   end; {GrepCurrentBase}


{-- GrepAreas --}
begin

   If not FullScreen then
      PaintRecord(Row,TRUE);

   Ans:=WhatAreasMenu(' Grep ');
(*
   If MarkCount = 0 then ml := 3
                    else ml := 4;

   M.Init(2,5,16,5+ml+1, ' Grep ',
                 LightGray,White+Blue*16,Yellow,LightRed,White,Centered);

   M.Add(mnAllAreas   );
   M.Add(mnCurrentArea);

   If MarkCount <> 0 then
      M.Add(mnMarkedAreas);

   M.Add(mnQuit_ESC);

   If MarkCount = 0 then Ans :=1
                    else Ans :=3;

   Ans:=M.ReadMenu(Ans);
   M.Done;
*)
   If (LastKey <> K_ESC) and (Ans <> ml) then begin

      { Store old MarkArray }
      If Ans = 1 {Current} then begin
         OldMC := MarkCount;
         OldMA := MarkArray[1];
         MarkCount := 1;
         MarkArray[1] := RecNo;
      end;

      OldScreen:=SaveScreen;
      OldColor:=TextAttr;
      OldRec  :=RecNo;

      cFileName:='';
      dStr:=Gs_Date_Empty;
      SetColor ('W/N');

      Box(27,11,53,15,Single,Shadow);

      SAY(29,11,' Grep Parameters: ');
      SAY(29,12,' AreaID:   ');
      SAY(29,13,' ApDate >= ');

      cFileName:=EditString (40,12,cFileName,8,NotConvert);
      cFileName:=Upper(AllTrim(cFileName));

      If (LastKey<>K_ESC) and (cFileName<>'') then begin

         Repeat
            dStr:=EditDate (40,13,dStr);              {Edit DATE field}
         Until (LastKey = K_ESC) or DateStrOk(dStr);

         nDate:=CTOD(dStr);
         dStr:=DTOS(nDate); {Convert date to 'YYYYMMDD' format}

         If LastKey <> K_ESC then begin

            OpenGrepBase(cFileName,'TMP');  {Create New Base for the Grepped Records}
            TargetArea:=CurrentArea;

            Select('AREAS');

            If Ans = 2 then begin {for ALL areas}
               GoTOP;
               While not dEOF do begin
                  { Grep Current Base }
                  GrepCurrentBase;
                  Skip(1);
               end;      { While not dEOF in work area}
            end else begin        {for current/marked areas}
               For i:=1 to MarkCount do begin
                  Go (MarkArray[i]);
                  { Grep Current Base }
                  GrepCurrentBase;
               end; { For }
            end;
         end; {If LastKey <> K_ESC in EditDate}


         Select('TMP');
         Use('','',False);  { Close 'TMP' DataBase }
      end;

      Select('AREAS');
      Go(OldRec);
      Delay(500);
      TextAttr:=OldColor;
      RestScreen(OldScreen);
   end;
end;






{*────────────────────────────────────────────────────────────────────*}
Procedure MoveCursor (cKey:Char);
{Key handler for Msg/Area Lister}
var
   s:string12;
   OldRow:integer;
begin
  OldRow:=Row;
  PaintRecord(OldRow,FALSE);

  If Key_Func then begin
   Case cKey of
      K_HOME       : GoHome;
      K_END        : GoEnd;
      K_CTRL_HOME  : GoHome;
      K_CTRL_END   : GoEnd;
      K_UP         : GoUp(true);
      K_DOWN       : GoDown(true);

      K_PGUP       : GoPgUp;
      K_PGDN       : GoPgDn;
      K_CTRL_PgUp  : GoHome;
      K_CTRL_PgDn  : GoEnd;

      K_F1         : begin
                        BrowseHelp;
                        If LastKey = K_CTRL_Q then
                           ExitReader;
                     end;
{      K_F7         : begin Seek end;}
      K_ALT_C      : If not EnterExit then begin
                        ChangeRecord(True);
                     end;
      K_ALT_G      : If not EnterExit then
                        If Alias = 'AREAS' then GrepAreas;
      K_ALT_L      : If not EnterExit then
                        {If Alias = 'AREAS' then} MakeMsgList;
      K_ALT_M      : If not EnterExit then begin
                        MoveRecords;
                     end;
      K_ALT_P      : If not EnterExit then begin
                        PackDataBase;
                     end;
      K_INS        : If not EnterExit then InsertNewRec;
      K_Del        : If not EnterExit then begin
                        DelRecords;
                     end;
      K_ALT_N      : AddNews;
      K_ALT_F      : FindRecords;
      K_ALT_D      : {DosShell};
      K_ALT_O      : If not EnterExit then begin
                        OrderBy;
                        AdjustRow;
                     end;
      K_ALT_W : If not EnterExit then begin
                   If Alias = 'WORK' then
                      WriteToFile;
                end;
      K_ALT_X : If not EnterExit then DoQuit;
      K_ALT_Y : If Alias='WORK' then ZipCurrentSnipet(AreaID);
      K_ALT_Z : FindInHeaders;
      else     ;
   End; {Case}
  end else begin
   Case cKey of
      K_CTRL_G     : GoTheRecord('');
      K_Space      : If not EnterExit then begin
                        MarkRecord;
                        If not FullScreen then
                           PaintRecord(Row,False);
                        GoDown(True);
                     end;
      K_CTRL_L     : FindNextRecord;
      K_CR         : If Alias='AREAS' then begin
                        If EnterExit then begin
                           Escaped := True
                        end else begin
                          GetAreaParameters;
{                          AreaID:=AllTRim(FieldGet('FILENAME'));}
                          If AreaID <> '' then begin
{                            AreaDescr:=AllTrim(FieldGet('AREA'));}
                            If OpenWorkBase(AreaID,'WORK',AskMe) then begin
                               Browse({fn,ar,}2,3,79,23,ar,False);
                               Use('','',False);  { Close Current DataBase }
                            end;
                            Select('AREAS');
{                            DrawScreen;}
                            AdjustRow;
                            PagePaint:=True;
                          end;
                        end;
                     end else begin
                        ViewMemo(1,6,80,24);
                     end;
      K_ESC   : begin
                   If (EnterExit) or (DbfUsed >= 2) then
                      Escaped := True
                   else
                      DoQuit;
                   end;
      K_CTRL_Q: ExitReader;
      '0'..'9'   : begin
                      GoTheRecord(cKey);  {Go to the N msg              }
                   end;
   End; {Case}
  end;

{  PaintRecord(OldRow,FALSE);}
  PaintRecord(Row,TRUE);
End;


{----------browse------------------------}
begin
   SaveColor(OldColor);
   OldScreen:=SaveScreen;

   MarkCount := 0;
   PagePaint := TRUE;
   Escaped   := FALSE;
   cKey      := #0;
   SkipRecs  := RowBottom - RowTop + 1;
   Row       := RowTop;
   FullLen   := ColRight-ColLeft+1;

   GoTop;
   RecNumTop := RecNo;
   RecNum    := RecNumTop;

   DrawScreen;

   SAY(30,1,PadR(InsCommas(IntToStr(MemAvail)),12));


   { ▄▄▄▄▄▄▄▄▄▄▄▄ Main loop ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄ }

   While not Escaped do begin

      If PagePaint then FillScreen;

      cKey := InKey(0);      { wait for a key }

      SAY(30,1,PadR(InsCommas(IntToStr(MemAvail)),12));

      MoveCursor(ckey);      { Handle the key }
   end;

   RestScreen(OldScreen);
   RestColor(OldColor);

end;


{*────────────────────────────────────────────────────────────────────*}
Procedure CONFIG (ConfName:String);
Var
   Conf:Text;
   lstr,Equ,Comment:byte;
   Line:string;
   StrConf,
   ParName,Parm:  string;

Begin
   IF not GsFileExists(ConfName) then begin
      Writeln('');
      Writeln('*** File ',ConfName,' not found!');
      Halt(1);
   end;

   If not FileOpen(Conf,ConfName,0) then begin
      writeln('*** Open error of "',ConfName,'"');
      HALT(1);
   end;

   While not System.EOF(Conf) do begin

      Readln(Conf,StrConf);

      Comment:=Pos('//',StrConf);               {Check for //}
      If Comment>0 then
         StrConf:=RTrim(Copy(StrConf,1,Comment-1));
      Comment:=Pos('&&',StrConf);            {Check for &&}
      If Comment>0 then
         StrConf:=RTrim(Copy(StrConf,1,Comment-1));
      Comment:=Pos(';',StrConf);             {Check for ; }
      If Comment>0 then
         StrConf:=RTrim(Copy(StrConf,1,Comment-1));

      Lstr:=Length(StrConf);
      Equ:=Pos('=',StrConf);

      If Equ>0 then begin
         ParName:=AllTrim(Upper(Copy(StrConf,1,Equ-1)));
         Parm:=AllTrim(Copy(StrConf,Equ+1,Lstr-Equ));

         If Length(Parm)<>0 then begin
            {*--- Parameters --------------------}
{            If      ParName = 'AREABASE'   then AreaBase  :=Parm}
            If      ParName = 'IMPORTDIR'  then ImportDir :=Parm
            else If ParName = 'EXTRACTDIR' then ExtractDir:=Parm
            else If ParName = 'BASEDIR'    then BaseDir   :=Parm
            else If ParName = 'LISTDIR'    then ListDir   :=Parm
            else If ParName = 'SWAGDIR'    then SwagDir   :=Parm
            else If ParName = 'AREAORDER'  then AreaOrder :=StrToInt(Parm)
            else If ParName = 'MSGORDER'   then MsgOrder  :=StrToInt(Parm)
            else If ParName = 'LASTUPDATE' then LastUpdate:=Parm
            else If ParName = 'INDEXHEADER' then IndexHeader:=Parm
            else If ParName = 'INDEXFOOTER' then IndexFooter:=Parm
            else If ParName = 'INDEXRECORD' then IndexRecord:=Parm
            else If ParName = 'AREAHEADER' then AreaHeader:=Parm
            else If ParName = 'AREAFOOTER' then AreaFooter:=Parm
            else If ParName = 'AREARECORD' then AreaRecord:=Parm
            else If ParName = 'MSGHEADER'  then MsgHeader:=Parm
{            else If ParName = 'MSGFOOTER'  then MsgFooter:=Parm}
            else If ParName = 'AREALIST'   then AreaList  :=Parm
            else If ParName = 'SNIPETS'    then SnipetsPerPage:=StrToInt(Parm)
            else If ParName = 'EDITOR'     then {Editor    :=Parm}
            ;
         end;
      end;
   end; {While}

   FileClose(Conf);

end;

{----------------------------------------------------}
Procedure SetPublicVar(const IniFile:string);
Var
   nPos:Integer;

begin
{-------Configure Parameters----------------------------------}

{----- [ Work Pathes ] -----}
   BaseDir   := '';         { Path to Data Bases      }
   AreaBase  := 'RSWAG';    { Area DataBase Name      }

{****************    Title Parameters *************************}
   ExitProc:=@ExitReader;
   SetCursorOff;
   SetColor('BG/B');

{--------- Check Ini Parameters ----------------------}
   If IniFile = '' then begin
      ConfigFile:=ParamStr(0){GetExeDir};

      nPos:=RAT('.',ConfigFile);
      ConfigFile:=Left(ConFigFile,nPos)+'INI';
   end else begin
      ConfigFile:=IniFile;
   end;
   Config(ConfigFile); { взять параметры настройки из файла конфигурации }

   BaseDir:=AllTrim(BaseDir);
   If BaseDir<>'' then
      If Right(BaseDir,1)='\' then
         Dec(Byte(BaseDir[0]));

   SwagDir:=AllTrim(SwagDir);
   If SwagDir<>'' then
      If Right(SwagDir,1)<>'\' then
         SwagDir:=SwagDir+'\';

   ListDir:=AllTrim(ListDir);
   If ListDir<>'' then
      If Right(ListDir,1)='\' then
         Dec(Byte(ListDir[0]));

   ExtractDir:=AllTrim(ExtractDir);
   If not EmptyStr(ExtractDir) then
      If Right(ExtractDir,1) = '\' then
         Dec(Byte(ExtractDir[0]));

   ImportDir:=AllTrim(ImportDir);
   If EmptyStr(ImportDir) then
      FileToWrite:=''
   else begin
      If Right(ImportDir,1) = '\' then
         Dec(Byte(ImportDir[0]));
      FileToWrite:=ExtractDir+'\';
   end;

   SetExact(True);        { Exact Matching for FIND           }
   SetDateStyle(German);  { Date Format = dd.mm.yy[yy]        }
   SetCenturyWrap(50);    { If year < 50 then century = 2000, }
                          { If year >= 50 then century = 1900 }
   SetCentury(False);     { Use two digits for YEAR           }
end;

(*
{---------------------------------------------------------}
Procedure ReZip;
var
   wrkbase,wrkcomm:string;
begin
   ClrScr;
   OpenMainBase(AreaBase);
   SetDeleted(True);
   GoTop;
   While not dEOF do begin
      Select(1);
      wrkbase := FieldGet('FILENAME');
      wrkcomm := FieldGet('AREA');
      Writeln(wrkbase,wrkcomm);

      Select(2);
      OpenWorkBase(wrkbase,2,'WORK');
      SetDeleted(True);
      GoTop;

      While not dEOF do begin
         writeln(FieldGet('FROM'),'=',FieldGet('SUBJ'));
         MemoGet('TEXT');
         SetMemoPacked(True);
         MemoPut('TEXT');
         SetMemoPacked(False);

         Skip(1);
      end;
      Use('','');  { Close Current DataBase }

      Select(1);
      Skip(1);
   end;
end;

*)

begin
   ExitSave := ExitProc;      {Store old exit procedure}
   ExitProc := @ExitReader;   {Set new exit procedure}
{   ClipBoardEmpty:=True;}
   FullScreen:=False;         {Set Browse mode (not FullScreen)}
   FindStr:='';               {Clear Search String}
   FindUp :='';
   SaveColor(DosColor);       {Store DOS color}
   AreaOrder:=0;              {Order Areas by NONE}
   MsgOrder:=0;               {Order Msgs by NONE}
   SetDateStyle(German);      {Set Date Style to GERMAN = dd.mm.yy}

   Today:=Gs_Date_Curr;       {Get Current Date}
   SnipetsPerPage:=10;

end.
