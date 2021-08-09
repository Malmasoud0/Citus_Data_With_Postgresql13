##### This files contains installation steps as well as basic commands #####
# to install citus with postgres on "ubuntu": 

1. Install PostgreSQL 13 and the Citus extension

# Add Citus repository for package manager
curl https://install.citusdata.com/community/deb.sh | sudo bash

# install the server and initialize db
sudo apt-get -y install postgresql-13-citus-10.1

2. Initialize the Cluster

Let’s create a new database on disk. For convenience in using PostgreSQL Unix domain socket connections, we’ll use the postgres user.

# this user has access to sockets in /var/run/postgresql
sudo su - postgres

# include path to postgres binaries
export PATH=$PATH:/usr/lib/postgresql/13/bin

cd ~
mkdir citus
initdb -D citus

3. Citus is a Postgres extension. To tell Postgres to use this extension 
you’ll need to add it to a configuration variable called shared_preload_libraries:

echo "shared_preload_libraries = 'citus'" >> citus/postgresql.conf

4. Start the database server

Finally, we’ll start an instance of PostgreSQL for the new directory:
cd /var/lib/postgresql 


5. Above you added Citus to shared_preload_libraries. That lets it hook into some deep parts of Postgres, swapping out the query planner and executor. Here, we load the user-facing side of Citus (such as the functions you’ll soon call):

psql -p 9700 -c "CREATE EXTENSION citus;"

6. 4. Verify that installation has succeeded

To verify that the installation has succeeded, and Citus is installed:

psql -p 9700 -c "select citus_version();"

7. to access database: 
psql -U postgres -d postgres -p 9700 

8. config file: 
/var/lib/postgresql/citus/postgresql.conf

dir path: 
/var/lib/postgresql/citus 

./pg_ctl -D /var/lib/postgresql/citus -o "-p 9700" -l citus_logfile start



# postgres@psj-myv-uv-ps01:/usr/lib/postgresql/13/bin$ ./pg_ctl -D /var/lib/postgresql/citus -o "-p 9700" -l citus_logfile stop

# to restart citus server: 
1. sudo su postgres
2. navigate to: /usr/lib/postgresql/13/bin
3. 
./pg_ctl -D /var/lib/postgresql/citus -o "-p 9700" restart 

-- before distributing tables, enable some extra features
SET citus.replication_model = 'streaming';

# to create distibute tables:

SELECT create_distributed_table('companies', 'id');
SELECT create_distributed_table('campaigns', 'company_id');
SELECT create_distributed_table('ads', 'company_id');

# to copy from csv: 
\copy ads from '/dump/ads.csv' with csv;
\copy campaigns from '/dump/campaigns.csv' with csv;

nocitus=# \copy companies from '/dump/companies.csv' with csv;

-- To go back to local, just call the undistribute_table function with your table as parameter
SELECT undistribute_table('my_table');


# to add more nodes: 
sudo -i -u postgres psql -c "SELECT * from citus_add_node('worker-101', 5432);"
