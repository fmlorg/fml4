# Debug Pattern Custom for &GetFieldsFromHeader
sub FieldsDebug
{
local($s) = q#"
FQDN                 $FQDN
DOMAIN               $DOMAINNAME

Mailing List         $MAIL_LIST
UNIX FROM            $Envelope{'UnixFrom'}
From(Original):      $Envelope{'from:'}
From_address:        $From_address
Original Subject:    $Envelope{'subject:'}
To:                  $Envelope{'mode:chk'}
Reply-To:            $Envelope{'h:Reply-To:'}
Addr2Reply:          $Envelope{'Addr2Reply:'}

DIR                  $DIR
LIBDIR               $LIBDIR
ACTIVE_LIST          $ACTIVE_LIST
MEMBER_LIST          $MEMBER_LIST
\@MEMBER_LIST         @MEMBER_LIST

CONTROL_ADDRESS:     $CONTROL_ADDRESS
Do uip               $Envelope{'mode:uip'}
LOAD_LIBRARY         $LOAD_LIBRARY
"#;

"print STDERR $s";
}

sub OutputEventQueue
{
    local($qp);

    &Debug("---Debug::OutputEventQueue();");
    for ($qp = 1; $qp ne ""; $qp = $EventQueue{"next:${qp}"}) {
	&Debug(sprintf("\tqp=%-2d link->%-2d fp=%s",
		       $qp, $EventQueue{"next:$qp"}, $EventQueue{"fp:$qp"}));
    }
}

1;
