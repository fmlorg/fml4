# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

sub FML_SYS_DBCtl
{
    local($type, $file, $action, $buf) = @_;

    if ($action eq 'add') {
	&TextDBAppend($file, $buf);
    }
    elsif ($action eq 'get') {
	&TextDBGet($file, $buf);
    }
}


sub TextDBAppend
{
    local($file, $buf) = @_;

    if (open(SAVE_ENV, ">> $file")) {
	print SAVE_ENV time, "\t", $buf, "\n";
	close(SAVE_ENV);
    }
    else {
	&Log("confirmation cannot save env");
    }
}


sub TextDBGet
{
    local($file, $key) = @_;
    local($time, $x_id, $x_buf);

    if (open(SAVE_ENV, $file)) {
	while (<SAVE_ENV>) {
	    chop;
	    ($time, $x_id, $x_buf) = split(/\s+/, $_, 3);
	    if ($x_id eq $key) { 
		return $x_buf;
	    }
	}
	close(SAVE_ENV);
    }
    else {
	&Log("confirmation cannot restore env");
    }

    $NULL;
}


1;
