# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# Crosspost Operation
# $Id$;

##### Class Crosspost: public fml #####
local(@DeliveryList);

#
# Crosspost Protocol
#
# Set %SKIP ($SKIP{$addr} = 1) if 
#    1 search which ML "addr" is registered in the fields "To: Cc: " 
#    2 $MAIL_LIST == the first entry of the registered list
#    3 $SKIP{$addr} = 1
#
#    4 this process is done in all mailing lists (pararelly)
#

&Debug("---Loading Crosspost") if $debug;

### Initialize
&Crosspost'Init(*Envelope, *CROSSPOST_CF); #';

&Debug("---Loading Crosspost Ends") if $debug;

package Crosspost;

# import
sub Crosspost'Log          { &main'Log(@_);}
sub Crosspost'AddressMatch { &main'AddressMatch(@_);}
sub Crosspost'Conv2mailbox { &main'Conv2mailbox(@_);}


sub Init
{
    local(*e, *CROSSPOST_CF) = @_;
    local(@trap, @scan_list, $scan_start);
    local($trap) = $e{'trap:rcpt_fields'};

    # DataBase Access
    # XXX If you uses database access, you cannot use crosspost.
    # XXX This logic requires database access for all mailing lists, isnt it? 
    if ($USE_DATABASE) {
	&Log("WARN: you cannot use USE_CROSSPOST with USE_DATABASE");
	return;
    }

    # Error Handling
    if (! @CROSSPOST_CF) {
	&Log("ERROR: please define \@CROSSPOST_CF to use \$USE_CROSSPOST");
	return;
    }


    @import = ("MAIL_LIST", "VARDB_DIR", "FP_VARDB_DIR");
    for (@import) { 
	eval("\$Crosspost'$_ = \$main'$_;");
	&Log("ERROR: eval $_ [$@]\n") if $@;
    }

    # debug
    $Crosspost'debug = $main'debug;

    # Set Hash Table %MLDir { $ml => $ml_home_directory }
    # *** mailing list name is lower case
    for (@CROSSPOST_CF) { &ReadCrosspostCF($_);}

    # flush
    if (-f "$FP_VARDB_DIR/crosspost.db") {
	print STDERR "unlink $FP_VARDB_DIR/crosspost.db\n" if $debug;
	unlink "$FP_VARDB_DIR/crosspost.db";
    }
    elsif (-f "$FP_VARDB_DIR/crosspost.pag") {
	print STDERR "unlink $FP_VARDB_DIR/crosspost.{pag,dir}\n" if $debug;
	unlink "$FP_VARDB_DIR/crosspost.pag";
	unlink "$FP_VARDB_DIR/crosspost.dir";
    }


    # search To: Cc: 
    # If To: A, B, C, D ... and  Cc: E, F, ..., we scan A,B,C,...E,F,...
    # If B == $MAIL_LIST, we should scan B => A
    # If C == $MAIL_LIST, we should scan C => B => A
    # 
    # If, A or B has $addr as a delivery member, we set $NoRcpt{$addr} = 1;
    $trap =~ s/^\s*//;
    for (split(/\s*,\s*/, $trap)) { 
	next unless $_;
	push(@trap, &Conv2mailbox($_));
    }

    # If To: A, B, C, scan C -> B -> A ..
    for (reverse @trap) {
	$scan_start = 1 if $_ eq $MAIL_LIST || &AddressMatch($_, $MAIL_LIST);
	push(@scan_list, $_) if $scan_start;
    }

    if ($debug) { 
	print STDERR "   === crosspost scan maling list entries ===\n";
	print STDERR "\t", join("\n\t",@scan_list), "\n"; 
	print STDERR "   === crosspost scan maling list entries end ===\n";
    }

    # scan C -> B -> A ..
    # set hash $WhichMLDeliver{$addr} => {C,B,A} in all entries;
    # with overwriting;
    local($ml, $list, $first_time);

    # full scanning is required for the first time(== $MAIL_LIST);
    # but we need to scan only members of $MAIL_LIST for other ML's. 
    $first_time = 1;

  scan: for $ml (@scan_list) {
      print STDERR "   ml: $ml\n" if $debug;
      next scan unless $ml;

      # *** mailing list name is lower case
      $ml =~ tr/A-Z/a-z/;

      $dir = $MLDir{$ml};

      if (! $dir) {
	  &Log("ERROR: Crosspost: directory not defined for ML $ml");
	  next scan;
      } 

      if (! -d $dir) {
	  &Log("ERROR: Crosspost: not exist $dir for ML $ml");
	  next scan;
      } 

      print STDERR "   scan: $ml => [$dir]\n" if $debug;

      # which active or members we should eval ?
      # eval ("do $dir/config.ph");
      # set @DeliveryList to scan;
      &EvalConfigPH("$dir/config.ph", $dir, $ml);

      for $list (@DeliveryList) {
	  # set %WMD;
	  &Scan($list, $ml, $first_time);
      }

      undef $first_time;
  }

    if ($debug) {
	dbmopen(%WMD, "$FP_VARDB_DIR/crosspost", 0400);
	for (keys %WMD) {
	    print STDERR "\t$_\t=>\t$WMD{$_}\n";
	}
	dbmclose(%WMD);
    }
}


sub Scan
{
    local($f, $ml, $first_time) = @_;
    local($addr);

    # 0600 is enough strict since distribution is concerned;
    dbmopen(%WMD, "$FP_VARDB_DIR/crosspost", 0600);

    print STDERR "   Scan($f)\n" if $debug;

    if (-f $f && open(FILE, $f)) {
	;
    }
    else {
	&Log("ERROR: Crosspost::Scan $f not exist");
	return 0;
    }

    scanbuf: while (<FILE>) {
	chop;
	next scanbuf if /^\#/o;   # skip comment and off member
	next scanbuf if /^\s*$/o; # skip null line
	next scanbuf if /matome/i;
	next scanbuf if /skip/i;
	next scanbuf if /[ms]=/i;

	if (/^(\S+)/) {
	    $addr = $1;
	    $addr =~ tr/A-Z/a-z/;

	    # if not first time, we need to scan $addr 
	    # which is already $WMD{$addr} != NULL;
	    next scanbuf if !$first_time && !$WMD{$addr};

	    print STDERR "\t\$WMD{$addr} = $ml;\n" if $debug;
	    $WMD{$addr} = $ml;
	}
    }

    close(FILE);
    dbmclose(%WMD);

    print STDERR "   Scan($f) Ends\n" if $debug;
}


sub ReadCrosspostCF
{
    local($f) = @_;
    local($ml, $dir);

    if (-f $f && open(IN, $f)) {
	;
    }				# 
    else {
	&Log("Cannot open $f");
	return 0;
    }

    while (<IN>) {
	next if /^\#/o;		# skip comment and off member
	next if /^\s*$/o;	# skip null line

	($ml, $dir) = split;

	$ml =~ tr/A-Z/a-z/;	# do lower only "$ml" NOT $dir;
	$MLDir{$ml} = $dir;
    }
    close(IN);
}


sub EvalConfigPH
{
    local($f, $dir, $ml)   = @_;
    local($buf);

    $crosspost_ns'DIR = $dir; #';

    package crosspost_ns;

    undef @DeliveryList;
    undef $AutoRegistP;

    # XXX 3.0B new loadconfig 2000/03/19
    require 'libloadconfig.pl'; &__LoadConfiguration;

    if ($CFVersion >= 3) {
	# fml 2.x
	if ($REJECT_POST_HANDLER    =~ /auto_regist/ ||
	    $REJECT_COMMAND_HANDLER =~ /auto_regist/) {
	    $AutoRegistP = 1;
	}
    }
    # $CFVersion < 3
    else {
	if (! $ML_MEMBER_CHECK) { $AutoRegistP = 1;}
    }

    # fml 3.x not use active/members difference no more.
    if ($AutoRegistP) {
	push(@DeliveryList, @MEMBER_LIST);
	push(@DeliveryList, $MEMBER_LIST);
    }
    else {
	push(@DeliveryList, @ACTIVE_LIST);
	push(@DeliveryList, $ACTIVE_LIST);
    }

    # export
    # XXX: rename DELIVERY_LIST to DeliveryList (since global but not
    # user-defined) but not changed. fixed on 1999/06/24 by 
    # fml-support: 6368, Atushi Sakauchi <sakauchi@micon.co.jp>
    @Crosspost'DeliveryList = @crosspost_ns'DeliveryList;
}


1;
