# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

### mead (mail error analyzer daemon) configuration ###
### THIS FILE CAN OVERWRITE COMMAND LINE OPTIONS    ###


# value: number
$LIMIT  = 5;

# the unit is "days"
# value: number
$EXPIRE = 14;

# value: bye / off 
$ACTION = "bye";

# value: report / auto
$MODE   = "report";


### Section: log
# value: 1/0
$SAVE_UNANALYZABLE_ERROR_MAIL = 0;


# algorithm (not yet implemented in fml 4.0)
# value: function string
$MEAD_COST_EVAL_FUNCTION = 'MeadSimpleEvaluator';

1;
