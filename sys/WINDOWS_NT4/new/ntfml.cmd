@setlocal
set perl=_PERL_
set fmldir=_EXEC_DIR_
set exfile=_ML_DIR_\exit.sts

_DRIVE_
cd %fmldir%
if exist %exfile% del %exfile%

:LOOP
%Perl% %fmldir%\ntfml.pl  %1 %2 %3 %4 %5 %6 %7 %8 %9 

if ERRORLEVEL 1 goto exit_loop
goto LOOP

:exit_loop
del %exfile%
endlocal
