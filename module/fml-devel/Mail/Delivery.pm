#-*- perl -*-
#
#  Copyright (C) 2000-2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Delivery.pm,v 1.7 2002/09/22 14:56:59 fukachan Exp $
#

package Mail::Delivery;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);
use Carp;
use IO::Socket;


=head1 NAME

Mail::Delivery - mail delivery system interface

=head1 SYNOPSIS

    use Mail::Delivery;
    my $service = new Mail::Delivery {
	protocol           => 'SMTP',
	default_io_timeout => 10,
    };
    if ($service->error) { Log($service->error); return;}

    $map_params = {
	'mysql:toymodel' => {
	    getline        => "select ... ",
	    get_next_value => "select ... ",
	    add            => "insert ... ",
	    delete         => "delete ... ",
	    replace        => "set address = 'value' where ... ",
	},
    };

    $service->deliver(
                      {
                          smtp_servers    => '[::1]:25 127.0.0.1:25',

                          smtp_sender     => 'rudo@nuinui.net',
                          recipient_maps  => $recipient_maps,
                          recipient_limit => 1000,
			  map_params      => $map_params,

                          message         => $message,
                      });
    if ($service->error) { Log($service->error); return;}

This class provides the entrance for sub classes.
Actually implementation of this class is
almost C<Mail::Delivery::SMTP> class.
Please see it for more details.

=head1 DESCRIPTION

In C<Mail::Delivery> class,
C<Delivery> is an adapter to
C<SMTP>
C<ESMTP>
C<LMTP> classes.
For example, we use
C<Delivery>
as an entrance into
actual delivery routines in
C<SMTP>
C<ESMTP>
C<LMTP> classes.

                     SMTP
                      |
                      A
                  ----------
                 |          |
  Delivery --> ESMTP       LMTP


=head1 METHODS

=item C<new($args)>

constructor. The request is forwarded to SUPER class.

=cut


# Descriptions: constructor.
#               load module suitable for specified protocol and
#               return object such as Mail::Delivery::ESMTP.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: load module
# Return Value: OBJ
sub new
{
    my ($self, $args) = @_;
    my $protocol =  $args->{ protocol } || 'SMTP';
    my $pkg      = 'Mail::Delivery::SMTP';

    # char's of the protocol name is aligned to upper case.
    $protocol =~ tr/a-z/A-Z/;

    if ($protocol eq 'SMTP') {
	$pkg = 'Mail::Delivery::SMTP';
    }
    elsif ($protocol eq 'ESMTP') {
	$pkg = 'Mail::Delivery::EMTP';
    }
    elsif ($protocol eq 'LMTP') {
	$pkg = 'Mail::Delivery::LMTP';
    }
    else {
	croak("unknown protocol=$protocol");
	return undef;
    }

    unshift(@ISA, $pkg);
    eval qq{require $pkg; $pkg->import();};
    unless ($@) {
	$self->SUPER::new($args);
    }
    else {
	croak("fail to load $pkg");
	return undef;
    }
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

Mail::Delivery first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
