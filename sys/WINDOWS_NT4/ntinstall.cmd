perl -i.b0 sys\arch\WINDOWS_NT4\fix_syscall.pl src\*.pl libexec\* bin\* sbin\*

del src\*.b0
del libexec\*.b0 
del bin\*.b0 
del sbin\*.b0

perl sys\arch\WINDOWS_NT4\bootstrap.pl
