# Copyright (C) 1994-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      kfuka@iij.ad.jp, kfuka@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)
# Crosspost Operation
local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && $1."[$2]");

##### Class Crosspost: public fml #####
&Debug("Loading Crosspost") if $debug;

# Delivered in the "last-matched mailinglist"
# export is
#      %NoRcpt;
# %NoRcpt = ( address => "the-last-match-ML in ML-1,2,3 ... joined-lists", ..);
# %Entry  = ( address => "matched ML-1,2,3 ... joined-lists", ..) for debug
# return NONE; fml.pl uses %NoRcpt INFORMATION in Distribution phase
# see "sub Distribute"
sub Crosspost 
{
    local(*cr);			# effective  ;
				# @cr : ARRAY ( Effective-ML-address ... )
				# %cr : HASH
    local(*e);			# @e : ARRAY ( ML-address ... )
				# %e : HASH  { ML-address => list-file }

    &CrosspostInit(*e);		# reading Cache Entry..

    &CrosspostGetEntry(*e, *cr);# effective ML's -> @cr
				# determine which ML's listfile to open.

    &CrosspostGetAddrLists(*e, *cr);
				# how-the-addr-is-joined-list -> %NoRcpt
				# NoRcpt is GLOBAL => fml.pl
				# %cr is debug info

    &CrosspostFixHeader(*e, *cr);
				# reply-to: and crosspost-infomation

    foreach $who (keys %NoRcpt) {
	if ($debug) {
	    $cr{$who} =~ s/phys.titech.ac.jp//g;
	    printf STDERR "%-30s::\t%s\n", $who, $cr{$who} if $debug;
	}

	if ($NoRcpt{$who} =~ /$MAIL_LIST/i) {
	    &Debug("NOT DELIVER ($who):\n\t$NoRcpt{$who} =~ /$MAIL_LIST/i") 
		if $debug;
	    undef $NoRcpt{$who}; # no-entry -> deliver in &fml.pl::Distribute
	}
    }

    if ($debug) { # for MASTER SOURCE DEBUG
	&Debug("***** LOCK FILE EXISTS *****, wait...") if -f $LockFile;
    }
}


# MAIN: reverse order is important;
# @cr: get effective ML's within entries { @e, %e }
# return NONE
sub CrosspostGetEntry
{
    local(*e, *cr) = @_;
    local($to) = $Envelope{'mode:chk'};
    local($which_ml, $entry);

    # accuracy of the level 'domain', so cannot using %CacheEntry ;-)
  ENTRY: foreach $entry (reverse split(/\s*,\s*/, $to) ) {
      undef $which_ml;		# reset

      # try $entry for each entry in %e
      foreach (@e) {
	  # match within effective cached ML's
	  if (/$entry/i || &AddressMatch($entry, $_)) { # exact or domainname
	      $which_ml = $_;	
	      push(@cr, $which_ml) if $which_ml; # effective ML
	  }
      }

      # Skip if not have cache data for "$entry-Mailing-List in some.domain"
      next ENTRY unless $which_ml;

      if ($debug) {
	  print STDERR "ML    = $which_ml\n";
	  print STDERR "Cache = $e{$which_ml, 'list'}\n";
	  print STDERR "\n";
      }

  }# foreach;
}


# Get member files of $ml and overwrite if matched
# since last-match entry is important
sub CrosspostGetAddrLists
{
    local(*e, *cr) = @_;
    local($ml, $log);
    
    foreach $ml (@cr) { # for each effective ML
	# DEBUG
	if ($debug) {
	    local($list) = $ML{$ml, 'list'};
	    $list =~ s@/home/axion/fukachan/work/spool@\$ML_SPOOL@;
	    # print STDERR "OPEN $ml::LIST\t$list\n";
	}

	if (-f $e{$ml, 'list'} &&
	    open(FILE, $e{$ml, 'list'})) {
	  line: while(<FILE>) {
	      next line if /^\s*$|^\#/o;

	      # for sailor-*@axion.phys.titech.ac.jp ML's
	      /^\#(\S+)\%(\S+)@\S+\s*$/ && ($_ = "$1\@$2");
	      /^(\S+)\%(\S+)@\S+\s*$/   && ($_ = "$1\@$2");

	      ($who) = split(/\s+/, $_);
	      $who =~ s/(\S+)\@\S+\.(\S+\.\S+\.\S+\.\S+)/$1\@$2/;

	      $cr{$who}    .= " $ml";# debug info

	      # NoRcpt IS GLOBAL => fml.pl
	      $NoRcpt{$who} = $ml;   # overwrite is essential;
	  }
	    close(FILE);
	}# if;
	else {
	    $log .= "Canont open $ml::list->$e{$ml, 'list'}\n";
	}# fi;

    } # foreach;

    &Debug("GetAddressList error:\n$log") if $debug && $log;
}


sub CrosspostFixHeader
{
    local(*e, *cr) = @_;

    if ($Envelope{'h:Reply-To:'}) { 
	; # if reply-to: exists, do nothing
    }
    else {
	$Envelope{'h:Reply-To:'} = join(", ", reverse @Crosspost); 
	foreach(reverse @cr) { 
	    $Envelope{'Crosspost:lists'} .= " ".(split(/@/,$_))[0];
	}
    }
}


# Initialize
sub CrosspostInit
{
    local(*e) = @_;
    
    # CONFIGURATION
    $ML_SPOOL  = $CROSSPOST_CACHE_SPOOL || "/home/axion/fukachan/work/spool";
    $CACHE_DIR = "$ML_SPOOL/EXP/contrib/Crosspost/Cache";

    &CrosspostReadCacheCF("$CACHE_DIR/Cache", *e);
    &CrosspostReadCacheCF("$CACHE_DIR/Config.fml", *e);
}


sub CrosspostReadCacheCF
{
    local($f, *e) = @_;

    print STDERR "Open Cache: Reading Entry " if $debug;

    -f $f && open(f) || &Log("Cannot open $f");
    while(<f>) {
	next if(/^\#/o);	# skip comment and off member
	next if(/^\s*$/o);	# skip null line
	($ml, $b) = split;

	print STDERR "." if $debug;

	# get ML_MEMBER_CHECK::INFO -> 
	# @e ML-addr-1, ML-addr-2, ML-addr-3
	# %e $e{ML-addr-1, "list|check"}
	&CrosspostReadConfigPH($ml, $b, *e); 
    }
    close(f);

    print STDERR " Done.\n" if $debug;
}


# Consider auto-registration or not? and 
# put data to %Crosspost
sub CrosspostReadConfigPH
{
    local($ml, $dir, *e)   = @_;
    local($dir)        = "$ML_SPOOL/$dir"; 
    local($configfile) = "$dir/config.ph"; 
    local($mcheck, $m, $a);

    -f $configfile && open(FILE, $configfile) || return 0;
    while(<FILE>) {
	next unless /^\$/;
	/^\$ML_MEMBER_CHECK\s*=\s*(\S+);/  && ($mcheck = $1);
	/^\$MEMBER_LIST\s*=\s*\"(\S+)\";/  && ($m = $1);
	/^\$ACTIVE_LIST\s*=\s*\"(\S+)\";/  && ($a = $1);
    }
    close(FILE);

    # fix $DIR
    $m =~ s/\$DIR/$dir/;
    $a =~ s/\$DIR/$dir/;

    # set member-check or not? and the list to deliver for the ML
    push(@e, $ml);
    $e{$ml, 'check'} = $mcheck;
    $e{$ml, 'list'}  = $mcheck ? $a : $m;
}

1;
