# Library of fml.pl 
# Copyright (C) 1994 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

$libid   = q$Id$;
($libid) = ($libid =~ /Id:(.*).pl,v(.*) *\d\d\d\d\/\d+\/\d+.*/ && $1.$2);
$rcsid  .= "/$libid";

sub GetFileWithUnixFrom
{
    local(@filelist) = @_;
    local(@tmp);

    foreach $file (@filelist) {
	open(FILE, $file) || next;
	push(@tmp, "From $MAINTAINER\n");
	while(<FILE>) { push(@tmp, $_);}
	close(FILE);
	push(@tmp, "\n");
    }

    return @tmp;
}

# Sending Given buffer cut by cut.
sub OrderedSendingOnMemory 
{
    local($to, $Subject, $MAIL_LENGTH_LIMIT, $SLEEP_TIME, @BUFFER) = @_;
    local($TOTAL) = int( scalar(@BUFFER) / $MAIL_LENGTH_LIMIT + 1);
    local($mails) = 1;
    local($ReturnBuffer, $mailbuffer);

    foreach (@BUFFER) {
	# UNIX FROM, when plain text
	if(/^From\s+/oi){ $ReturnBuffer .= $mailbuffer; $mailbuffer = "";}

	# add the current line to the buffer
	$mailbuffer .= $_; $totallines++;

	# send and sleep
	if($totallines > $MAIL_LENGTH_LIMIT) {
	    $totallines = 0; 
	    &Sendmail($to, "$Subject ($mails/$TOTAL) $ML_FN", $ReturnBuffer);
	    $ReturnBuffer = "";
	    $mails++;
	    sleep($SLEEP_TIME);
	}
    }# foreach;

    # final mail
    $ReturnBuffer .= $mailbuffer;
    &Logging("SendFile: Send a $_/$TOTAL to $to");
    &Sendmail($to, "$Subject ($mails/$TOTAL) $ML_FN", $ReturnBuffer);
}

if($0 =~ __FILE__) {
    @test = ("./spool/1", "./spool/2");

    $MAINTAINER = "Elena@phys.titech.ac.jp";
    print  &GetFileWithUnixFrom(@test);
}

1;
