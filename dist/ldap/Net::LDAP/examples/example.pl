#!/usr/bin/nperl

# This is a very simple example, hopefully I will get more soon.
# For more complex examples see the scripts in the bin directory

use lib '.';
use blib qw(../ber);
use Net::LDAP;

#ldap.switchboard.com
#ldap.whowhere.com
#ldap.infospace.com
#ldap.four11.com
#ldap.bigfoot.com

$ldap = Net::LDAP->new('ldap.switchboard.com',
		port => 389,
		debug => 3,
	) or
	die $@;

$ldap->bind();

for $filter (
	'(sn=Barr)',
	'(!(cn=Tim Howes))',
	'(&(objectClass=Person)(|(sn=Jensen)(cn=Babs J*)))',
	'(o=univ*of*mich*)',
	) {

    print "*" x 72,"\n",$filter,"\n","*" x 72,"\n";

    $mesg = $ldap->search(
		base   => "c=US",
		filter => $filter
    ) or die $@;

    map { $_->dump } $mesg->all_entries;

}
