# Password must be set this way when using chef-solo
node.default['postgresql']['password']['postgres'] = 'vagrant'

# Extensions necessary for the book
node.default['postgresql']['contrib']['extensions'] = [
  'tablefunc',
  'dict_xsyn',
  'fuzzystrmatch',
  'pg_trgm',
  'cube'
]