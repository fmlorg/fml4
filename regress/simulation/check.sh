#!/bin/sh
#
# $FML$
#

(
	head 	/var/spool/ml/elena/actives \
		/var/spool/ml/elena/members \
		/var/spool/ml/elena/members-admin
) | egrep -v '^#'

exit 0
