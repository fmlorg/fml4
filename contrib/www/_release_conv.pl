#!/usr/local/bin/perl

while (<>) {
	if (! /^#/) {
	   s/sapporo.iij.ad.jp/phys.titech.ac.jp/;	
	}

	print;
}