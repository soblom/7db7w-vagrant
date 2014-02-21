# encoding: utf-8
name             '7db7w-configure'
maintainer       'Sören Blom'
maintainer_email 'soeren.blom@lobsterion.de'
license          'All rights reserved'
description      'Configures the node for the 7db7w course.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends 'postgresql'
depends 'database'
depends 'riak'