{---------------------------------------------------------------}
{      RSWAG-98 to RSWAG-99 Update                              }
{                written 2000 by Valery Votintsev 2:5021/22     }
{---------------------------------------------------------------}
{$M 64565, 0, 655000}
{$I GSF_FLAG.PAS}
PROGRAM rswag99;
uses
   CRT,
   gsf_shel,
   gsf_glbl,
   gsf_dos,
   vScreen,
   vMenu,
   vMemo,
   vString,
   Reader_C,
   Reader_U;

Const
  UpdateName:string[7] = 'RSWAG99';
           { Include Constant 'UpdateName' with name of new patch}
  UpdatePeriod: String[8] = '1999';

Var
   TargetArea:byte;
   AreaID: String[8];
   AreaDescr: string[52];
   MsgCounter:Integer;

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


{*────────────────────────────────────────────────────────────────────*}
Procedure WriteCONFIG;
{ Used ConfigFile }
Var
   Conf:Text;
   ConfigBak:  string;
   n:byte;
Begin

   Writeln('Updating Config file ...');
   n:=Pos('.',ConfigFile);
   ConFigBak:=Copy(ConfigFile,1,n)+'BAK';
   FileCopy(ConfigFile,ConfigBak);

   If not FileOpen(Conf,ConfigFile,fmOpenWrite) then begin
      writeln('*** Open error of "',ConfigFile,'"');
      HALT(1);
   end;

   Writeln(Conf,';------- RSWAG Reader Configure Parameters --------------------------');
   Writeln(Conf);
   Writeln(Conf,'[ Work Pathes ]');
   Writeln(Conf,'BaseDir    = ',BaseDir,   '  // Path to DataBases');
   Writeln(Conf,'ExtractDir = ',ExtractDir,'  // Extract Project Directory');
   Writeln(Conf,'ImportDir  = ',ImportDir, '  // Import File Directory');
   Writeln(Conf,'DocDir     =              // Document Directory');
   Writeln(Conf,'ListDir    = ',ListDir,   '  // Path to HTML Lists');
   Writeln(Conf);
   Writeln(Conf,'[ Area & Msg Parameters ]');
   Writeln(Conf,';AreaOrder  = 0          // Not Ordered Area List (default)');
   Writeln(Conf,';AreaOrder  = 1          // Order Area List by DESCRIPTION');
   Writeln(Conf,';AreaOrder  = 2          // Order Area List by AREAID');
   Writeln(Conf,'AreaOrder  = ',AreaOrder:1,'          // Order Area List by');
   Writeln(Conf,';MsgOrder   = 0          // Not Ordered Msg List (default)');
   Writeln(Conf,';MsgOrder   = 1          // Order Msg List by FROM');
   Writeln(Conf,';MsgOrder   = 2          // Order Msg List by SUBJECT');
   Writeln(Conf,'MsgOrder  = ',MsgOrder:1,'          // Order Msg List by');
   Writeln(Conf);
   Writeln(Conf,';------- RSWAG to HTML Converter Configure Parameters -----------------');
   Writeln(Conf,'AreaList     = AREAS.LST');
   Writeln(Conf,'AreaHeader   = AREA.HDR');
   Writeln(Conf,'AreaFooter   = AREA.FTR');
   Writeln(Conf,'AreaRecord   = AREA.REC');
   Writeln(Conf,'IndexHeader  = INDEX.HDR');
   Writeln(Conf,'IndexFooter  = INDEX.FTR');
   Writeln(Conf,'IndexRecord  = INDEX.REC');
   Writeln(Conf,'MsgHeader    = BODY.HDR');
   Writeln(Conf,'MsgFooter    = BODY.FTR');
   Writeln(Conf,'Snipets      = 25         // Snipets Per Page');
   Writeln(Conf);
   Writeln(Conf,'LastUpdate = ',Lastupdate,'    // Last updated by putch "PATCHNAME" (w/o .ext)');

   FileClose(Conf);
   Writeln(' Ok.');
end;



{*────────────────────────────────────────────────────────────────────*}
{var x,y:integer;}

BEGIN

   SetPublicVar('READER.INI');        {Initialize Variables}
   MsgCounter:=0;
   SetColor('W/N');

   Writeln('------------',UpdateName,'---------------');
   Writeln('Russian SWAG update of ',UpdatePeriod);
   Writeln('written 1999-2000 by Valery Votintsev ');
   Writeln('                      (2:5021/22)');
   Writeln;

   If CheckWorkPath then begin

      Writeln('Updating current RSWAG bases with "'+UpdateName+'"');

      If (not GsFileExists(UpdateName+'.dbf')) and
         (not GsFileExists(UpdateName+'.fpt')) then begin
         SetColor('W+/N');
         Write('Error: ');
         SetColor('W/N');
         Writeln('Update files "'+UpdateName+'.*" not found!');
      end else begin
         If (Upper(UpdateName)=Upper(LastUpdate)) then begin
            SetColor('W+/N');
            Write('Error: ');
            SetColor('W/N');
            Writeln('"',UpdateName,'" update allready used!');
         end else begin
            FileCopy(UpdateName+'.dbf',BaseDir+'\'+UpdateName+'.dbf');
            FileCopy(UpdateName+'.fpt',BaseDir+'\'+UpdateName+'.fpt');

            GsFileDelete(UpdateName+'.dbf');
            GsFileDelete(UpdateName+'.fpt');

            OpenMainBase(AreaBase,'AREAS');
            SetTagTo('AreaID');
            GoTop;

            OpenWorkBase(UpdateName,'NEW',DontAsk);
            GoTop;

            While not dEOF do begin   {Check All Records in 'WORK'}
               {Copy the Msg to Another Area}
               AreaID:=AllTrim(FieldGet('FILENAME'));
               AreaDescr:=FieldGet('AREA');

               Write('Adding to "',AreaID,'" ...');
{               x:=WhereX;
               y:=WhereY;
}
               OpenWorkBase(AreaID,'WORK',DontAsk);
               TargetArea:=CurrentArea;

               Select ('AREAS');
               Find(AreaID);
               If dEOF or (not FOUND) then begin
                  InsertRecord;
                  FieldPut('FILENAME',AreaID);
                  FieldPut('AREA',AreaDescr);
                  Replace;
               end;

               Select('NEW');
               Copy1Record(TargetArea);

               Select('WORK');
               FieldPut('NEW','T');  {Mark inserted record as NEW}
               Replace;

               Use('','',False);            {Close WORK database}

               Select('AREAS');
               UpdateMsgCounter(1);
               Inc(MsgCounter);

               Select('NEW');
               Skip(1);
               Writeln('ok.');
            end;

            Select('NEW');
            Use('','',False);  { Close Update DataBase }

            Select('AREAS');
            Use('','',False);  { Close Main DataBase }

            EraseFiles(UpdateName); {Erase Update Databases}

            LastUpdate:=UpdateName; {Change LastUpdate}
            WriteConfig;            {and rewrite config file}

            Writeln('Snipets added:',MsgCounter);
            Writeln('All done.');   {Repart about the finishing}
         end;
      end;
   end;
END.
