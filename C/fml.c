#include <stdio.h>

main()
{
    setuid(1304);
    setgid(getegid());
    execl("/home/axion/fukachan/work/spool/EXP/fml.pl", "(fml)", NULL);
    exit(1);
}
