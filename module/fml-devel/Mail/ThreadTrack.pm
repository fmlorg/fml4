#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: ThreadTrack.pm,v 1.35 2003/08/23 04:35:45 fukachan Exp $
#

package Mail::ThreadTrack;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

use Mail::ThreadTrack::Analyze;
use Mail::ThreadTrack::DB;
use Mail::ThreadTrack::Print;

@ISA = qw(Mail::ThreadTrack::Analyze
	Mail::ThreadTrack::DB
	Mail::ThreadTrack::Print
	  );


=head1 NAME

Mail::ThreadTrack - analyze message thread

=head1 SYNOPSIS

    ... lock mailing list ...

    my $args = {
	fd          => \*STDOUT,
	db_base_dir => "/var/spool/ml/\@db\@/thread",
	ml_name     => 'elena',
	spool_dir   => "/var/spool/ml/elena/spool",
	article_id  => 100,
    };

    use Mail::ThreadTrack;
    my $thread = new Mail::ThreadTrack $args;
    $thread->analyze($msg);
    $thread->show_summary();

    ... unlock mailing list ...

where C<$msg> is Mail::Message object for the article 100.

=head1 DESCRIPTION

=head1 METHODS

=head2 new($args)

    $args = {
	fd          => \*STDOUT,
	db_base_dir => "/var/spool/ml/\@db\@/thread",
	ml_name     => 'elena',
	spool_dir   => "/var/spool/ml/elena/spool",
	article_id  => $id,
    };

C<db_base_dir>, C<spool_dir> and C<ml_name> in C<config> are mandatory.
C<$id> is the sequential number for input data (article).

Available variables in $args follows:

    variables               type       example
    ------------------------------------------------------------
    myname                  STR        ?
    ml_name                 STR        elena
    spool_dir               STR        /var/spool/ml/elena
    article_id              STR        100
    db_base_dir             STR        /var/spool/ml/@db@/thread
    reverse_order           STR        1 or 0
    rewrite_header          STR        1 or 0
    base_url                STR        "" or URL
    msg_base_url            STR        "" or URL
    dir_mode                NUM        0755
    thread_id_syntax        STR        elena/%d
    thread_subject_tag      STR        [elena/%d]
    fd                      HANDLE     \*STDOUT
    logfp                   CODE       \&Log()

=cut


my $dir_mode = 0755;


# Descriptions: constructor
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self, $args) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};
    my $config = $me->{ _config } = {
	db_type => 'AnyDBM_File',
    };

    if (defined $args->{ dir_mode }) {
	$dir_mode = $args->{ dir_mode };
    }

    my @keys = qw(myname ml_name spool_dir article_id db_base_dir
		  reverse_order
		  rewrite_header
		  base_url msg_base_url
		  );

    my %must = ('ml_name' => 1, 'spool_dir' => 1, 'db_base_dir' => 1);

    for my $key (@keys) {
	if (defined $args->{ $key }) {
	    $config->{ $key } = $args->{ $key };
	}
	elsif (defined $must{ $key }) {
	    croak("specify $key");
	}

    }
    my $ml_name = $config->{ ml_name };

    unless (defined $args->{ thread_id_syntax }) {
	$config->{ thread_id_syntax } = "$ml_name/\%d";
    }

    unless (defined $args->{ thread_subject_tag }) {
	my $id_syntax = $config->{ thread_id_syntax };
	$config->{ thread_subject_tag } = "[$id_syntax]";
    }

    # database directory used to store thread information et. al.
    use File::Spec;
    my $base_dir          = $config->{ db_base_dir };
    $me->{ _db_base_dir } = $base_dir;
    $me->{ _index_db }    = File::Spec->catfile($base_dir, "index");
    $me->{ _db_dir }      = File::Spec->catfile($base_dir, $ml_name);
    $me->{ _fd }          = $args->{ fd } || \*STDOUT;
    $me->{ _saved_args }  = $args;

    if (defined $config->{ rewrite_header } && $config->{ rewrite_header }) {
	$me->{ _is_rewrite_header } = 1;
	eval q{ use Mail::ThreadTrack::HeaderRewrite; };
	croak($@) if $@;
	push(@ISA, 'Mail::ThreadTrack::HeaderRewrite');
    }

    # XXX-TODO: $article_summary_lines hard-coded.
    # ::Print parameters
    $me->{ _article_summary_lines } = 5;

    # log function pointer
    if (defined $args->{ logfp }) {
	$me->{ _logfp } = $args->{ logfp };
    }

    # initialize directory
    _init_dir($me);

    return bless $me, $type;
}


# Descriptions: dummy
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: none
# Return Value: none
sub DESTROY {}


# Descriptions: "mkdir -p" or "mkdirhier"
#    Arguments: STR($dir) STR($mode)
# Side Effects: set $ErrorString
# Return Value: 1 or UNDEF
sub _mkdirhier
{
    my ($dir, $mode) = @_;

    # XXX $mode (e.g. 0755) should be a numeric not a string
    eval q{
        use File::Path;
        mkpath($dir, 0, $dir_mode);
    };

    return ($@ ? undef : 1);
}


# Descriptions: create the directory taken from $self->{ _db_dir }.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: create a "_db_dir" directory if needed
# Return Value: 1 (success) or undef (fail)
sub _init_dir
{
    my ($self, $args) = @_;

    if (defined $self->{ _db_dir }) {
	my $db_dir = $self->{ _db_dir };
	unless (-d $db_dir) {
	    _mkdirhier($db_dir) || do {
		croak("cannot make \$db_dir=$db_dir\n");
	    };
	}
    }
    else {
	croak("no \$db_dir\n");
    }

    return 1;
}


=head2 increment_id(file)

increment thread number which is taken up from C<file>
and save the new number to C<file>.

=cut


# Descriptions: increment thread number $id holded in DB.
#    Arguments: OBJ($self) STR($seq_file)
# Side Effects: increment id holded in $seq_file
# Return Value: NUM
sub increment_id
{
    my ($self, $seq_file) = @_;
    my $seq = 0;

    # XXX-TODO: $seq_file is not used. fix this method.

    $self->db_open();

    # prepare hash table tied to db_dir/*db's
    # XXX-TODO: we prepare $self->db_base(); ?
    my $rh = $self->{ _hash_table };

    if (defined $rh->{ _info }->{ sequence }) {
	$rh->{ _info }->{ sequence }++;
	return $rh->{ _info }->{ sequence };
    }
    else {
	$seq = $rh->{ _info }->{ sequence } = 1;
    }

    $self->db_close();

    return $seq;
}


=head2 list_up_thread_id()

return not closed ticket id(s) as ARRRAY_REF.

=cut


# Descriptions: return not closed ticket id(s) as ARRRAY_REF.
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: ARRAY_HASH
sub list_up_thread_id
{
    my ($self) = @_;
    my ($tid, $status);
    my $rh_status = $self->{ _hash_table }->{ _status };
    my $mode      = 'default';
    my $stat      = {};
    my @thread_id = ();

  TICEKT_LIST:
    while (($tid, $status) = each %$rh_status) {
	if ($status =~ /close/o) {
	    $stat->{ 'closed' }++;
	}
	else {
	    $stat->{ $status }++;
	}

	if ($mode eq 'default') {
	    next TICEKT_LIST if $status =~ /close/o;
	}

	push(@thread_id, $tid);
    }

    # save statistics
    $self->{ _ticket_id_stat } = $stat;

    \@thread_id;
}


=head2 set_mode($mode)

specify output format by $mode string.
"text" and "html" are available.
"text" by default.

=head2 get_mode()

get output format.

=cut


# Descriptions: set output format
#    Arguments: OBJ($self) STR($mode)
# Side Effects: update info in object
# Return Value: STR
sub set_mode
{
    my ($self, $mode) = @_;
    $self->{ _mode } = $mode || 'text';
}


# Descriptions: set output format
#    Arguments: OBJ($self)
# Side Effects: update info in object
# Return Value: STR
sub get_mode
{
    my ($self) = @_;
    return(defined $self->{ _mode } ?  $self->{ _mode } : undef);
}


=head2 set_fd( $fd )

=head2 get_fd()

=cut


# Descriptions: set output channel handle.
#    Arguments: OBJ($self) HADNLE($fd)
# Side Effects: update info in object.
# Return Value: HANDLE
sub set_fd
{
    my ($self, $fd) = @_;
    $self->{ _fd } = $fd;
}


# Descriptions: get output channel handle.
#    Arguments: OBJ($self)
# Side Effects: update info in object.
# Return Value: HANDLE
sub get_fd
{
    my ($self) = @_;
    return $self->{ _mode };
}


=head2 set_order( $order )

set thread listing order where $order is 'normal' or 'reverse'.

=cut


# Descriptions: set thread listing order
#    Arguments: OBJ($self) STR($order)
# Side Effects: update info in object.
# Return Value: none
sub set_order
{
    my ($self, $order) = @_;

    if ((defined $order) && $order eq 'normal') {
	$self->{ _config }->{ reverse_order } = 0;
    }
    elsif ((defined $order) && $order eq 'reverse') {
	$self->{ _config }->{ reverse_order } = 1;
    }
    else {
	warn("set_order: unknown order $order");
    }
}


=head2 exist($thread_id)

$thread_id exists or not in database?
return 1 (exist) or 0.

=cut


# Descriptions: $thread_id exists or not in database?
#    Arguments: OBJ($self) STR($id)
# Side Effects: none
# Return Value: 1 or 0
sub exist
{
    my ($self, $id) = @_;
    my $r  = 0;

    $self->db_open();

    my $rh = $self->{ _hash_table };

    if (defined $rh->{ _articles }) {
	my $a = $rh->{ _articles };
	$r = (defined $a->{ $id } ? 1 : 0);
    }

    $self->db_close();

    return $r;
}


=head2 close($thread_id)

close specified $thread_id.

=cut


# Descriptions: close specified $thread_id.
#    Arguments: OBJ($self) STR($thread_id)
# Side Effects: update status
# Return Value: none
sub close
{
    my ($self, $thread_id) = @_;

    $self->db_open();
    $self->_set_status($thread_id, "close");
    $self->db_close();
}


=head2 set_status($args)

set $status for $thread_id. It rewrites DB (file).
C<$args>, HASH reference, must have two keys.

    $args = {
	thread_id => $thread_id,
	status    => $status,
    }

C<set_status()> calls db_open() an db_close() automatically within it.

=cut


# Descriptions: set status.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: update status in db.
# Return Value: none
sub set_status
{
    my ($self, $args) = @_;
    my $thread_id = $args->{ thread_id };
    my $status    = $args->{ status };

    # XXX-TODO: validate input.
    $self->db_open();
    $self->_set_status($thread_id, $status);
    $self->db_close();
}


# Descriptions: set status.
#    Arguments: OBJ($self) STR($thread_id) STR($value)
# Side Effects: update status in db.
# Return Value: none
sub _set_status
{
    my ($self, $thread_id, $value) = @_;
    $self->{ _hash_table }->{ _status }->{ $thread_id } = $value;
}


=head2 add_filter( { key => value } )

add filter rule to ignore in thread database.

    my $thread = new Mail::ThreadTrack;
    $thread->set_filter( { 'subject' => 'fml cvs weekly changes' } );

=cut


# Descriptions: add filter rule(s) to ignore in thread database.
#    Arguments: OBJ($self) HASH_REF($hash)
# Side Effects: none
# Return Value: none
sub add_filter
{
    my ($self, $hash) = @_;

    # update filter list
    my ($k, $v);
    while (($k, $v) = each %$hash) {
	$self->{ _filterlist }->{ $k } = $v;
    }
}


=head2 log( $str )

log $str using the specified log function or into STDERR if logfp
unspecified.

=cut


# Descriptions: log
#    Arguments: OBJ($self) STR($str)
# Side Effects: none
# Return Value: none
sub log
{
    my ($self, $str) = @_;

    if (defined $self->{ _logfp }) {
	my $fp = $self->{ _logfp };
	&$fp( $str );
    }
    else {
	print STDERR "Log> $str\n";
    }
}


=head2 filepath($args)

return the article file path.

   $args = {
	base_dir   => DIR,
	id         => NUM,
	use_subdir => 1 or 0,
   };

=cut


# Descriptions: return the article file path.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: none
# Return Value: STR(file path)
sub filepath
{
    my ($self, $args) = @_;

    use Mail::Message::Spool;
    my $spool = new Mail::Message::Spool;
    my $file  = $spool->filepath($args);

    return $file;
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

Mail::ThreadTrack first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
