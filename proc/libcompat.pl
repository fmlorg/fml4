###############################################
### ### BACKWARD COMPATIBILITY LIBRARIES ###### 
###############################################

##### GLOCAL VARIABLES ##### 
##### PHASE 01 -> continues to PHASE02
$Reply_to            = $Reply_to || $Envelope{'h:Reply-To:'};

# TO:
$Original_To_address = $Envelope{'to:'};
$To_address          = $Envelope{'mode:chk'};

# FROM:
$From_address        = $Envelope{'h:From:'};

# OTHER
$Date                = $Envelope{'h:Date:'};
$Errors_to           = $Envelope{'h:Errors-To:'};
$Sender              = $Envelope{'h:Sender:'};
$Message_Id          = $Envelope{'h:Message-Id:'};
$Cc                  = $Envelope{'h:Cc:'};
$Subject             = $Envelope{'h:Subject:'};

### MIME
for ('mime-version', 'content-type', 'content-transfer-encoding') {
    next unless $Envelope{"$_:"};
    $_cf{'MimeHeaders'} .= "$_: ".$Envelope{"h:$_:"}."\n";
}

### SUPERFLUOUS
if ($SUPERFLUOUS_HEADERS) {
    $SuperfluousHeaders = $Envelope{'Hdr2add'};
}

### SUMMARY
$Summary_Subject = $Subject;
$Summary_Subject =~ s/\n(\s+)/$1/g;
$User = substr($From_address, 0, 15);


##### MIME decoding. #####
# If other fields are required to decode, add them here.
# c.f. RFC1522	2. Syntax of encoded-words
if ($USE_LIBMIME && $Envelope{'MIME'}) {
    &use('MIME');
    $Summary_Subject = &DecodeMimeStrings($Summary_Subject);
}





##### STARTREK FORM ##### 
$SMTP_OPEN_HOOK .= q#
    if ($STAR_TREK_FORM) {
	local($mon, $year) = (localtime(time))[4..5];
	local($ID) = sprintf("%02d%02d.%05d", $year - 90, $mon + 1, $ID);
	$Envelope{'h:Subject:'} = "[$ID] $Subject";
    }
#;


##### PLAY of TO: (95/10/3) ##### 
# $To_address is obsolete
$SMTP_OPEN_HOOK .= q#
    $To_address = $Envelope{"to:"};
#;
$SMTP_OPEN_HOOK .= $Playing_to;
push(@PLAY_TO, @Playing_to);


###### ($host, $headers, $body) #####
sub OldSmtp
{
    local($host, $body, @headers) = @_;
    local(*e, *rcpt);

    local($h, $b) = split(/\n\n/, $body);
    $e{'Hdr'}  = $h;
    $e{'Body'} = $b;
    @rcpt      = grep(/'RCPT TO:'/, @headers);

    &Smtp(*e, *rcpt);
}


1;
