# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

# do not change here for backward compat ;_;
sub ConfigByMakeFml
{
    $UnderMakeFml = 1; # Set Global Identifier;

    local($os);

    for (keys %MAKE_FML) {
	next unless $MAKE_FML{$_};

	if ($MAKE_FML{'NON_PORTABILITY'}) { 
	    $NON_PORTABILITY = 1;
	}

	if ($MAKE_FML{'OPT_MIME'}) { 
	    $USE_MIME = 1;
	}

	if ($MAKE_FML{'OPT_HTML'}) { 
	    require 'libmodedef.pl';
	    &ModeDef('HTML');
	}

	if ($MAKE_FML{'SUBJECT_TAG'}) {
	    require 'libtagdef.pl';
	    &SubjectTagDef($MAKE_FML{'SUBJECT_TAG'});

	    # below is not required now (97/01/30) but backward-compatibility;
	    $BRACKET = $MAKE_FML{'ML_NAME'}; 
	}

	if ($os = $MAKE_FML{'OS_TYPE'}) {
	    eval "\$COMPAT_${os} = 1;";
	}
    }
}

1;
