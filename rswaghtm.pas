{----------------------------------------------------------}
{                 Russian SWAG HTML Unit                   }
{                        v.4.1                             }
{      Unit Reader_C - Common utilities for the READER     }
{      written 1993-2001 by Valery Votintsev 2:5021/22     }
{                             E-Mail: rswag@sources.ru     }
{----------------------------------------------------------}
Unit RSWAGHTM;
{$i GSF_FLAG.PAS}
Interface
Uses
  Crt,
  vString,
  vMemo,
  gsf_dos,
  strings,
  reader_c,
  reader_u,
  gsf_shel;
Type
   pAreaObject = ^tAreaObject;
   tAreaObject = packed record
      ID       : string12;
      Descr    : string80;
      FileName : string12;
      MsgCounter : integer;
      MaxPageNum : integer;
   end;

   pAreaList = ^tAreaList;
   tAreaList = object(GSobjCollection)
      Constructor Create;
      Procedure   FreeItem(Item: Pointer); virtual;
      Procedure   InsertArea(const ID, FileName, Descr: String;
                             MsgCounter,MaxPageNum: integer); virtual;
      destructor  Destroy; virtual;
   end;

Const
  PgHeader = '<TR><TD class=page colspan=3 align=right>‘âà ­¨æë:&nbsp;&gt;&gt;&nbsp;<b>';
  PageFooter='</b></TD></TR>'#13#10;
{
  NavFirst  ='<a href="$FIRST$.htm"><img border=0 src="../img/first.gif" alt="To First Src"></a>&nbsp;&nbsp;&nbsp;&nbsp;';
  NavPrev   ='<a href="$PREV$.htm"><img border=0 src="../img/prev.gif" alt="To Prev Src"></a>&nbsp;&nbsp;&nbsp;&nbsp;';
  NavNext   ='<a href="$NEXT$.htm"><img border=0 src="../img/next.gif" alt="To Next Src"></a>&nbsp;&nbsp;&nbsp;&nbsp;';
  NavLast   ='<a href="$LAST$.htm"><img border=0 src="../img/last.gif" alt="To Last Src"></a>';
  NavFooter = '</td></tr>';
  Navigator ='$NAVIGATOR$';
}

Var
   IndexHeaderBuffer:MemoPtr;
   IndexFooterBuffer:MemoPtr;
   IndexRecordBuffer:MemoPtr;
   IndexHeaderSize:word;
   IndexFooterSize:word;
   IndexRecordSize:word;

   AreaHeaderBuffer:MemoPtr;
   AreaFooterBuffer:MemoPtr;
   AreaRecordBuffer:MemoPtr;
   AreaHeaderSize:word;
   AreaFooterSize:word;
   AreaRecordSize:word;

   MetaAboutBuffer:MemoPtr;
   AboutBuffer:MemoPtr;
   AboutSize:word;
   DescrBuffer:MemoPtr;
   DescrSize:word;
   DescriptionURL:string;
   ArchiveURL:string;
   ArchiveSize:string12;
   BodyBuffer:MemoPtr;
   BodySize:word;

   cFileName:string;
   written:word;

   ListOnly:string12;
   NeedBody:boolean;
   NeedSort:boolean;
   NeedAreaList:boolean;

   AreaColl:GsPtrStringCollection;
   AreaArray:pAreaList;
   spc:pChar;
   F:File;
{   FirstProject,LastProject:string12;
   PrevProject,NextProject:string12;
}
   PageHeader:string;
{   NavHeader:string;}
{   ArchiveTag:String;}
   Download:string;
   More:string;
   MoreInfo:string;

Procedure PrepareBuffers;
Procedure CloseBuffers;
Procedure ReadAreaList (ConfName:String);
Procedure GetAreaCollection;
Procedure MakeAreaList;
Procedure MakeMsgList;
Procedure WriteMsgBody;
Procedure FillMsgBuffers;

(*
Function AreaListed(const Area:string):Boolean;
Procedure ExtractAreaParameters(i:integer);
Procedure WriteAreaCollection;
Procedure ReadBuffer(const filename:string; var Buffer:MemoPtr;
                     var BufferLength:word);
Procedure PreparePageNum;
Procedure WriteAreaHeader;
Procedure WriteAreaFooter;
Procedure PrepareMsgBuffer;
Procedure PrepareAreaBuffer;
{Procedure PrepareNavigator;}
Procedure StripFromMemo(const s:string; var Param: string);
Procedure WriteMsgRecord;
Function FormFileName(PageNum:integer):string;
*)

Implementation

{-----------------------------------------------------------------------------
                              tAreaList
-----------------------------------------------------------------------------}

Constructor tAreaList.Create;
begin
   inherited Create(64,16);
end;

Destructor tAreaList.Destroy;
begin
   inherited Destroy;
end;

procedure tAreaList.FreeItem;  {(Item: Pointer)}
begin
  if Item <> nil then begin
     FreeMem(Item, SizeOf(tAreaObject));
  end;
end;


Procedure tAreaList.InsertArea(const ID,FileName,Descr: String; MsgCounter,MaxPageNum: integer);
var
   p : pAreaObject;
   j : integer;
begin
   j := length(ID);
   if j = 0 then exit;
   GetMem(p, SizeOf(tAreaObject));
   FillChar(p^, SizeOf(tAreaObject), #0);
   p^.ID:=Upper(ID);
   p^.FileName:=lower(FileName);
   p^.Descr := Descr;
   p^.MsgCounter := MsgCounter;
   Insert(p);
end;


{*ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ*}
Procedure ReadAreaList (ConfName:String);
Var
  FConf:Text;
  lstr,Equ,Comment:byte;
  Line:string;
  StrConf,
  ParName,Parm:  string;
  i:integer;
Begin
  IF not GsFileExists(ConfName) then begin
    Writeln('');
    Writeln('*** File ',ConfName,' not found!');
    Halt(1);
  end;

  If not FileOpen(FConf,ConfName,0) then begin
    writeln('*** Open error of "',ConfName,'"');
    HALT(1);
  end;

  GetMem(spc,256);

  While not System.EOF(FConf) do begin

    Readln(FConf,StrConf);

    Comment:=Pos('//',StrConf);               {Check for //}
    If Comment>0 then
      StrConf:=RTrim(Copy(StrConf,1,Comment-1));
    Comment:=Pos('&&',StrConf);            {Check for &&}
    If Comment>0 then
      StrConf:=RTrim(Copy(StrConf,1,Comment-1));
    Comment:=Pos(';',StrConf);             {Check for ; }
    If Comment>0 then
      StrConf:=RTrim(Copy(StrConf,1,Comment-1));

    If StrConf<>'' then begin
      StrPCopy(spc,StrConf);            {Add the AREA to AreaList}
      AreaColl^.Insert(StrGSNew(spc));
    end;
  end; {While}

  FreeMem(spc,256);
  FileClose(FConf);
end;

{-------------------------------------------------}
Function AreaListed(const Area:string):Boolean;
var
  i,equ:integer;
  AreaName:string;
  ID,fname:string12;
begin
  AreaListed:=False;
  For i:= 0 to Pred(AreaColl^.Count) do begin
    AreaName:=StrPas(AreaColl^.AT(i));
    ID:=Upper(Area);
    fname:=lower(ID);

    Equ:=Pos('=',AreaName);
    If Equ>0 then begin
      ID:=Upper(AllTrim(Copy(AreaName,Equ+1,
                             Length(AreaName)-Equ)));
      AreaName:=Upper(AllTrim(Copy(AreaName,1,Equ-1)));
    end;

    If AreaName=Upper(Area) then begin
      AreaListed:=True;
      AreaID:=ID;
      break;
    end;
  end;
end;


{---------------------------------------------------------}
Procedure ExtractAreaParameters(i:integer);
var
  p: pAreaObject;
begin
  p:=AreaArray^.AT(i);
  AreaID:=p^.ID;
  AreaDescr:=p^.Descr;
  RealAreaName:=p^.FileName;
  MsgCounter:=p^.MsgCounter;
  Str(MsgCounter,AreaMsgCounter);
  MaxPageNum:=((MsgCounter-1) div SnipetsPerPage) + 1;
  PageNum:=1;
end;



{-----------------------------------------------------------}
Procedure WriteAreaCollection;
var
  i:integer;
  p: pAreaObject;
begin
  For i:=0 to pred(AreaArray^.Count) do begin
    p:=AreaArray^.At(i);
    system.writeln(p^.ID,' ',p^.FileName,' ',p^.MsgCounter,' ',p^.Descr);
  end;
end;


{-----------------------------------------------------------}
Procedure ReadBuffer(const filename:string; var Buffer:MemoPtr;
                     var BufferLength:word);
var
   Fb:File;
begin
  BufferLength:=gsFileSize(filename);
  If BufferLength > 0 then begin
    GetMem(Buffer,BufferLength);
    Assign(Fb,filename);
    Reset(Fb,1);
    BlockRead(Fb,Buffer^,MaxMemoSize,BufferLength);
    Close(Fb);
  end;
end;

{------------------------------------------------------}
Procedure PreparePageNum;
var
  np:string12;
  s:string;
  i,nPage:word;
begin
  nPage:=ScanUpBufr('$Page$',Memo^,Memo_Size);
  If nPage>0 then begin
    dec(nPage);
    MemoDelChars(nPage,6);   {Remove Macros Name}
    If MaxPageNum > 1 then begin
      MemoInsString(nPage,PageHeader);
      Inc(nPage,Length(PageHeader));
      For i:=1 to MaxPageNum do begin
        str(i,np);
        If PageNum=i then begin
          s:=np+'&nbsp;';
        end else begin
          If i=1 then
            s:='<A href="index.htm">'+np+'</A>&nbsp;'
          else
            s:='<A href="index'+np+'.htm">'+np+'</A>&nbsp;';
        end;
        MemoInsString(nPage,s);
        Inc(nPage,Length(S));
      end;
      MemoInsString(nPage,PageFooter);
      Inc(nPage,Length(PageFooter));
    end;
  end;
end;


{-----------------------------------------}
Procedure PrepareAreaBuffer;
begin
  ReplaceInMemo('$AREALOW$',RealAreaName);
  ReplaceInMemo('$AREAID$',AreaID);
  ReplaceInMemo('$AREADESCR$',ConvertStr(AreaDescr,@Dos2Win));
  ReplaceInMemo('$MSGCOUNTER$',AreaMsgCounter);
  PreparePageNum;
end;

{-------------------------------------------------------------}
Procedure MakeAreaList;
{Build the Area list }
var
  i:integer;

begin {Procedure MakeAreaList;}

  {----------------------------------}
  { Form All Area List               }
  {----------------------------------}

  cFileName:=ListDir+'\sources.htm';
  Write('Making Area List ...');

  Assign(F,cFileName);
  {$i-} Rewrite(F,1); {$i-}          {Create New Area List}

  If IoResult <> 0 then begin
    Writeln('Error.');
  end else begin

    BlockWrite(F,IndexHeaderBuffer^,IndexHeaderSize,written); {Write Header}

    For i:=0 to Pred(AreaArray^.Count) do begin

      ExtractAreaParameters(i);
      If AreaListed(RealAreaName) then begin
        {Prepare the buffer for the AreaList Record}
        move(IndexRecordBuffer^,Memo^,IndexRecordSize);
        Memo_Size:=IndexRecordSize;
        PrepareAreaBuffer;
        BlockWrite(F,Memo^,Memo_Size,written);  {Write next Area Record}
      end;
    end;

    BlockWrite(F,IndexFooterBuffer^,IndexFooterSize,written); {Write Footer}

    Close(F);                        {Close Area List}
    Writeln('ok.');
  end;
end;

{-------------------------------------------------------------}
Procedure GetAreaCollection;
{Read the Main DataBase & Make Area Collection }
begin {Procedure MakeAreaList;}

  AreaArray := New(pAreaList, Create);
  GoTOP;

  While not dEOF do begin

    GetAreaParameters;
    AreaListed(realAreaName); {Convert Real Name to AreaID}

{     AreaID:=Upper(RealAreaName);}
      AreaArray^.InsertArea(AreaID,RealAreaName,AreaDescr,MsgCounter,MaxPageNum);
{    end;}
    Skip(1);
  end;
end;

{--------------------------------}
Procedure WriteAreaHeader;
begin
  move(AreaHeaderBuffer^,Memo^,AreaHeaderSize);
  Memo_Size:=AreaHeaderSize;
  PrepareAreaBuffer;
  BlockWrite(F,Memo^,Memo_Size,written);   {Write Current Msg Record}
end;

{--------------------------------}
Procedure WriteAreaFooter;
begin
  move(AreaFooterBuffer^,Memo^,AreaFooterSize);
  Memo_Size:=AreaFooterSize;
  PrepareAreaBuffer;
  BlockWrite(F,Memo^,Memo_Size,written);   {Write Current Msg Record}
end;


{------------------------------------------------------}
Procedure PrepareMsgBuffer;
var
  i,j:longint;
begin
  ReplaceInMemo('$FROM$',ConvertStr(FROM,@Dos2Win));
  ReplaceInMemo('$ADDR$',ConvertStr(Addr,@Dos2Win));
  ReplaceInMemo('$SUBJ$',ConvertStr(Subj,@Dos2Win));
  ReplaceInMemo('$DATE$',Date);

  IF Size = '' then begin
    ReplaceInMemo('$DOWNLOAD$','&nbsp;');
    ReplaceInMemo('$SIZE$','&nbsp;');
  end else begin
    ReplaceInMemo('$DOWNLOAD$',DownLoad);
    ReplaceInMemo('$SIZE$',Size);
  end;
  If (DescrSize=0) and (DescriptionURL='') then begin
    ReplaceInMemo('$MORE$','&nbsp;');
    ReplaceInMemo('$MOREINFO$','&nbsp;');
  end else begin
    ReplaceInMemo('$MORE$',More);
    ReplaceInMemo('$MOREINFO$',MoreInfo);
  end;

  ReplaceInMemo('$PROJECT$',Project);


  i:=ScanUpBufr('$METADESCR$',Memo^,Memo_Size);
  If i>0 then begin
    dec(i);
    MemoDelChars(i,11);
    For j:=pred(Memo_Size) downto i do
      Memo^[j+AboutSize]:=Memo^[j];
    move(AboutBuffer^,Memo^[i],AboutSize);
    Inc(Memo_Size,AboutSize);
  end;
  ReplaceInMemo('<br>'#13,'&#10;');


  i:=ScanUpBufr('$ABOUT$',Memo^,Memo_Size);
  If i>0 then begin
    dec(i);
    MemoDelChars(i,7);
    For j:=pred(Memo_Size) downto i do
      Memo^[j+AboutSize]:=Memo^[j];
    move(AboutBuffer^,Memo^[i],AboutSize);
    Inc(Memo_Size,AboutSize);
  end;


  i:=ScanUpBufr('$DESCR$',Memo^,Memo_Size);
  If i>0 then begin
    dec(i);
    MemoDelChars(i,7);
{    while memo^[i] in [' ',#9,#13,#10] do
        MemoDelChars(i,1);
}
    For j:=pred(Memo_Size) downto i do
      Memo^[j+DescrSize]:=Memo^[j];
    move(DescrBuffer^,Memo^[i],DescrSize);
    Inc(Memo_Size,DescrSize);
  end;
end;

(*
{--------------------------------}
Procedure PrepareNavigator;
var
  n:integer;
  j:word;
  s:string;
begin

  {Insert Horizontal Navigator Bar}
  Repeat
    j:=ScanUpBufr(Navigator,Memo^,Memo_Size);

    If j>0 then begin

      MemoDelChars(pred(j),Length(Navigator));

      MemoInsString(pred(j),NavHeader);
      Inc(j,Length(NavHeader));


      If Project<>FirstProject then begin
        s:=NavFirst;
        n:=pos('$FIRST$',s);
        if n>0 then begin
          s:=ReplaceAll(S,'$FIRST$',FirstProject);
          MemoInsString(pred(j),s);
          Inc(j,Length(s));
        end;
      end;

      If Project<>PrevProject then begin
        s:=NavPrev;
        n:=pos('$PREV$',s);
        if n>0 then begin
          s:=ReplaceAll(S,'$PREV$',PrevProject);
          MemoInsString(pred(j),s);
          Inc(j,Length(s));
        end;
      end;

      If Project<>NextProject then begin
        s:=NavNext;
        n:=pos('$NEXT$',s);
        if n>0 then begin
          s:=ReplaceAll(S,'$NEXT$',NextProject);
          MemoInsString(pred(j),s);
          Inc(j,Length(s));
        end;
        end;

      If Project<>LastProject then begin
        s:=NavLast;
        n:=pos('$LAST$',s);
        if n>0 then begin
          s:=ReplaceAll(S,'$LAST$',LastProject);
          MemoInsString(pred(j),s);
          Inc(j,Length(s));
        end;
      end;

      MemoInsString(pred(j),NavFooter);
    end;
  until (j=0);
end;
*)

Procedure StripFromMemo(const s:string; var Param: string);
var
  j,k,nd:longint;
begin
  Param:='';
  j:=ScanUpBufr(s,Memo^,Memo_Size);
  If j>0 then begin
     nd:=length(s);
     k:=j+nd-1;           {Position after "{archive"}
     While Memo^[k] in [' ','='] do begin
       inc(k);
       Inc(nd);
     end;
     While Memo^[k] <> '}' do begin
       Param:=Param + Memo^[k];
       Inc(k);
       Inc(nd);
     end;
     While Memo^[k] in ['}',' '] do begin
       inc(nd);
       inc(k);
     end;
     While Memo^[k] in [#13,#10] do begin
       If (Memo^[k] = #13) and (Memo^[k+1] = #10) then
         inc(nd);
       inc(k);
     end;
     MemoDelChars(pred(j),nd);
  end;
end;

{---------------------------------------------------------}
Procedure FillMsgBuffers;
var
  n,nd:longint;
  i,j,k:longint;
begin
{  n:=RecNo;
  Skip(1);
  If dEOF then
    NextProject:=LastProject
  else
    NextProject:=GetProject;
  Go(n);
}
{-----------------------------------}
{Strip ABOUT & Description from MEMO}
  ReadMemo('TEXT');
  ConvertMemo(@Dos2Win);
  AboutSize:=0;

  {Check for archive URL}
  StripFromMemo('{archive',ArchiveURL); {Check for "{archive=..."}

  {Check for archive size}
  StripFromMemo('{size',ArchiveSize); {Check for "{size=..."}
  If Size='' then Size:=ArchiveSize;

  {Check for ABOUT}
  i:=ScanUpBufr('{>$ABOUT}',Memo^,Memo_Size); {Check for "{>$About}
  If i>0 then begin
     MemoDelChars(0,i+9);
  end;

  {Check for Description}
  j:=ScanUpBufr('{>$Description',Memo^,Memo_Size);

  {Check for Description URL}
  If j>0 then begin
     StripFromMemo('{>$Description',DescriptionURL);
  end else
     j:=Memo_Size;

  If i>0 then
    AboutSize:=pred(j);

   {Insert <br> before CRLF inside the ABOUT body}
(*   i:=0;
   While i < AboutSize do begin
     If (Memo^[i]=#13) and (Memo^[i+1]=#10) and
        (Memo^[i+2]<>#13) and (Memo^[i+3]<>#10)
        and ((i + 3) < AboutSize) then begin
        MemoInsString(i,'<br>');
        inc(i,6);
        inc(AboutSize,4);
     end else inc(i);
   end;
*)
  While (Memo^[AboutSize-2]=#13) do begin
     MemoDelChars(AboutSize-2,1);
     Dec(AboutSize,2);
  end;

  move(memo^,AboutBuffer^,AboutSize);   {Fill the ABOUT buffer}

  move(memo^[AboutSize],memo^,Memo_Size-AboutSize);     {Remove ABOUT}
  Dec(Memo_Size,AboutSize);
{ Check for quoted
  i:=0;
  While i < Memo_Size do begin
    j:=scancrdn(i);
    If quoted then begin
      MemoInsString(i,'<b>');
      MemoInsString(j,'</b>');
      inc(j,7);
    end;
    i:=j;
  end;
}
  {Fill the Description buffer}
  DescrSize:=Memo_Size;
  move(memo^,DescrBuffer^,DescrSize);

  {Strip an Empty Tail from the Description buffer}
  j:=DescrSize;
  while (j>0) and (DescrBuffer^[pred(j)] in [' ',#9,#13,#10]) do begin
    dec(j);
    Dec(DescrSize);
  end;

  If ArchiveURL='' then
    DownLoad:='<A HREF="$PROJECT$.zip">'
  else
    DownLoad:='<A HREF="'+ArchiveURL+'">';

  DownLoad:='$SIZE$&nbsp;'+Download + '<img border=0 align=middle src="../img/dsk.gif"></A>';

  If DescriptionURL='' then begin
    If DescrSize=0 then begin
      More:='';
      MoreInfo:='';
    end else begin
      More:='<A class=subheader href="$PROJECT$.htm" target=_top>';
      MoreInfo:='<br><div align="right"><A href="$PROJECT$.htm"'+
                ' target=_top>...more info</A></div>';
    end
  end else begin
    More:='<A class=subheader href="'+DescriptionURL+'" target=_top>';
    MoreInfo:='<br><div align="right"><A href="'
              +DescriptionURL+'" target=_top>...more info</A></div>';
  end;

end;


{--------------------------------}
Procedure WriteMsgRecord;
begin
  move(AreaRecordBuffer^,Memo^,AreaRecordSize);
  Memo_Size:=AreaRecordSize;

  PrepareMsgBuffer;

  BlockWrite(F,Memo^,Memo_Size,written);   {Write Current Msg Record}
end;

{------------------------------------------}
Procedure WriteMsgBody;
var
  Fb:File;
  cFileName:string;

begin
 If DescrSize <> 0 then begin
  cFileName:=ListDir+'\'+RealAreaName+'\'+Project+'.htm';
(*{-----------------------}
ClrScr;
writeln('cFileName:=',ListDir+'\'+RealAreaName+'\'+Project+'.htm');
Readln;
{-----------------------}
*)
  Assign(Fb,cFileName);
  {$i-} Rewrite(Fb,1); {$i-}          {Create New Msg Body }

  If IoResult = 0 then begin
    move(BodyBuffer^,Memo^,BodySize);
    Memo_Size:=BodySize;
    PrepareAreaBuffer;
{    PrepareNavigator;}
    PrepareMsgBuffer;

    BlockWrite(Fb,Memo^,Memo_Size,written);   {Write Body File}
    Close(Fb);
  end;
 end;
end;

{-------------------------------------------------------------}
Function FormFileName(PageNum:integer):string;
var
  s:string12;
begin
  If PageNum=1 then
    FormFileName:=ListDir+'\'+RealAreaName+'\index.htm'
  else begin
    Str(PageNum,S);
    FormFileName:=ListDir+'\'+RealAreaName+'\index'+S+'.htm';
  end;
end;

{-------------------------------------------------------------}
Procedure MakeMsgList;
{Build the msgs list (like files.bbs) }
var
  ErrorCode:integer;
  AreaNum:integer;
  Counter:Integer;
  x,y:byte;
begin {Procedure MakeMsgList;}

  {----------------------------------}
  { Form Index.Htm for each Area    }
  {----------------------------------}

  For AreaNum:=0 to Pred(AreaArray^.Count) do begin

    ExtractAreaParameters(AreaNum);

    If (ListOnly = '*') or (ListOnly = RealAreaName) then begin

      If DirExists(listdir + '\'+RealAreaName) then begin
        Write('Listing of ',AreaID,': ');
        x:=WhereX;
        y:=WhereY;

        OpenWorkBase(RealAreaName,'WORK',DontAsk);
        SetCentury(True);

        If not NeedSort then
{!}        SetTagTo('');       {No Sorting by SUBJECT}

        GoTop;  {WORK}
{        FirstProject:=GetProject;
        PrevProject:=GetProject;

        GoBottom;
        LastProject:=GetProject;
        GoTop;  {WORK}

        MsgNumber:=1;
        PageNum:=1;
        Counter:=1;

        While (not dEOF) do begin
          If (MsgNumber=1) then begin
            cFileName:=FormFileName(PageNum);
            Assign(F,cFileName);
            {$i-} Rewrite(F,1); {$i-}
            WriteAreaHeader;  {Write Area Header}
          end;
          If IoResult <> 0 then begin
            {Error!}
          end else begin
            If not dEOF then begin
              GetMsgParameters;

              FillMsgBuffers;

              WriteMsgRecord;

              GotoXY(x,y);
              Write(Counter:5);
              Inc(Counter);

              If NeedBody then
                WriteMsgBody;

{              PrevProject:=Project;}

              Inc(MsgNumber);
            end;

            skip(1);

            If dEOF or (MsgNumber > SnipetsPerPage) then begin
              WriteAreaFooter;
              Close(F);
              MsgNumber:=1;

              Inc(PageNum);
            end;
          end;
        end; { while not dEOF}

        Use('','',False);  { Close Current Area DataBase }
        Writeln(' ok.');
      end;
    end;
  end;
end;

Procedure PrepareBuffers;
begin
   PageHeader:=ConvertStr(PgHeader,@Dos2Win);
{   NavHeader :='<tr><td colspan=3 align=right><a href="index1.htm">'+
               '<img border=0 src="../img/up.gif" alt="Up to Src List">'+
               '</a>&nbsp;&nbsp;&nbsp;&nbsp;';
{   ArchiveTag:='<A HREF="$PROJECT$.zip"><img src="../img/dsk.gif"></A>';}
   GetMem(AboutBuffer,MaxInt);
{   GetMem(MetaAboutBuffer,MaxInt);}
   GetMem(DescrBuffer,MaxMemoSize);

   ReadBuffer(IndexHeader,IndexHeaderBuffer,IndexHeaderSize);
   ReadBuffer(IndexFooter,IndexFooterBuffer,IndexFooterSize);
   ReadBuffer(IndexRecord,IndexRecordBuffer,IndexRecordSize);

   ReadBuffer(AreaHeader,AreaHeaderBuffer,AreaHeaderSize);
   ReadBuffer(AreaFooter,AreaFooterBuffer,AreaFooterSize);
   ReadBuffer(AreaRecord,AreaRecordBuffer,AreaRecordSize);

   ReadBuffer(MsgHeader,BodyBuffer,BodySize);

end;

Procedure CloseBuffers;
begin
   FreeMem(IndexHeaderBuffer,IndexHeaderSize);
   FreeMem(IndexFooterBuffer,IndexFooterSize);
   FreeMem(IndexRecordBuffer,IndexRecordSize);

   FreeMem(AreaHeaderBuffer,AreaHeaderSize);
   FreeMem(AreaFooterBuffer,AreaFooterSize);
   FreeMem(AreaRecordBuffer,AreaRecordSize);

   FreeMem(BodyBuffer,BodySize);

   FreeMem(AboutBuffer,MaxInt);
{   FreeMem(MetaAboutBuffer,MaxInt);}
   FreeMem(DescrBuffer,MaxMemoSize);
end;

{---------------------------------------------------------}
begin
  {PrepareBuffers;}
end.
