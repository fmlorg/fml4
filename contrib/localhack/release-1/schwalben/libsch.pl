# library for schwalben Chor ML
$libschid   = q$Id$;
($libschid) = ($libschid =~ /Id: *(.*) *\d\d\d\d\/\d+\/\d+.*/); 
$rcsid  .= "/$libschid";

##### Custumization #####
# schwalben-list@cs.titech.ac.jp    Schwalben E-mail Address List 最新版
# $ALLLIST_FILE = "$DIR/$MEMBER_FILE" is also right?
$LISTADDR     = "schwalben-list@cs.titech.ac.jp";
$ALLLIST_FILE = "$DIR/../spools/spool-info/alllist";
$LISTSubject  = "Schwalben Chor All List";

# schwalben-list@cs.titech.ac.jp    Schwalben E-mail Address List 最新版
# $ALLLIST_FILE = "$DIR/$MEMBER_FILE" is also right?
$AnonymousADDR     = "schwalben-anonymous@cs.titech.ac.jp";
$Anonymous_FILE    = "$DIR/../spools/spool-info/Anonymous";
$AnonymousSubject  = "Schwalben Chor Anonymous File Service";

# library functions are below
# &SchwalbenConfig;
# &SchwalbenSpecialAddress; for special addresses e.g. anonymous, list.. 

# this library should be called 
# after &Parsing and &GetFieldsFromHeader 
sub SchwalbenConfig
{
    if($INFO_Requested && !$CommandMode) {
        $MEMBER_LIST 	= "$DIR/../members/members-$ADDR";
    }
    if($Anonymous_Requested) {
        $MEMBER_LIST 	= "$DIR/../members/members-$ADDR";
        $ML_MEMBER_CHECK = 0;
    }

    &Logging("Request: To:$To_address");
    &Logging("Request: Cc:$Cc_address") if $Cc_address;
    &Logging("From:$From_address");
    &Logging("This Session for schwalben-$ADDR");

    # initialize when no spool or no file
    &InitConfig;
    
    # debug code
    print STDERR "e.g summary file is set to $SUMMARY_FILE\n" if($debug);
    print STDERR "    memvers file is set to $MEMBER_LIST\n"  if($debug);
}

# when info and list are requested, 
# send back a mail on info and list, unlock and exit.
sub SchwalbenSpecialAddress
{
    #   schwalben-list@cs.titech.ac.jp    Schwalben E-mail Address List 最新版
    
    if( $LIST_Requested ) { 
	&SendFile($From_address, $LISTSubject, $ALLLIST_FILE);
	&Logging("list request from $From_address");
	(!$USE_FLOCK) ? &Unlock : &Funlock;
	exit 0;
    }

    if( $Anonymous_Requested ) { 
	&SendFile($From_address, $AnonymousSubject, $Anonymous_FILE);
	&Logging("Anonymous request from $From_address");
	(!$USE_FLOCK) ? &Unlock : &Funlock;
	exit 0;
    }

}    

1;
