unit gsf_Expr;
{-----------------------------------------------------------------------------
                          Basic Expression Resolver

       gsf_Expr Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit evaluates database expressions and returns the result.

   Changes:

     !!RFG 090297 Corrected error in SubStr function that caused it to
                  reject if the last string position was used as the start
                  position.
     !!RFG 082397 Added .NOT.DELETED as another function to be tested.
     !!RFG 101497 Fixed CompressExpression to allow a space between the
                  '!,=,<,> operators.
     !!RFG 103197 Fixed problem in DTOC and DTOS functions so that empty
                  dates for MDX and NDX indexes are properly handled.  This
                  was a problem because empty dates for these indexes are
                  assigned 1E00 as a value.
     !!RFG 111897 Added STRZERO function to the list of those handled.
     !!RFG 111897 Changed ResolveFieldValue to use calls to retrieve the
                  field data rather than directly accessing the buffer.
                  This allows a single  access point to the buffer, which
                  means the location can be dynamically changed with no
                  impact on routines.  This is needed for better interface
                  with Delphi standard data-aware components.
     !!RFG 011498 Added ability to support logical fields in function
                  ResolveFieldValue.  It will return 'T' or 'F'.
     !!RFG 011498 Added ability to handle expressions surrounded by ().
     !!RFG 012198 Added ability to handle the '-' concatanation, where
                  the element is trimmed of trailing spaces and they are
                  added to the end of the key.  For example,
                     'LName-FName'
                  would trim LName, add FName, and pad the end of the
                  expression with the spaces that were trimmed to give the
                  correct expression length.

------------------------------------------------------------------------------}
{$I gsf_FLAG.PAS}
interface
uses
   Strings,
   gsf_Date,
   gsf_Eror,
   gsf_Indx,
   gsf_DBF,
   gsf_Glbl,
   vString,
   gsf_Xlat;

{private}

procedure CompressExpression(Exp: PChar);

function SolveExpression(pSrc: GSptrBaseObject; Who, Express, Rsl: PChar;
                           var Typ: char; var Chg: boolean): boolean;

implementation

const
   exFunctStrings = 'DTOCDTOSSUBSTRUPPERLEFTRIGHTRECNODATEEMPTYLOWER.NOT.DELETEDSTRZERO';
   exDATE     = 34;
   exEMPTY    = 38;
   exNOACTN   = 0;
   exDTOC     = 1;
   exDTOS     = 5;
   exSUBSTR   = 9;
   exSTR      = 12;
   exUPPER    = 15;
   exLower    = 43;
   exLEFT     = 20;
   exRIGHT    = 24;
   exNOTDELETED = 48;                        {!!RFG 082397}
   exDELETED  = 53;
   exRECNO    = 29;
   exSTRZERO  = 60;

Procedure FoundExpError(DB: GSP_dBaseFld; Code, Info:integer; StP: PChar);
begin
   if DB <> nil then
      DB^.FoundError(Code,Info,StP)
   else
      FoundPgmError(Code,Info,StP);
end;

procedure CompressExpression(Exp: PChar);
var
   i: integer;
   j: integer;
   b: boolean;
   op: boolean;
   v1: char;                          {!!RFG 101497}
begin
   if Exp = nil then exit;
   if StrLen(Exp) = 0 then exit;
   b := true;
   op := false;
   j := 0;
   for i := 0 to pred(StrLen(Exp)) do
   begin
      if Exp[i] in [#34,#39] then b := not b;
      v1 := Exp[i];                                         {!!RFG 101497}
      if b then                                             {!!RFG 101497}
      begin                                                 {!!RFG 101497}
         if (v1 in ['!','=','<','>']) then                  {!!RFG 101497}
         begin                                              {!!RFG 101497}
            if not op then                                  {!!RFG 101497}
               if (Exp[j] = ' ') and (j > 0) then inc(j);   {!!RFG 101497}
            op := true;                                     {!!RFG 101497}
         end                                                {!!RFG 101497}
         else                                               {!!RFG 101497}
         begin                                              {!!RFG 101497}
            if op then v1 := '.';                           {!!RFG 101497}
            op := false;                                    {!!RFG 101497}
         end;                                               {!!RFG 101497}
      end;                                                  {!!RFG 101497}
      Exp[j] := Exp[i];                                     {!!RFG 101497}
      if (not b) or (v1 <> ' ') then inc(j);                {!!RFG 101497}
   end;
   Exp[j] := #0;
end;


function ResolveElement(DB: GSP_dBaseFld; TG: GSptrIndexTag;
                        var Exp, Rsl: PChar;
                        var Typ: char; var Chg: boolean): boolean; forward;


function ResolveFunction(DB: GSP_dBaseFld; TG: GSptrIndexTag;
                         ExpFn, Exp: PChar; var Rsl: PChar;
                         var Typ: Char; var Chg: boolean): boolean;
var
   i: integer;
   j: integer;
   V1: longint;
   V2: longint;
   JD: longint;
   Ck: integer;
   FnAry: array[0..31] of char;
   fn: integer;
   FnTyp: char;
   FnOk: boolean;
   FnRsl: PChar;
   FnRslKp: PChar;
   FnRslWk: PChar;
   FnArgs: integer;
   FnFloat: FloatNum;
begin
   if StrLen(ExpFn) = 0 then
   begin
      ResolveFunction := true;
      exit;
   end;
   ResolveFunction := false;
   fn := StrLen(Exp);
   FnArgs := 1;
   V1 := 0;
   V2 := 0;
   j := 0;
   for i := 0 to pred(fn) do
   begin
      if (Exp[i] = ',') and (j = 0) then
      begin
         inc(FnArgs);
         Exp[i] := #0;
      end;
      if Exp[i] = '(' then inc(j);
      if Exp[i] = ')' then dec(j);
   end;
   if FnArgs > 1 then
   begin
      FnRslWk := StrEnd(Exp) + 1;
      val(FnRslWk,V1,Ck);
      if Ck <> 0 then
         FoundExpError(DB, gsBadFormula,inxResolveElement,FnRslWk)
      else
         if FnArgs > 2 then
         begin
            FnRslWk := StrEnd(FnRslWk) + 1;
            val(FnRslWk,V2,Ck);
            if Ck <> 0 then
               FoundExpError(DB, gsBadFormula,inxResolveElement,FnRslWk);
         end;
   end;
   fn := pos(StrPas(ExpFn),exFunctStrings);
   if fn = 0 then exit;
   FnTyp := #0;
   FnOk := false;
   GetMem(FnRslKp,256);
   FillChar(FnRslKp[0],256,#0);
   FnRsl := FnRslKp;
   FnRslWk := FnRslKp;
   case fn of
      exDTOC,
      exDTOS,
      exEMPTY,
      exSUBSTR,
      exSTR,
      exSTRZERO,                                                       {!!RFG 111897}
      exUPPER,
      exLOWER,
      exLEFT,
      exRIGHT     : begin
                       repeat
                          FnRsl := StrEnd(FnRslKp);
                          if Exp[0] = '+' then inc(Exp);
                       until not ResolveElement(DB, TG, Exp, FnRsl, FnTyp, Chg);
                       FnOk := StrLen(FnRslKp) > 0;
                    end;
      exDATE,
      exNOTDELETED,
      exDELETED,
      exRECNO     : FnOk := true;
   end;
   if FnOk then
   begin
      case fn of
         exDATE     : begin
                         FnTyp := 'D';
                         Chg := true;  {assume new date value}
                         V1 := GS_Date_Curr;
                         StrPCopy(FnRslWk,GS_Date_DBStor(V1));
                      end;
         exDTOC     : begin
                         if FnTyp = 'D' then
                         begin
                            Val(FnRslWk,JD,Ck);
                            if Ck <> 0 then JD := 0;                   {!!RFG 103197}
                            if V1 <> 1 then                            {!!RFG 103197}
                               StrPCopy(FnRslWk, GS_Date_View(JD))     {!!RFG 103197}
                            else                                       {!!RFG 103197}
                               StrPCopy(FnRslWk, GS_Date_DBStor(JD));  {!!RFG 103197}
                         end;                                          {!!RFG 103197}
                         FnTyp := 'C';
                      end;
         exDTOS     : begin
                         if FnTyp = 'D' then
                         begin
                            Val(FnRslWk,JD,Ck);
                            if Ck <> 0 then JD := 0;                   {!!RFG 103197}
                            StrPCopy(FnRslWk, GS_Date_DBStor(JD));     {!!RFG 103197}
                         end;
                         FnTyp := 'C';
                      end;
         exEMPTY    : begin
                         FnTyp := 'L';
                         FnRslWk[1] := #0;
                         if FnRslWk[0] = #0 then
                            FnRslWk[0] := 'T'
                         else
                            FnRslWk[0] := 'F';
                      end;
         exSUBSTR   : begin
                         if (V1 > 0) and (V1 <= Strlen(FnRslKp)) then {!!RFG 090297}
                         begin
                            FnRslWk := FnRslWk+pred(V1);
                            if (V2 > 0) then
                            begin
                               if V2 < StrLen(FnRslWk) then
                                  FnRslWk[V2] := #0;
                            end;
                         end;
                      end;
         exSTRZERO,                                                    {!!RFG 111897}
         exSTR      : begin
                         FnTyp := 'C';
                         if (FnArgs = 1) and (TG <> nil) then
                         begin
                            V1 := TG^.DefaultLen;
                            if V1 > 0 then
                               inc(FnArgs);
                         end;
                         if FnArgs > 1 then
                         begin
                            if FnArgs < 3 then
                            begin
                               FnRslWk := StrPos(FnRslKp,'.');
                               if FnRslWk = nil then
                                  V2 := 0
                               else
                                  V2 := pred(StrEnd(FnRslKp) - FnRslWk);
                            end;
                            StrTrimR(FnRslKp);
                            if StrLen(FnRslKp) > 0 then
                               val(FnRslKp,FnFloat,Ck)
                            else
                            begin     {A blank field}
                               Ck := 0;
                               FnFloat := 0.0;
                            end;
                            if (Ck <> 0) or (V1 > 31) then
                               FoundExpError(DB,gsBadFormula,inxResolveElement,FnRslKp)
                            else
                            begin
                               Str(FnFloat:V1:V2,FnAry);
                               StrCopy(FnRslKp,FnAry);
                            end;
                            FnRslWk := FnRslKp;
                         end;
                         if fn = exSTRZERO then                        {!!RFG 111897}
                         begin                                         {!!RFG 111897}
                            i := 0;                                    {!!RFG 111897}
                            while FnRslWk[i] = ' ' do                  {!!RFG 111897}
                            begin                                      {!!RFG 111897}
                               FnRslWk[i] := '0';                      {!!RFG 111897}
                               inc(i);                                 {!!RFG 111897}
                            end;                                       {!!RFG 111897}
                         end;                                          {!!RFG 111897}
                      end;
         exUPPER    : begin
                         CaseOEMPChar(FnRslWk, pCtyUpperCase, StrLen(FnRslWk));
                      end;
         exLOWER    : begin
                         CaseOEMPChar(FnRslWk, pCtyLowerCase, StrLen(FnRslWk));
                      end;
         exLEFT     : begin
                         FnRslWk[V1] := #0;
                      end;
         exRIGHT    : begin
                         FnRslWk := FnRslKp + (StrLen(FnRslKp)-V1);
                      end;
         exNOTDELETED:  begin                 {!!RFG 082397}
                           FnTyp := 'L';
                           FnRslWk[1] := #0;
                           if DB^.gsDelFlag then
                              FnRslWk[0] := 'F'
                           else
                              FnRslWk[0] := 'T';
                        end;
         exDELETED  : begin
                         FnTyp := 'L';
                         FnRslWk[1] := #0;
                         if DB^.gsDelFlag then
                            FnRslWk[0] := 'T'
                         else
                            FnRslWk[0] := 'F';
                      end;
         exRECNO    : begin
                         FnTyp := 'N';
                         Str(DB^.RecNumber,FnAry);
                         StrCopy(FnRslWk,FnAry);
                      end;
      end;
   end;
   if Typ = #0 then
      Typ := FnTyp
   else
     Typ := 'C';
   StrCopy(Rsl, FnRslWk);
   FreeMem(FnRslKp,256);
   ResolveFunction := FnOk;
end;

function ResolveFieldValue(DB: GSP_dBaseFld; TG: GSptrIndexTag;
                           Exp: PChar; var Rsl: PChar;
                           var Typ: Char; var Chg: boolean): boolean;
var
   mtch : boolean;
   i    : integer;
   ix   : integer;
   d: integer;
   s: string;
   r: FloatNum;
   z: FloatNum;
   li: longint;
begin
   ix := DB^.NumFields;
   i := 1;
   mtch := false;
   while (i <= ix) and not mtch do
   begin
      if CmprOEMPChar(Exp,GSR_DBFField(DB^.Fields^[i]).dbFieldName,
                                                 pCtyUpperCase,d) = 0 then
         mtch := true
      else
         inc(i);
   end;
   if mtch then
   begin
      if (StrLen(Rsl) + DB^.gsFieldLength(i)) < 255 then
      begin
         case DB^.Fields^[i].dbFieldType of                             {!!RFG 111897}
            'D',                                                        {!!RFG 111897}
            'C' : s := DB^.gsFieldGetN(i);                              {!!RFG 111897}
            'L' : if DB^.gsLogicGetN(i) then                                {!!RFG 011498}
                     s := 'T'                                           {!!RFG 011498}
                  else                                                  {!!RFG 011498}
                     s := 'F';                                          {!!RFG 011498}
            'T' : begin
                     r := DB^.gsNumberGetN(i);
                     z := r / GSMSecsInDay;
                     li := trunc(z);
                     z := li;
                     li := li + GSTimeStampDiff;
                     r := r - (z * GSMSecsInDay);
                     r := r / GSMSecsInDay;
                     r := r + li;
                     str(r,s);
                  end;
            else                                                        {!!RFG 111897}
                begin                                                   {!!RFG 111897}
                   Str(DB^.gsNumberGetN(i):DB^.Fields^[i].dbFieldLgth:   {!!RFG 111897}
                                         DB^.Fields^[i].dbFieldDec, s); {!!RFG 111897}
                end;                                                    {!!RFG 111897}
         end;                                                           {!!RFG 111897}
         StrPCopy(Rsl,s);                                               {!!RFG 111897}
         if Typ = #0 then
         begin
            Typ := DB^.Fields^[i].dbFieldType;
            if Typ = 'L' then Typ := 'C';
         end
         else
            Typ := 'C';
         Chg := Chg or (DB^.CurRecChg^[i] > 0);
         if (TG <> nil) then
         begin
            if Typ = 'D' then
            begin
               TG^.JulDateStr(Rsl,Rsl,Typ);
            end;
         end;
      end
      else
         mtch := false;
   end;
   ResolveFieldValue := mtch;
end;

function ResolveElement(DB: GSP_dBaseFld; TG: GSptrIndexTag;
                        var Exp, Rsl: PChar;
                        var Typ: char; var Chg: boolean): boolean;
var
   ExpBgn: PChar;
   ExpFun: PChar;
   TTyp: char;
   ParendCount: integer;
begin
   ResolveElement := false;
   if Exp[0] = #0 then exit;
   while Exp[0] = '(' do                  {!!RFG 011498}
   begin                                  {!!RFG 011498}
      inc(Exp);                           {!!RFG 011498}
      ExpBgn := StrEnd(Exp);              {!!RFG 011498}
      dec(ExpBgn);                        {!!RFG 011498}
      if ExpBgn >= Exp then               {!!RFG 011498}
         if ExpBgn[0] = ')' then          {!!RFG 011498}
            ExpBgn[0] := #0;              {!!RFG 011498}
   end;                                   {!!RFG 011498}
   ExpBgn := Exp;
   while not (Exp[0] in [#0,'+','(','"','-',#39]) do inc(Exp);
   TTyp := Exp[0];
   if Exp[0] <> #0 then
   begin
      Exp[0] := #0;
      inc(Exp);
   end;
   case TTyp of
      '-',
      '+',
      #0   : begin
                if not ResolveFieldValue(DB, TG, ExpBgn, Rsl, Typ, Chg) then
                begin
                   FoundExpError(DB,gsBadFormula,inxResolveElement,ExpBgn);
                end
                else
                   ResolveElement := true;
             end;
      '('  : begin
                ExpFun := Exp;
                ParendCount := 1;
                while ParendCount > 0 do
                begin
                   if Exp[0] = '(' then inc(ParendCount)
                      else if Exp[0] = ')' then dec(ParendCount)
                         else if Exp[0] = #0 then ParendCount := -1;
                   if ParendCount > 0 then inc(Exp);
                end;
                if ParendCount = 0 then
                begin
                   Exp[0] := #0;
                   inc(Exp);
                   if not ResolveFunction(DB,TG,ExpBgn,ExpFun,Rsl,Typ,Chg) then
                   begin
                      FoundExpError(DB,gsBadFormula,inxResolveElement,ExpFun);
                   end
                   else
                      ResolveElement := true;
                end
                else
                begin
                   FoundExpError(DB,gsBadFormula,inxResolveElement,ExpBgn);
                end;
             end;
      #39,                                      {!!RFG 012198}
      '"'  : begin
                ExpBgn := Exp;
                ParendCount := 1;
                while ParendCount > 0 do
                begin
                   if Exp[0] = TTyp then dec(ParendCount);
                   if ParendCount > 0 then inc(Exp);
                end;
                if ParendCount = 0 then
                begin
                   Exp[0] := #0;
                   StrCopy(Rsl,ExpBgn);
                   ResolveElement := true;
                   Typ := 'C';
                   Chg := false;
                end
                else
                begin
                   FoundExpError(DB,gsBadFormula,inxResolveElement,ExpBgn);
                end;
             end;
   end;
end;

function SolveExpression(pSrc: GSptrBaseObject; Who, Express, Rsl: PChar;
                           var Typ: char; var Chg: boolean): boolean;
var
   Exp: PChar;
   ExpKp: PChar;
   ExpR: PChar;
   ExpRKp: PChar;
   ExpFini: PChar;
   ExpLast: PChar;
   Fnd: boolean;
   EndSpaces: integer;          {!!RFG 012198}
   EndPosn: integer;            {!!RFG 012198}
   Rslv: boolean;               {!!RFG 012198}
   ADB: GSP_dBaseFld;
   ATG: GSptrIndexTag;
begin
   ADB := nil;
   ATG := nil;
   if pSrc <> nil then
      if pSrc^.ObjType = gsObtIndexTag then
      begin
         ADB := GSptrIndexTag(pSrc)^.Owner^.Owner;
         ATG := GSptrIndexTag(pSrc);
      end
      else
         ADB := pointer(pSrc);
   if (Express = nil) or (Express[0] = #0) or (ADB = nil) then
   begin
      SolveExpression := true;
      Typ := 'C';
      StrCopy(Rsl,Who);
      while StrLen(Rsl) < 10 do StrCat(Rsl, ' ');
      Chg := false;
      exit;
   end;

   Fnd := ADB^.gsFormula(Who, Express, Rsl, Typ, Chg) <> -1;
   SolveExpression := Fnd;
   if not Fnd then
   begin
      GetMem(ExpKp,256);
      GetMem(ExpRKp,256);
      Exp := ExpKp;
      ExpR := ExpRKp;
      ExpLast := nil;
      FillChar(ExpKp[0],256,#0);
      FillChar(ExpRKp[0],256,#0);
      Typ := #0;
      Chg := false;
      EndSpaces := 0;
      StrCopy(Exp,Express);
      CompressExpression(Exp);
      StrUpperCase(Exp, StrLen(Exp));
      ExpFini := StrEnd(Exp);
      repeat
         while (Exp[0] in  [#0,'+','-']) and (Exp <> ExpFini) do
         begin
            if Exp[0] = '-' then
            begin
               if ExpLast <> nil then
               begin
                  EndPosn := StrLen(ExpLast);
                  Dec(EndPosn);
                  while (EndPosn >= 0) and (ExpLast[EndPosn] = #32) do
                  begin
                     ExpLast[EndPosn] := #0;
                     inc(EndSpaces);
                     dec(EndPosn);
                  end;
               end;
            end;
            inc(Exp);
         end;
         ExpR := StrEnd(ExpRKp);       {add to result}
         ExpLast := ExpR;
         Rslv := ResolveElement(ADB, ATG, Exp, ExpR, Typ, Chg);
      until not Rslv;
      SolveExpression := StrLen(ExpRKp) > 0;
      if EndSpaces > 0 then                           {!!RFG 012198}
      begin
         EndPosn := StrLen(ExprKp);
         while EndSpaces > 0 do                       {!!RFG 012198}
         begin
            ExprKp[EndPosn] := #32;
            inc(EndPosn);
            dec(EndSpaces);
         end;
         ExprKp[EndPosn] := #0;
      end;
      StrCopy(Rsl,ExpRKp);
      FreeMem(ExpKp,256);
      FreeMem(ExpRKp,256);
   end;
end;

end.
