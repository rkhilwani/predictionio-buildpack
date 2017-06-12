#!/usr/bin/env bash

# Transform Postgres connection URL (Heroku config var) to PIO vars.
if [ -z "${DATABASE_URL:-}" ]; then
    export PIO_STORAGE_SOURCES_PGSQL_URL=jdbc:postgresql://localhost:5432/pio
    export PIO_STORAGE_SOURCES_PGSQL_USERNAME=pio
    export PIO_STORAGE_SOURCES_PGSQL_PASSWORD=pio
else
    # from: http://stackoverflow.com/a/17287984/77409
    # extract the protocol
    proto="`echo $DATABASE_URL | grep '://' | sed -e's,^\(.*://\).*,\1,g'`"
    # remove the protocol
    url=`echo $DATABASE_URL | sed -e s,$proto,,g`

    # extract the user and password (if any)
    userpass="`echo $url | grep @ | cut -d@ -f1`"
    pass=`echo $userpass | grep : | cut -d: -f2`
    if [ -n "$pass" ]; then
        user=`echo $userpass | grep : | cut -d: -f1`
    else
        user=$userpass
    fi

    # extract the host
    hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
    port=`echo $hostport | grep : | cut -d: -f2`
    if [ -n "$port" ]; then
        host=`echo $hostport | grep : | cut -d: -f1`
    else
        host=$hostport
    fi

    # extract the path (if any)
    path="`echo $url | grep / | cut -d/ -f2-`"

    if [ "${PIO_POSTGRES_OPTIONAL_SSL:-false}" = "true" ]
    then
        export PIO_STORAGE_SOURCES_PGSQL_URL=jdbc:postgresql://$hostport/$path
    else
        export PIO_STORAGE_SOURCES_PGSQL_URL=jdbc:postgresql://$hostport/$path?sslmode=require
    fi
    export PIO_STORAGE_SOURCES_PGSQL_USERNAME=$user
    export PIO_STORAGE_SOURCES_PGSQL_PASSWORD=$pass
fi