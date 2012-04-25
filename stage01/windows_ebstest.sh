#!/bin/bash

#echo "EBS test broken now; just return success"
#sleep 30
#exit 0
# test sequence
# 1. EBS test
# 2. Elastic IP test
REPEAT_EBS=1
source ../lib/winqa_util.sh
setup_euca2ools;

hostbit=$(host_bitness)
guestbit=$(guest_bitness)
if [ $guestbit -eq "64" ] && [ $hostbit -eq "32" ]; then
    echo "Running 64 bit guest on 32 bit host"
    sleep 10
    exit 0
fi

cp ../etc/id_rsa.proxy ./
chmod 400 ./id_rsa.proxy                                                                                                        
winimgs=$(euca-describe-images | grep windows | grep -v deregistered)
if [ -z "$winimgs" ]; then
        echo "ERROR: No windows image is found in Walrus"
        exit 1
fi

# kill for testing
hypervisor=$(describe_hypervisor)
echo "Hypervisor: $hypervisor"

exitCode=0
IFS=$'\n'
for img in $winimgs; do
	if [ -z "$img" ]; then
		continue;
	fi
	IFS=$'\n'
        emi=$(echo $img | cut -f2)
	echo "EMI: $emi"

	unset IFS
   	ret=$(euca-describe-instances | grep $emi | grep -E "running")
	if [ -z "$ret" ]; then
		echo "ERROR: Can't find the running instance of $emi"
		exitCode=1
		break;
	fi
        instance=$(echo -e ${ret/*INSTANCE/} | cut -f1 -d ' ')
	if [ -z $instance ]; then
                echo "ERROR: Instance from $emi is null"
		exitCode=1
                break;
        fi
	zone=$(echo -e ${ret/*INSTANCE/} | cut -f10 -d ' ')
        ipaddr=$(echo -e ${ret/*INSTANCE/} | cut -f3 -d ' ')
	keyname=$(echo -e ${ret/*INSTANCE/} | cut -f6 -d ' ')
	
	if [ -z "$zone" ] || [ -z "$ipaddr" ] || [ -z "$keyname" ]; then
		echo "ERROR: Parameter is missing: zone=$zone, ipaddr=$ipaddr, keyname=$keyname"
		exitCode=1
		break;
	fi
        keyfile_src=$(whereis_keyfile $keyname)
        if ! ls -la $keyfile_src; then
            echo "ERROR: cannot find the key file from $keyfile_src"
            exitCode=1
            break
        fi
      
	keyfile="$keyname.priv"

        cp $keyfile_src $keyfile
	
	if [ ! -s $keyfile ]; then
		echo "ERROR: can't find the key file $keyfile";
		exitCode=1
		break;
	fi

	ret=$(euca-describe-volumes | grep 'available')
        sleep 1
        if [ -n "$ret" ]; then
		echo "available volume found"
		echo "$ret"
                set -- $ret
                volume=$2
        else	
		echo "creating volume with size 2, zone=$zone"
                ret=$(euca-create-volume -s 2 -z "$zone")
                if !(echo $ret | grep "vol" > /dev/null;) then
                        echo "ERROR: volume was not created"; 	
			exitCode=1
			echo "$ret"
			break;
                fi
		sleep 20
                trial=0
                while [ $trial -lt 3 ]; do
                    ((trial++))
		    ret=$(euca-describe-volumes)
                    if echo "$ret" | grep 'available' ; then
                        break;
                    else
		        echo "no available volume at $trial's trial"
                        echo "$ret"
                        sleep 5
                        continue
                    fi 
		done 
      
		if [ $trial -ge 3 ]; then
			echo "ERROR: Could not create EBS volume"
			exitCode=1
			break;
		fi

		set -- $ret
                volume=$2;
		sleep 1
        fi

        if [ -z "$volume" ] || [ -z "$(echo $volume | grep 'vol-')" ]; then
                echo "ERROR: No available volume";
		exitCode=1	
		break; 
        fi

	dev="NULL"
        if [ $hypervisor = "kvm" ]; then
                dev="/dev/sdc"
        elif [ $hypervisor = "xen" ]; then
                dev="/dev/sdc"
        elif [ $hypervisor = "hyperv" ]; then
                dev="/dev/sdc"
        elif [ $hypervisor = "vmware" ]; then
                dev="/dev/sdc"
        else
                echo "ERROR: Unknown hypervisor"; 
		exitCode=1	
		break
        fi

	i=0
	error=0
	while [ $i -lt $REPEAT_EBS ]; do
		if [ $error -eq 1 ]; then
			break;
		fi

		((i++))
		echo "EBS test $i'th trial"
       		ret=$(euca-attach-volume -i $instance -d $dev $volume)
		echo "attach-volume requested: $ret"
	        echo "now sleeping for 60 sec"
                sleep 60;
		echo "checking the status of supposedly attached volume"
		timeout=60
       		j=0
        	attached=1
        	while !(euca-describe-volumes $volume | grep "in-use" > /dev/null); do
               	 	sleep 1
               	 	((j++))
                	if [ $j -gt $timeout ]; then
                       		attached=0
                        	break;
                	fi
        	done
        	if [ $attached -eq 0 ]; then
               		echo "ERROR: Couldn't attach the volume";
			euca-describe-volumes $volume;
			error=1
			exitCode=1
			sleep 10
                        if ! euca-delete-volume $volume; then
                                echo "Couldn't delete the volume $volume";
                        else
                                echo "Deleted the volume $volume";
                        fi
                        sleep 5
                        euca-describe-volumes $volume;
			break;
        	fi
	
		echo "Volume attached"
		sleep 20; # wait enough time to Windows to see the attached device      
		doguesttest=1;
	
                if ! should_test_guest; then  
                      echo "[WARNING] We don't perform guest test for this instance";
                      doguesttest=0;
                fi

                if cat ../input/2b_tested.lst | grep "NC00" | grep "RHEL" > /dev/null; then
                       if [ $hostbit -eq "32" ]; then
                              doguesttest=0;
                              echo "Skipping guest partition/format test for RHEL 32 bit host";
                       fi
                fi

	        if [ $doguesttest -eq 1 ]; then
        	       cmd="euca-get-password -k $keyfile $instance"
        	       echo $cmd
        	       passwd=$($cmd)
        	       if [ -z "$passwd" ]; then
               		      echo "ERROR: password is null"; 
			      error=1	
			      exitCode=1
		       else
			      echo "attempting to login.."	
       		 	      ret=$(./login.sh -h $ipaddr -p $passwd)
			      if [ -z "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
               		    	    echo "ERROR: Couldn't login for EBS test ($ret)";
				    error=1
				    exitCode=1
			      else	
				   echo "login successful; running ebs.sh"
			           guesstimeout=4;  # minutes after which guest ebs test is given up
                                   k=0;
                                   while [ $k -lt $guesstimeout ]; do
                                         ((k++))
         	                         # call ebs.sh
        			         ret=$(./ebs.sh)
       				         if [ -z "$(echo $ret | tail -n 1 | grep 'SUCCESS')" ]; then
					       echo "$k'th ebs guest test failed";
					       sleep 60;
        			         else    
               				       echo "Passed disk format test";
                                               ((k--));
                                               break;
        			         fi
			           done
                                   if [ $k -ge $guesstimeout ]; then
                                           echo "ERROR: disk format test ($ret)";
                                           ret=$(./eucalog.sh)
                                           echo "WINDOWS INSTANCE LOG: $ret"
                                           error=1
                                           exitCode=1
                                   fi
			      fi
		       fi
		fi

		ret=$(euca-detach-volume $volume)
       		detached=1
        	j=0
        	while !(euca-describe-volumes $volume | grep "available" > /dev/null); do
               		sleep 1
                	((j++))
                	if [ $j -gt $timeout ]; then
                       		detached=0
                        	break;
                	fi
        	done

        	if [ $detached -eq 0 ]; then
			echo "ERROR: Couldn't detach the volume"; 
			if [ $REPEAT_EBS -gt 1 ]; then	
				error=1
				exitCode=1
				break;
			fi	
		else
			echo "Detached the volume";

			if ! euca-delete-volume $volume; then
				echo "Couldn't delete the volume $volume";
			else
				echo "Deleted the volume $volume";
			fi 
			sleep 5;
			euca-describe-volumes $volume;
       		fi
		
		sleep 20 # between repeated EBS attachment
	done
	if [ $exitCode -eq 0 ]; then
		echo "EBS test succeeded for $instance";
	else
		break;
	fi
done
exit "$exitCode"

