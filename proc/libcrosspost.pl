# Copyright (C) 1994-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public License(see ./COPYING)
# Crosspost Operation
local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

##### Class Crosspost: public fml #####
&Debug("Loading Crosspost") if $debug;

# private 
local($ML_SPOOL, $CACHE_DIR, *CacheEntry, *ML, *Entry);


# Delivered in the "last-matched mailinglist"
# export is
#      %NORCPT;
# %NORCPT = ( address => "the-last-match-ML in ML-1,2,3 ... joined-lists", ..);
# %Entry  = ( address => "matched ML-1,2,3 ... joined-lists", ..) for debug
# return NONE; fml.pl uses %NORCPT INFORMATION in Distribution phase
# see "sub Distribute"
sub Crosspost 
{

    &Debug("&CrosspostInit; # reading Cache Entry..") if $debug;

    &CrosspostInit;		# reading Cache Entry..
    &CrosspostGetEntry;		# effective ML's -> @Crosspost
    &CrosspostGetAddrLists;	# how-the-addr-is-joined-list -> %NORCPT
    &CrosspostFixHeader;	# reply-to: and crosspost-infomation

    foreach $who (keys %NORCPT) {
	$Envelope{'xref:'} .= " $who";
	if ($debug) {
	    $Entry{$who} =~ s/phys.titech.ac.jp//g;
	    print STDERR "$who::\t$Entry{$who}\n" if $debug;
	}

	if ($NORCPT{$who} =~ /$MAIL_LIST/i) {
	    &Debug("NOT DELIVER ($who):\n\t$NORCPT{$who} =~ /$MAIL_LIST/i") 
		if $debug;
	    undef $NORCPT{$who}; # no-entry -> deliver in &Distribute
	}
    }

    if ($debug && -f $LockFile) { # for MASTER SOURCE DEBUG
	print STDERR "***** LOCK FILE EXISTS *****, wait....\n";
    }
}


# Initialize
sub CrosspostInit
{
    # CONFIGURATION
    $ML_SPOOL  = "/home/axion/fukachan/work/spool";
    $CACHE_DIR = "/home/axion/fukachan/work/spool/EXP/contrib/Crosspost/Cache";

    &CrosspostReadCacheCF("$CACHE_DIR/Cache");
    &CrosspostReadCacheCF("$CACHE_DIR/Config.fml");
}


# MAIN: reverse order is important;
# @Crosspost: effective ML's
# return NONE
sub CrosspostGetEntry
{
    local($to) = $Envelope{'mode:chk'};
    local($which_ml, $entry);

    # accuracy of the level 'domain', so cannot using %CacheEntry ;-)
  ENTRY: foreach $entry (reverse split(/\s*,\s*/, $to) ) {
      undef $which_ml;		# reset

      # try $entry for each entry in Cache
      foreach (keys %CacheEntry) {
	  # match within effective cached ML's
	  if (/$entry/i || &AddressMatch($entry, $_)) { # exact or domainname
	      $which_ml = $_;	
	      push(@Crosspost, $which_ml) if $which_ml; # effective ML
	  }
      }

      # Skip if not have cache data for "$entry-Mailing-List in some.domain"
      next ENTRY unless $which_ml;

      if ($debug) {
	  print STDERR "ML    = $which_ml\n";
	  print STDERR "Cache = $CacheEntry{$which_ml}\n";
	  print STDERR "\n";
      }

  }# foreach;
}


# Get member files of $ml and overwrite if matched
# since last-match entry is important
sub CrosspostGetAddrLists
{
    local($ml);

    foreach $ml (@Crosspost) {
	if (-f $ML{$ml, 'list'} && open(FILE, $ML{$ml, 'list'})) {
	  line: while(<FILE>) {
	      next line if /^\s*$/o;
	      next line if /^\#/o;

	      # for sailor-*@axion.phys.titech.ac.jp ML
	      /^\#(\S+)\%(\S+)@\S+\s*$/ && ($_ = "$1\@$2");
	      /^(\S+)\%(\S+)@\S+\s*$/   && ($_ = "$1\@$2");

	      ($who, $mx) = split(/\s+/, $_);
	      $who =~ s/(\S+)\@\S+\.(\S+\.\S+\.\S+\.\S+)/$1\@$2/;

	      # print STDERR "\$NORCPT{$who} = $ml;\n" if $debug;

	      $NORCPT{$who} = $ml;# overwrite is essential;
	      $Entry{$who} .= " $ml";# debug info
	  }
	    close(FILE);
	}# while;
	else {
	    print STDERR "Canont open $_::list->$ML{$_, 'list'}\n" if $debug;
	}# fi;

    } # foreach;
}


sub CrosspostFixHeader
{
    if ($Envelope{'h:Reply-To:'}) {
	;
    }
    else {
	$Envelope{'h:Reply-To:'} = join(", ", reverse @Crosspost); 
	foreach(reverse @Crosspost) { 
	    $Envelope{'Crosspost:lists'} .= (split(/@/,$_))[0];
	}
    }
}


sub CrosspostReadCacheCF
{
    local($f, $m) = @_;

    open(f) || &Log("Cannot open $f");
    while(<f>) {
	next if(/^\#/o);	# skip comment and off member
	next if(/^\s*$/o);	# skip null line
	($a, $b) = split;
	if(&CrosspostReadCF($a, $b)) {
	    ;
	}else {
	    $CacheEntry{$a} = "$CACHE_DIR/$b";
	}
    }
    close(f);
}


# Consider auto-registration or not? and 
# put data to %Crosspost
sub CrosspostReadCF
{
    local($ml, $dir)   = @_;
    local($dir)        = "$ML_SPOOL/$dir"; 
    local($configfile) = "$dir/config.ph"; 
    local($mcheck, $m, $a);

    open(FILE, $configfile) || return 0;
    while(<FILE>) {
	/^\$ML_MEMBER_CHECK\s*=\s*(\S+);/  && ($mcheck = $1);
	/^\\$MEMBER_LIST\s*=\s*\"(\S+)\";/ && ($m = $1);
	/^\$ACTIVE_LIST\s*=\s*\"(\S+)\";/  && ($a = $1);
    }
    close(FILE);

    # fix $DIR
    $m =~ s/\$DIR/$dir/;
    $a =~ s/\$DIR/$dir/;

    # set member-check or not? and the list to deliver for the ML
    $ML{$ml, 'check'} = $mcheck;
    $ML{$ml, 'list'}  = $mcheck ? $a : $m;

    return 1;
}

1;

