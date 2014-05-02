include_recipe 'riak::source'

# Hack for right now, copied from the riak cookbook
source_version = "#{node['riak']['source']['version']['major']}.#{node['riak']['source']['version']['minor']}"
source_file = "riak-#{source_version}.#{node['riak']['source']['version']['incremental']}"


execute "riak-dev-build" do
  cwd "#{Chef::Config[:file_cache_path]}/#{source_file}"
  command "make devrel DEVNODES=#{node['7db7w-configure']['riak']['dev_nodes']['number']}"
end

#copy the compiled files into vagrant home directory
execute "riak-dev-install" do
  command "mv #{Chef::Config[:file_cache_path]}/#{source_file}/dev /home/#{node['7db7w-config']['user']['name']}/riak"
  not_if { File.directory?("/home/#{node['7db7w-config']['user']['name']}/riak/dev1") }
end

execute 'riak-fix-permissions' do
  cwd "/home/#{node['7db7w-config']['user']['name']}"
  command "chown -R #{node['7db7w-config']['user']['name']} riak"
end

for dev_node in 1..node['7db7w-configure']['riak']['dev_nodes']['number'] do
  execute "riak-dev#{dev_node}-start" do
    command "/home/#{node['7db7w-config']['user']['name']}/riak/dev#{dev_node}/bin/riak start"   
  end
end

if node['7db7w-configure']['riak']['dev_nodes']['number'] > 1
  for dev_node in 2..node['7db7w-configure']['riak']['dev_nodes']['number'] do
    execute "riak-dev#{dev_node}-join-cluster" do
      command "/home/#{node['7db7w-config']['user']['name']}/riak/dev#{dev_node}/bin/riak-admin cluster join dev1@127.0.0.1"
      not_if "/home/#{node['7db7w-config']['user']['name']}/riak/dev1/bin/riak-admin member_status |grep dev#{dev_node}@127.0.0.1"
    end
  end
  
  execute "riak-dev#{dev_node}-cluster-plan" do
    command "/home/#{node['7db7w-config']['user']['name']}/riak/dev#{dev_node}/bin/riak-admin cluster plan"
  end
  
  execute "riak-dev#{dev_node}-cluster-commit" do
    command "/home/#{node['7db7w-config']['user']['name']}/riak/dev#{dev_node}/bin/riak-admin cluster commit"
  end
end
