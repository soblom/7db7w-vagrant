#
# Cookbook Name:: 7db7w-configure
# Recipe:: postgresql
#
# Copyright (C) Sören Blom
# 
#
#


###
# Prepration Hack
## 

# Total hack (imo), as postgres install recipe requires this but takes no action to ensure its
# installation.
e = execute "apt-get install ruby-dev -y" do
  action :nothing
end

e.run_action(:run)


include_recipe 'postgresql::server'
include_recipe 'database::postgresql'

###
# Setup DB for Book
###
postgresql_connection = {
  host:     '127.0.0.1',
  port:     node['postgresql']['config']['port'],
  username: 'postgres',
  password: node['postgresql']['password']['postgres']
}


# create a postgresql database
postgresql_database 'book' do
  connection postgresql_connection
  action :create
end


#Create a postgresql user but grant no privileges
postgresql_database_user 'vagrant' do
  connection postgresql_connection
  password   node['postgresql']['password']['postgres']
  action     :create
end

postgresql_database_user 'vagrant' do
  connection    postgresql_connection
  password      node['postgresql']['password']['postgres']
  database_name 'book'
  host          '%'
  privileges    [:all]
  action        :grant
end

package 'postgresql-contrib' do
  action :install
end

node['postgresql']['contrib']['extensions'].each do |extension|
  postgresql_database 'book' do
    connection postgresql_connection
    sql        "CREATE EXTENSION IF NOT EXISTS #{extension}"
    action     :query
  end
end
