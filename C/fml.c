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

  execl(FMLPROG, /* where is fml.pl */
	"(fml)", 
	FMLDIR, /* where is config.ph */
	FMLLIBDIR, /* library of fml package */
	NULL);

  exit(0);
}
