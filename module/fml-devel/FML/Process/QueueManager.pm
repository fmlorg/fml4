#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: QueueManager.pm,v 1.8 2002/09/11 23:18:16 fukachan Exp $
#

package FML::Process::QueueManager;

use strict;
use Carp;

=head1 NAME

FML::Process::QueueManager - provide queue manipulation functions

=head1 SYNOPSIS

    use FML::Process::QueueManager;
    my $obj = new FML::Process::QueueManager { directory => $queue_dir };
    $obj->send($curproc);

or if you send specific queue C<$queue_id>, use

    $obj->send($curproc, $queue_id);

where C<$queue_id> is queue id such as 1000390413.14775.1,
not file path.

=head1 DESCRIPTION

queue flush!

=head1 METHODS

=head2 C<new()>

constructor.

=cut


use FML::Log qw(Log LogWarn LogError);


# Descriptions: standard constructor
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self, $args) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};

    $me->{ _directory } = $args->{ directory };

    return bless $me, $type;
}


=head2 C<send($curproc, $id)>

try to send all mails in the queue.
If queue id C<$id> is specified, send queue for C<$id>.

=cut


# Descriptions: send message in queue directory sequentially
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($args)
# Side Effects: queue flush-ed
# Return Value: none
sub send
{
    my ($self, $curproc, $id) = @_;
    my $queue_dir = $self->{ _directory };

    use Mail::Delivery::Queue;
    my $queue = new Mail::Delivery::Queue { directory => $queue_dir };
    my $ra    = defined $id ? [ $id ] : $queue->list();

    for my $qid (@$ra) {
	my $q = new Mail::Delivery::Queue {
	    id        => $qid,
	    directory => $queue_dir,
	};

	if ( $q->lock() ) {
	    if ( $q->valid() ) {
		$self->_send($curproc, $q) && $q->remove();
	    }
	    else {
		Log("$qid is invalid");
	    }
	    $q->unlock();
	}
	else {
	    Log("$qid is locked. retry");
	}
    }
}


# Descriptions: send message object $q
#    Arguments: OBJ($self) OBJ($curproc) OBJ($q)
# Side Effects: queue flush-ed
# Return Value: STR
sub _send
{
    my ($self, $curproc, $q) = @_;
    my $info  = $q->getidinfo();
    my $qfile = $info->{ 'path' };
    my $qid   = $info->{ 'id' };

    use Mail::Message;
    my $msg = Mail::Message->parse( { file => $qfile } );

    use FML::Mailer;
    my $obj = new FML::Mailer;
    my $r   = $obj->send({
	sender     => $info->{ sender },
	recipients => $info->{ recipients },
	message    => $msg,
	curproc    => $curproc,
    });

    if ($r) {
	Log("queue=$qid status=sent");
    }
    else {
	Log("queue=$qid status=fail");
    }

    return $r;
}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Process::QueueManager first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;