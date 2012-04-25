#!/usr/bin/perl

$ec2timeout = 10;
$mode = shift @ARGV;
if ($mode eq "nonmanaged" || $mode eq "system" || $mode eq "static") {
    $managed = 0;
} else {
    $managed = 1;
}
# clean up keypairs
$count=0;
system("date");
$cmd = "runat $ec2timeout euca-describe-keypairs";
open(RFH, "$cmd|");
while(<RFH>) {
    chomp;
    my $line = $_;
    my ($tmp, $kp) = split(/\s+/, $line);
    if ($kp) {
	$kps[$count] = $kp;
	$count++;
    }
}
close(RFH);
if (@kps < 1) {
    print "WARN: could not get any keypairs from euca-describe-keypairs\n";
} else {
    for ($i=0; $i<@kps; $i++) {
	system("date");
$cmd = "runat $ec2timeout euca-delete-keypair $kps[$i]";
	$rc = system($cmd);
	if ($rc) {
	    print "ERROR: failed - '$cmd'\n";
	}
	system("rm $kps[$i].priv");
    }
}

# clean up groups
$count=0;
system("date");
$cmd = "runat $ec2timeout euca-describe-groups";
open(RFH, "$cmd|");
while(<RFH>) {
    chomp;
    my $line = $_;
    my ($type, $foo, $group) = split(/\s+/, $line);
    if ($type eq "GROUP") {
	if ($group && $group ne "default") {
	    $groups[$count] = $group;
	    $count++;
	}
    }
}
close(RFH);
if (@groups < 1) {
    print "WARN: could not get any groups from euca-describe-groups\n";
} else {
    for ($i=0; $i<@groups; $i++) {
	system("date");
$cmd = "runat $ec2timeout euca-revoke $groups[$i] -P icmp -s 0.0.0.0/0 -t -1:-1";
	$rc = system($cmd);
	if ($rc) {
	    print "ERROR: failed - '$cmd'\n";
	}
	system("date");
$cmd = "runat $ec2timeout euca-revoke $groups[$i] -P tcp -p 22 -s 0.0.0.0/0";
	$rc = system($cmd);
	if ($rc) {
	    print "ERROR: failed - '$cmd'\n";
	}
	system("date");
$cmd = "runat $ec2timeout euca-delete-group $groups[$i]";
	$rc = system($cmd);
	if ($rc) {
	    print "ERROR: failed - '$cmd'\n";
	}
    }
}

if ($managed) {
# clean up addrs
    $count=0;
    system("date");
$cmd = "runat $ec2timeout euca-describe-addresses | grep admin";
    open(RFH, "$cmd|");
    while(<RFH>) {
	chomp;
	my $line = $_;
	my ($tmp, $ip) = split(/\s+/, $line);
	if ($ip) {
	    $ips[$count] = $ip;
	    $count++;
	}
    }
    close(RFH);
    if (@ips < 1) {
	print "WARN: could not get any addrs from euca-describe-addresses\n";
    } else {
	for ($i=0; $i<@ips; $i++) {
	    system("date");
$cmd = "runat $ec2timeout euca-disassociate-address $ips[$i]";
	    $rc = system($cmd);
	    if ($rc) {
		print "ERROR: failed - '$cmd'\n";
	    }
	    $cmd = "euca-release-address $ips[$i]";
	    $rc = system($cmd);
	    if ($rc) {
		print "ERROR: failed - '$cmd'\n";
	    }
	}
    }
}
# clean up running instances
chomp($instIds=`runat 15 euca-describe-instances | grep INST | awk '{print \$2}'`);
$instIds=~s/\n/ /g;
print "INSTIDS: $instIds\n";
if ($instIds) {
    system("date");
$cmd = "runat $ec2timeout euca-terminate-instances $instIds";
    $rc = system($cmd);
    if ($rc) {
	print "ERROR: failed - '$cmd'\n";
    }
}

exit(0);
