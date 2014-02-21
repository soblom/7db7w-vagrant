#!/usr/bin/env bash

run_list=(os_maint postgres riak)
run_dir=/vagrant/provisioning

for run_item in ${run_list[@]}
do
	echo " "
	echo " "
	echo Running $run_item script
	source $run_dir/$run_item.sh
	echo Finished $run_item installation
	echo " "
	echo " "
done