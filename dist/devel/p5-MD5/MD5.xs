/*
**	Perl Extension for the
**
**	RSA Data Security Inc. MD5 Message-Digest Algorithm
**
**	This module by Neil Winton (N.Winton@axion.bt.co.uk)
**	SCCS ID @(#)MD5.xs	1.7 96/06/28
**
**	This extension may be distributed under the same terms
**	as Perl. The MD5 code is covered by separate copyright and
**	licence, but this does not prohibit distribution under the
**	GNU or Artistic licences. See the file md5c.c or MD5.pm
**	for more details.
*/

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "global.h"
#include "md5.h"

/*
** The following macro re-definitions added to work around a problem on
** Solaris where the original MD5 routines are already in /lib/libnsl.a.
** This causes dynamic linking of the module to fail.
** Thanks to Ken Pizzini (ken@spry.com) for finally nailing this one!
*/

#define MD5Init		MD5Init_perl
#define MD5Update	MD5Update_perl
#define MD5Final	MD5Final_perl

typedef MD5_CTX	*MD5;

#ifdef __cplusplus
}
#endif


MODULE = MD5		PACKAGE = MD5

PROTOTYPES: DISABLE

MD5
new(packname = "MD5")
	char *		packname
    CODE:
	{
	    RETVAL = (MD5_CTX *)safemalloc(sizeof(MD5_CTX));
	    MD5Init(RETVAL);
	}
    OUTPUT:
	RETVAL

void
DESTROY(context)
	MD5	context
    CODE:
	{
	    safefree((char *)context);
	}

void
reset(context)
	MD5	context
    CODE:
	{
	    MD5Init(context);
	}

void
add(context, ...)
	MD5	context
    CODE:
	{
	    SV *svdata;
	    STRLEN len;
	    unsigned char *data;
	    int i;

	    for (i = 1; i < items; i++)
	    {
		data = (unsigned char *)(SvPV(ST(i), len));
		MD5Update(context, data, len);
	    }
	}

SV *
digest(context)
	MD5	context
    CODE:
	{
	    unsigned char digeststr[16];

	    MD5Final(digeststr, context);
	    ST(0) = sv_2mortal(newSVpv((char *)digeststr, 16));
	}
