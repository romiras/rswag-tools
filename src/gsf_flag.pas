{------------------------------------------------------------------------------
                         Defines and Compiler Flags

       gsF_Flag Copyright (c) 1996 Griffin Solutions, Inc.

       Date
          4 Apr 1996

       Programmer:
          Richard F. Griffin                     tel: (912) 953-2680
          Griffin Solutions, Inc.             e-mail: grifsolu@hom.net
          102 Molded Stone Pl
          Warner Robins, GA  31088

       Modified (m) 1997-2000 by Valery Votintsev 2:5021/22

       -------------------------------------------------------------
       This unit handles the defines and compiler flags that are used
       to configure the compiler.  It is included ($I SSF_FLAG.PAS) in
       each unit.

   Changes:

------------------------------------------------------------------------------}

{Set define flag DELPHI if Delphi; set WINAPI if Windows, Win32, or Delphi}

{$IFDEF DPMI}
   {$DEFINE PROTECTEDMODE}
{$ENDIF}

{   $DEFINE FOXGENERAL}   {Set General Collate mode for FoxPro}

{   $DEFINE DBASE3OK}     {Include DBase 3 index code}
{   $DEFINE DBASE4OK}     {Include DBase 4 index code}
{   $DEFINE CLIPOK}       {Include Clipper index code}
{$DEFINE FOXOK}        {Include FoxPro index code}

{$DEFINE TESTING}   {Remove for the finished program}
{    $DEFINE HALCDEMO}     {Compile as demo library}


{$O+} {Enables or disables the use of overlays}
{$A+} {Switches between byte/word alignment of variables and typed constants}
{$I+} {Enables or disables the automatic code generation that checks the}
      {result of a call to an I/O procedure}
{$F+} {Controls which call model to use for subsequently-compiled procedures}
      {and functions}
{$V-} {Controls type-checking on strings passed as variable parameters}
{$T-} {Controls Type @ Operator}
{$B-} {Switches between the two different models of code generation for the}
      {AND and OR Boolean operators}
{$N+} {Switches between the two different models of floating-point code}
      {generation supported by the compiler}
{$E+} {Enables or disables linking with an 80x87-emulating run-time library}
{$X+} {Enables or disables Turbo Pascal's extended syntax}

{----------------------------------------------------------------------------}
{          These switches should be turned off for finished program          }
{----------------------------------------------------------------------------}
{$IFDEF TESTING}
{$D+} {Enables and disables the generation of debug information}
{$L+} {Enables or disables the generation of local symbol information}
{$Q+} {Enables and disables checking certain integer operations for overflow}
{$R+} {Enables and disables the generation of range-checking code}
{$S+} {Enables and disables the generation of stack-overflow checking code}
{$ELSE}
{$D-} {Enables and disables the generation of debug information}
{$L-} {Enables or disables the generation of local symbol information}
{$Q-} {Enables and disables checking certain integer operations for overflow}
{$R-} {Enables and disables the generation of range-checking code}
{$S-} {Enables and disables the generation of stack-overflow checking code}
{$ENDIF}

