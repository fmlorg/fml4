#!/usr/local/bin/perl

@addr = ('all', 'top', 'sec', 'bari', 'bass', 'student', '1987', 'info', 'list','anonymous');

$FROM = "fukachan@phys.titech.ac.jp";

$THREAD = 
    q# $ADDRESS = "schwalben-$addr[$i]@phys.titech.ac.jp" #
    ;

$ToSendmail = q#
$WHOLE_MAIL = "From fukachan
Received: by axion.phys.titech.ac.jp
Date: Wed, 7 Jul 93 23:51:33 JST
From: $FROM
Return-Path: <$FROM>
Message-Id: <9307071451.AA10557@axion.phys.titech.ac.jp>
To: $ADDRESS
Subject: Simulator Test [$SimulatorCount]

"#
    ;

$SimulatorCount = 0;

$rand = scalar(@addr); srand; 

while(1) {
    $SimulatorCount++;
    $i = int(rand($rand));
    eval "$THREAD";
    die($@) if $@;
    open(SERVER, "| ./fml") || die($!);
    eval "$ToSendmail";
    die($@) if $@;
    print "---\n$WHOLE_MAIL\n---\n";
    print SERVER $WHOLE_MAIL;
    close(SERVER);
    sleep(5);
}

exit 0;
