#!/usr/local/bin/perl
# multipart.pl: Multipart Canceler
# Converter from Multipart/Mixed or Multipart/Alternative to Text/Plain
# (C) 1996-1999 Yuao Tanigawa
#
# $Id: multipart.pl,v 1.3.1.2 1999/04/24 10:41:37 yuao Exp $
#

$count = 0;
while (<STDIN>) {
	if (1 .. /^$/) {# header
		if (/^[A-Za-z]/ || /^$/) {
			if (/^Content-Type: /i) {
				$CT_Field = 1;
			} else {
				if ($CT_Field) {
					if ($Content_Type =~ /multipart\/mixed/i) {
						$type = 'Multipart/Mixed';
						$Content_Type =~ /boundary=\"([^\"]+)\"/i;
						$boundary = '--'.$1;
					} elsif ($Content_Type =~ /multipart\/alternative/i) {
						$type = 'Multipart/Alternative';
						$Content_Type =~ /boundary=\"([^\"]+)\"/i;
						$boundary = '--'.$1;
					}
					if (length($type) > 0) {
						print "Content-Type: text/plain; charset=ISO-2022-JP\n";
						print "X-Ml-Ignore-Type: $type\n";
					} elsif (length($Content_Type) > 0) {
						print $Content_Type;
					}
				}
				$CT_Field = 0;
			}
		}
		if ($CT_Field) {
			$Content_Type .= $_;
		} else {
			print;
		}
	} else {# body
		if ($Happy99) {
			if (/^end/) {
				$Happy99 = 0;
				print " - - - >8 - - - >8 - - - >8 - - - >8 - - - >8 - - -\n";
				print "Happy99.exe worm was attached to this mail here.\n";
				print "multipart.pl removed it.\n";
				print " - - - >8 - - - >8 - - - >8 - - - >8 - - - >8 - - -\n";
			}
			next;
		}
		if (/^begin 644 Happy99\.exe/) {
			$Happy99 = 1;
			next;
		}
		if ($type eq 'Multipart/Mixed') {
			chop;
			if (index($_, $boundary) >= 0) {
				while (<STDIN>) {# skip part header
					last if /^$/;
				}
				print "# End of Document No.$count.\n--\n\n" if $count > 0;
				$count++;
			} else {
				print $_."\n" if $count > 0;
			}
		} elsif ($type eq 'Multipart/Alternative') {
			chop;
			if (index($_, $boundary) >= 0) {
				last if $count > 0; 
				while (<STDIN>) {# skip part header
					last if /^$/;
				}
				$count++;
			} else {
				print $_."\n" if $count > 0;
			}
		} else {
			print;
		}
	}
}

		

