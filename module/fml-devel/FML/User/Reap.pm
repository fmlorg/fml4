#-*- perl -*-
#
#  Copyright (C) 2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Info.pm,v 1.1 2003/11/23 14:18:23 fukachan Exp $
#

package FML::User::Reap;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD
	    $debug $default_expire_period);
use Carp;


=head1 NAME

FML::User::Reap - maintain data with expiration.

=head1 SYNOPSIS

    use FML::User::Reap;
    my $data = new FML::User::Reap $curproc;
    $data->import_from_mail_header($curproc, $info);

=head1 DESCRIPTION

=head1 METHODS

=head2 C<new()>

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($Infoargs)
# Side Effects: create object
# Return Value: OBJ
sub new
{
    my ($self, $curproc, $Infoargs) = @_;
    my ($type) = ref($self) || $self;
    my $me     = { _curproc => $curproc };

    use FML::User::DB;
    $me->{ _db } = new FML::User::DB $curproc;

    return bless $me, $type;
}


=head2 scan

=cut


# Descriptions: delete users.
#    Arguments: OBJ($self)
# Side Effects: delete users.
# Return Value: none
sub scan
{
    my ($self) = @_;



}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2003 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::User::Reap appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
