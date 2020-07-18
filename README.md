
**Bootstrap**

```
cd image
./build.sh

cd ..

# init alluxio
docker-compose run --rm alluxio-master bash -c 'mkdir /var/lib/alluxio/data /var/lib/alluxio/underfs'
docker-compose run --rm alluxio-master alluxio formatJournal
docker-compose run --rm alluxio-worker alluxio formatWorker

# init hive
docker-compose run --rm hive-metastore schematool -dbType derby -initSchema

docker-compose up -d
```


**testing**

```
docker-compose exec presto-coordinator presto
> CREATE SCHEMA hive.test;
> USE hive.test;
> CREATE TABLE test1 (id BIGINT, val VARCHAR);
> INSERT INTO test1 VALUES (1, 'foo');
> SELECT * FROM test1;
```
