#!/usr/local/bin/perl
#
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# Please obey GNU Public License(see ./COPYING)
#

$rcsid   = q$Id$;
$rcsid   =~ s/,v//;
$rcsid   =~ s/Id: (.*)\s+Exp\s+\S+/$1/;


##### variables to customize #####

$WWW_ADMIN = "www-admin\@sapporo.iij.ad.jp";
$RCPT_ADDR = 'questionnaire\@sapporo.iij.ad.jp';
$SENDMAIL  = 'sendmail';
$ADD_PATH  = ":/usr/bin:/usr/local/bin:/usr/contrib/bin";
$SUBJECT   = "questionnaire of www.sapporo.iij.ad.jp";

@SKIP_FIELD = ('submit-p');
@SKIP_ENV   = ('HTTP_ACCEPT', 'HTTP_ACCEPT_ENCODING',
	       SCRIPT_FILENAME, DOCUMENT_ROOT, PATH, SCRIPT_NAME, 
	       SERVER_ADMIN, SERVER_SOFTWARE, HTTP_MIME_VERSION, 
	       SERVER_PORT, SERVER_PROTOCOL, HTTP_REFERER, 
	       SERVER_NAME, REQUEST_METHOD, SCRIPT_NAME);

##### variables to customize ENDS #####



########## Configure ##########
# sendmail
$SENDMAIL = &search_path($SENDMAIL);

# Hmm... O.K. like this?
$ENV{'PATH'} .= $ADD_PATH;

# Get Entry
&GetBuffer(*input);

# HTML MODE
print "Content-type: text/plain\n\n";

# Addr-spec check
$addr = $input{'address'};
if ($addr !~ /\S+\@\S+/) { &ErrorMesg; exit 0;}

# Configure field names to skip
for (@SKIP_FIELD) { $SKIP_FIELD{$_} = 1;}
for (@SKIP_ENV)   { $SKIP_ENV{$_}   = 1;}


########## O.K. Forwarding ##########
# FORW
open(S, "|$SENDMAIL $RCPT_ADDR");

$FROM = $ENV{'HTTP_FROM'} || $WWW_ADMIN;

print S "From $WWW_ADMIN\n";
print S "From: $FROM\n";
print S "Subject: $SUBJECT\n";
print S "X-Forw: $rcsid\n";
print S "\n";

# convert for multiple lines 
# \n => \n\t 
foreach (sort keys %input) { 
    ($k, $v) = ($_, $input{$_});
    next if $SKIP_FIELD{$k};
    $v =~ s/\n/\n\t/g;
    print S "$k\t$v\n" if $v;
}

print S "\n\# end\n\n";
print S "-" x 60;
print S "\n\nEnverionment Variables Information (for Server Admin):\n\n";

foreach (sort keys %ENV) { 
    ($k, $v) = ($_, $ENV{$_});
    next if $SKIP_ENV{$k};
    print S "$k\t$v\n" if $v;
}

close(S);

##### REPLY 
print "Your message has been Sent.\nThanks in advance.\n";

exit 0;

sub search_path
{
    local($f) = @_;
    local($path) = $ENV{'PATH'};

    foreach $dir (split(/:/, $path)) { 
	if (-f "$dir/$f") { return "$dir/$f";}
    }

    "";
}

sub GetBuffer
{
    local(*s) = @_;

    $ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;

    if ($ENV{'REQUEST_METHOD'} eq "POST") {
	read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
    }
    else {
	$buffer = $ENV{'QUERY_STRING'};
    }

    foreach (split(/&/, $buffer) {
	($k, $v) = split(/=/, $_);
	$v =~ tr/+/ /;
	$v =~ s/%(..)/pack("C", hex($1))/eg;
	$s{$k} = $v;
    }
}

sub ErrorMesg
{
    print "Your Email Address is incomplete!!!\n";
    print "So, cannot be sent\n\n";
    print ("*" x 60); print "\n";
    print "Please define your Email Address!\n";
    print ("*" x 60); print "\n";
}

1;
