

$| = 1;

while(<>) {
	s/^Date:(.*)/At $1/i;
	s/^From:(.*)/Thanks to $1/i;
	/To:/ && $fl++;

	print ('-' x 30)."\n" if /^>>> fml/;

	next if /^>>> fml/;
	next if /mhl.format/;
	next if /Lines:|Posted:|Precedence:|Reply-To:/;
	next if /Return-Path:|Subject:|To:|X-ML-Name:|X-MLServer:|X-Mail-Count:/;

	print $_;
}

1;
