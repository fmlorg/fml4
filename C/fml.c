#include <stdio.h>

static char rcsid[] = "$Id$";

main()
{
  setuid(geteuid());
  setgid(getgid());
  execl("/home/axion/fukachan/work/spool/EXP/fml.pl", /* where is fml.pl */
	"(fml)", 
	"/home/axion/fukachan/work/spool/EXP", /* where is config.ph */
	"/home/axion/fukachan/work/spool/EXP", /* library of fml package */
	NULL);
  exit(0);
}
