# PostgreSQL plugin for semantic Search

This is an experimental extension for latent semantic analysis.


## Building the model

There is an example script for building a model. See `buildmodel.py`. You will minimally need adjust SQL in `get_messages()` function.

You need Python gensim module available. For non-standard import paths have a plpython function modify sys.path before calling load_lsi_model().
Refer - 

```
pip install gensim
```
## Postgres compile with python & Installation

Refer - https://www.endpoint.com/blog/2013/06/12/installing-postgresql-without-root

## env variable
```sh
export LD_LIBRARY_PATH="/home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/lib:$LD_LIBRARY_PATH" #needed for psql
export PATH="/home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/bin:$PATH"
```
```
./bin/pg_ctl -D ./data -l logfile start 

./bin/createdb Aa
```

## Using the extension
Install the extension , in `lsi_pg_extension` directory
```sh
make 
cp .o and .so files to lib folder o
cp lsi.o /home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/lib/
cp lsi.so /home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/lib/
```

start psql
```sh
./bin/psql -h localhost -p 5432 -d dbname
```

In psql, Only for each database
```
CREATE EXTENSION plpython3u;
CREATE EXTENSION lsi;

```



step 1) you need to load your model, Everytime

```sql
SELECT load_lsi_model('/path/to/my.model');

  load_lsi_model             
  ---------------------------------------
  Model with 100 topics and 28145 terms
  (1 row)
```

load the data
```
./bin/psql -h localhost -p 5432 -d a2 -f /media/jkl/64BCC6E1BCC6ACBC/Users/jkl/odrive/jagadkanihal/6.IITB/CS631_DB/Project/hackers-archive.sql
```


```sql
CREATE TABLE hackers_features (
  box_id text NOT NULL,
  msg_id integer NOT NULL,
  features real[]
  );
```


Step 2 is to transform your entries into feature space using `transform_to_model()`. Example:

```sql
INSERT INTO hackers_features 
SELECT box_id, msg_id, 
 transform_to_model(subject||' '||content) AS features 
FROM hackers_archive;
```


> Temporary Bug fix due to empty features
```sql
CREATE TABLE hackers_bad_features (
  box_id text NOT NULL,
  msg_id integer NOT NULL,
  features real[]
  );
```
```sql
INSERT INTO hackers_bad_features SELECT box_id, msg_id,features from hackers_features where cardinality(features)=0;

DELETE FROM hackers_features where cardinality(features)=0;
```


Step 3, find entries that are closest to your lookup document:

```sql
SELECT sender,
       subject, date, similarity
FROM hackers_archive
NATURAL JOIN
  (SELECT box_id,
          msg_id,
          dotproduct(features, lookup_features) AS similarity
   FROM
     (SELECT box_id,
             msg_id,
             features,
             lookup_features
      FROM hackers_features
      CROSS JOIN
        (SELECT transform_to_model('wal checksum performance') AS lookup_features) AS lookup
      ) AS temp_sim
   ORDER BY similarity DESC
   LIMIT 50) AS temp_top_sim ;

```
