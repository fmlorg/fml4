# library for schwalben Chor ML
$libschid   = q$Id$;
($libschid) = ($libschid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid  .= "/$libschid";

##### Custumization #####
#   schwalben-info@cs.titech.ac.jp    Schwalbenに関する最新情報
# adddress
# file of info
# Subject of the returned mail

$INFOADDR     = "schwalben-info@phys.titech.ac.jp";
$INFO         = "$DIR/info";
$INFOSubject  = "Schwalben Chor Info";

#   schwalben-list@cs.titech.ac.jp    Schwalben E-mail Address List 最新版
$LISTADDR     = "schwalben-list@phys.titech.ac.jp";
$ALLLIST_FILE = "$DIR/alllist";
$LISTSubject  = "Schwalben Chor All List";

# configuration: a list for available addresses
@addr = ('all', 'top', 'sec', 'bari', 'bass', 'student', '1987');

# configuratrion for each available MailingList Address and the files
$ML_THREAD = "\
    \$SPOOL_DIR	        = \"\$DIR/spool-\$ADDR\";\
    \$MEMBER_LIST 	= \"\$DIR/members-\$ADDR\";\
    \$ACTIVE_LIST 	= \"\$DIR/actives-\$ADDR\";\
    \$SUMMARY_FILE 	= \"\$DIR/summary-\$ADDR\";\
    \$SEQUENCE_FILE 	= \"\$DIR/seq-\$ADDR\";\
";

##### Custumization ends #####

&Schwalben;

sub Schwalben
{
    local(@MailHeaders) = split(/\n/, $MailHeaders, 999);
    while($_ = $MailHeaders[0], shift @MailHeaders) {
	print STDERR "$_\n";
	if(/^To: *.* *<(\S+)> *.*$/io) { $To_address = $1; next;}
	if(/^To: *(\S+) *.*$/io)       { $To_address = $1; next;}
    }

    print STDERR  $To_address, "<---To_adress\n" if($debug);
    &Logging("$To_address from $From_address");
    &SchwalbenSpecial;

    # for each mail address, configure each configuration file    
    $To_address =~ /.*schwalben\-(.*)@.*/io;
    $ADDR = $1;

    # check the address whether it is available address or not?
    # if not matched, log, send a mail back, unlock and exit
    CheckLoop: 
    for(;;) {
	if($ADDR eq $addr[0]) {last CheckLoop;}
	if(0 == scalar(@addr)) {
	    &Logging("No such address: $To_address requested from $From_address");
	    &Sendmail($From_address, "No address $To_address: Please check");
	    (!$USE_FLOCK) ? &Unlock : &Funlock;    
	    exit 0;
	}
	shift @addr;
    }

    # set variables of filenames corresponding to the given address
    eval $ML_THREAD;
    
    # initialize when no spool or no file
    eval "do \'setup.pl\'";
    
    # debug code
    print STDERR "e.g summary file is set to $SUMMARY_FILE\n" if($debug);
}

# when info and list are requested, 
# send back a mail on info and list, unlock and exit.
sub SchwalbenSpecial
{
    # special address for sending back only 
    #   schwalben-info@cs.titech.ac.jp    Schwalbenに関する最新情報
    #   schwalben-list@cs.titech.ac.jp    Schwalben E-mail Address List 最新版
    if( $INFOADDR eq $To_address ) { 
	&SendFile($From_address, $INFOSubject, $INFO);
	&Logging("info request from $From_address");
	(!$USE_FLOCK) ? &Unlock : &Funlock;    
	exit 0;
    }
    
    if( $LISTADDR eq $To_address ) { 
	&SendFile($From_address, $LISTSubject, $ALLLIST_FILE);
	&Logging("list request from $From_address");
	(!$USE_FLOCK) ? &Unlock : &Funlock;
	exit 0;
    }
}    

# debug code
if(__FILE__ eq $0) {
    $DIR = "/tmp";
    $debug = 'on';
    print STDERR "Debug Mode\n";
    while(<>) {
	chop;
	print $To_address = $_;
    }
}
# debug code ends

1;
