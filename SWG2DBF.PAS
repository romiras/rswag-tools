Program SWG2DBF;
{$I GSF_FLAG.PAS}

Uses
   Dos,
   Reader_U,
   Reader_C,
   gsf_shel,
   gsf_dos,
   gsf_date,
   Swag,
   vString,
   vMEMO;
{   vDisk,
   vMenu,
   GSF_Shel,
   gsf_tool,
   gsf_date,
   vScreen,
   vKBd,
   CRT,
   GSF_DOS,}
   {,ZipUnit}


Var
   DirInfo: SearchRec;
   n:integer;

Procedure AddRswagSnipet;
{Add new record to RSWAG base}
begin
   Append;
   ClearRecord;

   FieldPut('FROM',HeaderBuf.Contrib);
{   FieldPut('ADDR','');}
   FieldPut('SUBJ',HeaderBuf.Subject);
   FieldPut('DATE',Date2Str(HeaderBuf.Date));
   n:=pos('.',HeaderBuf.FName);
   Byte(HeaderBuf.FName[0]):=Pred(n); {Strip the filename extension}

   FieldPut('PROJECT',Upper(HeaderBuf.FName));
   Today:=Gs_Date_Curr;            {Get Current Date}
   FieldPut('APDATE',DTOS(Today)); {Put Current Date to 'ApDate' field}
   Memo_Size:=HeaderBuf.OrigSize;
   WriteMemo('TEXT');
   Replace;
end;

{===============================================}
begin

  SetPublicVar('reader.ini');        {Initialize Variables}

  PackBuf:=Pointer(Memo_Pack);
  UnPackBuf:=Pointer(Memo);
{  DrawTitleScreen;     {Draw Title Screen   }

  If not CheckWorkPath then begin   {}
     Halt(1);                       {Error - work pathes not found}
  end else begin

      OpenMainBase(AreaBase,'AREAS');  {Open Main base}
{      ScanAreas;                       {Scan all the areas}

  end;

{  SwagPath:=FormSwagPath(SwagPath);}

  FindFirst(SwagDir+'*.swg',Archive,DirInfo);

  While DosError = 0 do begin {For Each ('*.swg')}
     SwgName:=RTrim(DirInfo.Name);
     n:=pos('.',SwgName);
     If n>0 then
        Byte(SwgName[0]):=Pred(n);

     OpenSwagFile(SwgName);         {Open SWAG file}
     {ReadSwagFooter;                {Read SWAG file Title}

     Select('AREAS');
     Find(SwgName);                    {Check this name present}
     If not Found then begin           {Check this name present}
        {Add new record to main base}
        Append;
        ClearRecord;
        FieldPut('FILENAME',SwgName);
        FieldPut('AREA',FooterBuf.Title);
        Replace;
     end;

     {Check the base of this name exists}
     If not gsFileExists(BaseDir+'\'+SwgName+'.dbf') then
        CreateWorkBase(BaseDir+'\'+SwgName); {Create the base if not exists}

     OpenWorkBase(SwgName,'WORK',False);  {Open Work base}

     While not SwagEof do begin

        ReadNextSwagSnipet;             {Read next SWAG snipet}

        AddRswagSnipet;             {Add new record to RSWAG}

     end;

     CloseSwagFile;
     Use('','',False);

     FindNext(DirInfo);  {Searc next SWG file}
  end;


    writeln('SwgSize=',SwgCounter,' SourceSize=',InCounter,
            ' ZipSize=',OutCounter);

end.
