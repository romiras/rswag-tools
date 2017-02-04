{$M 34000, 0, 655000}
{$I GSOBOPTN.PAS}
PROGRAM Reader;

uses
   Reader_U;

BEGIN

   SetPublicVar;        {Initialize Variables}

   Rezip;

   CloseAll;

END.
