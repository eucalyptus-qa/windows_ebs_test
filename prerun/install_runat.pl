#!/usr/bin/perl

system("mkdir -p ../etc/bin");
system("gcc runat.c -o ../etc/bin/runat");

my $rc = $? >> 8;

if( $rc == 1) {
	exit(1);
};
exit(0);

