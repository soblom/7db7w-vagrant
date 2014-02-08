###
# RIAK
#
# Based on: https://gist.github.com/nojima/6850309	
###

# install dependencies
sudo apt-get -y install build-essential libc6-dev-i386 git erlang

#install riak
cd /opt	
sudo wget http://s3.amazonaws.com/downloads.basho.com/riak/1.4/1.4.7/riak-1.4.7.tar.gz
sudo tar zxvf riak-1.4.7.tar.gz
cd riak-1.4.7
sudo make rel
sudo make devrel
sudo chown -R vagrant /opt/riak-1.4.7
sudo rm /opt/riak-1.4.7.tar.gz

#setup riak environment
cd /opt/riak-1.4.7/dev/
dev1/bin/riak start
dev2/bin/riak start
dev3/bin/riak start
dev2/bin/riak-admin cluster join dev1@127.0.0.1
dev3/bin/riak-admin cluster join dev1@127.0.0.1