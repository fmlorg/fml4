# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

sub ConfigByMakeFml
{
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
	    $BRACKET = $MAKE_FML{'ML_NAME'};
	}

	if ($os = $MAKE_FML{'OS_TYPE'}) {
	    eval "\$COMPAT_${os} = 1;";
	}
    }
}

1;
