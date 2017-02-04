unit gsf_Date;
{-----------------------------------------------------------------------------
                             Date Processor
       gsf_Date Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit handles date conversion.

       Acknowledgements:

       An astronomers' Julian day number is a calendar system which is useful
       over a very large span of time.  (January 1, 1988 A.D. is 2,447,162 in
       this system.)  The mathematics of these procedures originally restricted
       the valid range to March 1, 0000 through February 28, 4000.  The update
       by Carley Phillips changes the valid end date to December 31, 65535.

       The basic algorithms are based on those contained in the COLLECTED
       ALGORITHMS from Communications of the ACM, algorithm number 199,
       originally submitted by Robert G. Tantzen in the August, 1963 issue
       (Volume 6, Number 8).  Note that these algorithms do not take into
       account that years divisible by 4000 are NOT leap years.  Therefore the
       calculations are only valid until 02-28-4000.  These procedures were
       modified by Carley Phillips (76630,3312) to provide a mathematically
       valid range of 03-01-0000 through 12-31-65535.

       The main part of Tantzen's original algorithm depends on treating
       January and February as the last months of the preceding year.  Then,
       one can look at a series of four years (for example, 3-1-84 through
       2-29-88) in which the last day will be either the 1460th or the 1461st
       day depending on whether the 4-year series ended in a leap day.

       By assigning a longint julian date, computing differences between
       dates, adding days to an existing date, and other mathematical actions
       become much easier.

       Changes:

          18 Apr 96 - Added GSbytNextCentury variable in gsf_Glbl to allow
                      the programmer to determine a limit year that will
                      use the next century instead of the current century
                      when the actual century is unknown (e.g. 04/18/96).
                      Any year equal to or greater than GSbytNextCentury
                      will use the current centruy.  Any value lower will
                      use the next century.  Default is 0 (unused)

                      The variable was added because many routines for date
                      entry do not allow including the century as part of
                      the entry field.  Thus, as the year 2000 approaches,
                      there must be some method to resolve unknown century
                      issues.  While this method is limited, it does offer
                      a solution for the majority of potential problems.

                      For example;
                         if GSbytNextCentury = 5, then
                            04/18/04 would be treated as 18 April, 2004
                            04/18/05 would be treated as 18 April, 1905

                      This is used in GS_Date_CurCentury to return the
                      'correct' century when the century is unknown.

          010898 -    Added routine to automtatically set the correct date
                      format in Delphi.  This is based on the Windows date
                      format.

------------------------------------------------------------------------------}
{$I gsf_FLAG.PAS}
interface

Uses
   gsf_DOS,
   vString,
   gsf_Glbl;

{private}

type
   GS_Date_StrTyp  = String[10];
   GS_Date_ValTyp  = longint;
   GS_Date_CenTyp  = String[2];

const
   GS_Date_Empty:GS_Date_StrTyp = '  .  .  ';{constant for invalid Julian day}
   GS_Date_JulInv  =  -1;             {constant for invalid Julian day}
   GS_Date_JulMty  = 0;               {constant for blank julian entry}
   MonthNames:String[48] ='JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC ';
const
   GSblnUseCentury   : Boolean = false;
   GSbytNextCentury  : Byte = 0;
   GSsetDateType     : GSsetDateTypes = American;

Var
   Today: GS_Date_ValTyp;

function  GS_Date_CurCentury(yr: integer) : GS_Date_CenTyp;
function  GS_Date_Curr : GS_Date_ValTyp;
function  GS_Date_DBLoad(sdate: GS_Date_StrTyp): GS_Date_ValTyp;
function  GS_Date_DBStor(nv : GS_Date_ValTyp) : GS_Date_StrTyp;
function  GS_Date_View(nv: GS_Date_ValTyp): GS_Date_StrTyp;
function  GS_Date_Juln(sdate : GS_Date_StrTyp) : GS_Date_ValTyp;
function  GS_Date_MDY2Jul(month, day, year : word) : GS_Date_ValTyp;
procedure GS_Date_Jul2MDY(jul : GS_Date_ValTyp; var month, day, year  : word);
function  DateStrOk (cDate:Gs_Date_StrTyp) : boolean;
Function  CNMONTH(Line:Gs_Date_StrTyp):Gs_Date_StrTyp;
Function  ParseDateStr(S:String):Gs_Date_StrTyp;


implementation

const
   JulianConstant =  1721119;  {constant for Julian day for 02-28-0000}
   JulianMin      =  1721120;  {constant for Julian day for 03-01-0000}
   JulianMax      =  25657575; {constant for Julian day for 12-31-65535}

type
   Str4 = String[4];

{*──────────────────────────────────────────*}
Function CNMONTH(Line:Gs_Date_StrTyp):Gs_Date_StrTyp;
{--- Convert Month Name to Month Number }
Var
  n,e:integer;
  S:Gs_Date_StrTyp;
begin
   n:=(Pos(UPPER(Line),MonthNames) div 4) + 1;
   Str(n:2,S);
   If S[1]=' ' then S[1]:='0';
   CNMONTH:=S;
end;

{*──────────────────────────────────────────*}
Function ParseDateStr(S:String):Gs_Date_StrTyp;
{--- Parse Date String & Form DB Date Field }
Var
   n:integer;
   cDay,cMonth,cYear:String[4];
begin
   S := AllTrim(S);

   n := AT(', ',S);  {Strip the Day of Week}
   If n = 4 then S:=Substr(S,n+2,255);

   cDay  := Substr(S,1,2);
   cMonth:= CnMonth(Substr(S,4,3));
   cYear := Substr(S,8,4);

   n := AT(' ',cYear);  {Check Year for 2 or 4 digits}
   If n > 0 then cYear:=Substr(cYear,1,n-1);

   If Length(cYear)=2 then begin
      If cYear[1]>'5' then
         cYear:= '19'+cYear
      else
         cYear:= '20'+cYear;
   end;

   ParseDateStr:=cYear+cMonth+cDay;
end;





{*──────────────────────────────────────────*}
function DateType_MDY(mm, dd, yy: Str4): GS_Date_StrTyp;
var
   ss  : String[10];
begin
   case GSsetDateType of
      American,
      MDY         : ss := '  /  /    ';
      USA         : ss := '  -  -    ';
   end;
   if not GSblnUseCentury then Delete(ss,9,2);
   if mm <> '' then
   begin
      move(mm[1],ss[1],2);
      move(dd[1],ss[4],2);
      if GSblnUseCentury then
         move(yy[1],ss[7],4)
      else
         move(yy[3],ss[7],2);
   end;
   DateType_MDY := ss;
end;

function DateType_DMY(mm, dd, yy: Str4): GS_Date_StrTyp;
var
   ss  : String[10];
begin
   case GSsetDateType of
      British,
      French,
      DMY         : ss := '  /  /    ';
      German      : ss := '  .  .    ';
      Italian     : ss := '  -  -    ';
   end;
   if not GSblnUseCentury then Delete(ss,9,2);
   if mm <> '' then
   begin
      move(dd[1],ss[1],2);
      move(mm[1],ss[4],2);
      if GSblnUseCentury then
         move(yy[1],ss[7],4)
      else
         move(yy[3],ss[7],2);
   end;
   DateType_DMY := ss;
end;

function DateType_YMD(mm, dd, yy: Str4): GS_Date_StrTyp;
var
   ss  : String[10];
begin
   case GSsetDateType of
      Japan,
      YMD         : ss := '    /  /  ';
      ANSI        : ss := '    .  .  ';
   end;
   if not GSblnUseCentury then system.Delete(ss,1,2);
   if mm <> '' then
   begin
      if GSblnUseCentury then
      begin
         move(yy[1],ss[1],4);
         move(mm[1],ss[6],2);
         move(dd[1],ss[9],2);
      end
      else
      begin
         move(yy[3],ss[1],2);
         move(mm[1],ss[4],2);
         move(dd[1],ss[7],2);
      end;
   end;
   DateType_YMD := ss;
end;

function LeapYearTrue (year : word)  : boolean;
begin
   LeapYearTrue := false;
   if (year mod 4 = 0) then
      if (year mod 100 <> 0) or (year mod 400 = 0) then
         if (year mod 4000 <> 0) then
            LeapYearTrue :=  true;
end;

function DateOk (month, day, year  : word) : boolean;
var
   daz : integer;
begin
   if (day <> 0) and
      ((month > 0) and (month < 13)) and
      ((year <> 0) or (month > 2)) then
   begin
      case month of
         2  : begin
                 daz := 28;
                 if (LeapYearTrue(year)) then inc(daz);
              end;
         4,
         6,
         9,
         11 : daz := 30;
         else  daz := 31;
      end;
      DateOk := day <= daz;
   end
   else DateOk := false;
end;

function DateStrOk (cDate:Gs_Date_StrTyp) : boolean;
var
   rsl:integer;
   month, day, year  : word;
   s:string[4];
begin
   If cDate = GS_Date_Empty then DateStrOk := True
   else begin
      s:=System.copy(cDate,1,2);
      val(s,day,rsl);

      s:=System.copy(cDate,4,2);
      val(s,month,rsl);
   {   If GSblnUseCentury then
         s:=System.copy(cDate,7,4)
      else}
      s:=System.copy(cDate,7,2);
      val(s,year,rsl);
      s:= GS_Date_CurCentury(year) + s;
      val(s,year,rsl);

      DateStrOk := DateOk(month, day, year);
   end;
end;

function GS_Date_MDY2Jul(month, day, year : word) : GS_Date_ValTyp;
var
   wmm,
   wyy,
   jul  : longint;
begin
   wyy := year;
   if (month > 2) then wmm  := month - 3
      else
      begin
         wmm := month + 9;
         dec(wyy);
      end;
   jul := (wyy div 4000) * 1460969;
   wyy := (wyy mod 4000);
   jul := jul +
            (((wyy div 100) * 146097) div 4) +
            (((wyy mod 100) * 1461) div 4) +
            (((153 * wmm) + 2) div 5) +
            day +
            JulianConstant;
   if (jul < JulianMin) or (JulianMax < jul) then
      jul := GS_Date_JulInv;
   GS_Date_MDY2Jul := jul;
end;

procedure GS_Date_Jul2MDY(jul : GS_Date_ValTyp; var month, day, year  : word);
var
   tmp1 : longint;
   tmp2 : longint;
begin
   if (JulianMin <= jul) and (jul <= JulianMax) then
      begin
         tmp1  := jul - JulianConstant; {will be at least 1}
         year  := ((tmp1-1) div 1460969) * 4000;
         tmp1  := ((tmp1-1) mod 1460969) + 1;
         tmp1  := (4 * tmp1) - 1;
         tmp2  := (4 * ((tmp1 mod 146097) div 4)) + 3;
         year  := (100 * (tmp1 div 146097)) + (tmp2 div 1461) + year;
         tmp1  := (5 * (((tmp2 mod 1461) + 4) div 4)) - 3;
         month :=   tmp1 div 153;
         day   := ((tmp1 mod 153) + 5) div 5;
         if (month < 10) then
            month  := month + 3
         else
            begin
               month  := month - 9;
               year := year + 1;
            end {else}
      end {if}
   else
      begin
         month := 0;
         day   := 0;
         year  := 0;
      end; {else}
end;

function  GS_Date_CurCentury(yr: integer) : GS_Date_CenTyp;
Var
  month, day, year : word;
  cw : word;
  tc: GS_Date_CenTyp;
begin
   gsGetDate(year,month,day,cw);
   day  := year mod 100;
   year := year div 100;
   if (yr  <  GSbytNextCentury) and
      (day >= GSbytNextCentury) then inc(year);  {Use next century if under limit}
   Str(year:2, tc);
   GS_Date_CurCentury := tc;
end;

function GS_Date_Curr : GS_Date_ValTyp;
Var
  month, day, year : word;
  cw : word;
begin
   gsGetDate(year,month,day,cw);
   GS_Date_Curr := GS_Date_MDY2Jul(month, day, year);
end;

function GS_Date_DBStor(nv : GS_Date_ValTyp) : GS_Date_StrTyp;
var
   mm,
   dd,
   yy  : word;
   ss  : String[8];
   sg  : String[4];
   i   : integer;
begin
   ss := '        ';
   if nv > 0 then
   begin
      GS_Date_Jul2MDY(nv,mm,dd,yy);
      str(mm:2,sg);
      move(sg[1],ss[5],2);
      str(dd:2,sg);
      move(sg[1],ss[7],2);
      str(yy:4,sg);
      move(sg[1],ss[1],4);
      for i := 1 to 8 do if ss[i] = ' ' then ss[i] := '0';
   end;
   GS_Date_DBStor := ss;
end;

function GS_Date_View(nv: GS_Date_ValTyp): GS_Date_StrTyp;
var
   mm,
   dd,
   yy  : word;
   ss  : String[10];
   sg1,
   sg2,
   sg3 : String[4];
   i   : integer;
begin
   if nv > GS_Date_JulInv then begin
      GS_Date_Jul2MDY(nv,mm,dd,yy);
      if mm = 0 then sg1 := ''
      else begin
         str(mm:2,sg1);
         str(dd:2,sg2);
         str(yy:4,sg3);
      end;
   end
   else sg1 := '';

   case GSsetDateType of
   American,
   USA,
   MDY          : ss := DateType_MDY(sg1,sg2,sg3);

   British,
   French,
   German,
   Italian,
   DMY          : ss := DateType_DMY(sg1,sg2,sg3);

   ANSI,
   Japan,
   YMD         : ss := DateType_YMD(sg1,sg2,sg3);
   end;

   if sg1 <> '' then
      for i := 1 to length(ss) do
         if ss[i] = ' ' then ss[i] := '0';
   GS_Date_View := ss;
end;

function GS_Date_Juln(sdate: GS_Date_StrTyp): GS_Date_ValTyp;
var
   t      : GS_Date_StrTyp;
   yy,
   mm,
   dd     : Str4;
   mmn,
   ddn,
   yyn    : word;
   i      : integer;
   e      : integer;
   rsl    : integer;
   okDate : boolean;
   co     : longint;

   function StripDate(var sleft: GS_Date_StrTyp): Str4;
   var
      ss1 : integer;
   begin
      ss1 := 1;
      while (ss1 <= length(sleft)) and (sleft[ss1] in ['0'..'9']) do inc(ss1);
      StripDate := system.copy(sleft,1,pred(ss1));
      system.delete(sleft,1,ss1);
   end;

begin
   ddn := 0;
   yyn := 0;
   mm:= '';
   dd := '';
   yy := '';
   t := sdate;
   rsl := 0;
   e := 0;
   for i := length(t) downto 1 do
   begin
      if t[i] < '0' then rsl := i;
      if not (t[i] in [' ','/','-','.']) then e := i;
   end;
   if e = 0 then
   begin
      GS_Date_Juln := GS_Date_JulMty;
      exit;
   end;
   if rsl = 0 then
   begin
      mm := system.copy(t,5,2);
      dd := system.copy(t,7,2);
      yy := system.copy(t,1,4);
   end
   else
   begin
      case GSsetDateType of
         American,
         USA,
         MDY          : begin
                           mm := StripDate(t);
                           dd := StripDate(t);
                           yy := StripDate(t);
                        end;
         British,
         French,
         German,
         Italian,
         DMY          : begin
                           dd := StripDate(t);
                           mm := StripDate(t);
                           yy := StripDate(t);
                        end;
         ANSI,
         Japan,
         YMD         : begin
                           yy := StripDate(t);
                           mm := StripDate(t);
                           dd := StripDate(t);
                        end;
      end;
      if length(yy) < 3 then   {Get Century}
      begin
         val(yy,yyn,rsl);
         if rsl = 0 then
            yy := GS_Date_CurCentury(yyn)+yy;
      end;
   end;
   okDate := false;
   val(mm,mmn,rsl);
   if rsl = 0 then
   begin
      val(dd,ddn,rsl);
      if rsl = 0 then
      begin
         val(yy,yyn,rsl);
         if rsl = 0 then
         begin
            if DateOk(mmn,ddn,yyn) then okDate := true;
         end;
      end;
   end;
   if not okDate then
      co := GS_Date_JulInv
   else
   begin
      co := GS_Date_MDY2Jul(mmn, ddn, yyn);
   end;
   GS_Date_Juln := co;
end;

function GS_Date_DBLoad(sdate: GS_Date_StrTyp): GS_Date_ValTyp;
var
   yy,
   mm,
   dd     : Str4;
   mmn,
   ddn,
   yyn    : word;
   rsl    : integer;
   okDate : boolean;
   co     : longint;

begin
   ddn := 0;
   yyn := 0;
   mm := system.copy(sdate,5,2);
   dd := system.copy(sdate,7,2);
   yy := system.copy(sdate,1,4);
   okDate := false;
   val(mm,mmn,rsl);
   if rsl = 0 then
   begin
      val(dd,ddn,rsl);
      if rsl = 0 then
      begin
         val(yy,yyn,rsl);
         if rsl = 0 then
         begin
            if DateOk(mmn,ddn,yyn) then okDate := true;
         end;
      end;
   end;
   if not okDate then
      co := GS_Date_JulInv
   else
   begin
      co := GS_Date_MDY2Jul(mmn, ddn, yyn);
   end;
   GS_Date_DBLoad := co;
end;


begin
   Today:=Gs_Date_Curr;            {Get Current Date}

end.
