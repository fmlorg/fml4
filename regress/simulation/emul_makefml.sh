#!/bin/sh
#
# $FML$
#

/usr/local/fml/makefml $*

sh `dirname $0`/check.sh

exit 0
