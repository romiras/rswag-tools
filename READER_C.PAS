{----------------------------------------------------------}
{      Unit Reader_C - Common utilities for the READER     }
{      for    Russian SWAG Msg Base Reader                 }
{                    v.4.0 beta H                          }
{      written 1993-2000 by Valery Votintsev 2:5021/22     }
{                             E-Mail: rswag@sources.ru     }
{----------------------------------------------------------}
{Constants for RSWAG Reader}
Unit Reader_C;
{$i GSF_FLAG.PAS}
Interface
Uses
   CRT,
   dos,
   gsf_dos,
   gsf_glbl,
   gsf_shel,
   gsf_Date,
   vScreen,
   vMenu,
   vMemo,
   vKbd,
   vString;
Type
   FileOfByte  = File of byte;
   sMsgStyle   = (UnKnown,GedStyle,RelcomStyle,SwagStyle);

{-----    Variable Definition    -----}
Const
  {****************    Title Parameters *************************}
  CopyRight     : String[33] ='(c) 1993-2001 by Valery Votintsev';
  Version       : String[ 7] ='v.4.2';
  RSWAG         : String[12] = 'Russian SWAG';
  GedStartOfMsg : String[8] =' Msg  : ';
  GedEndOfHeader: String80  ='ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ';
  GedEndOfMsg   : String12  =' * Origin: ';
  GedFromStr    : String[8] =' From : ';
  GedSubjStr    : String[8] =' Subj : ';
  RelStartOfMsg : String[8] ='From ';
  RelEndOfHeader: String[8] ='';
  RelDateStr    : String[8] ='Date: ';
  RelFromStr    : String[8] ='From: ';
  RelSubjStr    : String12  ='Subject: ';
  RelOrgStr     : String[14] ='Organization: ';
  RelEndOfMsg   : String[8] ='From ';
  ToArea        : String[8] ='X-Area: ';
  ToFile        : String[12] ='X-Filename: ';
  PickNewArea   : String[16] = '>>Pick New Area:';


  {----------- Colors ---------------}
{  MainColor : Byte =Blue + Magenta*16; { £« ¢­ë© ä®­ }
{  WaitColor : Byte =LightGray;
  WarnColor : Byte = LightGray;
  AborColor : Byte = LightGray;
  DocColor  : Byte = LightGray;
  SuspColor : Byte = LightGray;
  ReadyColor: Byte = LightGray;
}
  AskMe   = True;
  DontAsk = False;
Var
  {-------[ Work Pathes ]----------------}
  BaseDir  : String;        { Path to Data Bases         }
  ListDir  : String;        { Path to List Directory     }
  SwagDir  : String;        { Path to English SWAG Directory }
  AreaBase : String12;      { Area DataBase Name         }
  {-------[ Areas & Msg Order by ]----------------}
  AreaOrder,                { Area List Default Sort Order}
  MsgOrder : Integer;       { Message Default Sort Order  }
  {-------[ Other usefull variables ]----------------}
  DosColor : byte;          { Old DOS Shell Color        }
  FullScreen:Boolean;       { True if MSG text viewed    }
  Lastupdate:String12;      { Last Updated by 'PatchName'}

  AreaID:string12;          { Area ID (FileName)         }
  AreaDescr:string80;       { Area Description           }
  MsgCounter:integer;       { Area Msg Counter           }
  RealAreaName:string12;
  AreaMsgCounter:string12;
  Size:string12;
  ErrorCode:integer;
  PageNum,MaxPageNum:integer;
  PageStrNum:string12;
  MsgNumber:integer;
  From:string80;
  Addr:string80;
  Date,ApDate:string12;
  Subj:string80;
  Project:string12;
  MsgSize:word;
  SnipetsPerPage:integer;

Function  CheckWorkPath:Boolean;   {Check Work Path existing}
Procedure DrawTitleScreen;
Procedure ScanAreas;
Procedure OpenMainBase(dbFile,dbAlias:String);
Function  OpenWorkBase(dbFile:String;cAlias:string;AskForCreate:Boolean):Boolean;
Procedure CreateWorkBase(Name:String);
Procedure CreateGrepBase(Name:String);
Function  OpenGrepBase(dbFile:String;cAlias:string):Boolean;
Procedure Copy1Record(TargetArea:integer);
Procedure UpdateMsgCounter(AddNum:integer);
Procedure InsertRecord;
Procedure Write1Message(Var nHandle:File;NeedHeader:Boolean;Table:pCodeTable);
Procedure GetAreaParameters;
Procedure GetMsgParameters;
Function  GetProject:string12;

Implementation

{---------------------------------------------------------}
Procedure GetAreaParameters;
begin
  RealAreaName:=lower(AllTrim(FieldGet('FILENAME')));
  AreaID:=Upper(RealAreaName);
  AreaDescr:=AllTrim(FieldGet('AREA'));
  AreaMsgCounter:=AllTrim(FieldGet('MSGCOUNT'));
  Val(AreaMsgCounter,MsgCounter,ErrorCode); {nCounter = Number of messages}
  MaxPageNum:=(MsgCounter div SnipetsPerPage) + 1;
  PageNum:=1;
end;

{----------------------------}
Function GetProject:string12;
var
  s:string;
  n:integer;
begin
  If not FieldExists('PROJECT') then
    s:=''
  else begin
    s:=lower(AllTrim(FieldGet('PROJECT')));
    n:=pos('.',s);
    If n>0 then
      Byte(s[0]):=pred(n);
  end;
  GetProject:=s;
end;



{---------------------------------------------------------}
Procedure GetMsgParameters;
var
  n:longint;
  i,j:longint;
begin
  From:=AllTrim(FieldGet('FROM'));
  Addr:=AllTrim(FieldGet('ADDR'));
  Subj:=AllTrim(FieldGet('SUBJ'));
  Date:=DateGet('DATE');
  Project:=GetProject;
  n:=gsFileSize(listdir + '\'+RealAreaName+'\'+project+'.zip');
  Size:='';
  If n>0 then begin
    n:=(n div 1024);
    If n = 0 then n:=1;
    Str(n,Size);
    Size:=Size+'k';
  end;
end;







{*******************************************************}
Procedure WriteHeader(var nHandle:File;Table:pCodeTable);
var
   cStr:String;
   n:word;
begin
   cStr:='Ä '+AreaID+' ';
   cStr:=cStr+Replicate('Ä',76-Length(AreaDescr)-Length(cStr));
   cStr:=cStr+' '+AreaDescr+' Ä'+CRLF;
   If Table <> NIL then
      cStr:=ReplaceAll(cStr,'<','&lt;');
   cStr:=ConvertStr(cStr,Table);
   System.BlockWrite( nHandle, cStr[1],Length(cStr),n);

   cStr:=' Msg  : '+IntToStr(RecNo)+' of '+IntToStr(RecCount);
   cStr:=PadR(cStr,45)+'Addr';
   cStr:=PadR(cStr,73)+'Date'+CRLF;
   If Table <> NIL then
      cStr:=ReplaceAll(cStr,'<','&lt;');
   cStr:=ConvertStr(cStr,Table);
   System.BlockWrite( nHandle, cStr[1],Length(cStr),n);

   cStr:=PadR(' From : '+FieldGet('FROM')+'     '+
              FieldGet('ADDR'),71) + DateGet('DATE')+CRLF;
   If Table <> NIL then
      cStr:=ReplaceAll(cStr,'<','&lt;');
   cStr:=ConvertStr(cStr,Table);
   System.BlockWrite( nHandle, cStr[1],Length(cStr),n);

   cStr:=' Subj : '+RTrim(FieldGet('SUBJ'))+CRLF;
   If Table <> NIL then
      cStr:=ReplaceAll(cStr,'<','&lt;');
   cStr:=ConvertStr(cStr,Table);
   System.BlockWrite( nHandle, cStr[1],Length(cStr),n);

   cStr:=Replicate('Ä',79)+CRLF;
   cStr:=ConvertStr(cStr,Table);
   System.BlockWrite( nHandle, cStr[1],Length(cStr),n);

end;




Procedure Write1Message(Var nHandle:File;NeedHeader:Boolean;Table:pCodeTable);
var
   n:longint;
   bl,w:word;
{   MaxSize:Longint;}
begin
{   MaxSize:=Memo_Size;}
   If NeedHeader then
      WriteHeader(nHandle,Table);
   n:=0;                   {Num of written for this Msg   }
   bl:=MaxInt;             {Block Length for write =32767 }

   If Memo_Size > 0 then begin
      If Table <> NIL then begin
{         ReplaceInMemo('<','&lt;');}
         ConvertMemo(Table);
      end;

      Repeat
         If (n + bl) > Memo_Size then
            bl := Memo_Size - n;
         System.BlockWrite( nHandle, Memo^[n],bl,w);
         inc(n,w);
      until (n >=Memo_Size) or (w = 0);
   end;

   System.BlockWrite( nHandle, CRLF[1],2,w); {Msg Divider = CRLF}

end;





{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Function CheckWorkPath:Boolean;
Var
   Ok:Boolean;
begin
   Ok:=True;
   If not GsFileExists(BaseDir) then begin
      If AskYesNo(0,0,' Directory "'+BaseDir+'" not exists. Create it? ') then
         Ok:=MakeDir(BaseDir)=0
      else Ok:=False;
   end;

   If Ok and (not GsFileExists(ImportDir)) then begin
      If AskYesNo(0,0,' Directory "'+ImportDir+'" not exists. Create it? ') then
         Ok:=MakeDir(ImportDir)=0
      else Ok:=False;
   end;

   If Ok and (not GsFileExists(ExtractDir)) then begin
      If AskYesNo(0,0,' Directory "'+ExtractDir+'" not exists. Create it? ') then
         Ok:=MakeDir(ExtractDir)=0
      else Ok:=False;
   end;

   CheckWorkPath:=Ok;
   If not Ok then begin
      Beep; Beep;
      WaitForOk('Sorry, No work directories :-(','Ok',White+Red*16,White);
   end;
end;





{*******************************}
Procedure InsertRecord;
{  Insert a New Blank Record }
var
   LastOrder:integer;
begin
   LastOrder := IndexCurrentOrder;
   SetOrderTo(1);
   SetDeleted(False);

   GoTOP;

   If Deleted then begin
      RECALL;
      ClearRecord;
   end else begin
      ClearRecord;
      Append;
   end;

   SetOrderTo(LastOrder);
   SetDeleted(True);

   Replace;

end;



Procedure UpdateMsgCounter(AddNum:integer);
{--- Update Msg Counter }
Var
   ans: longint;
begin
{   Select('AREAS');}
   Ans:=IntegerGet('MSGCOUNT');
   Inc(Ans,AddNum);
   If Ans < 0 then Ans := 0;
   IntegerPut('MSGCOUNT',Ans);
   Replace;  { Rewrite Msg Counter }
{   Select('WORK');}
end;



{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
{Procedure calling for AREA base Create}
{$F+}
Function MainFieldProc(FldNo: integer; var AField: String; var AType: char;
                                     var ALen, ADec: integer): boolean;
Const MainStruct:Array[1..6] of GSR_FieldDesc = (
                 (FieldName:'AREA';     FieldType:'C';FieldLen:69;FieldDec:0),
                 (FieldName:'FILENAME'; FieldType:'C';FieldLen: 8;FieldDec:0),
                 (FieldName:'LASTREAD'; FieldType:'N';FieldLen: 6;FieldDec:0),
                 (FieldName:'LASTORDER';FieldType:'N';FieldLen: 1;FieldDec:0),
                 (FieldName:'MSGCOUNT'; FieldType:'N';FieldLen:10;FieldDec:0),
                 (FieldName:'';      FieldType:' ';FieldLen: 0;FieldDec:0)
                 );

begin
   MainFieldProc := true;     {Return true unless aborting DBFCreate}

   AField := MainStruct[FldNo].FieldName;
   AType  := MainStruct[FldNo].FieldType;
   ALen   := MainStruct[FldNo].FieldLen;
   ADec   := MainStruct[FldNo].FieldDec;
end;

{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
{Procedure calling for MSG base Create}
Function WorkFieldProc(FldNo: integer; var AField: String; var AType: char;
                                     var ALen, ADec: integer): boolean;

Const WorkFields:Array[1..10] of GSR_FieldDesc = (
          (FieldName:'FROM';  FieldType:'C';FieldLen:25;FieldDec:0),
          (FieldName:'ADDR';  FieldType:'C';FieldLen:35;FieldDec:0),
          (FieldName:'SUBJ';  FieldType:'C';FieldLen:52;FieldDec:0),
          (FieldName:'DATE';  FieldType:'D';FieldLen: 8;FieldDec:0),
          (FieldName:'APDATE';FieldType:'D';FieldLen: 8;FieldDec:0),
          (FieldName:'PROJECT'; FieldType:'C';FieldLen:12;FieldDec:0),
          (FieldName:'TEXT';  FieldType:'M';FieldLen:10;FieldDec:0),
          (FieldName:'ATTACHME'; FieldType:'M';FieldLen:10;FieldDec:0),
          (FieldName:'NEW';   FieldType:'L';FieldLen: 1;FieldDec:0),
          (FieldName:'';      FieldType:' ';FieldLen: 0;FieldDec:0)
          );
begin
   WorkFieldProc := true;     {Return true unless aborting DBFCreate}

   AField := WorkFields[FldNo].FieldName;
   AType  := WorkFields[FldNo].FieldType;
   ALen   := WorkFields[FldNo].FieldLen;
   ADec   := WorkFields[FldNo].FieldDec;
end;


{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
{Procedure calling for MSG base Create}
Function GrepFieldProc(FldNo: integer; var AField: String; var AType: char;
                                     var ALen, ADec: integer): boolean;

Const WorkFields:Array[1..12] of GSR_FieldDesc = (
          (FieldName:'FROM';  FieldType:'C';FieldLen:25;FieldDec:0),
          (FieldName:'ADDR';  FieldType:'C';FieldLen:35;FieldDec:0),
          (FieldName:'SUBJ';  FieldType:'C';FieldLen:52;FieldDec:0),
          (FieldName:'DATE';  FieldType:'D';FieldLen: 8;FieldDec:0),
          (FieldName:'APDATE';FieldType:'D';FieldLen: 8;FieldDec:0),
          (FieldName:'PROJECT'; FieldType:'C';FieldLen:12;FieldDec:0),
          (FieldName:'TEXT';  FieldType:'M';FieldLen:10;FieldDec:0),
          (FieldName:'ATTACHME'; FieldType:'M';FieldLen:10;FieldDec:0),
          (FieldName:'NEW';   FieldType:'L';FieldLen: 1;FieldDec:0),
          (FieldName:'AREA';  FieldType:'C';FieldLen:69;FieldDec:0),
          (FieldName:'FILENAME'; FieldType:'C';FieldLen: 8;FieldDec:0),
          (FieldName:'';      FieldType:' ';FieldLen: 0;FieldDec:0)
          );
begin
   GrepFieldProc := true;     {Return true unless aborting DBFCreate}

   AField := WorkFields[FldNo].FieldName;
   AType  := WorkFields[FldNo].FieldType;
   ALen   := WorkFields[FldNo].FieldLen;
   ADec   := WorkFields[FldNo].FieldDec;
end;
{$F-}





{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Procedure CreateMainBase(Name:String);
begin

   {Create new AREA dBase file}

   If AskYesNo(0,0,' Create '+Name+'? ') then begin
      CreateDBF(Name, 'F', MainFieldProc);
      {3 = dBase3,4 = dBase4,C = Clipper,F = FoxPro}
   end else begin
      Beep; Beep;
      WaitForOk('Sorry, can''t work without "'+NAME+'"...','Ok',White+Red*16,White);
      Halt(1);
   end;

   GsFileDelete (name+'.id1');
   GsFileDelete (name+'.id2');
   GsFileDelete (name+'.cdx');

end;



{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Procedure CreateWorkBase(Name:String);
begin

   {Create new MSG dBase file}

{   If AskYesNo(0,0,' Create '+Name+'? ') then begin}
      CreateDBF(Name, 'F', WorkFieldProc);
      {3 = dBase3,4 = dBase4,C = Clipper,F = FoxPro}
{   end;}

   GsFileDelete (name+'.id1');
   GsFileDelete (name+'.id2');
   GsFileDelete (name+'.cdx');

end;

{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Procedure CreateGrepBase(Name:String);
begin

   {Create new MSG dBase file}

{   If AskYesNo(0,0,' Create '+Name+'? ') then begin}
      CreateDBF(Name, 'F', GrepFieldProc);
      {3 = dBase3,4 = dBase4,C = Clipper,F = FoxPro}
{   end;}

   GsFileDelete (name+'.id1');
   GsFileDelete (name+'.id2');
   GsFileDelete (name+'.cdx');

end;





{--------------------------------------------------------------}
Function OpenWorkBase(dbFile:String;cAlias:string;AskForCreate:Boolean):Boolean;
Var
   l:boolean;
begin
   l:=False;
   If not GsFileExists(BaseDir+'\'+dbFile+'.dbf') then begin
      If AskForCreate then begin
         If AskYesNo(0,0,' Create "'+dbFile+'" database? ') then begin
            CreateWorkBase(BaseDir+'\'+dbFile+'.dbf');
         end;
      end else begin
         CreateWorkBase(BaseDir+'\'+dbFile+'.dbf');
      end;
   end;

   If GsFileExists(BaseDir+'\'+dbFile+'.dbf') then begin
      SetCentury(False);
{      Select(nArea);}
      Use(BaseDir+'\'+dbFile,cAlias,NewArea);
{      SetAlias(cAlias);}

      if not GsFileExists(BaseDir+'\'+dbFile+'.cdx') then begin
         IndexOn(BaseDir+'\'+dbFile+'.cdx','Subj','UPPER(SUBJ)','',Duplicates,Ascending);
         IndexOn(BaseDir+'\'+dbFile+'.cdx','From','UPPER(FROM)','',Duplicates,Ascending);
      end;

      Index(BaseDir+'\'+dbFile+'.cdx','SUBJ');

      SetOrderTo(MsgOrder);

{   SetMemoPacked(True);}

      SetDeleted(True);
      l:=True;
   end;
   OpenWorkBase:=l;
end;



{--------------------------------------------------------------}
Function OpenGrepBase(dbFile:String;cAlias:string):Boolean;
Var
   l:boolean;
begin
   l:=False;
   If not GsFileExists(BaseDir+'\'+dbFile+'.dbf') then
      CreateGrepBase(BaseDir+'\'+dbFile+'.dbf');

   If GsFileExists(BaseDir+'\'+dbFile+'.dbf') then begin
      SetCentury(False);
{      Select(nArea);}
      Use(BaseDir+'\'+dbFile,cAlias,NewArea);
{      SetAlias(cAlias);}

      if not GsFileExists(BaseDir+'\'+dbFile+'.cdx') then begin
         IndexOn(BaseDir+'\'+dbFile+'.cdx','Subj','UPPER(SUBJ)','',Duplicates,Ascending);
         IndexOn(BaseDir+'\'+dbFile+'.cdx','From','UPPER(FROM)','',Duplicates,Ascending);
      end;

      Index(BaseDir+'\'+dbFile+'.cdx','SUBJ');

      SetOrderTo(MsgOrder);

{   SetMemoPacked(True);}

      SetDeleted(True);
      l:=True;
   end;
   OpenGrepBase:=l;
end;




{--------------------------------------------------------------}
Procedure OpenMainBase(dbFile,dbAlias:String);
begin

   If not GsFileExists(BaseDir+'\'+dbFile+'.dbf') then
      CreateMainBase(BaseDir+'\'+dbFile);

{   Select(1);}
   Use(BaseDir+'\'+dbFile,dbAlias,NewArea);
{   SetAlias('AREAS');}

   if not GsFileExists(BaseDir+'\'+dbFile+'.cdx') then begin
      IndexOn(BaseDir+'\'+dbFile+'.cdx','AreaID','UPPER(FILENAME)','',Duplicates,Ascending);
      IndexOn(BaseDir+'\'+dbFile+'.cdx','AreaDescr','UPPER(AREA)','',Duplicates,Ascending);
   end;

   Index(BaseDir+'\'+dbFile+'.cdx','AREAID');

   SetOrderTo(AreaOrder);

{   SetMemoPacked(True);}
   SetDeleted(True);
   SetExact(True);
end;

{**********************************************************************}
Procedure Copy1Record(TargetArea:integer);
Var
  tmpStr:String;
  OldArea : Integer;

BEGIN
{   ObjFrom := DbfActive;}
   oldarea := DBFUsed;

   SelectArea(TargetArea);
   ClearRecord;
   Append;

   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('FROM');
     SelectArea(TargetArea);
     FieldPut('FROM',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('ADDR');
     SelectArea(TargetArea);
     FieldPut('ADDR',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('DATE');
     SelectArea(TargetArea);
     FieldPut('DATE',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('APDATE');
     SelectArea(TargetArea);
{     Today:=Gs_Date_Curr;            {Get Current Date}
{     FieldPut('APDATE',DTOS(Today)); {Put Current Date to 'ApDate' field}
     FieldPut('APDATE',tmpstr); {Put the Append Date to 'ApDate' field}
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('SUBJ');
     SelectArea(TargetArea);
     FieldPut('SUBJ',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   If FieldExists('PROJECT') then
      tmpStr:=FieldGet('PROJECT')
   else
      tmpStr:='';
     SelectArea(TargetArea);
     If FieldExists('PROJECT') then
        FieldPut('PROJECT',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('NEW');
     SelectArea(TargetArea);
     FieldPut('NEW',tmpStr);

   {-----------------------}
   SelectArea(OldArea);
   ReadMemo('TEXT');
     SelectArea(TargetArea);
     If Memo_Size > 0 then
       WriteMemo('TEXT');

   {------ATTACHMENT-----------------}
   SelectArea(OldArea);
   If FieldExists('ATTACHME') then begin      {If field exists}
     If MemoSize('ATTACHME') <> 0 then begin  {If attachment not empty}
       TmpStr:=FieldGet('PROJECT');           {Get Project Name}
       AttExtract(AllTrim(TmpStr));           {Extract the attachment}

       SelectArea(TargetArea);
       If FieldExists('ATTACHME') then
          AttImport(TmpStr);                  {Attach extracted file}
       gsFileDelete(TmpStr);                  {Erase this file}
     end;
   end;

   SelectArea(TargetArea);
   DbfActive^.RecModified:=True;
   Replace;

   SelectArea(OldArea);
   Go(RecNo);

END;        { Copy1Record }






{--------------------------------------------------------------}
Procedure DrawTitleScreen;
var i:integer;
begin
   SetColor('W+/N');
   for i:=1 to 24 do
      Fill_Char(1,i,'±',80);  {Write n char}

   SetColor('GR+/N');
   Box(3,2,77,22,Single,Shadow);

   SAY(7, 3,'ÉËÍÍË»                          ÉËÍÍË»');
   SAY(7, 4,'ºº  ºº R U S S I A N    S W A G ºº  ºº');
   SAY(7, 5,'ºº  ºº ÉËÍÍË» É»  É»  É» ÉËÍÍË» ºº  È¼');
   SAY(7, 6,'ºº  ºº ºº  È¼ ºº  ºº  ºº ºº  ºº ºº ÉË»');
   SAY(7, 7,'ºÌÍËÊ¼ ÈÊÍÍË» ºº  ºº  ºº ºÌÍÍ¹º ºº ººº');
   SAY(7, 8,'ºº ºÉ» É»  ºº ºº ÉÊÊ» ºº ºº  ºº ºº  ºº');
   SAY(7, 9,'ÊÊ ÈÊ¼ ÈÊÍÍÊ¼ ÈÊÍ¼  ÈÍÊ¼ È¼  È¼ ÈÊÍÍÊ¼');

   SAY(49,  2,'Â');
   SAY( 3, 10,'Ã');
   SAY(77, 10,'´');

   for i:=3 to 9 do
      SAY(49, i,'³');

   Fill_Char(4,10,'Ä',73);  {Write n char}

   SAY(49, 10,'Á');

   SetColor('W+/N');

   SAY(50, 4,'     The '+RSWAG);
   SAY(50, 5,'   Message Reader '+Version);
   SAY(50, 6,'     Written 1998-2001');
   SAY(50, 7,'   by Valery Votintsev');
   SAY(50, 8,'     FIDO:2:5021/22');
   SAY(50, 9,'(Thanks to Odinn Sorensen!)');

   SAY(19,12,'* * * Work In Progress: Getting There * * *');
   SAY(5,14,'* Registered to:');
   SAY(5,15,'* Registration serial number: absent');
   SAY(5,16,'* Valid for DOS versions.');

   SetColor('W/B');
   ClearLine(25);

   SetColor('W+/B');
   SAY(1,25,AllTrim(AreaBase));
   SAY(Length(AreaBase)+2,25, Version);
   SAY(25,25,'³ Scanning Area:');

end;

{-------------------------------------}
Procedure ScanAreas;
Var
   n,m:longint;
   fn:string[8];
begin

   GoTop;

   While not dEOF do begin
      fn:=AllTRim(FieldGet('FILENAME'));

      SAY(42,25,PadR(fn,8));

      n:=0;
      If fn <> '' then begin
         If not GsFileExists(BaseDir+'\'+fn+'.dbf') then
            n:=0
         else begin
            OpenWorkBase(fn,'WORK',DontAsk);
            n:=RecCount;

{      If RecCount > 0 then begin
{         n:=IndexRecNo;}
{         GoBottom;
         n:=IndexRecNo;
{         n:=m-n+1;}
{      end;
}
            Use('','',False);  { Close Current DataBase }
         end;
      end;

      Select('AREAS');
      IntegerPut('MSGCOUNT',n);   {Rewrite Msg Counter}
      Replace;
      Skip(1);
   end;

   GoTop;
   Delay(500);
end;


begin {READER_C}
  BaseDir:='';
  ListDir:='';
  SwagDir:='';
end.
