#! /usr/local/bin/perl
#
#	RMAIL2fml.pl --- RMAIL to fml
#
#		usage: RMAIL2fml.pl 'RMAIL-file'
#
#	!!! Please use 'fml' in debug mode.  ($debug = 'on')
#       Copyright (c) 1994-1995 yamane@ngi.co.jp
#	by S.Yamane (yamane@ngi.co.jp)
#       Copyright (c) 1994-1995 fukachan@phys.titech.ac.jp
#       Please obey GPL
#

$FML = '../fml';		# fml PATH

$state = 'GARBAGE';
while (<>) {
	chop;
	if ($state eq 'GARBAGE') {
		if ($_ !~ /^Received: /o) {
			next;			# discard
		}
		$state = 'HEADER';
		open(FML, "| $FML") || die("Cannot open pipe to 'fml'\n");
#		open(FML, "| less") || die("Cannot open pipe to 'less'\n");
	}
	if ($state eq 'HEADER') {
		if ($_ =~ /^\*\*\* EOOH \*\*\*/o) {
			$state = "EOOH";
			next;
		}
		print(FML "$_\n");
	}
	if ($state eq 'EOOH') {
		if ($_ !~ /^$/o) {
			next;			# discard
		}
		$state = 'BODY';
	}
	if ($state eq 'BODY') {
		if ($_ =~ /^$/o) {
			close(FML);
			$state = 'GARBAGE';
			next;			# discard
		}
		print(FML "$_\n");
	}
}

exit 0;
