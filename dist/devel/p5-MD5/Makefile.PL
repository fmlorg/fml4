# SCCS ID @(#)Makefile.PL	1.10 96/06/28
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'MD5',
    'VERSION_FROM' => 'MD5.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'CONFIG'	=> ['byteorder'],	# Used to determine 64-bitness
    'DEFINE'	=> '-DPERL_BYTEORDER=$(BYTEORDER)',
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
    'OBJECT'	=> q[MD5$(OBJ_EXT) md5c$(OBJ_EXT)],
);
