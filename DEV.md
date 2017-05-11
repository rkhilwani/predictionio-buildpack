# Local Development

Use [predictionio-buildpack](README.md) to setup your local PredictionIO environment.

To do any real development work with PredictionIO, you'll need to run it locally. We'll use the 🌱 [`bin/local/` features of predictionio-buildpack](https://github.com/heroku/predictionio-buildpack/tree/local-dev/bin/local) to simplify that setup procedure and ensure parity between the dev (local) & production (Heroku).

## 1. PostgreSQL database 

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

## 2. PredictionIO runtime

⚠️ *This step is only required once for your computer.*

```bash
# First, change directory up to your top-level projects.
cd ~/my/projects/

git clone https://github.com/heroku/predictionio-buildpack
cd predictionio-buildpack/

# Switch to the feature branch with local dev capabilities (until merged)
git checkout local-dev

export PIO_BUILDPACK_DIR="$(pwd)"
```

* As time passes, you may wish to `git pull` the newest buildpack updates.

## 3. The Engine

⚠️ *This step is required for each local engine directory.*

With a few commands, we'll install PredictionIO & its dependencies into `./PredictionIO-dist/` and configure it all via env vars & rendered config files.

```bash
# First, change directory to the target engine:
cd engine-dir/

# Install the environment template; edit it if you need to:
cp .env.local .env

# Ignore the local dev artifacts
echo '.env'               >> .gitignore
echo 'PredictionIO-dist/' >> .gitignore
echo 'repo/'              >> .gitignore

# Setup this working directory:
source $PIO_BUILDPACK_DIR/bin/local/setup
```

### Refreshing the environment

Rerun `bin/local/setup` whenever an env var is changed that effects dependencies, like:

* `PIO_S3_*` or
* `PIO_ELASTICSEARCH_*` variables.

## 4. Elasticsearch (optional)

⚠️ *Available if `PIO_ELASTICSEARCH_URL` is set; [refresh the environment](#refresh-the-environment) after configuring.*

In a new terminal,

```bash
cd engine-dir/PredictionIO-dist/elasticsearch
bin/elasticsearch
```

If the [Authenticated Elasticsearch patch](https://github.com/apache/incubator-predictionio/pull/372) is required (e.g. for the [Universal Recommender](https://github.com/heroku/predictionio-engine-ur)), then revise:

* **build.sbt**
  * change: `"0.11.0-incubating"` to: `"0.11.0-SNAPSHOT"`
  * append: `resolvers += "Buildpack Repository" at "file://"+baseDirectory.value+"/repo"`
* **template.json**
  * change: `"0.11.0-incubating"` to: `"0.11.0-SNAPSHOT"`

These changes will make the engine use the snapshot build included in the buildpack's `repo/`.

## 5. Eventserver (optional)

In a new terminal,

```bash
cd engine-dir/
source $PIO_BUILDPACK_DIR/bin/local/env
pio eventserver
```

## 6. Load environment

Run `bin/local/env` after initial setup, whenever starting in a new terminal, or if an environment variable is changed:

```bash
source $PIO_BUILDPACK_DIR/bin/local/env
```

## 6. Finally, use `pio`

```bash
pio status
pio app new my-engine-name
pio build --verbose
# Importing data is required before training will succeed
pio train -- --driver-memory 8G
pio deploy
```
