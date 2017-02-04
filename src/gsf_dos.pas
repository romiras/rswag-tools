unit gsF_DOS;
{-----------------------------------------------------------------------------
                          DOS Unit Replacement (Limited)

       gsF_DOS Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit provides a shell for calls to DOS/WINDOS/SYSUTILS
       units for simplified operation in DOS, BPW, and Delphi.
       Only calls needed by Griffin Solutions units are included.

   Changes:
      !!RFG 091297 Rewrote the GSGetFAttr routine to replace The FindFirst
                   routine with the DOS $43 Get File Attributes call.  This
                   was necessary because Novell file permissions could deny
                   users ScanFiles permissions, which prevents FindFirst from
                   working properly.

      !!RFG 091397 Added GSFileDelete Function. Returns 0 if successful, -1
                   if not.

      !!RFG 091597 Modified GSGetExpandedFile to handle Netware Volumes.
------------------------------------------------------------------------------}
{$I gsF_FLAG.PAS}
interface
uses
   gsF_Glbl,
   gsf_Xlat,
   {$IFDEF DPMI}
   WinAPI,
   {$ENDIF}
   Strings,
   DOS;

{private}

type
   GSrecDateTime = packed record
      Year,
      Month,
      Day,
      Hour,
      Min,
      Sec : word
   end;

   GSrecLongint =  packed record
      case byte of
         1 : (Lo, Hi: word);
         2 : (All: longint);
   end;

type
{ Typed and untyped files }
  TFileRec = record
    Handle: Word;
    Mode: Word;
    RecSize: Word;
    Private: array[1..26] of Byte;
    UserData: array[1..16] of Byte;
    Name: array[0..79] of Char;
  end;


{public}

Procedure GSCheckMessages;

Procedure GSGetDate(var Year, Month, Day, WeekDay : word);
Procedure GSGetTime(var Hour, Minute, Second, Sec100 : word);

Function  GsFileSize    (const FileName: String) : longint;
Function  GSFileIsOpen  (const FileName : String): boolean;
Function  GSFileExists  (const FileName : String) : Boolean;
Function  GSFileOpen    (const FileName : String; Mode: integer): integer;
Function  GSFileCreate  (const FileName : String): integer;
Function  GSFileDelete  (const FileName : String): integer;
Function  GSFileRename  (const FileName,NewFileName : String): Boolean;
Function  GSFileRead    (Handle: Integer; var Buffer; Count: Longint): Longint;
Function  GSFileWrite   (Handle: Integer; var Buffer; Count: Longint): Longint;
Function  GSFileTruncate(Handle: integer; Offset: longint): boolean;
Procedure GSFileClose   (Handle: integer);
Function  GSFileSeek    (Handle: Integer; Delta: Longint;
                                 Origin: Integer): Longint;
Procedure GSFileDateTime(Handle: integer;var Year,Month,Day,Hour,Min,Sec: Word);

Function  GSGetFAttr    (const FileName: String ) :Integer;
Function  GSGetExpandedFile(const FileName: String): String;
Function  GSGetFTime    (Handle: integer) : longint;
Procedure GSSetLastError(Value: Integer);
Function  GSGetLastError: integer;

Procedure GSUnpackTime(P: longint; var T : GSrecDateTime);
Function  GSGetPointer(P: Pointer; OSet: Longint): pointer;

Function  GS_ExtendHandles(HndlCount : byte) : boolean;
Function  GS_Flush(Hndl : longint): integer;
Function  GS_LockFile(Hndl,FilePosition,FileLength : LongInt) : integer;
Function  GS_UnLockFile(Hndl,FilePosition,FileLength : LongInt) : integer;

Function  DirExists(const FileName: String ):Boolean;
Function  FileDeleteByMask(const FilePath,FileMask: String ):Integer;
Function  MakeDir(Name:string):Integer;
Procedure WaitForKey;
Function  ValidDosName(S:String):Boolean;
Function  FileOpen(Var F:Text;FileName:String;Mode:Integer):Boolean;
Procedure FileClose(Var F:Text);
Function  FileCopy(const FromFile,ToFile: String) : Boolean;
Function DosShell(Const Command,ParamString:string):Integer;

implementation
Uses
   vString;

{*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴*}
Function  FileDeleteByMask(const FilePath,FileMask: String ):Integer;
Var
  cFileName:String80;
  DirInfo:SearchRec;
  Slash:string[1];
  nResult:integer;
begin
  nResult:=0;
  If Right(FilePath,1)='\' then Slash:=''
                           else Slash:='\';
  FindFirst(FilePath+Slash+FileMask,Archive,DirInfo);
  While DosError = 0 do begin
    cFileName:=FilePath+Slash+DirInfo.Name;

    nResult:=GsFileDelete(cFileName);
    If nResult <> 0 then break;

    FindNext(DirInfo);
  end;
  FileDeleteByMask:=nResult;
end;

Function DosShell(Const Command,ParamString:string):Integer;
begin

   dos.SwapVectors;
   dos.Exec(Command,ParamString);
   dos.SwapVectors;
   DosShell := Dos.DosError;
end;





{*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴*}
Function  FileCopy(const FromFile,ToFile: String) : Boolean;
{Written by Dmitry Suhodoev  2:5010/150.16}
{modified by Valery Votintsev             }
{procedure   CopyFile(From,Too: string; Add: Boolean);}
 type
  tBuf=array[1..$FFFF] of Char;
 var
  FromF,ToF: file;
  NumRead,NumWrItten: Word;
  Buf: ^TBuf;
  Time: Longint;
  Attr: Word;
 begin
  FileCopy:=False;
  if Not GsFileExists(FromFile) then exit;
  if Upper(FromFile)=Upper(ToFile) then exit;

  Assign(FromF,FromFile);
  GetFTime(FromF,Time);
  GetFAttr(FromF,Attr);
  SetFAttr(FromF,Archive);

  Reset(FromF,1);
  Assign(ToF,ToFile);
  ReWrite(ToF,1);
  New(buf);

  repeat
   BlockRead(FromF,Buf^,SizeOf(Buf^),NumRead);
   BlockWrite(ToF,Buf^,NumRead,NumWrItten);
  until (NumRead = 0) or (NumWritten <> NumRead);

  Dispose(buf);
  Close(FromF);
  Close(ToF);

  SetFTime(ToF,Time);
  SetFAttr(ToF,Attr);

  SetFAttr(FromF,Attr);
  FileCopy:=True;

 end;

{*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴*}
Procedure  FileClose(Var F:Text);
begin
  System.Close(F);
end;

{*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴*}
Function FileOpen(Var F:Text;FileName:String;Mode:Integer):Boolean;
Begin
   System.Assign(F,FileName);
   (*$I-*)
   Case Mode of
   fmOpenRead:      System.reset(F);
   fmOpenWrite:     System.rewrite(F);
   fmOpenReadWrite: System.Append(F);
   end;
   (*$I+*)
   FileOpen:=(IOResult= 0);
end;



{*******************************}
Function ValidDosName(S:String):Boolean;
Const ValidDosChars = ['A'..'Z','a'..'z','0'..'9','$','%','''',
                  '-','@','{','}','~','`','!','#','(',')','&'];
var
   i:byte;
begin
   ValidDosName:=True;
   For i:=1 to Length(s) do begin
      If not (s[i] in ValidDosChars) then begin
         ValidDosName := False;
         break;
      end;
   end;
end;

{---------------------------------------------------}
Function DirExists(const FileName: String ):Boolean;
Var
  attr:integer;
begin
  DirExists:=False;
  attr:=GsGetFAttr(FileName);
  If Attr <> -1 then
    DirExists:=($10 and Attr) > 0;
end;



{*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴*}
Function MakeDir(Name:string):Integer;
Var
   n:integer;
   FirstStr:string;
   LastStr:string;
begin
   MakeDir:=0;
   FirstStr:='';
   If LastStr[Length(LastStr)]='\' then Dec(Byte(LastStr[0]));
   LastStr:=GsGetExpandedFile(Name);

   While LastStr<>'' do begin
      n:=Pos('\',LastStr);
      If n = 0 then begin
         FirstStr:=FirstStr+'\'+LastStr;
         LastStr:='';
         end
      else begin
         If FirstStr = '' then
            FirstStr:=Copy(LastStr,1,n-1)
         else
            FirstStr:=FirstStr +'\'+ Copy(LastStr,1,n-1);
         System.Delete(LastStr,1,n);
      end;
      If Length(FirstStr)>2 then begin
         If not gsFileExists(FirstStr) then begin
            {$I-}
            MkDir(FirstStr);
            {$I+}
            n:=IoResult;
            MakeDir:=n;
            If n <> 0 then break;
         end;
      end;
   end;
end;




Function  GsFileSize(const FileName: String) : longint;
{written by VVF}
var
   DirInfo: SearchRec;
begin
   FindFirst(FileName, Archive, DirInfo);
   If DosError = 0 then GsFileSize:=DirInfo.Size
                   else GsFileSize:=-1;
end;



Procedure GSCheckMessages;
begin
end;


procedure GSGetDate(var Year, Month, Day, WeekDay : word);
begin
   GetDate(Year, Month, Day, WeekDay);
end;



Procedure GSGetTime(var Hour, Minute, Second, Sec100 : word);
begin
   GetTime(Hour, Minute, Second, Sec100);
end;


Function GSFileIsOpen(const FileName : String): boolean;
var
   fmode : byte;
   frslt : integer;
   fopn  : boolean;
begin
   fmode := fmOpenReadWrite + fmShareExclusive;
   frslt := GSFileOpen(FileName,fmode);
   if frslt > 0 then
   begin
      GSFileClose(frslt);
      fopn := false;
   end
   else
      fopn := GSGetLastError = 5;
   GSFileIsOpen := fopn;
end;

Function GSFileExists(const FileName : String) : Boolean;
begin
   GSFileExists := GSGetFAttr(FileName) >= 0;
end;

Function GSFileRename(const FileName,NewFileName : String) : Boolean;
Var F:File;
begin
   {$i-}
   Assign(F,FileName);
   {$i+}
   If IoResult = 0 then begin
      {$i-}
      System.Rename(F,NewFileName);
      {$i+}
   end;
   GSFileRename := (IoResult = 0);
end;

Function GSFileOpen(const FileName : String; Mode: integer): integer;
      {File Modes (including sharing)
   dfCreate            = $0F;
      fmOpenRead       = $00;
      fmOpenWrite      = $01;
      fmOpenReadWrite  = $02;
      fmShareCompat    = $00;
      fmShareExclusive = $10;
      fmShareDenyWrite = $20;
      fmShareDenyRead  = $30;
      fmShareDenyNone  = $40;
}
var
   Path: PChar;
   Handle: integer;
begin
   GSintLastError := 0;
   GetMem(Path,81);
   StrPCopy(Path,FileName);
   Asm
     PUSH DS
     LDS DX,Path
     MOV AH,3Dh
     MOV AL,Mode.Byte[0]
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     POP DS
     JNC  @@1
     MOV GSintLastError,AX { save error code in global variable }
     MOV AX,-1
   @@1:
     MOV Handle, AX
   end;
   GSFileOpen := Handle;
   FreeMem(Path,81);
end;

Function GSFileCreate(const FileName : String): integer;
var
   Path: PChar;
   Handle: integer;
begin
   GSintLastError := 0;
   GetMem(Path,81);
   StrPCopy(Path,FileName);
   Asm
     PUSH DS
     LDS DX,Path
     MOV AH,3Ch
     XOR CX,CX
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     POP DS
     JNC  @@1
     MOV GSintLastError,AX { save error code in global variable }
     MOV AX,-1
   @@1:
     MOV Handle, AX
   end;
   GSFileCreate := Handle;
   FreeMem(Path,81);
end;

Function GSFileDelete(const FileName : String): integer;   {!!RFG 091397}
var
   Path: PChar;
   Rsl: integer;
begin
   GetMem(Path,81);
   StrPCopy(Path,FileName);
   Asm
     PUSH DS
     LDS DX,Path
     MOV AH,41h
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     POP DS
     JNC  @@1
     MOV AX,-1
   @@1:
     MOV Rsl, AX
   end;
   if Rsl <> -1 then Rsl := 0;
   GSFileDelete :=  Rsl;
   FreeMem(Path,81);
end;


Function GSFileRead(Handle: Integer; var Buffer; Count: Longint): Longint;
var
   bread: word;
begin
   GSintLastError := 0;
   Asm
     PUSH DS
     LDS DX,Buffer
     MOV CX,Count.Word[0]
     MOV BX,Handle
     MOV AH,3Fh
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     POP DS
     JNC @@1
     MOV GSintLastError,AX { save error code in global variable }
     MOV AX,0
   @@1:
     MOV bread,AX
   end;
   if GSintLastError = 0 then
      GSFileRead := bread
   else
      GSFileRead := -1;
end;

Function GSFileWrite(Handle: Integer; var Buffer; Count: Longint): Longint;
var
   bwrit: word;
begin
   GSintLastError := 0;
   Asm
     PUSH DS
     LDS DX,Buffer
     MOV CX,Count.Word[0]
     MOV BX,Handle
     MOV AH,40h
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     POP DS
     JNC @@1
     MOV GSintLastError,AX { save error code in global variable }
     MOV AX,0
   @@1:
     MOV bwrit,AX
   end;
   if GSintLastError = 0 then
      GSFileWrite := bwrit
   else
      GSFileWrite := -1;
end;

Procedure GSFileClose(Handle: integer);
begin
   GSintLastError := 0;
   Asm
     MOV AH,3Eh
     MOV BX,Handle
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     JNC  @@1
     MOV GSintLastError,AX { save error code in global variable }
   @@1:
   end;
end;

Function GSFileSeek(Handle: Integer; Delta: Longint;
                                     Origin: Integer): Longint;
var
   cloc: GSrecLongint;
begin
   GSintLastError := 0;
   Asm
     MOV CX,Delta.Word[2]
     MOV DX,Delta.Word[0]
     MOV BX,Handle
     MOV AX,Origin
     MOV AH,42h
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     JNC @@1
     MOV GSintLastError,AX { save error code in global variable }
   @@1:
     MOV cloc.Lo,AX
     MOV cloc.Hi,DX
   end;
   if GSintLastError = 0 then
      GSFileSeek := cloc.All
   else
      GSFileSeek := -1;
End;

Function GSFileTruncate(Handle: integer; Offset: longint): boolean;
var
   cloc: longint;
begin
   GSintLastError := 0;
   cloc := GSFileSeek(Handle, Offset, 0);
   if cloc <> -1 then
      cloc := GSFileWrite(Handle,cloc,0)
   else
      GSFileTruncate := false;
End;



Function GSGetFAttr(const FileName : String) : integer;  {!!RFG 091297}
var
  Attrib: integer;
  FileNameBuf: array[0..80] of char;
begin
   StrPCopy(FileNameBuf, FileName);
   asm
        PUSH    DS
        PUSH    SS
        POP     DS
        LEA     DX,FileNameBuf
        MOV     AX,4300H
        {$IFDEF PROTECTEDMODE}
        Call  DOS3Call  { Call DOS ...               }
        {$ELSE}
        INT   $21
        {$ENDIF}
        POP     DS
        JNC     @@1
        NEG     AX
        JMP     @@2
   @@1: XCHG    AX,CX
   @@2: MOV     Attrib,AX
   end;

   if Attrib < 0 then
   begin
      Attrib := -1;
   end;
   GSGetFAttr := Attrib;
end;

Function GSGetFTime(Handle: integer) : longint;
var
   fdttm: GSrecLongint;
begin
   GSintLastError := 0;
   Asm
     MOV BX,Handle
     MOV AX,5700h { read date and time }
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     JNC @@1
     MOV GSintLastError,AX { save error code in global variable }
     JMP @@2
   @@1:
     MOV fdttm.Lo,CX
     MOV fdttm.Hi,DX
   @@2:
   end;
   if GSintLastError = 0 then
      GSGetFTime := fdttm.All
   else
      GSGetFTime := -1;
end;


Function GSGetExpandedFile(const FileName: String): String;
   begin
     if (Pos('\\',Filename) <> 0) or (pos(':',FileName) > 2) then {!!RFG 091597}
       GSGetExpandedFile := FileName
     else
       GSGetExpandedFile := FExpand(FileName);
   end;

Procedure GSFileDateTime(Handle: integer;
                          var Year,Month,Day,Hour,Min,Sec: Word);
var
   dt : GSrecDateTime;
   ftime : longint;
begin
   ftime := GSGetFTime(Handle); { Get creation time }
   GSUnpackTime(ftime,dt);
   Year := dt.Year;
   Month := dt.Month;
   Day := dt.Day;
   Hour := dt.Hour;
   Min := dt.Min;
   Sec := dt.Sec;
end;

Function GSGetLastError: integer;
begin
   GSGetLastError := GSintLastError;
   GSintLastError := 0;
end;

Procedure GSSetLastError(Value: Integer);
begin
   GSintLastError := Value;
end;


procedure GSUnpackTime(P : longint; var T : GSrecDateTime);
   begin
      UnpackTime(P, DateTime(T));
   end;


function  GSGetPointer(P: Pointer; OSet: Longint): pointer;
type
   LongRec = record
      LoPart : word;
      HiPart : word;
   end;
var
   WkOSet: Longint;
   APtr: pointer;
begin
   WkOSet := LongRec(P).LoPart + OSet;
   APtr := Ptr(
      LongRec(P).HiPart + (LongRec(WkOSet).HiPart * SelectorInc),
      LongRec(WkOset).LoPart);
   GSGetPointer := APtr;
end;

{------------------------------------------------------------------------------
                              Global Routines
------------------------------------------------------------------------------}

   {These are needed in the Data Segment for DOS Real Mode}

      {$IFNDEF DPMI}
   var
      NewHandleTable: array[0..255] of byte;   { New table for handles }
      OldHandleTable: pointer;                 { Pointer to original table }
      OldNumHandles : byte;                    { Original number of handles }
      {$ENDIF}


Function GS_Flush(Hndl : longint): integer;
var
   w: word;
begin
   asm
      mov   AH,$68             {DOS function to duplicate a file handle}
      mov   BX,word(Hndl)
      {$IFDEF PROTECTEDMODE}
      Call  DOS3Call  { Call DOS ...               }
      {$ELSE}
      int   $21
      {$ENDIF}
      jc    @1                  { fail? }
      xor   AX,AX
   @1:
      mov   w,AX
   end;
   GS_Flush := w;
end;

Function GS_LockFile(Hndl,FilePosition,FileLength : LongInt) : integer;
var
  rsl : word;
begin
  ASM
      mov   AL,0      { subfunction 0: lock region   }
      mov   AH,$5C    { DOS function $5C: FLOCK    }
      mov   BX,word(Hndl)   { put FileHandle in BX       }
      mov   CX,FilePosition.WORD[2]    { Load Start Into  CX:DX. }
      mov   DX,FilePosition.WORD[0]
      mov   SI,FileLength.WORD[2]      { Load Len Into SI:DI.                  }
      mov   DI,FileLength.WORD[0]
      {$IFDEF PROTECTEDMODE}
      Call  DOS3Call  { Call DOS ...               }
      {$ELSE}
      int   $21
      {$ENDIF}
      jc    @Fin      { if error then return AX    }
      xor   AX,AX     { else return 0              }
  @Fin:
      mov   rsl,AX
  end;
   GS_LockFile := rsl;
end;

Function GS_UnLockFile(Hndl,FilePosition,FileLength : LongInt) : integer;
var
  rsl : word;
begin
  ASM
      mov   AL,1      { subfunction 1: Unlock region   }
      mov   AH,$5C    { DOS function $5C: FLOCK    }
      mov   BX,word(Hndl)   { put FileHandle in BX       }
      mov   CX,FilePosition.WORD[2]    { Load Start Into  CX:DX. }
      mov   DX,FilePosition.WORD[0]
      mov   SI,FileLength.WORD[2]      { Load Len Into SI:DI.                  }
      mov   DI,FileLength.WORD[0]
      {$IFDEF PROTECTEDMODE}
      Call  DOS3Call  { Call DOS ...               }
      {$ELSE}
      int   $21
      {$ENDIF}
      jc    @Fin      { if error then return AX    }
      xor   AX,AX     { else return 0              }
  @Fin:
      mov   rsl,AX
  end;
   GS_UnLockFile := rsl;
end;
   {$IFDEF DPMI}
   Function GS_ExtendHandles(HndlCount : byte) : boolean;
   begin
      GS_ExtendHandles := false;
      if HndlCount <= 20 then exit;
      asm
         mov   BH,0
         mov   BL,HndlCount
         mov   AH,67H
         Call  DOS3Call  { Call DOS ...               }
      end;
      GS_ExtendHandles := true;
   end;

   {$ELSE}  {DOS Real Mode}
   Function GS_ExtendHandles(HndlCount : byte) : boolean;
   var
      hcnt   : word;
      pfxcnt : pointer;
      pfxtbl : pointer;
   begin
      GS_ExtendHandles := false;
      if HndlCount <= 20 then exit;
      fillchar(NewHandleTable,sizeof(NewHandleTable),$FF);
                                   { Initialize new handles as unused }
      pfxcnt := Ptr(PrefixSeg, $0032);
      pfxtbl := Ptr(PrefixSeg, $0034);
       OldNumHandles := byte(pfxcnt^); { Get old table length }
      OldHandleTable := pointer(pfxtbl^);
                                       { Save address of old table }
      byte(pfxcnt^) := HndlCount;     { Set new table length }
      pointer(Pfxtbl^) := Addr(NewHandleTable);
                                       { Point to new handle table }
      move(OldHandleTable^,NewHandleTable,OldNumHandles);
         { Copy the current handle table to the new handle table }
      GS_ExtendHandles := true;
   end;
   {$ENDIF}

procedure WaitForKey;
begin
  asm
     mov   ah,$07
     {$IFDEF PROTECTEDMODE}
     Call  DOS3Call  { Call DOS ...               }
     {$ELSE}
     int   $21
     {$ENDIF}
     cmp   al,0
     jnz   @@1
     mov   ah,$07
     int   21h
  @@1:
  end;
end;

end.

