{---------------------------------------------------------------}
{Convert old RSWAG-95 format Databases to New RSWAG-96 DataBases}
{                written 2000 by Valery Votintsev 2:5021/22     }
{---------------------------------------------------------------}
{$M 64565, 0, 655000}
{$I GSF_FLAG.PAS}
PROGRAM c95to96;
uses
   gsf_shel,
   gsf_dos,
   vScreen,
   vString,
   vMemo,
   Reader_C,
   Reader_U;

Var
   TargetArea:byte;
   fNew: string12;

Procedure EraseFiles(fName:string12);
begin
   If GsFileExists(BaseDir+'\'+fname+'.dbf') then begin
      GsFileDelete(BaseDir+'\'+fname+'.dbf');
      GsFileDelete(BaseDir+'\'+fname+'.cdx');
      GsFileDelete(BaseDir+'\'+fname+'.fpt');
   end;
end;

Procedure RenameFiles(fName,NewName:string12);
begin
   GsFileRename(BaseDir+'\'+fname+'.dbf',BaseDir+'\'+NewName+'.dbf');
   GsFileRename(BaseDir+'\'+fname+'.cdx',BaseDir+'\'+NewName+'.cdx');
   GsFileRename(BaseDir+'\'+fname+'.fpt',BaseDir+'\'+NewName+'.fpt');
end;

{-------------------------------------}
Procedure ConvertAllAreas;
Var
   n,m:longint;
   fn:string12;
begin
   GoTop;
   While not dEOF do begin
      fn:=AllTRim(FieldGet('FILENAME'));
      n:=0;
      If fn <> '' then begin
         If GsFileExists(BaseDir+'\'+fn+'.dbf') then begin
            Write('Converting "',fn,'.DBF" ... ');

            GsFileDelete(BaseDir+'\'+fn+'.cdx');
            OpenWorkBase(fn,'WORK',DontAsk);
            { Set Order To NONE }
            SetTagTo('');
            n:=RecCount;

            EraseFiles(fNew);

            OpenWorkBase(fnew,'NEW',DontAsk);
            TargetArea:=CurrentArea;
            { Set Order To NONE }
            SetTagTo('');

            Select ('WORK');
            GoTop;

            While not dEOF do begin   {Check All Records in 'WORK'}

               ReadMemo('TEXT');      {Read Old Memo-Field        }
               RemoveSoftCR;          {Remove SoftCR if exists    }
               ChangeCutters;         {Convert to new FileCutters }
               If MemoUpdated then    {Save MEMO if changed       }
                  WriteMemo('TEXT');

               {Copy the Msg to Another Area}
               Copy1Record(TargetArea);
               Skip(1);
            end;

            Select ('WORK');
            Use('','',False);  { Close 'WORK' DataBase }
            Select ('NEW');
            Use('','',False);  { Close 'NEW' DataBase }

            {Rename temporary DBF to it's real name}
            EraseFiles(fn);

            RenameFiles(fnew,fn);

            Writeln('ok.');

         end;
      end;

      Select('AREAS'{1});
      Skip(1);
   end;

end;


{**********************************************************************}
Procedure CopyMainRecord(TargetArea:integer);
Var
  tmpStr:String;
  OldArea : Integer;

BEGIN

   oldarea := DBFUsed;

   SelectArea(TargetArea);
   ClearRecord;
   Append;

   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('AREA');
     SelectArea(TargetArea);
     FieldPut('AREA',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('FILENAME');
     SelectArea(TargetArea);
     FieldPut('FILENAME',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('LASTREAD');
     SelectArea(TargetArea);
     FieldPut('LASTREAD',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   tmpStr:=FieldGet('LASTORDER');
     SelectArea(TargetArea);
     FieldPut('LASTORDER',tmpStr);
   {-----------------------}
   SelectArea(OldArea);
   If FieldExists('MSGCOUNT') then
      tmpStr:=FieldGet('MSGCOUNT')
   else
      tmpStr:='';
   SelectArea(TargetArea);
   If FieldExists('MSGCOUNT') then
      FieldPut('MSGCOUNT',tmpStr);

   DbfActive^.RecModified:=True;
   Replace;

   SelectArea(OldArea);
{   Go(RecNo);}

END;        { CopyMainRecord }





BEGIN

   SetColor('W/N');
   Writeln('------------ RSWAG DataBase Converter --------------------');
   Writeln('Converts All Old RSWAG-95 DataBases to New RSWAG-96 Format');
   Writeln('    written 16.07.2000 by Valery Votintsev (2:5021/22)');
   Writeln;

   SetPublicVar('READER.INI');        {Initialize Variables}

   fNew :='$$$$$$$$';

   If CheckWorkPath then begin

      SetColor('W/N');
      If Upper(LastUpdate) >= 'RSWAG96' then begin
         SetColor('W+/N');
         Write('Error: ');
         SetColor('W/N');
         Writeln('RSWAG Databases allready converted to RSWAG-96 format!');
      end else begin
         Write('Converting "'+AreaBase+'"...');

         EraseFiles(fNew);
         OpenMainBase(AreaBase,'AREAS');

         OpenMainBase('$$$$$$$$','NEW');
         TargetArea:=CurrentArea;

         Select ('AREAS');
         GoTop;
         While not dEOF do begin   {Check All Records in 'WORK'}
            {Copy the Msg to Another Area}
            CopyMainRecord(TargetArea);
            Skip(1);
         end;

         Select('AREAS');
         Use('','',False);  { Close Main DataBase }
         Select('NEW');
         Use('','',False);  { Close New Main DataBase }

         EraseFiles(AreaBase);
         RenameFiles(fNew,AreaBase);

         OpenMainBase(AreaBase,'AREAS');   { ReOpen Converted Main Base }
         Writeln('ok.');

         ConvertAllAreas;

         Select('AREAS');
         Use('','',False);  { Close NEW Main DataBase }

         Writeln('All Done.');
         Writeln('Start the READER.EXE now.');
      end;
   end;

END.
