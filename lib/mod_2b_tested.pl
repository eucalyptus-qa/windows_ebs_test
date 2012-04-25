#!/usr/bin/perl

use strict;

use Cwd;

$ENV{'PWD'} = getcwd();

my $cwd = getcwd();

my $this_case = 0;

if( $cwd =~ /_No_(\d+)\// ){
	$this_case = $1;
};

my $this_case_str = sprintf("%03d", $this_case);

my $case_file_name = "case_" . $this_case_str . ".txt"; 

my @case_file_line = ();
my $new_network_mode = "";


print "\n";
print "Reading the existing 2b_tested.lst File\n";

print "\n";
print "=================================================================================\n";
print "\n";

read_input_file();
print "\n";

if( is_mod_2b_tested_dir_from_memo() == 0 ){
	print "No MOD_2B_TESTED_DIR field in MEMO\n";
	print "No Need for Modification of 2b_tested.lst\n\n";
	exit(0);
};

print "\n";
print "=================================================================================\n";
print "\n";


my $mod_dir = "../share/mod_2b_tested_dir/" . $ENV{'QA_MEMO_MOD_2B_TESTED_DIR'};

if( !(-e "$mod_dir/$case_file_name") ){
	print "[TEST_REPORT]\tFAILED to locate the case file $mod_dir/$case_file_name\n";
        print "[TEST_REPORT]\tFAILED to Modify 2b_tested.lst\n\n";
        exit(1);
};

print "Reading the case file $mod_dir/$case_file_name\n\n";

print "=================================================================================\n\n";
print "----------------------\n";
print "CASE FILE No $this_case_str\n";
print "----------------------\n";

open( CASEFILE, "< $mod_dir/$case_file_name" ) or die $!;

my $is_memo = 0;
my $new_memo = "";

my $line;

while ($line = <CASEFILE> ){
	chomp($line);

	if( $is_memo ){
		if( $line ne "END_MEMO" ){
			$new_memo .= $line . "\n";
		};
	};

	if( $line =~ /^\d+\.\d+\.\d+\.\d+\s+.+\s+\[(.+)\]/ ){
		print $line . "\n";
		push(@case_file_line, $1);
	}elsif($line =~ /^\#\d+\.\d+\.\d+\.\d+\s+(.+)/ ){
		print $line . "\n";
                push(@case_file_line, "NULL");
	}elsif($line =~ /^NETWORK\s+(.+)/){
		print $line . "\n";
		$new_network_mode = $1;
	}elsif( $line =~ /^MEMO/ ){
		$is_memo = 1;
	}elsif( $line =~ /^END_MEMO/ ){
		$is_memo = 0;
	};
};

print "\nFOUND NEW MEMO\n\n";
print "$new_memo\n";
print "END_OF_NEW_MEMO\n";
print "----------------------\n";

my %new_memo_hash;
my @new_memo_array = split("\n", $new_memo);

foreach my $m (@new_memo_array){
	if( $m =~ /^(.+)=(.+)/m ){
		my $k = $1;
		my $v = $2;
		$v =~ s/\r//g;
#		print "$k\t$v\n";
		$new_memo_hash{$k} = $v;
	};
};

close( CASEFILE );


print "\n";
print "=================================================================================\n";
print "\n";

print "Existing 2b_tested.lst\n\n";
system("cat ../input/2b_tested.lst");

print "\n";
print "=================================================================================\n";
print "\n";

print "MOD 2b_tested.lst\n";



open( TESTED, "< ../input/2b_tested.lst" ) or die $!;

system( "touch ../input/2b_tested.new" );

open( NEW, "> ../input/2b_tested.new" ) or die $!;

$is_memo = 0;
my $count = 0;

while( $line = <TESTED> ){
	chomp($line);

	if( $line =~ /^(\d+\.\d+\.\d+\.\d+)\s+(.+)\s+\[.+\]/ ){
		if( @case_file_line == 0 ){
			print NEW $line . "\n";
		}elsif( $count >= @case_file_line ){

		}else{
			if( $case_file_line[$count] ne "NULL" ){			
				print NEW $1 . "\t" . $2 . "\t[" . $case_file_line[$count] . "]\n";
			};
			$count++;
		};
	}elsif($line =~ /^NETWORK\s+(.+)/){
		if( $new_network_mode eq "" ){
			print NEW $line . "\n";
		}else{
			print NEW "NETWORK\t" . $new_network_mode . "\n";
		};
	}else{
		if( $is_memo == 1 ){
			if( $line =~ /^(.+)=(.+)/ ){
				if( $new_memo_hash{$1} ne "" ){
					print NEW $1 . "=" . $new_memo_hash{$1} . "\n";
				}else{
					print NEW $line . "\n";
				};
			}else{
				print NEW $line . "\n";
			};
		}else{
			print NEW $line . "\n";
		};

		if( $line =~ /^MEMO/ ){
			$is_memo = 1;
		};
	};
};

close( TESTED );

close( NEW );

system( "mv -f ../input/2b_tested.new ../input/2b_tested.lst" );


print "\n";
print "=================================================================================\n";
print "\n";

print "Modified 2b_tested.lst\n\n";
system("cat ../input/2b_tested.lst");

print "\n";
print "=================================================================================\n";
print "\n";

print "\n";
print "MOD 2b_tested.lst HAS BEEN COMPLETED\n";
print "\n";

exit(0);



########################################### SUBROUTINES ##########################################################

sub is_mod_2b_tested_dir_from_memo{
	$ENV{'QA_MOD_2B_TESTED_DIR'} = "";
        if( $ENV{'QA_MEMO'} =~ /MOD_2B_TESTED_DIR=(.+)\n/ ){
                my $extra = $1;
                $extra =~ s/\r//g;
                print "FOUND in MEMO\n";
                print "MOD_2B_TESTED_DIR=$extra\n";
                $ENV{'QA_MEMO_MOD_2B_TESTED_DIR'} = $extra;
                return 1;
        };
        return 0;
};

# Read input values from input.txt
sub read_input_file{

	my $is_memo = 0;
	my $memo = "";

	open( INPUT, "< ../input/2b_tested.lst" ) || die $!;

	my $line;
	while( $line = <INPUT> ){
		chomp($line);
		if( $is_memo ){
			if( $line ne "END_MEMO" ){
				$memo .= $line . "\n";
			};
		};

        	if( $line =~ /^([\d\.]+)\t(.+)\t(.+)\t(\d+)\t(.+)\t\[(.+)\]/ ){
			print "\n";
			print "IP $1 [Distro $2, Version $3, ARCH $4] is built from $5 as Eucalyptus-$6\n";
			$ENV{'QA_DISTRO'} = $2;
			$ENV{'QA_DISTRO_VER'} = $3;
			$ENV{'QA_ARCH'} = $4;
			$ENV{'QA_SOURCE'} = $5;
			$ENV{'QA_ROLL'} = $6;

        	}elsif( $line =~ /^NETWORK\t(.+)/ ){
        	        print( "\nNETWORK\t$1\n" );
			$ENV{'QA_NETWORK_MODE'} = $1;
        	}elsif( $line =~ /^BZR_DIRECTORY\t(.+)/ ){
        	        print ( "\nBZR DIRECTORY\t$1\n" );
			$ENV{'QA_BZR_DIR'} = $1; 
        	}elsif( $line =~ /^BZR_REVISION\t(.+)/ ){
        	        print ( "\nBZR REVISION\t$1\n" );
			$ENV{'QA_BZR_REV'} = $1;
		}elsif( $line =~ /^PXE_TYPE\t(.+)/ ){
                        print ( "\nPXE_TYPE\t$1\n" );
			$ENV{'QA_PXETYPE'} = $1;
		}elsif( $line =~ /^TESTNAME\s+(.+)/ ){
			print "\nTESTNAME\t$1\n";
			$ENV{'QA_TESTNAME'} = $1;
		}elsif( $line =~ /^TEST_SEQ\s+(.+)/ ){
			print "\nTEST_SEQ\t$1\n";
			$ENV{'QA_TEST_SEQ'} = $1;
		}elsif( $line =~ /^MEMO/ ){
			$is_memo = 1;
		}elsif( $line =~ /^END_MEMO/ ){
			$is_memo = 0;
		};
	};	

	close(INPUT);

	$ENV{'QA_MEMO'} = $memo;

	return 0;
};


1;

