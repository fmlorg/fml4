/*
  Copyright (C) 1993-2000 Ken'ichi Fukamachi
           All rights reserved. 
                1993-1996 fukachan@phys.titech.ac.jp
                1996-2000 fukachan@sapporo.iij.ad.jp
 
  FML is free software; you can redistribute it and/or modify
  it under the terms of GNU General Public License.
  See the file COPYING for more details.

*/

#include <stdio.h>
#include "config.h"

static char rcsid[] = "$Id$";

main()
{

#ifdef POSIX			/* 4.4BSD */
				/* must be done under setuid-as-root! */
  setuid(XXUID);
  setgid(XXGID);

#else				/* 4.3BSD */

  setuid(geteuid());
  setgid(getgid());

#endif

  if (getuid() != geteuid()) 
    fprintf(stderr, "Warning: uid != euid\n");

  if (getgid() != getegid()) 
    fprintf(stderr, "Warning: gid != egid\n");

#ifdef DEBUG
  if (getuid() == geteuid() && (getuid() < (Uid_t) 10))
    fprintf(stderr, "Warning: Hmm... uid seems set to %d < 10. O.K.? \n", 
	    (int) getuid());
#endif

  execl("_EXEC_DIR_/libexec/fmlserv.pl", /* where is fml.pl */
	"(fml)", 
	"_ML_DIR_", /* where is the top dir over dir's with rconfig.ph */
	"_EXEC_DIR_", /* library of fml package */
	NULL);

  exit(0);
}
