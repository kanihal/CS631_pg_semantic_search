# PostgreSQL plugin for semantic Search

These are experimental extensions for latent semantic Indexing(LSI) and clustering using LSI features.


## Building the model
We are using news dataset from https://www.kaggle.com/snapcrack/all-the-news to train LSI model to get features.
Each value of the feature will correspond to a latent topic the news document belongs to.

There is an example script for building a model. See `lsi_model.py`. 

We need Python `gensim` module available for both training and postgres extension to work.

```
pip install gensim
```

## Postgres compilation with python support and postgres extension build instructions

References: 

https://www.endpoint.com/blog/2013/06/12/installing-postgresql-without-root 

http://big-elephants.com/2015-10/writing-postgres-extensions-part-i/

## exporting env variable and starting the server
```sh
export LD_LIBRARY_PATH="/home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/lib:$LD_LIBRARY_PATH" #needed for psql
export PATH="/home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/bin:$PATH"
```
```
./bin/pg_ctl -D ./data -l logfile start 

./bin/createdb a2
```

## Using the extension
Install the extension , in `lsi_pg_extension` directory
```sh
# make 
#cp .o and .so files to lib folder postgres installation
cp lsi.control /home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/share/extension/
cp lsi.sql /home/jkl/Qt_Projects/postgresql-11.1/postgres_bin/share/extension/
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
```

create table and load the data

```
CREATE TABLE news (
  id integer NOT NULL,
  title text NOT NULL,
  content text
  );
```

```
./bin/psql -h localhost -p 5432 -d a2 -f 
# COPY news FROM ('csv path' FORMAT ('csv'))
`

```sql
CREATE TABLE news_features (
  id integer NOT NULL,
  title text NOT NULL,
  features real[]
  );
```

Step 2 is to transform your entries into feature space using `transform_to_model()`. Example:

```sql
INSERT INTO news_features 
SELECT id, title, 
 transform_to_model(title||' '||content) AS features 
FROM news;
```

Step 3, find entries that are closest to your lookup document:

```sql
SELECT id,title,similarity,content
FROM news
NATURAL JOIN
  (SELECT id,
          title,
          dotproduct(features, lookup_features) AS similarity
   FROM
     (SELECT id,
             title,
             features,
             lookup_features
      FROM news_features
      CROSS JOIN
        (SELECT transform_to_model('politics obama') AS lookup_features) AS lookup
      ) AS temp_sim
   ORDER BY similarity DESC
   LIMIT 5) AS temp_top_sim ;

```

## Clustering and create new tables for each cluster

```
create extension cluster;
```
```sql
select create_clusters('news_features', 'features','integer;text;real[]', 5);

```
