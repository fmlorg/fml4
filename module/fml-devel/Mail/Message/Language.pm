#-*- perl -*-
#
# Copyright (C) 2003 Ken'ichi Fukamachi
#
# $FML: Language.pm,v 1.1 2003/10/15 09:09:14 fukachan Exp $
#

package Mail::Message::Language;
use strict;

=head1 NAME

Mail::Message::Language - handle *-Language:

=head1 SYNOPSIS

   use Mail::Message::Language;
   my $mh = new Mail::Message::Language;

=head1 DESCRIPTION

=head1 METHODS

=cut


# Descriptions: return list of languages to accept as ARRAY_REF.
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: ARRAY_REF
sub accept_language_list
{
    my ($self) = @_;
    my $header = $self->whole_message_header();
    my $buf    = $header->get('Accept-Language');
    my $list   = [];

  LANG:
    for my $s (split(/\s*,\s*/, $buf)) {
	if ($s =~ /^\s*ja/oi) {
	    push(@$list, 'ja');
	    last LANG;
	}
	elsif ($s =~ /^\s*en/oi) {
	    push(@$list, 'en');
	    last LANG;
	}
    }

    push(@$list, '*'); # any language by default.
    return $list;
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2003 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut


1;
