#
# $Id: Tr.pm,v 0.60 1999/10/18 06:01:38 dankogai Exp dankogai $
#

package Jcode::Tr;

use strict;
use vars qw($VERSION $RCSID);

$RCSID = q$Id: Tr.pm,v 0.60 1999/10/18 06:01:38 dankogai Exp dankogai $;
$VERSION = do { my @r = (q$Revision: 0.60 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use Carp;

use Jcode::Constants qw(:all);
use vars qw(%_TABLE);

sub tr {
    # $prev_from, $prev_to, %table are persistent variables
    my ($r_str, $from, $to, $opt) = @_;
    my (@from, @to);
    my $n = 0;

    undef %_TABLE;
    &_maketable($from, $to, $opt);

    $$r_str =~ s(
		 ([\x80-\xff][\x00-\xff]|[\x00-\xff])
		 )
    {defined($_TABLE{$1}) && ++$n ? 
	 $_TABLE{$1} : $1}ogex;

    return $n;
}

sub _maketable {
    my ($from, $to, $opt) = @_;
    my ($ascii) = '(\\\\[\\-\\\\]|[\x00-\x5b\x5d-\x7f])';
    grep(s/(([\x80-\xff])[\x80-\xff]-\2[\x80-\xff])/&_expnd2($1)/geo,
	 $from,$to);
    grep(s/($ascii-$ascii)/&_expnd1($1)/geo,
	 $from,$to);

    my @to   = $to   =~ /[\x80-\xff][\x00-\xff]|[\x00-\xff]/go;
    my @from = $from =~ /[\x80-\xff][\x00-\xff]|[\x00-\xff]/go;

    push(@to, ($opt =~ /d/ ? '' : $to[$#to]) x (@from - @to)) if @to < @from;
    @_TABLE{@from} = @to;
}

sub _expnd1 {
    my ($str) = @_;
    s/\\(.)/$1/og;
    my($c1, $c2) = unpack('CxC', $str);
    if ($c1 <= $c2) {
        for ($str = ''; $c1 <= $c2; $c1++) {
            $str .= pack('C', $c1);
        }
    }
    return $str;
}

sub _expnd2 {
    my ($str) = @_;
    my ($c1, $c2, $c3, $c4) = unpack('CCxCC', $str);
    if ($c1 == $c3 && $c2 <= $c4) {
        for ($str = ''; $c2 <= $c4; $c2++) {
            $str .= pack('CC', $c1, $c2);
        }
    }
    return $str;
}

1;
