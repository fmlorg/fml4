#!/usr/local/bin/perl

#printMembers.pl 
#given the name of a group (assume object class is groupOfUniqueNames) will
#display the members of the group including members of any groups that may be a member
#of the original group
#
#By default it will display the DN of the member entries, you can specify a particular 
#attribute you wish to display instead (e.g. mail attribute)

#example: printMembers.pl -n "Accounting Managers" 


#optionally you can also specify the host, port, binded search and search base.

#Mark Wilcox mark@mjwilcox.com
#
#first version: August 8, 1999

use strict;
use Carp;
use Net::LDAP;
use vars qw($opt_h $opt_p $opt_D $opt_w $opt_b $opt_n $opt_a );
use Getopt::Std;

my $usage = "usage: $0 [-hpDwba] -n group_DN";

die $usage unless @ARGV;

getopts('h:p:D:w:b:n:a:');

die $usage unless ($opt_n);

#get configuration setup
$opt_h = "airwolf" unless $opt_h;
$opt_p = 389 unless $opt_p;
$opt_b = "o=airius.com" unless $opt_b;


my $isGroup = 0; #checks for group or not

my $ldap = new Net::LDAP ($opt_h, port=> $opt_p);

#will bind as specific user if specified else will be binded anonymously
$ldap->bind(DN => $opt_D, password=> $opt_p) || die "failed to bind as $opt_D"; 


#get the group DN
my @attrs = ['dn'];
eval
{
   my $mesg = $ldap->search(
               base => $opt_b,
	       filter => "(&(cn=$opt_n)(objectclass=groupOfUniqueNames))",
	       attrs => @attrs
	       );

   die $mesg->error if $mesg->code;

   my $entry = $mesg->pop_entry();

   my $groupDN = $entry->dn();

   &printMembers($groupDN,$opt_a);
   $isGroup = 1;
};

print "$opt_n is not a group" unless ($isGroup);

$ldap->unbind();


sub printMembers
{
  my ($dn,$attr) = @_;

  my @attrs = ["uniquemember"];

  my $mesg = $ldap->search(
               base => $dn,
	       scope => 'base',
	       filter => "objectclass=*",
	       attrs => @attrs
	      );

  die $mesg->error if $mesg->code;

  #eval protects us if nothing is returned in the search

  eval
  {

     #should only be 1 entry
     my $entry = $mesg->pop_entry();

     print "\nMembers of group: $dn\n";

     #returns an array reference
     my $values = $entry->get("uniquemember");

     foreach my $val (@{$values})
     {
       my $isGroup = 0; #lets us know if the entry is also a group, default no

       #change val variable to attribute

       #now get entry of each member
       #is a bit more efficient since we use the DN of the member
       #as our search base, greatly reducing the number of entries we 
       #must search through for a match to 1 :)

       my @entryAttrs = ["objectclass",$attr];

       $mesg = $ldap->search(
               base => $val,
	       scope => 'base',
	       filter => "objectclass=*",
	       attrs => @entryAttrs
	      );

      die $mesg->error if $mesg->code;

      eval
     {
        my $entry = $mesg->pop_entry();


        if ($attr)
	{
          my  $values = $entry->get($attr);

           foreach my $vals (@{$values})
           {
             print $vals,"\n";
           }
	}
        else
	{
           print "$val\n";
	}

        my $values = $entry->get("objectclass");

        # This value is also a group, print the members of it as well  

        &printMembers($entry->dn(),$attr) if (grep /groupOfUniqueNames/, @{$values});
     };
   } 
 };
    return 0;
  }






