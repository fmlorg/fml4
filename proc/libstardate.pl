#!/usr/local/bin/perl
#
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# q$Id$;

if ($0 eq __FILE__) {
    print &Stardate."\n";
}

sub Stardate
#    stardate(tm, issue, integer, fraction)
# unsigned long tm;
# long *issue, *integer, *fraction;
#
{
    local($issue, $integer, $fraction);

    # It would be convenient to calculate the fractional part with
    # *fraction = ( (tm%17280) *1000000) / 17280;
    # but the long int type may not be long enough for this (it requires 36
    # bits).  Cancelling the 1000000 with the 17280 gives an expression that
    # takes only 27 bits.

    $fraction = int (    (((time % 17280) * 3125) / 54)   );

    # Get integer part.
    $integer = time / 17280 + 9350;

    # At this stage, *integer contains the issue number in the obvious place,
    # biased to always be non-negative.  The issue number can be extracted by
    # simply dividing *integer by 10000 and offsetting it appropriately:

    $issue = int($integer / 10000) - 36;
    
    # Remove the issue number from *integer.

    $integer = $integer % 10000;

    sprintf("[%d]%04d.%02.2s", $issue, $integer, $fraction);
}

1;
