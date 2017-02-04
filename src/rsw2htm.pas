{---------------------------------------------------}
{ Create Russian SWAG Snipets List in HTML Format   }
{    written 2000 by Valery Votintsev 2:5021/22     }
{                   E-Mail: rswag AT sources.ru     }
{ Usage:                                            }
{       RSW2HTM <area | * > [/A] [/B]               }
{                                                   }
{ where  <area> - List msgs for Area ID, f.e. GRAPH }
{        use * for all the areas                    }
{        /A    - Create All Area List (CATEGORY.HTM)}
{        /B    - Create HTM files for all Msg bodies}
{                in selected Area                   }
{---------------------------------------------------}
{$M 64565, 0, 655000}
{$I GSF_FLAG.PAS}
PROGRAM RSW2HTM;
uses
   CRT,
   Reader_C,
   Reader_U,
   gsf_dos,
   gsf_shel,
   vString,
   RswagHTM;

Procedure CheckListDir;
begin
   If ListDir<>'' then
     If not DirExists(ListDir) then
       MakeDir(ListDir);

(*   If ListDir<>'' then
    If ListDir[Length(ListDir)] <> '\' then
      ListDir:=ListDir + '\';
*)

end;


Procedure CheckParameters;
var
  i:integer;
  s:string;
begin
  ListOnly:='';
  NeedBody:=False;
  NeedSort:=False;
  NeedAreaList:=False;
  For i:=1 to ParamCount do begin
    s:=Upper(ParamStr(i));
    If s[1]='/' then begin
      case s[2] of
      'A': NeedAreaList:=True;
      'B': NeedBody:=True;
      'S': NeedSort:=True;
      end;
    end else begin
      ListOnly:=lower(s); {Get the single Base name for list}
                          { "*" for ALL the Bases}
    end;
  end;
end;

{*────────────────────────────────────────────────────────────────────*}

BEGIN

   SetPublicVar('RSW2HTM.INI');       {Initialize Variables}

   CheckListDir;                      {Create List Directory}

   CheckParameters;

   PrepareBuffers;

   TextAttr:=LightGray;
   Writeln('-----------------------------------------');
   Writeln('      Russian SWAG HTML Lister');
   Writeln('written 1999-2001 by Valery Votintsev');
   Writeln('                      (2:5021/22)');
   Writeln('-----------------------------------------');

   If CheckWorkPath then begin            {If work pathes exists then}
    If ListOnly = '' then
      Writeln('Nothing to do.')
    else begin
      OpenMainBase(AreaBase,'AREAS');     {Open Main (AREAS) base}

      AreaColl:= New(GSptrStringCollection, Create(100,32));
      ReadAreaList(AreaList);

      GetAreaCollection;

      If NeedAreaList then
        MakeAreaList;       {Make All Area List}

      MakeMsgList;        {Make Msg List for each area}

      Select('AREAS');
      Use('','',False);

      Dispose(AreaColl, Destroy);

      Writeln('All Done.');
    end;
   end;
   CloseBuffers;

end.
