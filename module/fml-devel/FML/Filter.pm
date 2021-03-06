#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003,2004 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Filter.pm,v 1.40 2004/02/01 14:52:49 fukachan Exp $
#

package FML::Filter;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;
use FML::Log qw(Log LogWarn LogError);
use ErrorStatus qw(error_set error error_clear);

my $debug = 0;

=head1 NAME

FML::Filter - entry point for FML::Filter::* modules

=head1 SYNOPSIS

    ... under reconstruction now. synopsis disabled once ...

where C<$message> is C<Mail::Message> object.

=head1 DESCRIPTION

top level dispatcher for FML filtering engine.
It consists of two types, header and body filtering engines.
The detail of rules is found in
L<FML::Filter::Header>,
L<FML::Filter::TextPlain>,
and
L<FML::Filter::MimeComponent>.

=head1 METHODS

=head2 new()

constructor.

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};
    return bless $me, $type;
}


# Descriptions: entry point for FML::Filter::* modules.
#    Arguments: OBJ($self) OBJ($curproc)
# Side Effects: none
# Return Value: STR or UNDEF, error reason (string). return undef if ok.
sub article_filter
{
    my ($self, $curproc) = @_;
    my $message = $curproc->incoming_message();
    my $config  = $curproc->config();

    if (defined $message) {
	my $functions = $config->get_as_array_ref('article_filter_functions');
	my $status    = 0;

      FUNCTION:
	for my $function (@$functions) {
	    if ($config->yes( "use_${function}" )) {
		$curproc->log("filter(debug): check by $function") if $debug;
		my $fp  = "_apply_$function";
		$status = $self->$fp($curproc, $message);
	    }
	    else {
		if ($debug) {
		    $curproc->log("filter(debug): $function check disabled.");
		}
	    }

	    last FUNCTION if $status;
	}

	return $status if $status;
    }

    return undef;
}


# Descriptions: size based filtering.
#    Arguments: OBJ($self) OBJ($curproc) OBJ($mesg)
# Side Effects: none
# Return Value: STR(reason) or 0 (not trapped, ok)
sub _apply_article_size_filter
{
    my ($self, $curproc, $mesg) = @_;
    my $config = $curproc->config();

    use FML::Filter::Size;
    my $obj = new FML::Filter::Size $curproc;

    if (defined $obj) {
	$obj->set_class('incoming_article');

	# overwrite filter rules based on FML::Config
	my $rules = $config->get_as_array_ref('article_size_filter_rules');

	# overwrite rules
	if (defined $rules) {
	    $obj->set_rules( $rules );
	}

	# go check
	$obj->size_check($mesg);
	if ($obj->error()) {
	    my $x;
	    $x =  $obj->error();
	    $x =~ s/\s*at .*$//o;
	    $x =~ s/[\n\s]*$//mo;
	    $self->error_set($x);
	    return $x;
	}
    }

    return 0;
}


# Descriptions: header based filter.
#    Arguments: OBJ($self) OBJ($curproc) OBJ($mesg)
# Side Effects: none
# Return Value: STR(reason) or 0 (not trapped, ok)
sub _apply_article_header_filter
{
    my ($self, $curproc, $mesg) = @_;
    my $config = $curproc->config();

    use FML::Filter::Header;
    my $obj = new FML::Filter::Header;

    if (defined $obj) {
	# overwrite filter rules based on FML::Config
	my $rules = $config->get_as_array_ref('article_header_filter_rules');

	# overwrite rules
	if (defined $rules) {
	    $obj->set_rules( $rules );
	}

	# go check
	$obj->header_check($mesg);
	if ($obj->error()) {
	    my $x;
	    $x =  $obj->error();
	    $x =~ s/\s*at .*$//o;
	    $x =~ s/[\n\s]*$//mo;
	    $self->error_set($x);
	    return $x;
	}
    }

    return 0;
}


# Descriptions: filter non MIME format message.
#    Arguments: OBJ($self) OBJ($curproc) OBJ($mesg)
# Side Effects: none
# Return Value: 0 (always ok, anyway)
sub _apply_article_non_mime_filter
{
    my ($self, $curproc, $mesg) = @_;
    my $config = $curproc->config();

    if ($config->yes( 'use_article_non_mime_filter' )) {
	my $hdr   = $curproc->incoming_message_header();
	my $rules =
	    $config->get_as_array_ref('article_non_mime_filter_rules');

      RULE:
	for my $rule (@$rules) {
	    $curproc->log("article_non_mime_filter.check $rule") if $debug;

	    if ($rule eq 'permit') {
		return 0;
	    }

	    if ($rule eq 'reject_empty_content_type') {
		if (defined $hdr) {
		    my $type  = $hdr->get('content-type') || '';
		    unless ($type) {
			my $s = "no Content-Type:";
			$self->error_set($s);
			return $s;
		    }
		}
	    }
	}
    }

    return 0;
}


# Descriptions: syntax check for text(/plain).
#    Arguments: OBJ($self) OBJ($curproc) OBJ($mesg)
# Side Effects: none
# Return Value: none
sub _apply_article_text_plain_filter
{
    my ($self, $curproc, $mesg) = @_;
    my $config = $curproc->config();

    if ($config->yes( 'use_article_text_plain_filter' )) {
	use FML::Filter::TextPlain;
	my $obj = new FML::Filter::TextPlain;

	# overwrite filter rules based on FML::Config
	my $rules =
	    $config->get_as_array_ref('article_text_plain_filter_rules');
	if (defined $rules) {
	    $obj->set_rules( $rules );
	}

	# go check
	$obj->body_check($mesg);
	if ($obj->error()) {
	    my $x;
	    $x =  $obj->error();
	    $x =~ s/\s*at .*$//o;
	    $x =~ s/[\n\s]*$//mo;
	    $self->error_set($x);
	    return $x;
	}
    }

    return 0;
}


# Descriptions: analyze MIME structure and filter it if matched.
#    Arguments: OBJ($self) OBJ($curproc) OBJ($mesg)
# Side Effects: none
# Return Value: none
sub _apply_article_mime_component_filter
{
    my ($self, $curproc, $mesg) = @_;
    my $config = $curproc->config();

    if ($config->yes( 'use_article_mime_component_filter' )) {
	use FML::Filter::MimeComponent;
	my $obj  = new FML::Filter::MimeComponent $curproc;
	my $file = $config->get('article_mime_component_filter_rules');

	if (-f $file) {
	    $obj->read_filter_rule_from_file($file);
	    $obj->mime_component_check($mesg);
	}
	else {
	    if ($debug) {
		$curproc->log("(debug) disabled since rule file not found");
	    }

	    return 0;
	}

	if ($obj->error()) {
	    my $x;
	    $x =  $obj->error();
	    $x =~ s/\s*at .*$//o;
	    $x =~ s/[\n\s]*$//mo;
	    $self->error_set($x);
	    return $x;
	}
    }

    return 0;
}


=head1 REJECT NOTIFICATION

=head2 article_filter_reject_notice($curproc, $msg_args)

send back message on rejection, with reason if could.

=cut


# Descriptions: send back message on rejection, with reason if could.
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($msg_args)
# Side Effects: update reply message queue
# Return Value: none
sub article_filter_reject_notice
{
    my ($self, $curproc, $msg_args) = @_;
    $self->_filter_reject_notice($curproc, $msg_args, "article");
}


# Descriptions: send back message on rejection, with reason if could.
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($msg_args)
# Side Effects: update reply message queue
# Return Value: none
sub command_mail_filter_reject_notice
{
    my ($self, $curproc, $msg_args) = @_;
    $self->_filter_reject_notice($curproc, $msg_args, "command_mail");
}


# Descriptions: send back message on rejection, with reason if could.
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($msg_args) STR($class)
# Side Effects: update reply message queue
# Return Value: none
sub _filter_reject_notice
{
    my ($self, $curproc, $msg_args, $class) = @_;
    my $cred   = $curproc->{ credential };
    my $config = $curproc->config();
    my $msg    = $curproc->incoming_message();
    my $r      = $msg_args->{ _arg_reason } || 'unknown';
    my $type   = $config->{ "${class}_filter_reject_notice_data_type" } ||
	'string';
    my $size   = 2048;

    # recipients
    my $list  =
	$config->get_as_array_ref("${class}_filter_reject_notice_recipients");
    my $rcpts = $curproc->convert_to_mail_address($list);
    $msg_args->{ recipient }    = $rcpts;
    $msg_args->{ _arg_address } = $cred->sender();
    $msg_args->{ _arg_size    } = $size;

    $curproc->log("filter notice: [ @$rcpts ]");

    $curproc->reply_message_nl("error.reject_post",
			       "your post is rejected.",
			       $msg_args);
    $curproc->reply_message_nl("error.reject_post_reason",
			       "reason(s) for rejection: $r",
			       $msg_args);

    # XXX-TODO: need swtich to forward whether header or header+body ?
    # what we forward ?
    if ($type eq 'multipart') {
	$curproc->reply_message($msg, $msg_args);
    }
    elsif ($type eq 'string') {
	my $s = $msg->whole_message_as_str( {
	    indent => '   ',
	    size   => $size,
	});
	my $r = "The first $size bytes of this message follows:";
	$curproc->reply_message_nl("error.reject_notice_preamble",
				   $r,
				   $msg_args);
	$curproc->reply_message(sprintf("\n\n%s", $s), $msg_args);
    }
    else {
	my $s = "unknown ${class}_filter_reject_notice_data_type: $type";
	$curproc->logerror($s);
    }
}


=head1 COMMAND MAIL

=head2 command_mail_filter($curproc)

entry point for FML::Filter::* modules.

=cut


# Descriptions: entry point for FML::Filter::* modules.
#    Arguments: OBJ($self) OBJ($curproc)
# Side Effects: none
# Return Value: STR or UNDEF, error reason (string). return undef if ok.
sub command_mail_filter
{
    my ($self, $curproc) = @_;
    my $message = $curproc->incoming_message();
    my $config  = $curproc->config();

    if (defined $message) {
	my $functions =
	    $config->get_as_array_ref('command_mail_filter_functions');
	my $status    = 0;

      FUNCTION:
	for my $function (@$functions) {
	    if ($config->yes( "use_${function}" )) {
		$curproc->log("filter(debug): check by $function") if $debug;
		my $fp  = "_apply_$function";
		$status = $self->$fp($curproc, $message);
	    }
	    else {
		if ($debug) {
		    $curproc->log("filter(debug): $function check disabled.");
		}
	    }

	    last FUNCTION if $status;
	}

	return $status if $status;
    }

    return undef;
}


# Descriptions: size based filtering.
#    Arguments: OBJ($self) OBJ($curproc) OBJ($mesg)
# Side Effects: none
# Return Value: STR(reason) or 0 (not trapped, ok)
sub _apply_command_mail_size_filter
{
    my ($self, $curproc, $mesg) = @_;
    my $config = $curproc->config();

    use FML::Filter::Size;
    my $obj = new FML::Filter::Size $curproc;

    if (defined $obj) {
	$obj->set_class('incoming_command_mail');

	# overwrite filter rules based on FML::Config
	my $rules =
	    $config->get_as_array_ref('command_mail_size_filter_rules');

	# overwrite rules
	if (defined $rules) {
	    $obj->set_rules( $rules );
	}

	# go check
	$obj->size_check($mesg);
	if ($obj->error()) {
	    my $x;
	    $x =  $obj->error();
	    $x =~ s/\s*at .*$//o;
	    $x =~ s/[\n\s]*$//mo;
	    $self->error_set($x);
	    return $x;
	}
    }

    return 0;
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001,2002,2003,2004 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Filter first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
