#-*- perl -*-
#
# Copyright (C) 1993-2000 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-2000 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

##################### WARNING #############################
#
# THIS IS THE FUNDAMENTAL TRIAL on TROUBLE TICKET SYSTEM.
# PLEASE DO NOT USE THIS LIBRARY NOW.
#
###########################################################


sub AnalyzeTroubleTicket
{
   local(*e) = @_;
   my ($subject);
   my (%config);

   if (! $TTS_LOG_DIR) {
       &Log("ERROR: please define \$TTS_LOG_DIR");
       return $NULL;
   }

   $subject = $e{'h:subject:'};
   $subject =~ s/\n/ /g;
   $subject =~ s/^\s*//g;


   if ($subject =~ /$TTS_PICKUP_ID_PATTERN/) {
       my ($desc, $date, $tid);
       $desc = $1;
       $date = $2;
       $tid  = $3;
       &Log("date=$date tid=$tid");
       &Log($desc);
       $config{'date'}    = $date;       
       $config{'tid'}     = $tid;
       $config{'subject'} = $subject;
       $config{'index'}   = "$TTS_LOG_DIR/index";
       $config{'description'} = $desc;
   }
   else {
       &Log("no ticket-id, ignored");
       return $NULL;
   }
   
   my ($tts_already_pickup) = 0;
   eval $TTS_PICKUP_HOOK;
   &Log($@) if $@;

   if ($tts_already_pickup) {
       &Log("aleady pick-up-ed");
   }
   elsif ($subject =~ /$TTS_PICKUP_ACCEEPT_PATTERN/) {
       eval &TroubleTicket::SaveTicket(*e, \%config);
       &Log($@) if $@;
       eval &TroubleTicket::LogIndex(*e, \%config);
       &Log($@) if $@;
   }
   else {
	&Log("ignored");
   }
}


package TroubleTicket;


sub SubDir
{
    local($tid) = @_;
    my ($dir, $dir1, $dir2);

    if ($tid =~ /^(..)(..)/) {
	$dir1 = $1;
	$dir2 = $2;
	return ($dir1, $dir2);
    }
}


sub ID2SubDir
{
    local($id) = @_;
    my ($tid, $date);

    if ($id =~ /^(\d+)\.(\S+)/) {
	return ($1, $2, &SubDir($2));
    }
}


sub SaveTicket
{
    local(*e, $cp) = @_;
    my ($dir);

    my ($tid) = $cp->{'tid'};
    my ($date) = $cp->{'date'};
    my ($dir1, $dir2) = &SubDir($tid);
    $dir = "$main::TTS_LOG_DIR/${dir1}/${dir2}/$tid";
    &main::Mkdir($dir);

    if (open($dir, ">> $dir/$date")) {
	print $dir $e{'Header'};
	print $dir "\n";
	print $dir $e{'Body'};
	print "\n";
	close($dir);
    }
}


sub LogIndex
{
    local(*e, $cp) = @_;
    my ($tid, $date, $index);

    $tid  = $cp->{'tid'};
    $date  = $cp->{'date'};
    $index = $cp->{'index'};
    $description = $cp->{'description'};

    my ($tid) = $cp->{'tid'};
    my ($date) = $cp->{'date'};
    my ($dir1, $dir2) = &SubDir($tid);

    if (open($index, ">> $index")) {
	select($index); $| = 1; select(STDOUT);
	print $index "${date}.${tid}\t${dir1}/${dir2}/${tid}/${date}";
	print $index "\t";
	print $index $description;
	print $index "\n";
	close($index);
    }
}


package main;
if ($0 eq __FILE__) {
    ;
}

1;
