#! /usr/local/bin/perl
# Copyright (C) 1995-2000 yuao@infonia.ne.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id: libtraffic.pl,v 1.3 2000/03/09 08:19:31 yuao Exp yuao $;
$rcsid  .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

if ($0 eq __FILE__) {
	# insert code(s), $name = 'Main Address' if $name eq 'Another Address';
	$TRF_NAME_HOOK = q#
	#; # for multi-address users

	&Traffic(*ARGV,*e);
	print $e{'message'};
}

sub Traffic {
	local(*TARGV,*e) = @_;
	local($fever) = 25;       # print feverish days over $fever mails;
	local($daily) = 0;        # print daily traffic if $daily;
	local($printname) = 10;   # print the best $printname posters;
	local($dir) = $DIR || '.';        # summary file path
	local($arg);
	local(@line,%member,@members,$hour,$min,$sec,$dummy,$name);
	local($start,$end,$over,@monthtab,$days,$mdays);
	local(@dcount,@hmail,$risky,$w,$i,$j);
	local($datebak,$monthbak,$count,$mcount,$mcount_max);
	local($very_first,$first,$mfirst,$mails,$max,$mean);
	local($ey,$em,$ed);
	local(@user,@address,$address_ok);
	local($from_flg) = 0;
	local($to_flg) = 0;
	local($gflg) = 0;
	local($glen);
	local($graph) = '****************************************';
	$graph .= $graph;

	if ( $TARGV[0] eq '#' && $TARGV[1] =~ /^traffic$/io ) {
		shift(@TARGV);
		shift(@TARGV);
	}
	$arg = shift(@TARGV);
	while(length($arg)>0){
		if ( $arg eq '-d' ) {
			$daily = 1;
		} elsif ( $arg =~ /^-n(.*)/ ) {
			if ( length($1) > 0 ) {
				$printname = $1;
			} else {
				$printname = shift(@TARGV);
			}
		} elsif ( $arg =~ /^-m(.*)/ ) {
			if ( length($1) > 0 ) {
				$fever = $1;
			} else {
				$fever = shift(@TARGV);
			}
		} elsif ( $arg =~ /^-u(.*)/ ) {
			if ( length($1) > 0 ) {
				$name = $1;
			} else {
				$name = shift(@TARGV);
			}
			$name = substr( $name, 0, 15 );
			eval $TRF_NAME_HOOK;
			push( @user, $name );
		} elsif ( $arg =~ /^-a(.*)/ ) {
			if ( length($1) > 0 ) {
				push( @address, substr( $1, 0, 15 ) );
			} else {
				push( @address, substr( shift(@TARGV), 0, 15 ) );
			}
		} elsif ( $arg =~ /^-f(.*)/ ) {
			$from_flg = 1;
			if ( length($1) > 0 ) {
				$start = $1;
			} else {
				$start = shift(@TARGV);
			}
			$start = &TRF_ExDate($start);
		} elsif ( $arg =~ /^-t(.*)/ ) {
			$to_flg = 1;
			if ( length($1) > 0 ) {
				$end = $1;
			} else {
				$end = shift(@TARGV);
			}
			$end = &TRF_ExDate($end);
		} elsif ( $arg =~ /^-g(.*)/ ) {
			$gflg = 1;
		} else {
			if ($0 eq __FILE__) {
				$dir = $arg;
			} else {
				return "\tUnknown Option: $arg\n\tStop.\n";
			}
		}
		$arg = shift(@TARGV);
	}

	$datebak = 0;
	$monthbak = 0;
	$count = 0;
	$first = 1;
	$very_first = 1;
	$mfirst = 1;
	$mails = 0;
	$max = 0;
	$mean = 0;
	$mcount_max = 0;
	$e{'message'} = "Mails IN THE LIFE\n";
	$e{'message'} .= "Date      Mails\n" if $daily;
	open( SOURCE_OF_TRF, "$dir/summary" );
	while( <SOURCE_OF_TRF> ) {
		@line = split( ' ', $_ );
		if ( $very_first ) {
			$start = $from_flg ? $start : $line[0];
			$very_first = 0;
		}
		next if ($from_flg && &TRF_ExYear($line[0]) lt &TRF_ExYear($start));
		next if ($to_flg && &TRF_ExYear($line[0]) gt &TRF_ExYear($end));
		( $dummy, $name ) = split( ':', $line[2] );
		$name =~ s/]$//;
		$address_ok = 1;
		foreach $w ( @address ) {
			$address_ok = 0;
			if ( $w eq $name ) {
				$address_ok = 1;
				last;
			}
		}
		eval $TRF_NAME_HOOK;
		foreach $w ( @user ) {
			$address_ok = 0 if @address == 0;
			if ( $w eq $name ) {
				$address_ok = 1;
				last;
			}
		}
		next unless $address_ok;
		$member{$name}++;
		( $hour, $min, $sec ) = split( ':', $line[1] );
		$hmail[$hour]++;
		if ( $line[0] eq $datebak ) {
			$count++;
		} else {
			if ( $first ) {
				$first = 0;
			} else {
				$e{'message'} .= "$datebak: $count\n" if $daily;
				$dcount[$count]++;
				$over .= "$datebak: $count\n" if $count >= $fever;
				$mails += $count;
				$max = $count if $max < $count;
			}
			$datebak = $line[0];
			$count = 1;
		}
		( $year, $month, $day ) = split( '/', $line[0] );
		$month = "$year/$month";
		if ( $month eq $monthbak ) {
			$mcount++;
		} else {
			if ( $mfirst ) {
				$mfirst = 0;
			} elsif ( $monthbak ) {
				push( @monthtab, $monthbak, $mcount );
				$mcount_max = $mcount if $mcount > $mcount_max;
			}
			$monthbak = $month;
			$mcount = 1;
		}
	}
	close(SOURCE_OF_TRF);
	push( @monthtab, $monthbak, $mcount );
	$mcount_max = $mcount if $mcount > $mcount_max;
	$e{'message'} .= "$datebak: $count\n\n" if $daily;
	$dcount[$count]++;
	$over .= "$datebak: $count\n" if $count >= $fever;
	$mails += $count;
	($ey,$em,$ed)=(localtime)[5,4,3];
	$em++;
	$end = $to_flg ? $end : sprintf("%02d/%02d/%02d",($ey % 100),$em,$ed);
	$days = &difday( $start, $end );
	if ( $mails == 0 ) {
		$e{'message'} .= "\nTotal:$mails mails are posted ";
		$e{'message'} .= "from $start to $end ($days days).\n";
    	return;
    }
	$max = $count if $max < $count;
	$e{'message'} .= "Month  Mails\n";
	for ( $i = 0; $i < @monthtab; $i += 2 ) {
		$e{'message'} .= sprintf( "%5s:%5d", $monthtab[$i], $monthtab[$i+1] );
		if ( $gflg ) {
			$glen = int(60.0*$monthtab[$i+1]/$mcount_max+0.5);
			$e{'message'} .= ' |'.substr($graph,0,$glen);
		}
		$e{'message'} .= "\n";
	}
	$max = $count if $max < $count;
	$mean = $mails / $days;
	$e{'message'} .= "\nMails  Days\n";
	$mdays = 0;
	for ( $i = 1; $i < @dcount; $i++ ) {
		$mdays += $dcount[$i];
	}
	$dcount[0] = $days - $mdays;
	for ( $i = 0; $i < @dcount; $i++ ) {
		$e{'message'} .= sprintf("%5d: %-5d\n", $i, $dcount[$i]) if $dcount[$i] > 0;
	}
	$mcount_max = 0;
	for ( $i = 0; $i < 24; $i++ ) {
		$mcount_max = $hmail[$i] if $hmail[$i] > $mcount_max;
	}
	$e{'message'} .= "\nMails in each TIME-frames...\n";
	$e{'message'} .= "Hour   Mails\n";
	for ( $i = 0; $i < 24; $i++ ) {
		$e{'message'} .= sprintf("%02d-%02d:%5d",	$i, $i+1, $hmail[$i]);
		if ( $gflg ) {
			$glen = int(60.0*$hmail[$i]/$mcount_max+0.5);
			$e{'message'} .= ' |'.substr($graph,0,$glen);
		}
		$e{'message'} .= "\n";
	}
	if ( length( $over ) > 0 ) {
		$e{'message'} .= "\nRED HOT days over $fever mails...\nDate      Mails\n";
		$e{'message'} .= $over;
	}
	@members = %member;
	if ( $printname && @members > 2 ) {
		$risky = $printname;
		$printname *= 2;
		for ( $i = 0; $i < @members; $i+=2 ) {
			for ( $j = $i + 2; $j < @members; $j+=2 ) {
				if ( $members[$i+1] < $members[$j+1] ) {
					$w = $members[$i];
					$members[$i] = $members[$j];
					$members[$j] = $w;
					$w = $members[$i+1];
					$members[$i+1] = $members[$j+1];
					$members[$j+1] = $w;
				}
			}
		}
		$risky = @members / 2 if $risky > @members / 2;
		$e{'message'} .= "\nThe most RISKY $risky posters...\n";
		$e{'message'} .= "   E-mail address    Mails\n";
		for ( $i = 0, $count = 1; $i < @members; $i+=2 ) {
			$count = $i/2+1 if ( $i > 0 && $members[$i+1] < $members[$i-1] );
			$glen = int(40.0*$members[$i+1]/$members[1]+0.5) if $gflg;
			if ($count <= $risky){
				$e{'message'} .= sprintf("%2d.%s:%5d(%4.1f%%)", $count,
					$members[$i],$members[$i+1],
					$members[$i+1]/$mails*100);
				$e{'message'} .= ' |'.substr($graph,0,$glen) if $gflg;
				$e{'message'} .= "\n";
			}
		}
	}
	$e{'message'} .= "\nTotal:$mails mails are posted ";
	$e{'message'} .= "from $start to $end ($days days).\n";
	$e{'message'} .= sprintf("Mean: %.1f mails/1day  ", $mean);
	$e{'message'} .= sprintf("Max: %d mails/1day\n", $max);

}

sub difday { # usable from 1971 to 2070
	local( $date1, $date2 ) = @_;
	local( @day ) = ( 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
	local( $y1, $m1, $d1 ) = split( '/', $date1 );
	local( $y2, $m2, $d2 ) = split( '/', $date2 );
	local( $y, $m, $days );
	
	if ( $y1 > 70 ) {
		$y1 += 1900;
	} else {
		$y1 += 2000;
	}
	if ( $y2 > 70 ) {
		$y2 += 1900;
	} else {
		$y2 += 2000;
	}

	$days = 0;
	for ( $y = $y1; $y <= $y2; $y++ ) {
		if ( ( $y % 4 == 0 && $y % 100 != 0 ) || ( $y % 400 == 0 ) ) {
			$day[2] = 29;
		} else {
			$day[2] = 28;
		}
		for ( $m = ($y==$y1? $m1 : 1); $m <= ($y==$y2? $m2 : 12); $m++ ) {
			if ( $y == $y1 && $m == $m1 && $y == $y2 && $m == $m2 ) {
				$days += $d2 - $d1 + 1;
			} elsif ( $y == $y1 && $m == $m1 ) {
				$days += $day[$m] - $d1 + 1;
			} elsif ( $y == $y2 && $m == $m2 ) {
				$days += $d2;
			} else {
				$days += $day[$m];
			}
		}
	}
	return $days;
}

sub TRF_ExDate {
	local($date) = @_;
	local($y,$m,$d) = split( '/', $date);
	$m = ( $m || '01' );
	$d = ( $d || '01' );
	return sprintf( "%02d/%02d/%02d", $y, $m, $d );
}

sub TRF_ExYear {
	local($date) = @_;
	local($y,$m,$d) = split( '/', $date);
	if ( $y > 70 ) {
		$y += 1900;
	} else {
		$y += 2000;
	}
	return sprintf( "%04d/%02d/%02d", $y, $m, $d );
}

1;

