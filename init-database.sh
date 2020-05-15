#!/usr/bin/env bash

if [ $(psql -tA --username "postgres" -c "select count(1) from pg_database where datname='notaryserver'") = "0" ]; then 
    psql -v ON_ERROR_STOP=1 --username "postgres" --no-password -c "create database notaryserver with encoding='utf8' TEMPLATE template0;"
fi

if [ $(psql -tA --username "postgres" -c "select count(1) from pg_database where datname='notarysigner'") = "0" ]; then 
    psql -v ON_ERROR_STOP=1 --username "postgres" --no-password -c "create database notarysigner with encoding='utf8' TEMPLATE template0;"
fi

if [ $(psql -tA --username "postgres" -c "select count(1) from pg_database where datname='clair'") = "0" ]; then 
    psql -v ON_ERROR_STOP=1 --username "postgres" --no-password -c "create database clair with encoding='utf8' TEMPLATE template0;"
fi

if [ $(psql -tA --username "postgres" -c "select count(1) from pg_database where datname='registry'") = "0" ]; then 
    psql -v ON_ERROR_STOP=1 --username "postgres" --no-password -c "create database registry with encoding='utf8' TEMPLATE template0;"
fi

#if [ $(psql -tA --username "postgres" -c "select count(1) from pg_database where datname='test'") = "0" ]; then 
#    psql -v ON_ERROR_STOP=1 --username "postgres" --no-password -c "create database test with encoding='utf8' TEMPLATE template0;"
#fi
#psql -lqt --username postgres
#psql --username "postgres" -c "DROP DATABASE test";