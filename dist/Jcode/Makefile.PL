#!/usr/local/bin/perl
#
# $Id: Makefile.PL,v 0.59 1999/10/16 22:10:06 dankogai Exp $
#

use ExtUtils::MakeMaker;

WriteMakefile
    (
     NAME         => 'Jcode',
     VERSION_FROM => 'Jcode.pm',
     PREREQ_PM    => {
	 'MIME::Base64'     => "2.1",
     }
     );	       

