sub AggregateLinks
{
    local(*links) = @_;
    local($p, $q, $recursive, %prev, %cache);

    while ($recursive++ < 16) {
	%prev = %links;
	undef %cache;
	&DoAggregateLinks(*links, *cache);

	# enough aggregated ?
	$p = join(" ", values %prev);
	$q = join(" ", values %links);
	$p =~ s/\s+/ /g;
	$q =~ s/\s+/ /g;
	if ($p eq $q) { last;}
    }

    # If a key in a list with no value is included in a %links, 
    # delete it.
    for $hp (keys %links) {
	next if $links{$hp};	# avoid non-empty list;

	if ($debug_html && $cache{$hp}) {
	    print STDERR "--delete $hp=>$links{$hp}\n";
	}

	delete $links{$hp} if $cache{$hp};
    }
}


sub DoAggregateLinks
{
    local(*links, *cache) = @_;
    local($hp, $tp);

    undef $cache;

    for $hp (keys %links) {
	next unless $links{$hp};

	@x  = split(/\s+/, $links{$hp});
	$tp = $x[$#x];
	for (@x) { $cache{$_} = 1;}

	# (tail 'list) -> (head 'another_list)
	if ($links{$tp}) {
	    $links{$hp} .= " ". $links{$tp};
	    undef $links{$tp};
	}
    }

    if ($debug_html) {
	for $hp (sort {$a <=> $b} keys %links) {
	    print STDERR "$hp => $links{$hp}\n";
	}
    }
}


sub OutPutAggrThread
{
    local(*list, *links) = @_;
    local($buf, $p, $i, $level, %already);

    for $p (sort {$a <=> $b} keys %links) {
	next if $already{$p};

	if ($debug_thread) { print "==$p\n";}

	print OUT "\n<UL><!-$p->\n";
	print OUT "\n<!- UL $p ->\n";
	print OUT $list{$p};
	&ThreadPrint(*list, *links, *already, $p, 0);

	print OUT "\n</UL>\n";
    }
}


sub ThreadPrint
{
    local(*list, *links, *already, $np, $offset) = @_;
    local($i, $p, $level, %np);

    print OUT "\n", ("   " x ($offset+1)),"<!-    sets in   UL ->\n";

    # nesting check
    return 1 if $ThreadPrintNest++ > 10;

    # alrady print out :)
    $already{$np} = 1;

    # here we go!
    for $i (split(/\s+/, $links{$np})) {
	if ($list{$i}) {
	    $level++;

	    if ($debug_thread) {
		print STDERR "==", ("   " x ($level+$offset)), " $i\n";
	    }

	    if ($offset) {
		if ($level > 1) {
		    print OUT "\n", 
		    ("   " x ($level+$offset)), "<UL>\n";
		}
	    }
	    else {
		print OUT "\n", ("   " x ($level+$offset)), "<UL>\n";
	    }
	    
	    print OUT ("   " x ($level+$offset)), "<!- UL $i->\n";
	    print OUT $list{$i};

	    # links pointer;
	    $np{$level} = $i;
	}
    }

    if ($offset) { $level--;}

    while ($level > 0) {
	print OUT "\n", ("   " x ($level+$offset)), "</UL>\n";

	$level--;

	if ($p = $np{$level}) {
	    if ($links{$p}) {
		&ThreadPrint(*list, *links, *already, $p, $level - 1);
	    }
	}
    }

    print OUT "\n", ("   " x ($offset+1)),"<!-    sets out   UL ->\n";

    # nesting check
    $ThreadPrintNest--;
}


1;
