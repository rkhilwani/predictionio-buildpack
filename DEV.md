# Local Development

Use [predictionio-buildpack](README.md) to setup your local PredictionIO environment.

To do any real development work with PredictionIO, you'll need to run it locally. We'll use the [`bin/local/` scripts](https://github.com/heroku/predictionio-buildpack/tree/master/bin/local) to simplify that setup procedure and ensure parity between the dev (local) & production (Heroku).

## Background

This local dev technique sets up a complete installation of PredictionIO inside each engine you wish to work on. Each engine may have different configuration and dependencies, so the entire environment is contained within an engine directory.

## How-to

### 1. PostgreSQL database 

⚠️ *This step is only required once for your computer.*

1. [Install](https://www.postgresql.org/download/) and run PostgreSQL 9.6.
   * for macOS, we 💜 [Postgres.app](http://postgresapp.com)
1. Create the database and grant access to work with the [buildpack's `pio-env.sh` config](https://github.com/heroku/predictionio-buildpack/blob/local-dev/config/pio-env.sh) (database `pio`, username `pio`, & password `pio`):

   ```bash
   $ psql
   CREATE DATABASE pio;
   CREATE ROLE pio WITH password 'pio';
   GRANT ALL PRIVILEGES ON DATABASE pio TO pio;
   ALTER ROLE pio WITH LOGIN;
   ```

### 2. The Buildpack

⚠️ *This step is only required once for your computer.*

```bash
# First, change directory up to your top-level projects.
cd ~/my/projects/

git clone https://github.com/heroku/predictionio-buildpack
cd predictionio-buildpack/

# Capture this directory's path for use in next steps.
export PIO_BUILDPACK_DIR="$(pwd)"
```

### 3. The Engine

⚠️ *This step is required for each local engine directory.*

With a few commands, we'll install PredictionIO & its dependencies into `./PredictionIO-dist/` and configure it all via env vars & rendered config files.

```bash
# First, change directory to the target engine:
cd ~/my/projects/engine-dir/

# Depending on the engine, an environment template may be available.
# Copy & edit it:
cp .env.local .env
#
# …or create a new one:
echo 'PIO_EVENTSERVER_APP_NAME=my-engine' >> .env
echo 'PIO_POSTGRES_OPTIONAL_SSL=true'     >> .env

# Ignore the local dev artifacts
echo '.env'               >> .gitignore
echo 'PredictionIO-dist/' >> .gitignore
echo 'repo/'              >> .gitignore

# Setup this working directory:
$PIO_BUILDPACK_DIR/bin/local/setup

# Load the environment:
source $PIO_BUILDPACK_DIR/bin/local/env
```

#### Refreshing the setup

♻️ Run `…/bin/local/setup` whenever an env var is changed that effects dependencies, like:

* `PIO_S3_*` or
* `PIO_ELASTICSEARCH_*`

### 4. Elasticsearch (optional)

⚠️ *Only available if `PIO_ELASTICSEARCH_URL` is set.*

#### Configure ES

1. In the engine, open `.env/` and add the default local address for ES:

    ```bash
    PIO_ELASTICSEARCH_URL=http://127.0.0.1:9200
    ```
    
1. [Refresh the setup](#refreshing-the-setup)
1. If the [Authenticated Elasticsearch patch](https://github.com/apache/incubator-predictionio/pull/372) is required (e.g. for the [Universal Recommender](https://github.com/heroku/predictionio-engine-ur)), then revise:

    * **build.sbt**
      * change: `"0.11.0-incubating"` to: `"0.11.0-SNAPSHOT"`
      * append: `resolvers += "Buildpack Repository" at "file://"+baseDirectory.value+"/repo"`
    * **template.json**
      * change: `"0.11.0-incubating"` to: `"0.11.0-SNAPSHOT"`

    These changes will make the engine use the snapshot build included in the buildpack's `repo/`.

#### Run ES

In a new terminal, from the engine's directory:

```bash
cd PredictionIO-dist/vendors/elasticsearch/
bin/elasticsearch
```

### 5. Eventserver (optional)

In a new terminal,

```bash
cd ~/my/projects/engine-dir/
source $PIO_BUILDPACK_DIR/bin/local/env
pio eventserver
```

### 6. Load environment

♻️ Perform this step whenever starting in a new terminal or if an environment variable is changed.

✏️ *Replace `$PIO_BUILDPACK_DIR` with the path of **predictionio-buildpack** from step 2.*

```bash
source $PIO_BUILDPACK_DIR/bin/local/env
```

### 7. Finally, use `pio`

```bash
pio status
pio app new my-engine-name
pio build --verbose
# Importing data is required before training will succeed
pio train -- --driver-memory 8G
pio deploy
```
