#!/usr/bin/env bash

run_list=(riak)
run_dir=/vagrant/provisioning

for run_item in ${run_list[@]}
do
	echo Running $run_item script
	source $run_dir/$run_item.sh
done