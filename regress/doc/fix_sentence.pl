while (<>) {
$org = $_;

######### list #########
s/Cannot write to tmporary file/cannot write tmporary file/;
s/ is already registered as a member/ is already a member/;
s/since we do not spool articles/since we do not have spooled articles/;
s/which is of no use/passwd auth is not needed under pgp mode/;
s/PGP Environment Error/Error: verify PGP environment/;
s/\$proc had something error/\$proc: something error occurs/;
s/file \\"$file\\" not exists/file \"$file\" does not exist/;
s/no such.*exists/no such($1)is found/;
s/Error: such a user does not exist/Error: no such user found/;


s/The script to remove dead users is also generated/mead generated a script to remove dead users/;
s/Your PGP signature seems incorrect, ML delivery is not allowed/Your PGP signature seems incorrect. ML delivery is not allowed/;
s/554 PASSWD UNCHANGED/554 PASSWD REMAINS UNCHANGED/;

s/which command is prohibited/which command fml prohibits/;
s/old-address should be a member now/old-address should be a member/;
s/ may case a mail loop, reject/ may case a mail loop. fml reject it./;
s/Try exact-match for/try exact matching for/;
s/Please check your From: field/please check your From: header field/;


######### list end #########

print STDERR "> ", $org if $org ne $_;
print STDERR "  ", $_   if $org ne $_;

print;
}