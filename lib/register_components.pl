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

sub is_it_multi_clusters{
        open( TESTED, "< ../input/2b_tested.lst" ) or die $!;
        my $multi = 0;
        my $line;
        while( $line = <TESTED> ){
                chomp($line);
		if( $line =~ /^([\d\.]+)\t(.+)\t(.+)\t(\d+)\t(.+)\t\[(.+)\]/ ){
                        my $compo = $6;
                        while( $compo =~ /(\d+)(.+)/ ){
                                if( int($1) > $multi ){
                                        $multi = int($1);
                                };
                                $compo = $2;
                        };
                };
        };
        close(TESTED);
        return $multi;
};

sub get_this_cc_id{
	my $this_ip = shift @_; 
        my $id = -1;
        my $scan = `cat ../input/2b_tested.lst | grep $this_ip`;
        chomp($scan);
        if( $scan =~ /CC(\d+)/ ||  $scan =~ /NC(\d+)/ ){
                $id = int($1);
                $ENV{'MY_CC_ID'} = $id;
        };
        return $id;
};

sub get_this_priv_ip{
	my $input_ip = shift @_;
	my $this_cc_id = get_this_cc_id($input_ip);
	
	my $priv_ip = "10.10.";

	if( $input_ip =~ /192\.168\.(\d+)\.(\d+)/ ){
        	my $priv_group = 10 + $this_cc_id;
        	$priv_ip .= $priv_group . "." . $2;
        	$ENV{'PRIV_IP'} = $priv_ip;
	};

	return $priv_ip;
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

close( LIST );


if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){
	$ENV{'EUCALYPTUS'} = "";
};

### check for multi-clusters mode

$ENV{'IS_IT_MULTI'} = is_it_multi_clusters();


my $outstr = "";

print "$clc_ip :: $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-walrus $ws_ip \n";

#Register Walrus
print("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-walrus $ws_ip\"\n");
$outstr = `ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-walrus $ws_ip\"`;

print $outstr;
if( $outstr =~ /SUCCESS:/ ){
	print "Registered Walrus $ws_ip successfully !\n\n";
}else{
	print "[TEST_REPORT]\tFAILED to Register Walrus $ws_ip !!\n\n";
	exit(1);
};



sleep(30);

# quick hack for DEBIAN to resolve deadlock
if( $distro_lst[0] eq "DEBIAN" ){
	print "In order to resolve deadlock issue in DEBIAN, the CLC will be restarted.\n";
	system("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cloud restart\" ");
	sleep(30);
};

for( my $i = 0; $i <= $max_cc_num; $i++){

	my $group = sprintf("%02d", $i);

	my $my_cc_ip = $cc_lst{"CC_$group"};
	print "$clc_ip :: $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-cluster test$group $my_cc_ip\n";

	#Register Cluster
	print("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-cluster test$group $my_cc_ip\"\n");
	$outstr = `ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-cluster test$group $my_cc_ip\"`;

	print $outstr;
	if( $outstr =~ /SUCCESS:/ ){
	        print "Registered Cluster $my_cc_ip successfully !\n\n";
	}else{
	        print "[TEST_REPORT]\tFAILED to Register Cluster $my_cc_ip !!\n\n";
	        exit(1);
	};


	sleep(30);

	# quick hack for DEBIAN to resolve deadlock
	if( $distro_lst[0] eq "DEBIAN" ){
		print "In order to resolve deadlock issue in DEBIAN, the CLC will be restarted.\n";
	        system("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cloud restart\" ");
	        sleep(30);
	}elsif( $distro_lst[0] eq "OPENSUSE" ){
#		sleep(30);
#		print "In order to resolve deadlock issue in OPENSUSE, the CLC will be restarted.\n";
#		system("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/etc/init.d/eucalyptus-cloud restart\" ");
#		sleep(30);
	};

	my $my_sc_ip = $sc_lst{"SC_$group"};
	print "$clc_ip :: $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-sc test$group $my_sc_ip \n";

	#Register Storage Control
	print("ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-sc test$group $my_sc_ip\"\n");
	$outstr = `ssh -o StrictHostKeyChecking=no root\@$clc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-sc test$group $my_sc_ip\"`;

	print $outstr;
        if( $outstr =~ /SUCCESS:/ ){
                print "Registered StorageController $my_sc_ip successfully !\n\n";
        }else{
                print "[TEST_REPORT]\tFAILED to Register StorageController $my_sc_ip !!\n\n";
                exit(1);
        };

	sleep(30);

	my @my_nc_ips = split( / / , $nc_lst{"NC_$group"} );
	foreach my $my_nc_ip (@my_nc_ips){


		# addition for multi-clusters mode !
		if( $ENV{'IS_IT_MULTI'} > 0 ){
	#		$my_nc_ip = get_this_priv_ip( $my_nc_ip );
		};


		print "$my_cc_ip :: $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-nodes $my_nc_ip \n";
		#Register Nodes
		print("ssh -o StrictHostKeyChecking=no root\@$my_cc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-nodes $my_nc_ip\"\n");
		$outstr = `ssh -o StrictHostKeyChecking=no root\@$my_cc_ip \"$ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --register-nodes $my_nc_ip\"`;

	        print $outstr;
	        if( $outstr =~ /\.\.\.done/ ){
	                print "Registered Node $my_nc_ip successfully !\n\n";
	        }else{
	                print "[TEST_REPORT]\tFAILED to Register Node $my_nc_ip !!\n\n";
	                exit(1);
	        };

		sleep(30);
	};
};
	

print "\nREGISTRATION OF COMPONENETS HAVE BEEN COMPLETED\n";

exit(0);
