#!/usr/bin/perl
use strict;
use Cwd;

$ENV{'PWD'} = getcwd();

if( $ENV{'TEST_DIR'} eq "" ){
        my $cwd = getcwd();
        if( $cwd =~ /^(.+)\/lib/ ){
                $ENV{'TEST_DIR'} = $1;
        }else{
                print "ERROR !! Incorrect Current Working Directory ! \n";
                exit(1);
        };
};

# does_It_Have( $arg1, $arg2 )
# does the string $arg1 have $arg2 in it ??
sub does_It_Have{
	my ($string, $target) = @_;
	if( $string =~ /$target/ ){
		return 1;
	};
	return 0;
};



#################### APP SPECIFIC PACKAGES INSTALLATION ##########################

my @ip_lst;
my @distro_lst;
my @version_lst;
my @arch_lst;
my @source_lst;
my @roll_lst;

my %cc_lst;
my %sc_lst;
my %nc_lst;

my $clc_index = -1;
my $cc_index = -1;
my $sc_index = -1;
my $ws_index = -1;

my $clc_ip = "";
my $cc_ip = "";
my $sc_ip = "";
my $ws_ip = "";

my $nc_ip = "";

my $max_cc_num = 0;

$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

#### read the input list

my $index = 0;

open( LIST, "../input/2b_tested.lst" ) or die "$!";
my $line;
while( $line = <LIST> ){
	chomp($line);
	if( $line =~ /^([\d\.]+)\t(.+)\t(.+)\t(\d+)\t(.+)\t\[(.+)\]/ ){
		print "IP $1 [Distro $2, Version $3, Arch $4] will be built from $5 with Eucalyptus-$6\n";

		if( !( $2 eq "VMWARE" || $2 eq "WINDOWS" ) ){

			push( @ip_lst, $1 );
			push( @distro_lst, $2 );
			push( @version_lst, $3 );
			push( @arch_lst, $4 );
			push( @source_lst, $5 );
			push( @roll_lst, $6 );

			my $this_roll = $6;

			if( does_It_Have($this_roll, "CLC") ){
				$clc_index = $index;
				$clc_ip = $1;
			};

			if( does_It_Have($this_roll, "CC") ){
				$cc_index = $index;
				$cc_ip = $1;

				if( $this_roll =~ /CC(\d+)/ ){
					$cc_lst{"CC_$1"} = $cc_ip;
					if( $1 > $max_cc_num ){
						$max_cc_num = $1;
					};
				};			
			};

			if( does_It_Have($this_roll, "SC") ){
				$sc_index = $index;
				$sc_ip = $1;

				if( $this_roll =~ /SC(\d+)/ ){
	                                $sc_lst{"SC_$1"} = $sc_ip;
	                        };
			};

			if( does_It_Have($this_roll, "WS") ){
	                        $ws_index = $index;
	                        $ws_ip = $1;
	                };

			if( does_It_Have($this_roll, "NC") ){
				$nc_ip = $1;
				if( $this_roll =~ /NC(\d+)/ ){
					if( $nc_lst{"NC_$1"} eq	 "" ){
	                                	$nc_lst{"NC_$1"} = $nc_ip;
					}else{
						$nc_lst{"NC_$1"} = $nc_lst{"NC_$1"} . " " . $nc_ip;
					};
	                        };
	                };

			$index++;
		};
        };
};

close( LIST );

if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){
        $ENV{'EUCALYPTUS'} = "";
};

print "$clc_ip :: $ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cloud stop\n";

#Stopping CLC
system("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cloud stop\" ");


for( my $i = 0; $i <= $max_cc_num; $i++){

	my $group = sprintf("%02d", $i);

	my $my_cc_ip = $cc_lst{"CC_$group"};
	print "$my_cc_ip :: $ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cc stop\n";
        #Stopping CC
        system("ssh -o StrictHostKeyChecking=no root\@$my_cc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cc stop\" ");

	my $my_sc_ip = $sc_lst{"SC_$group"};
	print "$my_sc_ip :: $ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-sc stop\n";
	#Stopping Storage Control
	system("ssh -o StrictHostKeyChecking=no root\@$my_sc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-sc stop\" ");


	my @my_nc_ips = split( / / , $nc_lst{"NC_$group"} );
	foreach my $my_nc_ip (@my_nc_ips){
		print "$my_nc_ip :: $ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-nc stop\n";
		#Stopping Node Control
		system("ssh -o StrictHostKeyChecking=no root\@$my_nc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-nc stop\" ");
	};
};

print "$ws_ip :: $ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-walrus stop\n";

#Stopping Walrus 
system("ssh -o StrictHostKeyChecking=no root\@$ws_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-walrus stop\" ");


print "\nALL THE COMPONENETS HAS BEEN STOPPED\n";

exit(0);
