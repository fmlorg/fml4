#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: Text.pm,v 1.4 2001/11/19 08:47:01 fukachan Exp $
#

package Mail::ThreadTrack::Print::Text;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;
use Mail::ThreadTrack::Print::Utils qw(decode_mime_string STR2EUC);

my $is_show_cost_indicate = 0;

my $format = "%-20s %10s %5s %8s %s\n";


# Descriptions: show articles as HTML in this thread
#    Arguments: $self $str
# Side Effects: none
# Return Value: none
sub show_articles_in_thread
{
    my ($self, $thread_id) = @_;
    my $mode      = $self->get_mode || 'text';
    my $config    = $self->{ _config };
    my $spool_dir = $config->{ spool_dir };
    my $articles  = $self->{ _hash_table }->{ _articles }->{ $thread_id };
    my $wh        = $self->{ _fd } || \*STDOUT;

    use FileHandle;
    if (defined($articles) && defined($spool_dir) && -d $spool_dir) {
	my $s = '';
	for (split(/\s+/, $articles)) {
	    my $file = File::Spec->catfile($spool_dir, $_);
	    my $fh   = new FileHandle $file;
	    while (defined($_ = $fh->getline())) {
		next if 1 .. /^$/;
		$s = STR2EUC($_);
		print $wh $s;
	    }
	    $fh->close;
	}
    }
}


# Descriptions: show guide line
#    Arguments: $self $args
# Side Effects: none
# Return Value: none
sub __start_thread_summary
{
    my ($self, $args) = @_;
    my $fd = $self->{ _fd } || \*STDOUT;

    printf($fd $format, 'id', 'date', 'age', 'status', 'articles');
    print $fd "-" x60;
    print $fd "\n";
}


# Descriptions: print formated brief summary
#    Arguments: $self $args
# Side Effects: none
# Return Value: none
sub __print_thread_summary
{
    my ($self, $optargs) = @_;
    my $fd        = $self->{ _fd } || \*STDOUT;
    my $date      = $optargs->{ date };
    my $age       = $optargs->{ age };
    my $status    = $optargs->{ status };
    my $thread_id = $optargs->{ thread_id };
    my $articles  = $optargs->{ articles };
    my $aid       = (split(/\s+/, $articles))[0];

    printf($fd $format, $thread_id, $date, $age, $status, 
	   _format_list(25, $articles));
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub __end_thread_summary
{
    my ($self, $args) = @_;
    my $fd = $self->{ _fd } || \*STDOUT;
}


# Descriptions: create a string of "a b c .." style up to $num bytes
#    Arguments: $num $str
# Side Effects: none
# Return Value: string
sub _format_list
{
    my ($max, $str) = @_;
    my (@idlist) = split(/\s+/, $str);
    my $r = '';

    for (@idlist) {
	$r .= $_ . " ";
	if (length($r) > $max) {
	    $r .= "...";
	    last;
	}
    }

    return $r;
}


# Descriptions: print message summary
#    Arguments: $self $args
# Side Effects: none
# Return Value: none
sub __print_message_summary
{
    my ($self, $thread_id) = @_;
    my $config = $self->{ _config };
    my $age  = $self->{ _age }  || {};
    my $cost = $self->{ _cost } || {};
    my $fd   = $self->{ _fd }   || \*STDOUT;
    my $rh   = $self->{ _hash_table };

    if (defined $config->{ spool_dir }) {
	my ($aid, @aid, $file);
	my $spool_dir  = $config->{ spool_dir };

      THREAD_ID_LIST:
	for my $thread_id (@$thread_id) {
	    if ($is_show_cost_indicate) {
		my $how_bad = _cost_to_indicator( $cost->{ $thread_id } );
		printf $fd "\n%6s  %-10s  %s\n", $how_bad, $thread_id;
	    }
	    else {
		printf $fd "\n>Thread-Id: %-10s  %s\n", $thread_id;
	    }

	    # show only the first article of this thread $thread_id
	    if (defined $rh->{ _articles }->{ $thread_id }) {
		(@aid) = split(/\s+/, $rh->{ _articles }->{ $thread_id });
		$aid  = $aid[0];
		$file = File::Spec->catfile($spool_dir, $aid);
		if (-f $file) {
		    $self->print(  $self->message_summary($file) );
		}
	    }
	}
    }
}


# Descriptions: ( broken now ;-)
#    Arguments: $string
# Side Effects: none
# Return Value: string
sub _cost_to_indicator
{
    my ($cost) = @_;
    my $how_bad = 0;

    if ($cost =~ /(\w+)\-(\d+)/) { 
	$how_bad += $2;
	$how_bad += 2 if $1 =~ /open/;
	$how_bad  = "!" x ($how_bad > 6 ? 6 : $how_bad);
    }

    $how_bad;
}


1;