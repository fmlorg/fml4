# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: (\S+).pl,v\s+(\S+)\s+/ && $1."[$2]");

package CF;

sub GetEachDataBuffer
{
    local(*Buf, *CF) = @_;

    $eval = qq#;
    \$domain = 'HEADER';
    foreach (split(/\\n/, \$Buf)) { 
	\$_ = "\$_\n";
	$CF{'eval'};
    };
    ;#;

    print "$eval\n" if $debug;

    local($domain, $seq);
    eval $eval;
    &Error($@) if $@;

    # while (($k, $v) = each %Buf) { print "Buf $k\n$v\n\n";}

    @CF = keys %Buf;
}


sub SetEachDataType
{
    local(*CFBuffer, *CF) = @_;
    local(%begin, $eval, $type);

    foreach (split(/\n/, $CFBuffer)) {
	if (/^\.config/ .. /^data-type/i) { 
	    next if /^\.config/;
	    $Aucea'AuceaConfig .= "$_\n" unless /^data-type/i; #';
	}

	if (/^data-type\s+(\S+)/i) {
	    $type = $1;
	    push(@CF, $type);
	}
	elsif (/^field-type\s+(.+)/i) {
	    $CF{$type, 'field-type'} = $1;
	}
	elsif (/^data-begin-here\s+(.+)/i) { 
	    $begin{$type}     = $1;
	    $beginhere{$type} = 1;
	}
	elsif (/^data-begin\s+(.+)/i) { 
	    $begin{$type}   = $1;
	}
	elsif (/^data-end\s+(.+)/i) { 
	    $end{$type}   = $1;
	}
	else {
	    # ATTENTION! %CF here;
	    $CF{${type}, "proc"} .= "$_\n";
	}
    }

    foreach $type (@CF, 'HEADER') {
	$key    = $begin{$type};
	$here   = $beginhere{$type};
	$endkey = $end{$type} || "\\\\s*";

	if (! $endkey) {
	    $eval .= qq#;
	    if (/^$endkey\$/ && \$datatype eq '$type') { 
		undef \$datatype; next;
	    }
	    #;
	}

	if ($key) {
	    $eval .= qq#;
	    if (/^($key)/)    { 
		\$datatype = \"$type\"; 
		if (\$Buf{\$datatype}) {
		    \$seq++; 
		    \$datatype = \"$type\#\$seq\";
		}
		else {
		    \$datatype = \"$type\";
		}

		next unless $here;
	    }
	    \n#;
	}
    }

    $eval .= qq#;
    ;
    if (\$datatype) {
	\$Buf{\$datatype} .= \$_;
    }
    \n#;

    $CF{'eval'} = $eval;
}

sub Onelined
{
    local(*CFBuffer, *file) = @_;
 
    open(CF, $file);

    while (<CF>) {
	chop;

	# next if /^\s*$/;
	# next if /^\$/;

	s/^\s*//;
	s/\s*$//;

	$CFBuffer .= /\\$/ ? $_: "$_\n";
    }
}

1;
