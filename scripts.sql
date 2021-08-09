-- create 2 database: 
-- with citus added on node1: 
create database citus_test; 
--create database on node2: 
create database nocitus; 
-- don't added citus in this databases! 
______________________________________________________________________
-- create 2 tables: 
CREATE TABLE campaigns (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name text NOT NULL,
    cost_model text NOT NULL,
    state text NOT NULL,
    monthly_budget bigint,
    blacklisted_site_urls text[],
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

CREATE TABLE ads (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    campaign_id bigint NOT NULL,
    name text NOT NULL,
    image_url text,
    target_url text,
    impressions_count bigint DEFAULT 0,
    clicks_count bigint DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

CREATE TABLE companies (
    id bigint NOT NULL,
    name text NOT NULL,
    image_url text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
______________________________________________________________________
-- Next, you can create primary key indexes on each of the tables just like you would do in PostgreSQL
ALTER TABLE companies ADD PRIMARY KEY (id);
ALTER TABLE campaigns ADD PRIMARY KEY (id, company_id);
ALTER TABLE ads ADD PRIMARY KEY (id, company_id);
______________________________________________________________________
-- before distributing tables, enable some extra features
SET citus.replication_model = 'streaming';
-- if it doesn't accept then you need to set the following: 
 SET citus.shard.replication_factor = 'streaming';

# then you need to add citus extension in every database you plan to use: 

# then create distribute tables: 
SELECT create_distributed_table('companies', 'id');
SELECT create_distributed_table('campaigns', 'company_id');
SELECT create_distributed_table('ads', 'company_id');

# Copy the data into the tables once you create them from (script attached): 
\copy ads from '/dump/ads.csv' with csv;
\copy campaigns from '/dump/campaigns.csv' with csv;
\copy companies from '/dump/companies.csv' with csv;

# create table with huge data: 

CREATE TABLE t_demo (data numeric);
CREATE OR REPLACE PROCEDURE insert_data(buckets integer)
LANGUAGE plpgsql
AS $$
   DECLARE
      i int;
   BEGIN
      i := 0;
      WHILE i < buckets
      LOOP
         INSERT INTO t_demo SELECT random()
            FROM generate_series(1, 1000000);
         i := i + 1;
         RAISE NOTICE 'inserted % buckets', i;
         COMMIT;
      END LOOP;
      RETURN;
   END;
$$;
CALL insert_data(200);
# add primary key column id :
ALTER TABLE t_demo ADD COLUMN id SERIAL PRIMARY KEY;
# add id coumnd: 
ALTER TABLE t_demo ADD COLUMN id SERIAL PRIMARY KEY;


# set number of shards count to be created: 
set citus.shard_count= '5';
SET


# To change the shard count you just use the shard_count parameter:

SELECT alter_distributed_table ('products', shard_count := 30);


# This post by Halil Ozan Akgul was originally published on the Azure Database for PostgreSQL Blog on Microsoft TechCommunity.

Citus is an extension to Postgres that lets you distribute your application’s workload across multiple nodes. Whether you are using Citus open source or using Citus as part of a managed Postgres service in the cloud, one of the first things you do when you start using Citus is to distribute your tables. While distributing your Postgres tables you need to decide on some properties such as distribution column, shard count, colocation. And even before you decide on your distribution column (sometimes called a distribution key, or a sharding key), when you create a Postgres table, your table is created with an access method.

Previously you had to decide on these table properties up front, and then you went with your decision. Or if you really wanted to change your decision, you needed to start over. The good news is that in Citus 10, we introduced 2 new user-defined functions (UDFs) to make it easier for you to make changes to your distributed Postgres tables.

Before Citus 9.5, if you wanted to change any of the properties of the distributed table, you would have to create a new table with the desired properties and move everything to this new table. But in Citus 9.5 we introduced a new function, undistribute_table. With the undistribute_table function you can convert your distributed Citus tables back to local Postgres tables and then distribute them again with the properties you wish. But undistributing and then distributing again is… 2 steps. In addition to the inconvenience of having to write 2 commands, undistributing and then distributing again has some more problems:

Moving the data of a big table can take a long time, undistribution and distribution both require to move all the data of the table. So, you must move the data twice, which is much longer.
Undistributing moves all the data of a table to the Citus coordinator node. If your coordinator node isn’t big enough, and coordinator nodes typically don’t have to be, you might not be able to fit the table into your coordinator node.
So, in Citus 10, we introduced 2 new functions to reduce the steps you need to make changes to your tables:

alter_distributed_table
alter_table_set_access_method
In this post you’ll find some tips about how to use the alter_distributed_table function to change the shard count, distribution column, and the colocation of a distributed Citus table. And we’ll show how to use the alter_table_set_access_method function to change, well, the access method. An important note: you may not ever need to change your Citus table properties. We just want you to know, if you ever do, you have the flexibility. And with these Citus tips, you will know how to make the changes.

Altering the properties of distributed Postgres tables in Citus
When you distribute a Postgres table with the create_distributed_table function, you must pick a distribution column and set the distribution_column parameter. During the distribution, Citus uses a configuration variable called shard_count for deciding the shard count of the table. You can also provide colocate_with parameter to pick a table to colocate with (or colocation will be done automatically, if possible).

However, after the distribution if you decide you need to have a different configuration, starting from Citus 10, you can use the alter_distributed_table function.

alter_distributed_table has three parameters you can change:

distribution column
shard count
colocation properties
How to change the distribution column (aka the sharding key)
Citus divides your table into shards based on the distribution column you select while distributing. Picking the right distribution column is crucial for having a good distributed database experience. A good distribution column will help you parallelize your data and workload better by dividing your data evenly and keeping related data points close to each other.However, choosing the distribution column might be a bit tricky when you’re first getting started. Or perhaps later as you make changes in your application, you might need to pick another distribution column.

With the distribution_column parameter of the new alter_distributed_table function, Citus 10 gives you an easy way to change the distribution column.

Let’s say you have customers and orders that your customers make. You will create some Postgres tables like these:

CREATE TABLE customers (customer_id BIGINT, name TEXT, address TEXT);
CREATE TABLE orders (order_id BIGINT, customer_id BIGINT, products BIGINT[]);
When first distributing your Postgres tables with Citus, let’s say that you decided to distribute the customers table on customer_id and the orders table on order_id.

SELECT create_distributed_table ('customers', 'customer_id');
SELECT create_distributed_table ('orders', 'order_id');
Later you might realize distributing the orders table by the order_id column might not be the best idea. Even though order_id could be a good column to evenly distribute your data, it is not a good choice if you frequently need to join the orders table with the customers table on the customer_id. When both tables are distributed by customer_id you can use colocated joins, which are very efficient compared to joins on other columns.

So, if you decide to change the distribution column of orders table into customer_id here is how you do it:

SELECT alter_distributed_table ('orders', distribution_column := 'customer_id');
Now the orders table is distributed by customer_id. So, the customers and the orders of the customers are in the same node and close to each other, and you can have fast joins and foreign keys that include the customer_id.

You can see the new distribution column on the citus_tables view:

SELECT distribution_column FROM citus_tables WHERE table_name::text = 'orders';
How to increase (or decrease) the shard count in Citus
Shard count of a distributed Citus table is the number of pieces the distributed table is divided into. Choosing the shard count is a balance between the flexibility of having more shards, and the overhead for query planning and execution across the shards. Like distribution column, the shard count is also set while distributing the table. If you want to pick a different shard count than the default for a table, during the distribution process you can use the citus.shard_count configuration variable, like this:

CREATE TABLE products (id BIGINT, name TEXT);
SET citus.shard_count TO 20;
SELECT create_distributed_table ('products', 'id');
After distributing your table, you might decide the shard count you set was not the best option. Or your first decision on the shard count might be good for a while but your application might grow in time, you might add new nodes to your Citus cluster, and you might need more shards. The alter_distributed_table function has you covered in the cases that you want to change the shard count too.

To change the shard count you just use the shard_count parameter:

SELECT alter_distributed_table ('t_demo', shard_count := 3);
After the query above, your table will have 30 shards. You can see your table’s shard count on the citus_tables view:

SELECT shard_count FROM citus_tables WHERE table_name::text = 't_demo';