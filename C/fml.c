#include <stdio.h>

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

  execl("/home/axion/fukachan/work/spool/EXP/fml.pl", /* where is fml.pl */
	"(fml)", 
	"/home/axion/fukachan/work/spool/EXP", /* where is config.ph */
	"/home/axion/fukachan/work/spool/EXP", /* library of fml package */
	NULL);

  exit(0);
}
