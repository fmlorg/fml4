#!/usr/local/bin/perl

$HOME 		= $ENV{'HOME'};
$WWWMAILDIR 	= $ENV{'WWWMAILDIR'} ? $ENV{'WWWMAILDIR'} : "$HOME/WWW_MAIL";
$SEQUENCE_FILE 	= "$WWWMAILDIR/seq";
$HTML  		= "$WWWMAILDIR/Elena.html";
$WHERE 		= "$WWWMAILDIR/dir";
$MBOX		= "$WWWMAILDIR/mbox";

# flock system call
$LOCK_SH 	= 1;
$LOCK_EX 	= 2;
$LOCK_NB 	= 4;
$LOCK_UN 	= 8;


# SPECAIL DEBUG
#$WWWMAILDIR = '/home/axion/fukachan/work/spool/EXP/contrib/www-mail-client';

# make dir
if(!-d) { mkdir($WWWMALIDIR, 0700);}

# go
while(<>) {
    if(/^Show\s+(\d+)\s+(\d+)/oi)     { &Show($1, $2);}
    if(/^ShowPage\s+(\d+)\s+(\d+)/oi) { &ShowPage($1, $2);}
    if(/^URL\s+(\d+)/oi)              { &MailURL($1);}
    if(/^daemon$/oi)		      { &Daemon;}
}

exit 0;

sub GetID
{
    # Get the present ID
    open(IDINC, "< $SEQUENCE_FILE") || die("cannot open $SEQUENCE_FILE");
    $ID = <IDINC>;		# get
    $ID++;			# increment
    close(IDINC);		# more safely
    
    return $ID;
}

sub ResetID
{
    # Get the present ID
    open(IDINC, "> $SEQUENCE_FILE") || die("cannot open $SEQUENCE_FILE");
    print IDINC $ID. "\n";
    close(IDINC);		# more safely
}

sub Daemon
{
    while(1) {
	sleep(60);
	open(LOCK, $MBOX);
	flock(LOCK, $LOCK_EX);

	if(-s $MBOX) {		# non zero
	    local($NEW) = 1;

	    open(MBOX) ;
	    while(<MBOX>) {
		if(/^REQUEST:/ .. /\/REQUEST/) { 
		    if($NEW) {
			$ID = &GetID;
			open(OUT, "> $WWWMAILDIR/$ID");
			$NEW = 0;
			&ResetID;
		    }
		    print OUT $_; 
		}
	    }

	    system "cp $WWWMAILDIR/$ID $WWWMAILDIR/html" unless $NEW;
	    close(OUT) unless $NEW;
	}# IF NON ZERO;

	close(LOCK);
	flock(LOCK, $LOCK_UN);
    }# END OF WHILE;
}

sub MailURL
{
    local($which) = @_;

    $NO_SHOW = 1;
    &ShowPage(20, 100);
    $HTTP = &GetHTTP;
    local($URL) = $URL{$which};

    print "Mail Request URL:";

    if($URL =~ /http:/oi || 
       $URL =~ /gopher:/oi ||
       $URL =~ /ftp:/oi  ||
       $URL =~ /wais:/oi  ) { 
	print $URL;
    } else {
	print "$HTTP/".$URL;	
    }

    print "\n";
}

sub GetHTTP
{
    open(HTML, "< $WHERE");
    $HTTP = <HTML>;
    chop $HTTP;
    close(HTML);

    return $HTTP;
}


sub Show
{
    local($BEGIN, $END) = @_;

    open(HTML, "< $HTML");
    while(<HTML>) {
	if($BEGIN <= $. && $. < $END) { 
	    print $_;
	}
    }
    close(HTML);
}

sub ShowPage
{
    local($ROWS, $WHICH) = @_;

    local($BEGIN) = $ROWS * ($WHICH - 1);
    local($END)   = $ROWS * ($WHICH);

    local($UL, $HREF, $URL);

    open(HTML, "< $HTML");
    while(<HTML>) { 
	s/  / /g;
	s/กว/'/g;
	next if /^$/;
	$ON = 1 if (/<A\s/oi);
	$ON = 0 if (/<\/A>/oi);

	if($ON) {
	    chop;
	    $STRING .= $_;
	    next;
	}
	$STRING .= $_;
    }
    close(HTML);

    $count = 0;

    line: foreach (split(/\n/, $STRING, 9999)) {
#	print ">>>$_\n";
	$URL = "";
	
	# cut the first spaces
	s/\s*(.*)/$1/;
	
	# UL 
	if(/<UL>/oi)   { $UL++;}
	if(/<\/UL>/oi) { $UL--;}
	local($i) = $UL;

	# get HREF
	if(/<A\s+HREF\s*=\s*(.*)>(.*)<\/A>/oi) { 
	    $HREF++;
	    $URL = $1;
	    $URL{$HREF} = $URL;
	    print "$HREF $URL\n" if $debug;
	    $_ = $2;
	}

	s/<P>//g;
	s/<.*>//g;
	next line if /^\s+$/o;
	next line if $NO_SHOW;
	$count++;

	# main output
	if($BEGIN <= $count && $count < $END) { 
	    while($i-- > 0) { print "\t";}
	    if($URL) {
		# s/\s*(.*)/$1/;
		print "$HREF\t$_\n";
	    } else {
		print "$_\n";
	    }
	}
    }

    close(HTML);
}
