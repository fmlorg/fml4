#!/usr/local/bin/perl

# $Author$
# $State$
;$rcsid = "$Id$";

# Mailing List home directory
$DIR		= '/home/axion/fukachan/work/spool/EXP';

$incc = @INC;
$INC[$incc] = "$DIR";

require 'configure.pl';
require 'smtp.pl';

umask (022);			# rw-r--r--
$[ = 1;				# set array base to 1
chdir $DIR || die "Can't chdir to $DIR\n";
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);$wday++;
$Now = sprintf("%2d/%02d/%02d %02d:%02d:%02d", $year, $mon+1, $mday, $hour, $min, $sec);
$MailDate = sprintf("%s, %d %s %d %02d:%02d:%02d %s", $WDay[$wday],
		    $mday, $Month[$mon+1], $year, $hour, $min, $sec, $TZone);

&lock;
#&makeActives();
&parseHeader;

if ($CommandLine =~ /^#/) {
    require './libcommand.pl';
    &COMMAND;
} else {
#    &MAILBACK; this routine is for YP_ML backup server
#    because the design of no distribution of mails need 
#    implementation of no distribution 
#    require './sendmail.pl';
    &DISTRIBUTE;
}

&cleanup;

exit 0;

################### Libraries ###################

# lock
sub lock
{
    open(LOCK_TMP, ">$LOCK_TMP") || die "Can't make LOCK\n";
    close(LOCK_TMP);
    
### lock temporary file; just existance of lockfile
    
    for ($timeout = 0; $timeout < $MAX_TIMEOUT; $timeout++) {
	if (link($LOCK_TMP, $LOCK_FILE) == 0) {
	    sleep (rand(3)+5);
	} else {
	    last;
	}
    }
    
    unlink $LOCK_TMP;
    
# save incoming mail, send warning to maintainer, put log, die
    if ($timeout >= $MAX_TIMEOUT) {
	$TIMEOUT = sprintf("TIMEOUT.%2d%02d%02d%02d%02d%02d", 
			   $year, $mon+1, $mday, $hour, $min, $sec);
	open(TIMEOUT, ">" . $TIMEOUT);
	while (<>) {
	    print TIMEOUT $_;
	}
	close(TIMEOUT);
	&sendmail($MAINTAINER, "LOCK " . $TIMEOUT, "zonky");
	&fatal("LOCK " . $TIMEOUT);
    }
}


# sub parseHeader()
# parse header and save body into a file
# $_ is mail text from the mail daemon

sub parseHeader
{
    local($body) = 0;
    local($tag, $text);

    open(MAIL_BODY, ">$MAIL_BODY");
    while (<stdin>) {
	if (($body == 0) && /^$/) { # 1st null line separates header and body 
	    $body = 1;
	} else {
	    if ($body) {	# save mail body
		print MAIL_BODY $_;
		if (++$BodyLines == 1) {
		    $CommandLine = $_; # save 1st line of body for command check
		}
	    } else {
		chop;		# strip record separator
		($tag, $text) = /^([^: ]*): *(.*)/;

		$tag =~ /^Date$/i && ($Date = $text);
		$tag =~ /^Reply-to$/i && ($Reply_to = $text);
		$tag =~ /^Errors-to$/i && ($Errors_to = $text);
		$tag =~ /^X-Distribution$/i && ($Distribution = $text);		
		# get From: field, address and username
		if ($tag =~ /^From$/i) {
		    $From = $text;
		    if ($From =~ /<(.*)>/) { # <add@ress>
			$From_address = $1;
			$From_1 = $1;					     
		    } else {
			$From =~ /^([^ ]*) */; # add@ress (NAME)
			$From_address = $1;
			$From_2 = $1;					     
		    }
		    $User = substr($From_address, 1, 15);
		    # printf "From_address: %s\n", $From_address;
		    # printf "user: %s\n", $User;
		}

		# get subject (strip [id:user], move multiple Re:)
		if ($tag =~ /^Subject$/i) {
		    $Subject = $text; 			# default
		    if ($Subject =~ /Re: *\[.*\] *Re: *(.*)/) {
			$Subject = "Re: " . $1; 	# strip [id] and Re:
		    } elsif ($Subject =~ /^Re: *\[.*\] *(.*)/) { 
			$Subject = "Re: " . $1;		# strip [id] and Re:
		    } elsif ($Subject =~ /^.*\[.*\] *(.*)/) {
			$Subject = $1; 			# strip [id]
		    }
		    # printf "Subject: %s\n", $Subject;

		    }
	    }
	}
    }
    close(MAIL_BODY);
}

# distribute mail to member

sub DISTRIBUTE
{
    local($ID) = 0;
    local($mail_file, $to);
    
    # check mail from members
    if (&checkmember($From_address, $MEMBER_LIST) == 0) {
	&putlog(sprintf("Added: (%s)", $From_address));
	&sendmail($MAINTAINER, sprintf("NOT MEMBER article from %s", 
				       $From_address), $MAIL_BODY);
    }
    
    # make ID
    open(SEQUENCE_FILE);
    while (<SEQUENCE_FILE>) {
	$ID = $_;
    }
    $ID = $ID + 1;
    open(SEQUENCE_FILE, ">$SEQUENCE_FILE"); # close then open
    printf SEQUENCE_FILE "%d\n", $ID; # update sequence number
    close(SEQUENCE_FILE);

    # save summary and put log
    open(SUMMARY, ">>$SUMMARY_FILE");
    printf SUMMARY "%s [%d:%s] %s\n", $Now, $ID, $User, $Subject;
    close(SUMMARY);
    &putlog(sprintf("ARTICLE %d (%s)", $ID, $From_address));
    
    # save message
    if (! -d $SPOOL_DIR) {
	system "mkdir $SPOOL_DIR";
    }
    $mail_file = sprintf("%s/%d", $SPOOL_DIR, $ID);
    open(mail_file, ">$mail_file");
    close(mail_file);

    # Distribution mode
    open(ACTIVE_LIST) || &fatal("can't open $ACTIVE_LIST.\n");

    $_ = "";
    $to = "";
    $count = 0;
    @tothem = ();

  line: while (<ACTIVE_LIST>) {
      chop;			# strip newline
      next line if (/(.*)#/);	# strip comment
		    next line if /^[ \t]*$/; # skip null line
		    push(tothem,$_);    
		    $count++;
		}

      $headers = "HELO \nRSET\nMAIL FROM: $From\n";
      for(; $count > 0; $count--) {
#	  $to = $to . pop(tothem); for usual sendmail
	  $headers .= "RCPT TO: ". pop(tothem) . "\n";	  
      }
      close(ACTIVE_LIST);
      $headers .= "DATA\n";	  

      $IDTMP = substr("00000", 1, 5 - length($ID)) . "$ID";

      $body = 
	  "Date: $MailDate\n" . 
	  "To: $MAIL_LIST $ML_FN\n" . 
	  "From: $From\n" .
          "Return-Path: <$MAINTAINER>\n" .
	  "Subject: $Subject\n". 
          "Posted: $Date\n" .
          "Sender: $From\n" .
          "$XMLNAME: $XML\n" .
          "$MLCOUNT: $IDTMP\n" .
	      "Reply-To: ";
      $body .= 
	  $Reply_to ? $Reply_to : $MAIL_LIST;
      $body .= "\nErrors-To: ";
      $body .= 
	  $Errors_to ? $Errors_to : $MAINTAINER; 
      $body .= "\nLines: $BodyLines\n";

      open(MAIL_BODY);
      while (<MAIL_BODY>) {
	  $body .=  $_;
      }
      close(MAIL_BODY);
      $body .= ".\n";
      print "HEADERS:\n\n\n$headers";
      print "BODY   :\n\n$body";      
      &smtp($machine, $headers, $body);
      &cleanup;		# remove lock
}

# 
# addtional for YP_ML backup server 
# 
sub MAILBACK
{
    local($to) = $Reply_to ? $Reply_to : $From;
    local($line, $cmd, $subcmd, $ok, $subject);

    &sendmail($to, "HELP for phys ML:backup server", $YPHELP_FILE);
    &putlog(sprintf("HELP for Yuong Phys ML sent to <%s>", $From_address));
}

# checkmember(address, file)
# return 1 if given address belongs to member's else return 0

sub checkmember
{
    local($address, $file) = @_;

    open(FILE, $file) || return 0;
    line: while (<FILE>) {
	chop;
	if (/(.*)#/) {		# strip comment
	    $_ = $1;
	}
	if (/([^ \t]*)/) {	# strip space
	    $_ = $1;
	}
	next line if /^[ \t]*$/; # skip null line
	if (&fuzzyAddressMatch($_, $address) == 1) {
	    close(FILE);
	    return 1;
	}
    }
    close(FILE);
    return 0;
}

# makeActives()
# create actives file if not exist

sub makeActives
{
    if (! -f $ACTIVE_LIST) {
	open(MEMBER_LIST) || &fatal("NO MEMBER LIST!");
	open(ACTIVE_LIST, ">$ACTIVE_LIST");
	while (<MEMBER_LIST>) {
	    print ACTIVE_LIST $_;
	}
	close(ACTIVE_LIST);
	close(MEMBER_LIST);
    }

}

# changeMemberList(cmd, address, file)
# delete or add address from/to file

sub changeMemberList
{
    local($cmd, $address, $file) = @_;
    local($line);

    open(LIST, $file);
    open(NEW, ">hml.tmp");
  line:
    while (<LIST>) {
	$line = $_;		# save line
	chop;
	if (/(.*)#/) {
	    $_ = $1;		# strip comment
	}
	if (/([^ \t]*)/) {
	    $_ = $1;		# strip space
	}
	if (&fuzzyAddressMatch($_, $address) == 0) {	# copy if not match
	    print NEW $line;
	}
    }
    if ($cmd eq 'add') {	# add new entry
	print NEW $address, "\n";
    }
    close(NEW);
    close(LIST);
    rename('hml.tmp', $file);
}

# sub fuzzyAddressMatch($address1, $address2)
# return 1 given addresses are almost match else return 0

sub fuzzyAddressMatch
{
    local($address1, $address2) = @_;
    
    $address1 =~ y/A-Z/a-z/;	# canonicalize to lower case
    $address2 =~ y/A-Z/a-z/;
    # try exact match
    if ($address1 eq $address2) {
	return 1;
    }
    # try fuzzy match
    local($name1, $addr1) = split(/@/, $address1);
    local($name2, $addr2) = split(/@/, $address2);
    if ($name1 ne $name2) {
	return 0;			# name not match
    }
    local(@domain1) = split(/\./, $addr1);
    local($num1) = $#domain1;
    local(@domain2) = split(/\./, $addr2);
    local($num2) = $#domain2;
    local($match) = 0;
    while ($num1 > 0 && $num2 > 0) {
	if ($domain1[$num1] eq $domain2[$num2]) {
	    $match++;
	}
	$num1--;
	$num2--;
    }
    return ($match >= 3 ? 1 : 0);
}

# checkFileName(filename)
# return 1 if filename does not start with '/' and not include '.'.
# else return 0

sub checkFileName
{
    local($name) = @_;

    return 0 if ($name =~ /^\// || $name =~ /\./ || $name =~ /$HML/);
    return 1;
}
	

# fatal(msg)
sub fatal
{
    &putlog(@_);
    &cleanup;
    exit 0;
}

# putlog(msg)

sub putlog
{
    local($msg) = @_;

    # open then close; since this log will be called once in usual.
    open(LOG_FILE, ">>$LOG_FILE") || (&cleanup && die "Can't open $LOG_FILE\n");
    printf LOG_FILE "%s %s\n", $Now, $msg;
    close(LOG_FILE);
}

sub cleanup
{
    if (-f $MAIL_BODY) {
	unlink $MAIL_BODY;
    }
    if (-f $LOCK_FILE) {
	unlink $LOCK_FILE;
    } 
}
