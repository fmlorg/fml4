#!?bin/sh

echo '-- jperl 4.036'
jperl4.036 perlversion.pl
echo '' 

echo '-- perl 5.00503 + jperl patch'
jperl5.00503  perlversion.pl
echo '' 

echo '-- perl 5.00503'
perl perlversion.pl
echo '' 


exit 0;
