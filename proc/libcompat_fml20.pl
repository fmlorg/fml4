# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$


sub ProcRetrieveFileInSpool_FML_20
{
    local($proc, *Fld, *e, *misc, *cat, $ar, $mail_file) = @_;
    
    $cat{"$SPOOL_DIR/$ID"} = 1;
    if ($ar eq 'TarZXF') {  
	&use('utils');
	&Sendmail($e{'Addr2Reply:'}, "Get $ID $ML_FN", 
		  &TarZXF("$DIR/$mail_file", 1, *cat));
    }
    else {
	&SendFile($e{'Addr2Reply:'}, "Get $ID $ML_FN", 
		  "$DIR/$mail_file", 
		  $_cf{'libfml', 'binary'});
	undef $_cf{'libfml', 'binary'}; # destructor
    }

    &Log("Get $ID, Success");
}

1;
