/*
$Header$
$RCSfile$
*/

static char rcsid[] = "$Id$";
#include <stdio.h>
#include <sys/types.h>

main()
{
  setuid(geteuid());
  setgid(getegid());
  execl("/home/axion/fukachan/work/spool/EXP/fml.pl", "(fml)", NULL);
  exit(1);
}
