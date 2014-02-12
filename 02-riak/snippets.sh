# curl parameters:
#  v => verbose
#  X => specify the request command
#  H => specify custom header line
#  d => specify the POST data


# Day 1

# Update (if key non-existing: create) a value, specifiying key and value
curl -v -X PUT http://localhost:10018/riak/animals/ace \
  -H "Content-Type: application/json" \
  -d '{"nickname" : "The Wonder Dog", "breed" : "German Shepherd"}'

# List existing buckets
curl -X GET http://localhost:10018/riak?buckets=true

curl -v -X PUT http://localhost:10018/riak/animals/polly?returnbody=true \
  -H "Content-Type: application/json" \
  -d '{"nickname" : "Sweet Polly Purebred", "breed" : "Purebred"}'

# Create a new value. Return the key under which it got stored
curl -i -X POST http://localhost:10018/riak/animals \
  -H "Content-Type: application/json" \
  -d '{"nickname" : "Sergeant Stubby", "breed" : "Terrier"}'


curl -i -X GET http://localhost:10018/riak/animals/LmaFiGUua88C5I0YL1QVy5aFUBO

# Delete the value at <key>
curl -i -X DELETE http://localhost:10018/riak/animals/LmaFiGUua88C5I0YL1QVy5aFUBO

# Return all keys from a bucket
curl http://localhost:10018/riak/animals?keys=true

curl -X PUT http://localhost:10018/riak/cages/1 \
  -H "Content-Type: application/json" \
  -H "Link: </riak/animals/polly>; riaktag=\"contains\"" \
  -d '{"room" : 101}'

curl -i http://localhost:10018/riak/animals/polly

curl -X PUT http://localhost:10018/riak/cages/2 \
-H "Content-Type: application/json" \
-H "Link:</riak/animals/ace>;riaktag=\"contains\",
  </riak/cages/1>;riaktag=\"next_to\"" \
-d '{"room" : 101}'

### Link Walking
# Format: bucket,tag,keep with '_' as placeholder

# All links from cage 1
curl http://localhost:10018/riak/cages/1/_,_,_

# All links from cage 2 linking to objects in animal bucket
curl http://localhost:10018/riak/cages/2/animals,_,_

curl http://localhost:10018/riak/cages/2/_,next_to,_

curl http://localhost:10018/riak/cages/2/_,next_to,1/_,_,_