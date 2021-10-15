#!/bin/bash
#------------------------------------------------------------------------------------------------------------------------
# For a given tree and presence absence matrix this script performs terrace anaylsis using Gentrius algorithm.
#
# Usage:
# ./script-run-main-terrace-analysis-PER_DATASET.sh <pr_ab_matrix> <tree>
#
#-------------------------------------
# tree - Newick format
# 
# Example of pr_ab_matrix: 
#  5 3  
#  species_1 0 1 1  
#  species_2 1 0 1  
#  species_3 1 1 1  
#  species_4 1 1 0  
#  species_5 1 1 1  
#
#-------------------------------------
# CHANGE the path to iqtree2 binary
#------------------------------------------------------------------------------------------------------------------------
# SUMMARY OUTPUTS:
# tree.DEFAULT.log.SUMMARY_gentrius	- results of run with default thresholds
# tree.*.log.SUMMARY_gentrius_MAIN	- final results: either from DEFAULT, INCREASED or COMPLEX analysis
#------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
# BINARIES/SCRIPTS
#---------------------------------------------------------------------------------
iqtree2="YOUR_PATH_TO/iqtree2" # Path to iqtree2 binary
#---------------------------------------------------------------------------------
# FUNCTIONS
#---------------------------------------------------------------------------------
function check_if_run_finished {
        file=$1
        if [ ! -e $file ]
        then
                echo "ERROR: file - $file - does not exist!"
                exit
        else
                check="`grep "Total CPU time used" $file | wc -l | awk -F " " '{print $1}'`"
                if [ "$check" -ne 1 ]
                then
                        echo "ERROR: the run - $file - might have failed! Please, check."
                        exit
                fi
        fi
}
#---------------------------------------------------------------------------------
function summary_gentrius {
	file="$1"
	if [ ! -e $file ]
        then
                echo "ERROR: file - $file - does not exist!"
                exit
	else
		#-----------------------------------------------------------------
		# stop_rule
		stop_rule="0"
		check=`grep "WARNING: stopping condition is active" $file | wc -l | awk -F " " '{print $1}'`
		if [ "$check" -gt 0 ]
		then
        		check="`cat $file | grep "Type of stopping rule: terrace size" | wc -l | awk -F " " '{print $1}'`"
        		if [ "$check" -eq 1 ]
        		then
                		stop_rule="1"
        		else
                		check="`cat $file | grep "Type of stopping rule: number of visited intermediate trees" | wc -l | awk -F " " '{print $1}'`"
                		if [ "$check" -eq 1 ]
                		then
                        		stop_rule="2"
                		else
                        		stop_rule="3"
                		fi
        		fi
		fi
		#-----------------------------------------------------------------
		terrace_size="`cat $file | grep "Number of trees on terrace"| awk -F ": " '{print $2}'`"
                inter_num="`cat $file | grep "Number of intermediated trees visited"| awk -F ": " '{print $2}'`"
                dead_ends="`cat $file | grep "Number of dead ends encountered"| awk -F ": " '{print $2}'`"
                total_cpu="`cat $file | grep "Total CPU time used" | awk -F " " '{print $5, $7}'`"
                miss_percent="`cat $file | grep "missing entries in supermatrix"| awk -F ": " '{print $2}'`"
		
		n="`cat $file | grep "Number of taxa\:" | awk -F ": " '{print $2}'`"
		k="`cat $file | grep "Number of partitions" | awk -F ": " '{print $2}'`"
		u="`cat $file | grep "Number of special taxa" | awk -F ": " '{print $2}'`"


		init_size="-1"
		taxa_to_insert="-1"
		c1_lim="-1"
		c2_lim="-1"
		c3_lim="-1"

		check="`cat $file | grep "There are only trivial terraces" | wc -l | awk -F " " '{print $1}'`"
		if [ "$check" -eq 0 ]
		then
			init_size="`cat $file | grep "Number of taxa on initial tree"| awk -F ": " '{print $2}'`"
			taxa_to_insert="`cat $file | grep "Number of taxa to be inserted"| awk -F ": " '{print $2}'`"

			c1_lim="`cat $file | grep "Stop if terrace size reached" | awk -F ": " '{print $2}'`"
			c2_lim="`cat $file | grep "Stop if the number of intermediate visited trees reached" | awk -F ": " '{print $2}'`"
			c3_lim="`cat $file | grep "Stop if the CPU time reached" | awk -F " " '{print $8}'`"
		fi

		echo "$file | TAXA $n PART $k MD $miss_percent UniqT $u T_SIZE $terrace_size CPU $total_cpu INT $inter_num DEAD $dead_ends STOP_RULE $stop_rule | INIT_TREE $init_size TAXA_TO_INSERT $taxa_to_insert | C1_LIM $c1_lim C2_LIM $c2_lim C3_LIM $c3_lim" > $file.SUMMARY_gentrius
	fi
}
#---------------------------------------------------------------------------------
# INPUTs 
#---------------------------------------------------------------------------------
pr_ab_matrix="$1"
tree="$2"

# INPUT CHECK:
if [ "$pr_ab_matrix" == "" ] || [ "$tree" == "" ]
then
	echo "ERROR: either a matrix or a tree is not supplied!"
	exit
else
	if [ ! -e "$pr_ab_matrix" ]
	then
		echo "ERROR: matrix file - $pr_ab_matrix - does not exist!"
		exit
	fi

	if [ ! -e "$tree" ]
        then
                echo "ERROR: tree file - $tree - does not exist!"
                exit
        fi
fi
#---------------------------------------------------------------------------------
# MAIN TERRACE ANALYSIS
#---------------------------------------------------------------------------------
# RUN: DEFAULT
#---------------------------------------------------------------------------------
tag="DEFAULT"
file=${tree}.${tag}.log
if [ ! -e $file ]
then
	$iqtree2 -gentrius -pr_ab_matrix $pr_ab_matrix $tree -pre ${tree}.${tag} -quiet
fi
#---------------------------------------------------------------------------------
check_if_run_finished $file
#---------------------------------------------------------------------------------
terrace_size=`grep "Number of trees on terrace" $file | awk -F ": " '{print $2}'`
taxa_to_insert="`cat $file | grep "Number of taxa to be inserted"| awk -F ": " '{print $2}'`"
stop_rule="0"
check=`grep "WARNING: stopping condition is active" $file | wc -l | awk -F " " '{print $1}'`
if [ "$check" -gt 0 ]
then
	check="`cat $file | grep "Type of stopping rule: terrace size" | wc -l | awk -F " " '{print $1}'`"
	if [ "$check" -eq 1 ]
	then
		stop_rule="1"
	else
		check="`cat $file | grep "Type of stopping rule: number of visited intermediate trees" | wc -l | awk -F " " '{print $1}'`"
		if [ "$check" -eq 1 ]
		then
			stop_rule="2"
		else
			stop_rule="3"
		fi
	fi
fi
#---------------------------------------------------------------------------------
summary_gentrius $file
if [ "$stop_rule" -eq 0 ]
then
	cp $file.SUMMARY_gentrius $file.SUMMARY_gentrius_MAIN
fi
#---------------------------------------------------------------------------------
# POST DEFAULT ANALYSIS
#---------------------------------------------------------------------------------
run_increased=OFF
run_complex=OFF
#---------------------------------------------------------------------------------
if [ "$terrace_size" -eq 0 ] && [ "$stop_rule" -eq 2 ]
then
	run_complex=ON
elif [ "$stop_rule" -eq 1 ] || [ "$stop_rule" -eq 2 ]
then
	run_increased=ON
fi
#---------------------------------------------------------------------------------
# RUN POST DEFAULT ANALYSIS
#---------------------------------------------------------------------------------
# RUN: with increased stopping thresholds
#---------------------------------------------------------------------------------
if [ "$run_increased" == ON ]
then
	tag=INCREASED
	file=${tree}.${tag}.log
	stop_t_lim=100000000
	#stop_i_lim=100000000 # or maybe turn this one off: option "-g_stop_i 0" instead of "-g_stop_i $stop_i_lim"
	$iqtree2 -gentrius -pr_ab_matrix $pr_ab_matrix $tree -pre ${tree}.${tag} -g_stop_t $stop_t_lim -g_stop_i 0 -quiet
	check_if_run_finished $file
	summary_gentrius $file
	mv $file.SUMMARY_gentrius $file.SUMMARY_gentrius_MAIN
fi
#---------------------------------------------------------------------------------
# RUN: run backward analysis
#---------------------------------------------------------------------------------
if [ "$run_complex" == ON ]
then
	stop_t_lim=100000000
	stop_i_lim=100000000
	#-------------------------------------
	leaves_rm_min=1
	leaves_rm_max=$taxa_to_insert # get from default
	leaves_rm=`echo "$leaves_rm_max/2" | bc | awk -F "." '{print $1}'`
	#-------------------------------------
	step=0
	while [ "$run_complex" == ON ]

	do
		step=$[$step+1]
		tag=COMPLEX_${step}_${leaves_rm}
		file=${tree}.${tag}.log
		$iqtree2 -gentrius -pr_ab_matrix $pr_ab_matrix $tree -pre ${tree}.${tag} -quiet -g_stop_t $stop_t_lim -g_rm_leaves $leaves_rm -g_stop_i $stop_i_lim
		check_if_run_finished ${tree}.${tag}.log
		#----------------------------------------
		stop_rule="0"
		check=`grep "WARNING: stopping condition is active" $file | wc -l | awk -F " " '{print $1}'`
		if [ "$check" -gt 0 ]
		then
        		check="`cat $file | grep "Type of stopping rule: terrace size" | wc -l | awk -F " " '{print $1}'`"
        		if [ "$check" -eq 1 ]
        		then
                		stop_rule="1"
        		else
                		check="`cat $file | grep "Type of stopping rule: number of visited intermediate trees" | wc -l | awk -F " " '{print $1}'`"
                		if [ "$check" -eq 1 ]
                		then
                        		stop_rule="2"
                		else
                        		stop_rule="3"
                		fi
        		fi
		fi
		#-----------------------------------------
		if [ "$stop_rule" -eq 2 ]
		then
			# check, if you still can modify leave_rm
			if [ "$leaves_rm" -ne "$leaves_rm_min" ] && [ "$leaves_rm" -ne "$leaves_rm_max" ]
			then
				terrace_size=`grep "Number of trees on terrace" $file | awk -F ": " '{print $2}'`
				range_l=$[$leaves_rm_max - $leaves_rm_min]
				if [ "$range_l" -eq 1 ]
				then
					leaves_rm_min=$[$leaves_rm_min +1]
					leaves_rm=$leaves_rm_min
				elif [ "$terrace_size" -eq 0 ]		 # decrease leave_rm
				then
					leaves_rm_max=$leaves_rm
					range_l=$[$leaves_rm_max - $leaves_rm_min]
					d=`echo "$range_l/2" | bc | awk -F "." '{print $1}'`
					leaves_rm=$[$leaves_rm_min+$d]
				elif [ "$terrace_size" -lt $stop_t_lim ] # increase leave_rm
				then
					leaves_rm_min=$leaves_rm
					range_l=$[$leaves_rm_max - $leaves_rm_min]
					d=`echo "$range_l/2" | bc | awk -F "." '{print $1}'`
					leaves_rm=$[$leaves_rm_min+$d]
				fi
			else
				run_complex=OFF
			fi
		else
			run_complex=OFF
		fi
		#-----------------------------------------
	done
	summary_gentrius $file
	mv $file.SUMMARY_gentrius $file.SUMMARY_gentrius_MAIN
fi


