# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)
# Crosspost.ph (called in ParsinHeader() must be)

$rcsid   = q$Id$;
($rcsid) = ($rcsid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);

$CROSSPOST_INCLUDE = "Crosspost.ph";
$CROSSPOST_FILE    = "/home/axion/fukachan/work/spool/lib/Crosspost.ph";
$ML_SPOOL          = '/home/axion/fukachan/work/spool';

%Crosspost = (
	      'fml-test@phys.titech.ac.jp', 	"$ML_SPOOL/EXP",
	      'fml-support@phys.titech.ac.jp', 	"$ML_SPOOL/FML",
	      'elena@phys.titech.ac.jp', 	"$ML_SPOOL/EXP",
	      'uja@phys.titech.ac.jp', 	"$ML_SPOOL/contrib/Crosspost",	      
	      'pollyanna@phys.titech.ac.jp', 	"$ML_SPOOL/pollyanna",
	      'mama4@phys.titech.ac.jp', 	"$ML_SPOOL/mama4",
	      'yuuri@phys.titech.ac.jp', 	"$ML_SPOOL/yuuri",
	      'marybell@phys.titech.ac.jp', 	"$ML_SPOOL/yuuri",
	      'rosy@phys.titech.ac.jp', 	"$ML_SPOOL/yuuri",
	      'enterprise@phys.titech.ac.jp',   "$ML_SPOOL/enterprise",
	      'momo@phys.titech.ac.jp',   "$ML_SPOOL/momo"
);

1;
