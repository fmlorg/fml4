=head2 C<compare_euc_string($buf, $pat)>

search $pat in EUC string $buf.
return 1 if found or 0 if not.

=cut


# Descriptions: compare Japanese EUC strings
#    Arguments: OBJ($self) STR($a) STR($pat)
# Side Effects: none
#      History: fml 4.0: EUCCompare($buf, $pat)
#               where $pat should be $& (matched pattern)
# Return Value: NUM(1 or 0)
sub compare_euc_string
{
    my ($self, $a, $pat) = @_;

    # XXX validate $a and $pat ???
    #     e.g. defined($a) ?

    # (Refeence: jcode 2.12)
    # $re_euc_c    = '[\241-\376][\241-\376]';
    # $re_euc_kana = '\216[\241-\337]';
    # $re_euc_0212 = '\217[\241-\376][\241-\376]';
    my ($re_euc_c, $re_euc_kana, $re_euc_0212);
    $re_euc_c    = '[\241-\376][\241-\376]';
    $re_euc_kana = '\216[\241-\337]';
    $re_euc_0212 = '\217[\241-\376][\241-\376]';

    # always true if given buffer is not EUC.
    if ($a !~ /($re_euc_c|$re_euc_kana|$re_euc_0212)/) {
	&Log("EUCCompare: do nothing for non EUC strings");# if $debug;
	return 1;
    }

    # extract EUC code (e.g. .*EUC_PATTERN.*)
    # but how to do for "EUC ASCII EUC" case ???
    my ($pa, $loc, $i);
    do {
	if ($a =~ /(($re_euc_c|$re_euc_kana|$re_euc_0212)+)/) {
	    $pa  = $1;
	    $loc = index($pa, $pat);
	}

	print STDERR "buf = <$a> pa=<$pa> pat=<$pat> loc=$loc\n" if $debug;

	return 1 if ($loc % 2) == 0;

	$a = substr($a, index($a, $pa) + length($pa) );
    } while ($i++ < 16);

    0;
}
