#!/bin/sh

(
   echo '.HTML_PRE'
   sed -n '/ifdef-3.0/,/endif-3.0/p' $1
   echo '.~HTML_PRE'
) |\
perl -nple 's/^\.C\s*/��/; s/^\=E.C\s*/=E\n<>/;' | nkf -e
echo '$Id$'
echo '.#'
echo ".# Copyright (C) Ken'ichi Fukamachi"
echo '.#     all rights reserved'

exit 0
