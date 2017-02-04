Program SWG2DBF;
{$I GSF_FLAG.PAS}

Uses
   Reader_U,
   Reader_C,
{   vDisk,
   vMEMO,
   vMenu,
   GSF_Shel,
   gsf_tool,
   gsf_date,
   vScreen,
   vKBd,
   CRT,
   GSF_DOS,}
   LZH,ZipUnit;

TYPE
  SwagHeader =
    RECORD
      HeadSize : BYTE;                 {size of header}
      HeadChk  : BYTE;                 {checksum for header}
      HeadID   : ARRAY [1..5] OF CHAR; {compression type tag}
      NewSize  : LONGINT;              {compressed size}
      OrigSize : LONGINT;              {original size}
      Time     : WORD;                 {packed time}
      Date     : WORD;                 {packed date}
      Attr     : WORD;                 {file attributes and flags}
      BufCRC   : LONGINT;              {32-CRC of the Buffer }
      Swag     : STRING[12];           {stored SWAG filename}
      Subject  : STRING[40];           {snipet subject}
      Contrib  : STRING[35];           {contributor}
      Keys     : STRING[70];           {search keys, comma deliminated}
      FName    : String[79];           {filename (variable length)}
      CRC      : WORD;                 {16-bit CRC (immediately follows FName)}
    END;

    SWAGFooter =
    RECORD
       CopyRight : String[60];         { GDSOFT copyright }
       Title     : String[65];         { SWG File Title   }
       Count     : INTEGER;
    END;

Var
   HeaderBuf: SwagHeader;              { Temporary buffer     }
   NextPos:LongInt;                    { Next snipet position }
   fSize:  LongInt;                    { File size            }
   F,dbF:  File;
   Name:   String[8];
{   Base :  DBase3;}

 be,en,BytesLeft:word;
 StartLzh,i:Word;
 PackBuf:  UserBufType;
 UnPackBuf:UserBufType;

 Result:Word;
 InCounter,OutCounter,SwgCounter:LongInt;

Procedure GetBlock(Var Target; NoBytes: Word; Var Actual_Bytes: Word); Far;
begin
 if NoBytes > BytesLeft then
   Actual_Bytes:=BytesLeft
 else
   Actual_Bytes:=NoBytes;

 move(PackBuf^[be],Target,Actual_Bytes);
 be:=be+Actual_Bytes;
 Dec(BytesLeft,Actual_Bytes);
end;

Procedure PutBlock(Var Source; NoBytes: Word; Var Actual_Bytes: Word); Far;
begin
  move(Source,UnPackBuf^[StartLzh],NoBytes);
  Inc(StartLzh,NoBytes);
  en:=en+NoBytes;
  Actual_Bytes:=NoBytes;
end;

{----------------------------------------------}
Procedure InsertToBuf(PackBuf:UserBufType;Var BufLen:Word;
                      InsPos:Word;InsStr:String);
Var i,L:word;
begin
  L:=Length(InsStr);
  For i:=BufLen DownTo InsPos do
     PackBuf^[i+l]:=PackBuf^[i];
  move(InsStr[1],PackBuf^[InsPos],L);
  Inc(BufLen,L);
end;


{----------------------------------------------}
{ Convert Integer to string & add leading zero }
Function LeadZero(L:Longint;n:byte):String;
Var
   i:integer;
   S:String;
begin
   STR(L:n,S);
   For i:=1 to n do
      If S[i]=' ' then S[i]:='0';
   LeadZero:=S;
end;
{-------------------------------------------}
{ Convert packed date to string }

Function Date2str(D:Word):String;
Var
   Day  :Word;
   Month:Word;
   Year :Word;
begin
   Day  := ( D and $1F);
   Month:= ( D and $1E0) shr 5;
   Year := ( D and $FE00) shr 9;
   Date2str:=LeadZero(Day,2)+'-'
            +LeadZero(Month,2)+'-'
            +LeadZero((Year+80),2);
   Date2str:=LeadZero((Year+80),4)
            +LeadZero(Month,2)+
            +LeadZero(Day,2);
end;



{===============================================}
begin
  InCounter:=0;
  OutCounter:=0;
  SwgCounter:=0;

{  SetPublicVar;        {Initialize Variables}

{  DrawTitleScreen;     {Draw Title Screen   }

  If not CheckWorkPath then begin   {}
     Halt(1);
  end else begin

      OpenMainBase(AreaBase,'AREAS');
      ScanAreas;

  end;

  For Each ('*.swg') do begin
     SwgName:=DirInfo.Name;
     If not Seek(SwgName) then
        CreateWorkBase(SwgName);

     ReadSwgHeader(SwgName);
     ReadNextMessage;

  end;




  If ParamStr(1)<>'' then  begin

    Name:=ParamStr(1);
    i:=Pos('.',Name);
    If i>0 then Name[0]:=Chr(i-1);

    Base.Assign(Name); {пpисвоить БД имя}
    Base.Init; {подготовиться к созданию БД}

    Base.AddField('FROM','C',25,0);
    Base.AddField('ADDR','C',25,0);
    Base.AddField('SUBJ','C',52,0);
    Base.AddField('DATE','D', 8,0);
    Base.AddField('APDATE','D', 8,0);
    Base.AddField('TEXT','M',10,0);
    Base.AddField('KEYS','C',40,0);
    Base.AddField('NEW', 'L',1,0);

    if Base.Create then
       Base.Open(ReadWrite)
    else begin
       writeln('Не могу создать базу данных...');
       exit;
    end;

    getmem(PackBuf,  sizeof(BuffType));
    getmem(UnPackBuf,sizeof(BuffType));

    Assign(F,ParamStr(1));
    Reset(F,1);

    FSize:=FileSize(F);
    NextPos:=0;

    While (nextPos+SizeOf(HeaderBuf)) < FSize do begin
      Seek(F,NextPos);
      BlockRead(F,HeaderBuf,SizeOf(HeaderBuf));

      seek(f,NextPos+HeaderBuf.HeadSize+2);
      blockread(f,PackBuf^,HeaderBuf.NewSize);

      Base.Append;
      Base.WriteStr('FROM',HeaderBuf.Contrib);
      Base.WriteStr('SUBJ',HeaderBuf.Subject);
      Base.WriteStr('KEYS',HeaderBuf.Keys   );
      Base.WriteStr('DATE',Date2Str(HeaderBuf.Date));
      Base.WriteStr('APDATE',Date2Str(HeaderBuf.Date));
      Base.WriteLog('NEW', FALSE);

(*  SwagHeader =
    RECORD
      HeadSize : BYTE;                 {size of header}
      HeadChk  : BYTE;                 {checksum for header}
      HeadID   : ARRAY [1..5] OF CHAR; {compression type tag}
      NewSize  : LONGINT;              {compressed size}
      OrigSize : LONGINT;              {original size}
      Time     : WORD;                 {packed time}
      Date     : WORD;                 {packed date}
      Attr     : WORD;                 {file attributes and flags}
      BufCRC   : LONGINT;              {32-CRC of the Buffer }
      Swag     : STRING[12];           {stored SWAG filename}
      Subject  : STRING[40];           {snipet subject}
      Contrib  : STRING[35];           {contributor}
      Keys     : STRING[70];           {search keys, comma deliminated}
      FName    : PathStr;              {filename (variable length)}
      CRC      : WORD;                 {16-bit CRC (immediately follows FName)}
    END;

*)

      be:=0;
      en:=0;
      BytesLeft:=HeaderBuf.NewSize;
      StartLzh:=0;

      LZHUnPack(HeaderBuf.OrigSize,GetBlock,PutBlock);

      For i:=0 to HeaderBuf.OrigSize-1 do begin
        If UnPackBuf^[i] = #26 then begin
           StartLzh:=i;
           Break;
        end;
      end;

      Inc(InCounter,HeaderBuf.OrigSize);
      Inc(SwgCounter,HeaderBuf.NewSize);
{
      Result := Zip(UnPackBuf, PackBuf, StartLzh);

      i:=0;
      While i < Result do begin
        If PackBuf^[i] = #26 then begin
           InsertToBuf(PackBuf,Result,i+1,'wG');
           PackBuf^[i]:='S';
           Inc(i,2);
        end;
        Inc(i);
      end;

      writeln('ZipSize=',Result);

      Inc(OutCounter,Result);
}
(*      Base.WriteMemo('TEXT',{Un}PackBuf,{StartLzh}Result); *)
      Base.WriteMemo('TEXT',UnPackBuf,StartLzh{Result});

      NextPos:=NextPos+HeaderBuf.HeadSize+HeaderBuf.NewSize+2;
    end;

    Close(F);
    Base.Close;
    writeln('SwgSize=',SwgCounter,' SourceSize=',InCounter,
            ' ZipSize=',OutCounter);

 end;
end.
