#!/bin/sh

(echo making manual of fml_locol 1>&2)
($FML/libexec/fml_local.pl -h > doc/smm/fml_local_builtin_functions.wix 2>&1)

exit 0;
