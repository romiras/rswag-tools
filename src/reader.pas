{$A+,B-,D+,E+,F-,G-,I+,L+,N-,O-,P-,Q-,R-,S+,T-,V+,X+,Y+}
{$M 16384,0,655360}
{----------------------------------------------------------}
{             Russian SWAG Msg Base Reader                 }
{                       v.4.1                              }
{      written 1993-2000 by Valery Votintsev 2:5021/22     }
{                          E-Mail: rswag AT sources.ru     }
{----------------------------------------------------------}
{$M 64565, 0, 655000}
{$I GSF_FLAG.PAS}
PROGRAM Reader;
uses
   Reader_C,
   Reader_U;
BEGIN
{   CheckKeys;}

   SetPublicVar('');                          {Initialize Variables      }

   DrawTitleScreen;                           {Draw RSWAG Title screen   }

   If CheckWorkPath then begin                {If work pathes exists then}

      OpenMainBase(AreaBase,'AREAS');             {Open Main (AREAS) base}
      ScanAreas;                                  {  and scan it         }

      Browse({AreaBase,RSWAG,}2,3,79,23,PickNewArea,False); {and browse it }

   end;

END.
