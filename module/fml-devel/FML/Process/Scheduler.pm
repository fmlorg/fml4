#-*- perl -*-
#
# Copyright (C) 2002 Ken'ichi Fukamachi
#          All rights reserved.
#
# $FML: Scheduler.pm,v 1.18 2002/09/15 00:11:44 fukachan Exp $
#

package FML::Process::Scheduler;

use vars qw($debug @ISA @EXPORT @EXPORT_OK);
use strict;
use Carp;
use FML::Log qw(Log LogWarn LogError);
use FML::Config;

=head1 NAME

FML::Process::Scheduler -- Scheduler utility.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut


# Descriptions: dummy constructor.
#               avoid the default fml new() since we do not need it.
#    Arguments: OBJ($self) OBJ($curproc)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self, $curproc) = @_;
    my ($type) = ref($self) || $self;
    my $me     = { _curproc => $curproc };
    my $config = $curproc->config();
    my $qdir   = $config->{ event_queue_dir };

    unless (-d $qdir) {
	$curproc->mkdir($qdir, "mode=public");
    }

    return bless $me, $type;
}


# Descriptions:
#    Arguments: OBJ($self) STR($key)
# Side Effects:
# Return Value: none
sub queue_in
{
    my ($self, $key) = @_;
}


# Descriptions:
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects:
# Return Value: none
sub exits
{

}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2002 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Process::Scheduler first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
