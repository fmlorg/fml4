#!/bin/sh

(
   echo '.HTML_PRE'
   sed -n '/ifdef-3.0/,/endif-3.0/p' $1
   echo '.~HTML_PRE'
) |\
perl -nple 's/^\.C\s*/��/; s/^\=E.C\s*/��/;' | nkf -e

exit 0
