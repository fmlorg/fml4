while (<>) {
	$e{'Body'} .= $_;
}


	{
	    local($pp, $p, $maxlen, $len, $buf);

	    $pp     = 0;
	    $maxlen = length($e{'Body'});

	    # write each line in buffer
	  smtp_io:
	    while (1) {
		$p   = index($e{'Body'}, "\n", $pp);
		$len = $p  - $pp + 1;
		printf("%-3d  => %-3d (%-3d)", $pp, $p ,($p < 0 ? $maxlen-$pp : $len));
		$buf = substr($e{'Body'}, $pp, ($p < 0 ? $maxlen-$pp : $len));
#		if ($buf !~ /\r\n$/) { $buf =~ s/\n$/\r\n/;}
#		print SMTPLOG $buf;
#		print S $buf;
		print  $buf;
		$LastSmtpIOString = $buf;

		last smtp_io if $p < 0;
		$pp = $p + 1;
	    }
	}
