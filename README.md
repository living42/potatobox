
**Bootstrap**

```
cd deploy/local
vagrant up
```


**testing**

```
vagrant ssh
cd potatobox/role/presto-coordinator
docker-compose exec coordinator presto
> CREATE SCHEMA hive.test;
> USE hive.test;
> CREATE TABLE test1 (id BIGINT, val VARCHAR);
> INSERT INTO test1 VALUES (1, 'foo');
> SELECT * FROM test1;
```
