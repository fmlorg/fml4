
	    while (sysread(STDIN, $buf, 4)) {
		$buf =~ s/\n/\r\n/g;
		$buf =~ s/\r\r\n/\r\n/g; # twice reading;

		print STDERR "buf={$buf}\n";

		# ^. -> .. 
		$buf =~ s/\n\./\n../g;

		# XXX: 1. "xyz\n.abc" => "xyz\n" + ".abc"
		# XXX: 2. "xyz..abc" => "xyz." + ".abc"
		if (! $pbuf) { $buf =~ s/^\./../g;}
		if ($pbuf =~ /\n$/) { $buf =~ s/^\./../g;}

#		print S $buf;
		print STDERR "out={$buf}\n";
		print $buf;
		$pbuf = substr($buf, -4); # the last buffer
	    }
