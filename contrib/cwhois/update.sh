#!/bin/sh

DBDIR=$HOME/db
OFFICE=/amd/argoss/disk1/office

eval renice +18 $$ >/dev/null 2>&1

chdir $DBDIR

perl gendb.pl $OFFICE/apply/ --DB=${PWD}/applydb --diff

# /usr/local/bin/perl bin/gen-apply-db.pl -c apply-db $OFFICE/Mail/apply |\
# /usr/ucb/tee -a apply-db
