#!/usr/local/bin/perl

#isMember.pl 
#pass the common name of a group entry (assuming groupOfUniqueNames objectclass) and 
#a uid, the script will tell you if the uid is a member of the group or not.

$version = 2.0;

#in this version, the uid is a member of the given group if:
#are a member of the given group
#or are a member of a group who is a member of the given group

#Mark Wilcox mark@mjwilcox.com
#
#first version: August 8, 1999
#second version: August 14, 1999

#bugs: none ;)
#
#To Do: add support of Netscape Directory Server's dymanic groups 

use strict;
use Carp;
use Net::LDAP;
use vars qw($opt_h $opt_p $opt_D $opt_w $opt_b $opt_n $opt_u );
use Getopt::Std;


my $DEBUG = 1;

my $usage = "usage: $0 [-hpDwb] -n group_name -u uid ";

die $usage unless @ARGV;

getopts('h:p:D:w:b:n:u:');

die $usage unless ($opt_n && $opt_u);

#get configuration setup
$opt_h = "airwolf" unless $opt_h;
$opt_p = 389 unless $opt_p;
$opt_b = "o=airius.com" unless $opt_b;

my $isMember = 0; # by default you are not a member


my $ldap = new Net::LDAP ($opt_h, port=> $opt_p);

#will bind as specific user if specified else will be binded anonymously
$ldap->bind(DN => $opt_D, password=> $opt_p) || die "failed to bind as $opt_D"; 


#get user DN first
my @attrs = ["dn"];

my $mesg = $ldap->search(
               base => $opt_b,
	       filter => "uid=$opt_u",
	       attrs => @attrs
	      );

eval
{

    my $entry = $mesg->pop_entry();

   print "user is ",$entry->dn(),"\n" if $DEBUG;
   my $userDN = $entry->dn();

    #get original group DN
    $mesg = $ldap->search(
               base => $opt_b,
	       filter => "(&(cn=$opt_n)(objectclass=groupOfUniqueNames))",
	       attrs => @attrs
	       );

    $entry = $mesg->pop_entry();
   my $groupDN = $entry->dn();

   print "group is $groupDN\n" if $DEBUG;


   $isMember = &getIsMember($groupDN,$userDN);

}; 


die $mesg->error if $mesg->code;

#


if ($isMember)
{
  print "$opt_u is a member of group $opt_n\n";
}
else
{
  print "$opt_u is not a member of group $opt_n\n";
}


$ldap->unbind();

sub getIsMember
{
   my ($groupDN,$userDN) = @_;

   my $isMember = 0;


   eval
   {

       #if user is a member then this will compare to true and we're done

      my $mesg = $ldap->compare($groupDN,attr=>"uniquemember",value=>$userDN);

      print $mesg->code(),":$groupDN:$userDN\n" if $DEBUG;
      if ($mesg->code() == 6)
      {
        $isMember = 1;
        return $isMember;
      }


      #ok so you're not a member of this group, perhaps a member of the group
      #is also a group and you're a member of that group


      my @groupattrs = ["uniquemember","objectclass"];

      $mesg = $ldap->search(
               base => $groupDN,
	       filter => "(&(cn=$opt_n)(objectclass=groupOfUniqueNames)",
	       attrs => @groupattrs
	       );

      my $entry = $mesg->pop_entry();

      my $values = $entry->get("uniquemember");
    
     foreach my $val (@{$values})
     {
       &getIsMember($val,$userDN) if (grep /groupOfUniqueNames/, @{$val});
     }
     

     die $mesg->error if $mesg->code;


     #if make it this far then you must be a member
  
   }; 

   return $0;
}
