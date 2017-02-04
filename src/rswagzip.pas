{---------------------------------------------------}
{ Create Russian SWAG Snipets in PkZip Archive      }
{    written 2000 by Valery Votintsev 2:5021/22     }
{---------------------------------------------------}
{$M 64565, 0, 655000}
{$I GSF_FLAG.PAS}
PROGRAM RswagZip;
uses
   CRT,
   DOS,
   gsf_shel,
   gsf_glbl,
   gsf_dos,
   vScreen,
{   vMenu,}
   vMemo,
   vString,
   Reader_C,
   Reader_U;

Var
   F:Text;
   MsgCounter:Integer;

Procedure EraseFileByMask(const FilePath,FileMask:string80);
Var
  cFileName:String80;
  DirInfo:SearchRec;
  Slash:string[1];
begin
  If Right(FilePath,1)='\' then Slash:=''
                           else Slash:='\';
  FindFirst(FilePath+Slash+FileMask,Archive,DirInfo);
  While DosError = 0 do begin
    cFileName:=FilePath+Slash+DirInfo.Name;
    GsFileDelete(cFileName);
    FindNext(DirInfo);
  end;
end;

{-------------------------------------------------------------}
Procedure MakeArchives;
{Build the PkZip Archives for All the Snipets }
var
   project,
   fn,
   descr:string80;

   {--------------------------------}
   Procedure ZipCurrentSnipet;
   Var
     cZipFileName:string80;
     n:integer;
   begin
      Inc(MsgCounter);
      If FieldExists('PROJECT') then
         Project:=Lower(RTrim(FieldGet('PROJECT')))
      else
         Project:='';

      If Project = '' then begin
         Project:=IntToStr(MsgCounter);
         If FieldExists('PROJECT') then begin
            FieldPut('PROJECT',Project);  {Put the project name if empty}
            Replace;
         end;
      end;

     cZipFileName:=ListDir+fn+'\'+Project+'.zip';
     EraseFileByMask(ExtractDir,'*.*');

     ReadMemo('TEXT');
     Extract(DontAsk);    {Extract the snipet to EXTRACT Dir}
     {PkZip extracted to List Dir}
{     OpExec('pkzip.exe '+cZipFileName+' '+ExtractDir+'\*.*');}


SwapVectors;
Exec('c:\arc\pkzip.exe',cZipFileName+' '+ExtractDir+'\*.*');
SwapVectors;

end;



begin {Procedure MakeArchives;}

   If ListDir<>'' then
      If ListDir[Length(ListDir)] <> '\' then
         ListDir:=ListDir + '\';
   If not DirExists(ListDir+fn) then
      MakeDir(ListDir+fn);       {Create The "List" SubDirectory}

   {----------------------------------}
   { Form Project.Zip for each Snipet }
   {----------------------------------}
   Select('AREAS');
   GoTop;  {AREAS}

   While not dEOF do begin

      MsgCounter:=0;
      AreaID:=AllTRim(FieldGet('FILENAME')); {Get Area ID}
      fn:=Lower(AreaID);
{      AreaDescr:=RTrim(FieldGet('AREA'));    {Get Area Description}

      If AreaID <> '' then begin
         If not GsFileExists(BaseDir+'\'+fn+'.dbf') then
         else begin

{            cFileName:=ListDir+fn+'\index.htm';}

            If not DirExists(ListDir+fn) then
               MakeDir(ListDir+fn);       {Create The Category SubDirectory}

{ GsFileDelete(cFileName);}

            begin
               Write('Archiving the ',AreaID,' ... ');

               OpenWorkBase(AreaID,'WORK',DontAsk); {Open next Snipets Base}
               GoTop;  {WORK}

               While not dEOF do begin
                  ZipCurrentSnipet;
                  skip(1);
               end;
               Use('','',False);  { Close Current Snipets Base }

               Writeln('ok.');
            end;
         end;
      end;
      Select('AREAS');
      Skip(1);
   end;
   Writeln('All Done.');

end;



{*────────────────────────────────────────────────────────────────────*}

BEGIN

   SetPublicVar('READER.INI');        {Initialize Variables}

   MsgCounter:=0;
   SetColor('W/N');

   Writeln('-----------------------------------------');
   Writeln('      Russian SWAG Snipets Zipper');
   Writeln('written 1999-2000 by Valery Votintsev');
   Writeln('                      (2:5021/22)');
   Writeln('-----------------------------------------');

   If CheckWorkPath then begin            {If work pathes exists then}

      OpenMainBase(AreaBase,'AREAS');     {Open Main (AREAS) base}

      If ListDir<>'' then
         If not DirExists(ListDir) then
            MakeDir(ListDir);

      MakeArchives;

      Use('','',False);
   end;
end.
