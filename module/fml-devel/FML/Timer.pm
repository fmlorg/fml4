#-*- perl -*-
#
#  Copyright (C) 2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: @template.pm,v 1.7 2003/01/01 02:06:22 fukachan Exp $
#

package FML::Timer;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

=head1 NAME

FML::Timer - what is this

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<new()>

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: create object
# Return Value: OBJ
sub new
{
    my ($self, $args) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};

    for my $id ('keyword', 'class', 'address', 'buffer', 'cache_dir') {
	if (defined $args->{ $id }) {
	    $me->{ "_$id" } = $args->{ $id };
	}
    }

    return bless $me, $type;
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

__YOUR_NAME__

=head1 COPYRIGHT

Copyright (C) 2003 __YOUR_NAME__

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Timer appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
