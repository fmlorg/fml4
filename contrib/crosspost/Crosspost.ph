# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)
# Crosspost.ph (called in ParsinHeader() must be)
#
#$phid = q$Id$;

#e.g. consider two ML's ML-1 and ML-2 ...
#	/usr/spool/ML-1 for ML-1 
#	/usr/spool/ML-2 for ML-2 
#       that is ML-1/config.ph ML-2/config.ph...
#

$ML_SPOOL          = '/home/axion/fukachan/work/spool';

%Crosspost = (
#.debug
	      'sailor-moon@phys.titech.ac.jp', 	 "$ML_SPOOL/Kessha",
	      'sailor-mercury@phys.titech.ac.jp',"$ML_SPOOL/Kessha",
	      'sailor-mars@phys.titech.ac.jp', 	 "$ML_SPOOL/Kessha",
	      'sailor-jupiter@phys.titech.ac.jp',"$ML_SPOOL/Kessha",
	      'sailor-venus@phys.titech.ac.jp',  "$ML_SPOOL/Kessha",
	      'sailor-uranus@phys.titech.ac.jp', "$ML_SPOOL/Kessha",
	      'sailor-uranus@phys.titech.ac.jp', "$ML_SPOOL/Kessha",
	      'sailor-pluto@phys.titech.ac.jp',  "$ML_SPOOL/Kessha",
	      'sailor-chibi-moon@phys.titech.ac.jp', "$ML_SPOOL/Kessha",
	      'fml-test@phys.titech.ac.jp', 	"$ML_SPOOL/EXP",
	      'fml-support@phys.titech.ac.jp', 	"$ML_SPOOL/FML",
	      'elena@phys.titech.ac.jp', 	"$ML_SPOOL/EXP/tmp",
#.enddebug
	      'uja@phys.titech.ac.jp', 		"$ML_SPOOL/contrib/Crosspost",
	      'pollyanna@phys.titech.ac.jp', 	"$ML_SPOOL/pollyanna",
	      'mama4@phys.titech.ac.jp', 	"$ML_SPOOL/mama4",
	      'mama4-world@phys.titech.ac.jp', 	"$ML_SPOOL/meisaku-world",
	      'meisaku-world@phys.titech.ac.jp',"$ML_SPOOL/meisaku-world",
	      'yuuri@phys.titech.ac.jp', 	"$ML_SPOOL/yuuri",
	      'marybell@phys.titech.ac.jp', 	"$ML_SPOOL/yuuri",
	      'rosy@phys.titech.ac.jp', 	"$ML_SPOOL/yuuri",
	      'enterprise@phys.titech.ac.jp',   "$ML_SPOOL/enterprise",
	      'momo@phys.titech.ac.jp',   	"$ML_SPOOL/momo",
	      'Rin@phys.titech.ac.jp',   	"$ML_SPOOL/Rin",
	      'mizuiro@phys.titech.ac.jp',   	"$ML_SPOOL/mizuiro",
	      'moechan@phys.titech.ac.jp',   	"$ML_SPOOL/moechan",
	      'phys-faq@phys.titech.ac.jp',   	"$ML_SPOOL/phys-faq",
	      'luna@phys.titech.ac.jp',   	"$ML_SPOOL/manami",
	      'manami@phys.titech.ac.jp',   	"$ML_SPOOL/manami",
	      'Elilin@phys.titech.ac.jp',   	"$ML_SPOOL/Elilin",
	      'Elilin.event@phys.titech.ac.jp',   "$ML_SPOOL/Elilin.event"
);

1;
