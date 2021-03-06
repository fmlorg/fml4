#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Analyze.pm,v 1.33 2003/08/23 04:35:48 fukachan Exp $
#

package Mail::ThreadTrack::Analyze;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

# XXX-TODO: we should remove not used function ?

my $debug = 0;

=head1 NAME

Mail::ThreadTrack::Analyze - analyze mail thread relation

=head1 SYNOPSIS

See C<Mail::ThreadTrack> perl module for more detail.

=head1 DESCRIPTION

=head1 METHODS

=head2 analyze($mesg)

C<$mesg> is Mail::Message object.

This is top level entrance for

1) assign a new thread or extract the existing thread-id from the subject.

2) update thread status if needed.

3) update database.

=cut


# Descriptions: top level entrance
#    Arguments: OBJ($self) OBJ($msg)
#               $msg = "Mail::Messge object"
# Side Effects: none
# Return Value: none
sub analyze
{
    my ($self, $msg) = @_;

    $self->assign($msg);
    $self->rewrite_header($msg) if $self->{ _is_rewrite_header };
    $self->update_thread_status($msg);
    $self->update_db($msg);
}


=head2 assign($msg)

analyze message given by $msg and assign thread id if needed.

=cut


# Descriptions: given string looks like subject or not
#    Arguments: STR($subject)
# Side Effects: none
# Return Value: 1 or 0
sub _is_reply
{
    my ($subject) = @_;

    use Mail::Message::Language::Japanese::Subject;
    return Mail::Message::Language::Japanese::Subject::is_reply($subject);
}


# Descriptions: assign a new thread id or
#               extract the existing thread-id from the subject
#    Arguments: OBJ($self) OBJ($msg)
#                  $msg = Mail::Message object
# Side Effects: a new thread_id may be assigned
# Return Value: none
sub assign
{
    my ($self, $msg) = @_;
    my $header   = $msg->whole_message_header();
    my $subject  = $header->get('subject');
    my $is_reply = _is_reply($subject);

    # XXX-TODO: who validate $thread_id regexp
    # XXX-TODO: since $thread_id is given from outside.
    # 1. try to extract $thread_id from header
    my $thread_id = $self->_extract_thread_id_in_subject($header);
    unless ($thread_id) {
	# If we fail to pick up thread id from subject,
	# we try to speculate id from other fields in header.
	$thread_id = $self->_speculate_thread_id_from_header($header);
	if ($thread_id) {
	    $is_reply = 1; # message already have thread_id, so replied one?
	    $self->set_thread_id($thread_id);
	    $self->log("speculated id=$thread_id");
	}
	else {
	    $self->log("(debug) fail to spelucate thread_id") if $debug;
	}
    }

    # 2. check "X-Thread-Pragma:" field,
    #    we ignore this mail if the pragma is specified as "ignore".
    if (defined $header->get('x-thread-pragma')) {
	my $pragma = $header->get('x-thread-pragma') || '';
	if ($pragma =~ /ignore/io) {
	    $self->{ _pragma } = 'ignore';
	    $self->_append_thread_status_info("ignored");
	    return undef;
	}
    }

    # 3. if the header has some thread_id,
    #    we do not rewrite the subject but save the extracted $thread_id.
    if ($is_reply && $thread_id) {
	$self->log("reply message with thread_id=$thread_id");
	$self->set_thread_id($thread_id);
	$self->set_thread_status('analyzed');
	$self->_append_thread_status_info('analyzed');
    }
    elsif ($thread_id) {
	$self->log("message with thread_id=$thread_id but not reply");
	$self->set_thread_id($thread_id);
	$self->_append_thread_status_info("found");
    }
    else {
	$self->log("message without thread_id") if $debug;

	my $id = $self->_assign_new_thread_id_number();

	# side effect:
	# define $self->{ _thread_subject_tag } and $self->{ _thread_id }
	my $thread_id = $self->_create_thread_id_strings($id);
	$self->set_thread_id($thread_id);
	$self->_append_thread_status_info("newly assigned");
    }
}


# Descriptions: assign new thread_id
#    Arguments: OBJ($self)
# Side Effects: increment id
# Return Value: NUM
sub _assign_new_thread_id_number
{
    my ($self) = @_;
    my $id = 0;

    # assign a new thread number for a new message
    if (1) {
	# unique but non sequential number
	$id = $self->{ _config }->{ article_id };
    }
    else {
	# incremental number
	$id = $self->increment_id();
    }

    $self->log("assign thread_id=$id") if $debug;
    return $id;
}


# Descriptions: update $self->{ _status_info }
#    Arguments: OBJ($self) STR($s)
# Side Effects: update $self->{ _status_info }
# Return Value: STR
sub _append_thread_status_info
{
    my ($self, $s) = @_;
    $self->{ _status_info } .= $self->{ _status_info } ? " -> ".$s : $s;
}


=head2 get_thread_status()

get thread status.

=head2 set_thread_status($status)

set thread status.

=cut


# Descriptions: get thread status
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: STR
sub get_thread_status
{
    my ($self) = @_;
    return(defined $self->{ _status } ? $self->{ _status } : undef);
}


# Descriptions: set thread status
#    Arguments: OBJ($self) STR($thread_status)
# Side Effects: none
# Return Value: STR
sub set_thread_status
{
    my ($self, $thread_status) = @_;
    $self->{ _status } = $thread_status;
    return $thread_status;
}


=head2 update_thread_status($msg)

ignore this procedure if "ignore" pragma is specified.

update status to "close" if "close" pragma or "close" commmand in the
message is found.

=cut


# Descriptions: update thread status
#    Arguments: OBJ($self) OBJ($msg)
# Side Effects: update database
# Return Value: none
sub update_thread_status
{
    my ($self, $msg) = @_;
    my $content = '';
    my $subject = '';
    my $pragma  = '';

    if (defined $self->{ _pragma }) {
	return if $self->{ _pragma } eq 'ignore';
    }

    unless (ref($msg) eq 'Mail::Message') {
	croak("invalid object");
    }

    # filter messages of some class
    if (defined $self->{ _filterlist }) {
	if ($self->_is_ignore($msg)) {
	    $self->log("this thread should be ignored");
	    $pragma = "close";
	}
    }

    my $header  = $msg->whole_message_header();
    my $textmsg = $msg->find_first_plaintext_message();
    $content    = $textmsg->message_text() if defined $textmsg;
    $subject    = $header->get('subject') || '';
    $pragma     = $header->get('x-thread-pragma') || $pragma || '';

    if ($pragma  =~ /close/     ||
	$content =~ /^\s*close/ ||
	$subject =~ /^\s*close/) {
	$self->set_thread_status("close");
	$self->_append_thread_status_info("closed");
	$self->log("thread is closed");
    }
    else {
	$self->log("thread status not changed");
    }
}


# Descriptions: check filter whether this $msg should be ignored or not.
#    Arguments: OBJ($self) OBJ($msg)
# Side Effects: none
# Return Value: 1 or 0
sub _is_ignore
{
    my ($self, $msg) = @_;
    my ($header, $textmsg, $content);
    my ($field, $rule);
    my $filterlist = $self->{ _filterlist };

    $header  = $msg->whole_message_header();
    $textmsg = $msg->find_first_plaintext_message();
    $content = $textmsg->message_text() if defined $textmsg;

    # check header
    while (($field, $rule) = each %$filterlist) {
	if (defined $header->get($field)) {
	    my $value = $header->get($field);
	    if ($debug) {
		print STDERR "ignore $field: $value\n" if $value =~ /$rule/m;
	    }
	    return 1 if $value =~ /$rule/;
	}
    }

    return 0;
}


=head2 get_thread_id()

get thread_id in object ($self->{ _thread_id }).

=head2 set_thread_id($thread_id)

set thread_id in object ($self->{ _thread_id }).

=cut


# Descriptions: get thread_id in object ($self->{ _thread_id }).
#    Arguments: OBJ($self)
# Side Effects: none.
# Return Value: STR or UNDEF
sub get_thread_id
{
    my ($self) = @_;
    return(defined $self->{ _thread_id } ? $self->{ _thread_id } : undef);
}


# Descriptions: set thread_id
#    Arguments: OBJ($self) STR($thread_id)
# Side Effects: update $self->{ _thread_id }.
# Return Value: STR
sub set_thread_id
{
    my ($self, $thread_id) = @_;
    $self->{ _thread_id } = $thread_id;
    return $thread_id;
}


# Descriptions: create regexp for a subject tag, for example
#               "[%s %05d]" => "\[\S+ \d+\]"
#    Arguments: STR($s)
#               XXX non OO type function
# Side Effects: none
# Return Value: STR(a regexp for the given tag)
sub _regexp_compile
{
    my ($s) = @_;

    $s = quotemeta( $s );
    $s =~ s@\\\%@\%@g;
    $s =~ s@\%s@\\S+@g;
    $s =~ s@\%d@\\d+@g;
    $s =~ s@\%0\d+d@\\d+@g;
    $s =~ s@\%\d+d@\\d+@g;
    $s =~ s@\%\-\d+d@\\d+@g;

    # quote for regexp substitute: [ something ] -> \[ something \]
    # $s =~ s/^(.)/quotemeta($1)/e;
    # $s =~ s/(.)$/quotemeta($1)/e;

    return $s;
}


# Descriptions: extract message-id list and return it.
#    Arguments: OBJ($header)
#               function not OO
# Side Effects: none
# Return Value: ARRAY_HASH
sub _extract_message_id_references
{
    my ($header) = @_;
    my (@addrs, @r, %uniq) = ();

    # XXX-TODO: Mail::Message should provide this function ?

    use Mail::Address;

    if (defined $header->get('in-reply-to')) {
	my $buf = $header->get('in-reply-to');
	push(@addrs, Mail::Address->parse($buf));
    }

    if (defined $header->get('references')) {
	my $buf = $header->get('references');
	push(@addrs, Mail::Address->parse($buf));
    }

    for my $addr (@addrs) {
        my $a = $addr->address;
        unless (defined $uniq{ $a } && $uniq{ $a }) {
	    # RFC822 says msg-id = "<" addr-spec ">" ; Unique message id
            push(@r, "<".$addr->address.">");
            $uniq{ $a } = 1;
        }
    }

    return \@r;
}


# Descriptions: extract thread_id in Subject:
#    Arguments: OBJ($self) OBJ($header)
# Side Effects: none
# Return Value: STR or 0
sub _extract_thread_id_in_subject
{
    my ($self, $header) = @_;
    my $config  = $self->{ _config };
    my $tag     = $config->{ thread_subject_tag } || '';
    my $loctype = $config->{ thread_subject_tag_location } || 'appended';
    my $subject = $header->get('subject') || '';
    my $regexp  = _regexp_compile($tag);

    # Subject: ... [thread_id]
    if (($loctype eq 'appended') && ($subject =~ /($regexp)\s*$/)) {
	my $id = $1;
	$id =~ s/^(\[|\(|\{)//;
	$id =~ s/(\]|\)|\})$//;
	return $id;
    }
    # XXX incomplete, we check subject after cutting off "Re:" et. al.
    # Subject: [thread_id] ...
    # Subject: Re: [thread_id] ...
    elsif (($loctype eq 'prepended') && ($subject =~ /^\s*($regexp)/)) {
	my $id = $1;
	$id =~ s/^(\[|\(|\{)//;
	$id =~ s/(\]|\)|\})$//;
	return $id;
    }
    else {
	$self->log("no thread id /$regexp/ in subject") if $debug;
	return 0;
    }
}


# Descriptions:
#               For example, consider a posting to both elena ML and
#               rudo (DM) from kenken.
#
#                    From: kenken
#                    To: elena-ml
#                    Cc: rudo
#
#                The reply to this DM (direct message) from rudo is
#
#                    From: rudo
#                    To: elena-ml
#
#                    This reply message has no thread_id since the
#                    message from kenken to rudo comes directly from
#                    kenken not through fml driver.  In this case, we
#                    try to speculdate the reply relation and the
#                    thread_id of this thread by using _
#                    speculate_thread_id_from_header().
#
#    Arguments: OBJ($self) OBJ($header)
# Side Effects: none
# Return Value: STR(message id)
sub _speculate_thread_id_from_header
{
    my ($self, $header) = @_;
    my $midlist = _extract_message_id_references( $header );
    my $result  = '';

    if (defined $midlist) {
	$self->db_open();

	# prepare hash table tied to db_dir/*db's
	my $rh = $self->{ _hash_table };

      MSGID_LIST:
	for my $mid (@$midlist) {
	    $result = $rh->{ _message_id }->{ $mid };
	    last MSGID_LIST if $result;
	}

	$self->db_close();
    }

    if ($debug) {
        $self->log("(debug) not speculated") unless $result;
    }
    $result;
}


# Descriptions: create thread_id
#    Arguments: OBJ($self) STR($id)
# Side Effects: update $self->{ _thread_subject_tag }
# Return Value: STR(thread_id string)
sub _create_thread_id_strings
{
    my ($self, $id) = @_;
    my $config = $self->{ _config };

    # thread_id appeared in subject: field
    my $subject_tag = $config->{ thread_subject_tag };
    $self->{ _thread_subject_tag } = sprintf($subject_tag, $id);

    # thread_id used as primary key
    my $id_syntax   = $config->{ thread_id_syntax };
    return sprintf($id_syntax, $id);
}


=head2 update_db($msg)

update database.

=cut


# Descriptions: top level dispatcher to drive database update
#    Arguments: OBJ($self) OBJ($msg)
# Side Effects: update databases
# Return Value: none
sub update_db
{
    my ($self, $msg) = @_;
    my $config  = $self->{ _config };
    my $ml_name = $config->{ ml_name };

    if (defined $self->{ _pragma }) {
	return if $self->{ _pragma } eq 'ignore';
    }

    $self->db_open();

    # save $ticke_id et.al. in db_dir/$ml_name
    $self->_update_db($msg);

    $self->prepare_history_info($msg) if $self->{ _is_rewrite_header };

    # save cross reference pointers among $ml_name
    $self->_update_index_db();

    $self->db_close();
}


# Descriptions: speculate unixtime from header
#    Arguments: OBJ($msg)
# Side Effects: none
# Return Value: NUM(unix time)
sub _speculate_time
{
    my ($msg) = @_;
    my $header = $msg->whole_message_header;

    if (defined $header->get('date')) {
	use Mail::Message::Date;
	my $obj = new Mail::Message::Date;
	return $obj->date_to_unixtime($header->get('date'));
    }
    else {
	return time;
    }
}


# Descriptions: update database
#    Arguments: OBJ($self) OBJ($msg)
# Side Effects: update database
# Return Value: STR
sub _update_db
{
    my ($self, $msg) = @_;
    my $config     = $self->{ _config };
    my $article_id = $config->{ article_id };
    my $thread_id  = $self->get_thread_id();

    # 0. logging
    $self->log("article_id=$article_id thread_id=$thread_id") if $debug;

    # prepare hash table tied to db_dir/*db's
    my $rh = $self->{ _hash_table };

    # check
    if (defined $rh->{ _thread_id }->{ $article_id }) {
	print STDERR "_update_db.ignore id=$article_id\n" if $debug;
	return;
    }

    # 1.
    $rh->{ _thread_id }->{ $article_id }  = $thread_id;
    $rh->{ _date      }->{ $article_id }  = _speculate_time($msg);
    $rh->{ _articles  }->{ $thread_id  } .= $article_id . " ";

    # 2. record the sender information
    my $header = $msg->whole_message_header;
    $rh->{ _sender }->{ $article_id } = $header->get('from');

    # 3. update status information
    if (defined $self->get_thread_status()) {
	my $status = $self->get_thread_status();
	$self->_set_status($thread_id, $status);
    }
    else {
	# set the default status value for the first time.
	unless (defined $rh->{ _status }->{ $thread_id }) {
	    $self->_set_status($thread_id, 'open');
	}
    }

    # 4. save optional/additional information
    #    message_id hash is { message_id => thread_id };
    # RFC822 says msg-id =  "<" addr-spec ">" ; Unique message id
    my $mid = $header->get('message-id'); $mid =~ s/[\n\s]*$//;
    if ($mid eq "") {
	print STDERR "missing message-id $thread_id\n" if $debug;
	return;
    }
    $rh->{ _message_id }->{ $mid } = $thread_id;
}


# Descriptions: register myself to index_db for further reference
#               among mailing lists
#    Arguments: OBJ($self)
# Side Effects: update object
# Return Value: STR
sub _update_index_db
{
    my ($self) = @_;
    my $config    = $self->{ _config };
    my $thread_id = $self->get_thread_id();
    my $rh        = $self->{ _hash_table };
    my $ml_name   = $config->{ ml_name };

    my $ref = $rh->{ _index }->{ $thread_id } || '';
    if ($ref !~ /^$ml_name|\s$ml_name\s|$ml_name$/) {
	$rh->{ _index }->{ $thread_id } .= $ml_name." ";
    }
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

Mail::ThreadTrack::Analyze first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
