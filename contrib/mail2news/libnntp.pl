# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
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

    for $h (@order) {
	$v = $main::NEWS_FIELD_TO_OVERWRITE{$h} || 
	    $e{"h:${h}:"} || $main::NEWS_FIELD_DEFAULT{$h};
	push(@header, "${h}: $v") if $v;
    }

    @body   = split(/\n/, $e{'Body'});

    $c->post(@header, "", @body);

    if ($debug) {
	&Log("NNTP debug: " .($c->message));
	print STDERR "NNTP debug: " .($c->message)."\n";
    }

    &Log($c->ok ? "NntpPost: $main::ID is posted to $e{\"h:newsgroups:\"}" : 
	 "NntpPost::Error $main::ID is not posted to netNews");

    $c->quit;
}


1;
