while(<>) {
	/^>>> fml/ && ( print ('-' x 30)."\n") && next;

	# mh
	next if /mhl.format|\(Message\s+inbox:\d+\)/;

	# headers to skip
	next if /^(Lines|Posted|Precedence|Reply-To|Return-Path|Subject):/i;
	next if /X-.*:/i && !/Count/i;

	print " $_";
}

1;
