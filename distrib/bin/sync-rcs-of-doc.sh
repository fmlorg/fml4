#!/bin/sh

echo -n "--info [sync-rcs-of-doc] "; pwd

fvs CI doc/ri/*.wix doc/smm/*.wix

exit 0
