# Copyright (C) 1993-1997 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1997 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

package mail2news;

sub Log { &main::Log(@_);}


sub main::NntpPost
{
    local(*e) = @_;
    my ($c); # client
    my ($h, $v, @header, @body, @order);

    $debug = $main::debug;

    &main::PerlModuleExistP("News::NNTPClient") || return 0;

    $c = new News::NNTPClient($main::NEWS_SERVER || "localhost");

    if ($debug) {
	&Log("NNTP debug: " .($c->message));
	print STDERR "NNTP debug: " .($c->message)."\n";
	$c->debug(2);

	print STDERR $c->list();
    } 

    # default
    if (@main::NEWS_HDR_FIELDS_ORDER) {
	@order = @main::NEWS_HDR_FIELDS_ORDER;
    }
    else {
	@order = 
	    ("from", "newsgroups", "subject", "supersedes", "references");
    }

    # Newsgroup:
    $e{"h:newsgroups:"} = $e{"h:newsgroups:"} || 
	$e{"h:Newsgroups:"} || $main::DEFAULT_NEWS_GROUP;

    if (! $e{"h:newsgroups:"}) {
	&Log("NntpPost: I don\'t know which newsgroup I should post");
	&Log("NntpPost: critical error");
	return $NULL;
    }

    # set up a header
    for $h (@order) {
	$v = $main::NEWS_FIELD_TO_OVERWRITE{$h} || 
	    $e{"h:${h}:"} || $main::NEWS_FIELD_DEFAULT{$h};
	push(@header, "${h}: $v") if $v;
    }

    @body = split(/\n/, $e{'Body'});

    # postable?
    $c->postok || $c->mode_reader; # fml-support: 04471

    if ($c->postok) {
	$c->post(@header, "", @body);
    }
    else {
	&Log("NntpPost: cannot set post-able");
    }

    if ($debug) {
	&Log("NNTP debug: " .($c->message));
	print STDERR "NNTP debug: " .($c->message)."\n";
    }

    &Log($c->ok ? "NntpPost: $main::ID is posted to $e{\"h:newsgroups:\"}" : 
	 "NntpPost::Error $main::ID is not posted to netNews");

    $c->quit;
}


1;
