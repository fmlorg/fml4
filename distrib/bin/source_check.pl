#!/usr/bin/env perl


use strict;
use FileHandle;

my @VARS = ();

my $fh = new FileHandle "cf/MANIFEST";

while (<$fh>) {
    if (/^([A-Z0-9_]+):/) {
	my $x = $1;
	push(@VARS, "\$${x}");
	if ($x =~ /_DIR/)  {
	    push(@VARS, "\$FP_${x}");
	}
    }
}


push(@VARS, qw($DIR @LIBDIR
	       $NULL $DO_NOTHING
	       $FML $MyProcessInfo
	       $CFVersion $MailDate $From_address

	       @HdrFieldsOrder %HdrFieldCopy
	       @ResentForwHdrFieldsOrder @ResentHdrFieldsOrder

	       %SecureRegExp
	       %SECURE_REGEXP
	       %INSECURE_REGEXP


	       @PermitProcedure @DenyProcedure %LocalProcedure
	       @PermitAdminProcedure @DenyAdminProcedure %LocalAdminProcedure
	       @MailContentHandler

	       %Envelope %e

	       $DEBUG_OPT_VERBOSE_LEVEL_2
	       $DEBUG_OPT_DELIVERY_ENABLE

	       %REJECT_HDR_FIELD_REGEXP_REASON
	       %REJECT_HDR_FIELD_REGEXP
	       %LOOP_CHECKED_HDR_FIELD

	       @ACTIVE_LIST
	       @MEMBER_LIST

	       $START_HOOK $DISTRIBUTE_START_HOOK $SMTP_OPEN_HOOK
	       $HEADER_ADD_HOOK $DISTRIBUTE_CLOSE_HOOK
	       $DISTRIBUTE_END_HOOK $ADMIN_COMMAND_HOOK
	       $RFC1153_CUSTOM_HOOK $MSEND_OPT_HOOK $FML_EXIT_HOOK
	       $FML_EXIT_PROG $MSEND_START_HOOK
	       $REPORT_HEADER_CONFIG_HOOK $AUTO_REGISTRATION_HOOK
	       $MSEND_HEADER_HOOK $SMTP_CLOSE_HOOK $MODE_BIFURCATE_HOOK
	       $HTML_TITLE_HOOK $PROCEDURE_CONFIG_HOOK
	       $ADMIN_PROCEDURE_CONFIG_HOOK $COMMAND_HOOK
	       $REJECT_DISTRIBUTE_FILTER_HOOK
	       $REJECT_COMMAND_FILTER_HOOK
	       ));

for my $file (@ARGV) {
    my $tmp = "/tmp/$$.pl";
    my $wh  = new FileHandle "> $tmp";

    print $wh "use strict;\n";
    print $wh "use vars qw(@VARS);\n";

    my $fh = new FileHandle $file;
    while (<$fh>) { $wh->print($_);}
    $fh->close;

    $wh->close;

    my $rh = new FileHandle;
    my @inc = <module/*>;
    my $opt = "-I" . join(" -I ", @inc);
    if (open($rh, "perl $opt -cw $tmp 2>&1 |")) {
	print STDERR "check $file ... ";

	my $buf;
	my $i = 0;
	my $fix_count = 0;
	while (<$rh>) {
	    $i++;
	    $buf .= $_;

	    $fix_count++ if /\$* is deprecated/;

	    if ($i == (1 + $fix_count) && /syntax OK\s*$/) {
		print STDERR "ok\n";
		undef $buf;
		last;
	    }
	}
	close($rh);

	if ($buf) {
	    print STDERR "bad\n$buf\n\n";
	}
    }
    else {
	print STDERR $@;
    }

    unlink $tmp;
}
