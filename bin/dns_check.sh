#!/bin/sh
#
# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

echo " "
echo perl4.036 bin/dns_check.pl
perl4.036 bin/dns_check.pl


echo " "
echo perl5.003 bin/dns_check.pl
perl5.003 bin/dns_check.pl

