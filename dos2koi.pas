program dostowin;
Uses DOS;

Const
Dos2KoiTable:Array[0..127] of char =
      {  0    1    2    3    4    5    6    7    8    9 }
{120} (                                        #$E1,#$E2,
{130}  #$F7,#$E7,#$E4,#$E5,#$F6,#$FA,#$E9,#$EA,#$EB,#$EC,
{140}  #$ED,#$EE,#$EF,#$F0,#$F2,#$F3,#$F4,#$F5,#$E6,#$E8,
{150}  #$E3,#$FE,#$FB,#$FD,#$FF,#$F9,#$F8,#$FC,#$E0,#$F1,
{160}  #$C1,#$C2,#$D7,#$C7,#$C4,#$C5,#$D6,#$DA,#$C9,#$CA,
{170}  #$CB,#$CC,#$CD,#$CE,#$CF,#$D0,#$90,#$91,#$92,#$81,
{180}  #$87,#$B2,#$B4,#$A7,#$A6,#$B5,#$A1,#$A8,#$AE,#$AD,
{190}  #$AC,#$83,#$84,#$89,#$88,#$86,#$80,#$8A,#$AF,#$B0,
{200}  #$AB,#$A5,#$BB,#$B8,#$B1,#$A0,#$BE,#$B9,#$BA,#$B6,
{210}  #$B7,#$AA,#$A9,#$A2,#$A4,#$BD,#$BC,#$85,#$82,#$8D,
{220}  #$8C,#$8E,#$8F,#$8B,#$D2,#$D3,#$D4,#$D5,#$C6,#$C8,
{230}  #$C3,#$DE,#$DB,#$DD,#$DF,#$D9,#$D8,#$DC,#$C0,#$D1,
{240}  #$B3,#$A3,#$99,#$98,#$93,#$9B,#$9F,#$97,#$9C,#$95,
{250}  #$9E,#$96,#$BF,#$9D,#$94,#$20);

Var
  S,MaskIn,InFile,OutFile:string;
  F1,F2:Text;
  p:integer;
  RenameIt:Boolean;
  DirInfo:SearchRec;

Function Dos2Koi8(S:String):String;
Var i:integer;
begin
   For i:=1 to length(S) do begin
      If S[i]>#127 then
         S[i]:=Dos2KoiTable[Byte(S[i])-128];
   end;
   Dos2Koi8:=S;
end;


begin
  writeln('DOS to KOI-8R converter');
  writeln('  by Valery Votintsev');
  RenameIt:=False;

  If paramcount > 0 then begin
    MaskIn:=ParamStr(1);
    FindFirst(MaskIn,Archive,DirInfo);
    While DosError=0 do begin
      InFile:=DirInfo.Name;
      OutFile:=ParamStr(2);
      If OutFile='' then begin
        p:=pos('.',InFile);
        If p=0 then p:=length(InFile)+1;
        OutFile:=copy(InFile,1,p-1)+'.tmp';
        RenameIt:=True;
      end;

      Assign(F1,InFile);
      {$i-}Reset(F1);{$i-}
      If IoResult<>0 then begin
        writeln('*** Error open file: ',InFile);
        Halt(1);
      end;
      Assign(F2,OutFile);
      {$i-}Rewrite(F2);{$i-}
      If IoResult<>0 then begin
        writeln('*** Error open file: ',OutFile);
        Halt(2);
      end;

      While not EOF(F1) do begin
        {$i-}Readln(F1,S);{$i-}
        If IoResult<>0 then begin
          writeln('*** Error reading file: ',InFile);
          Halt(3);
        end;
        s:=Dos2Koi8(s);
        {$i-}Writeln(F2,S);{$i-}
        If IoResult<>0 then begin
          writeln('*** Error writing file: ',OutFile);
          Halt(4);
        end;
      end;
      Close(F2);
      Close(F1);

      If RenameIt then begin
        Erase(F1);
        Rename(F2,InFile);
      end;

      FindNext(DirInfo);
    end;
    writeln('Ok.');
  end;
end.
