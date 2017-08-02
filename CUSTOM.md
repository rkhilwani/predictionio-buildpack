# Deploy [PredictionIO](http://predictionio.incubator.apache.org) to Heroku

👓 Requires intermediate technical skills working with PredictionIO, the Scala programming language, and Heroku.

🍎 For an simpler demo of PredictionIO, try the [example Predictive Classification app](https://github.com/heroku/predictionio-engine-classification).

🗺 See the [buildpack README](README.md) for an overview of the tools used in these docs.

🛠 Follow the [local development](DEV.md) workflow to setup an engine on your computer.

## Docs 📚

✏️ Throughout this document, code terms that start with `$` represent a value (shell variable) that should be replaced with a customized value, e.g `$EVENTSERVER_NAME`, `$ENGINE_NAME`, `$POSTGRES_ADDON_ID`…

Please, follow the steps in the order documented.

* [Engine](#user-content-engine)
  1. [Create the app](#user-content-create-an-engine)
     * [Provision the database](#user-content-provision-the-database)
     * [Persistent filesystem](#user-content-optional-persistent-filesystem) (optional)
  1. [Update source configs](#user-content-update-source-configs)
     1. [`template.json`](#user-content-update-template-json)
     1. [`build.sbt`](#user-content-update-build-sbt)
     1. [`engine.json`](#user-content-update-engine-json)
  1. [Import data](#user-content-import-data)
     * [Built-in Data Hooks](#user-content-built-in-data-hooks)
  1. [Deploy to Heroku](#user-content-deploy-to-heroku)
     * [Scale-up](#user-content-scale-up)
     * [Retry release](#user-content-retry-release)
* [Training](#user-content-training)
  * [Automatic training](#user-content-automatic-training)
  * [Manual training](#user-content-manual-training)
* [Evaluation](#user-content-evaluation) (optional)
  1. [Changes required for evaluation](#user-content-changes-required-for-evaluation)
  1. [Perform evaluation](#user-content-perform-evaluation)
  1. [Re-deploy best parameters](#user-content-re-deploy-best-parameters)
* [Eventserver](#user-content-eventserver) (optional)
  1. [Deploy the eventserver](#user-content-deploy-the-eventserver)
* [Using pre-release features](#user-content-using-pre-release-features)
* [Configuration](#user-content-configuration)
  * [Migrate values from `engine.json`](#user-content-migrate-values-from-engine-json)
  * [Config files; `pio-env.sh`](#user-content-config-files)
  * [Environment variables](#user-content-environment-variables)
    * [Build configuration](#user-content-build-configuration)
    * [Storage configuration](#user-content-storage-configuration)
    * [Release configuration](#user-content-release-configuration)
    * [Spark configuration](#user-content-spark-configuration)
    * [Runtime configuration](#user-content-runtime-configuration)
* [Local development](#user-content-local-development)
  * [`pio-shell`](#user-content-pio-shell)
* [Testing](#user-content-testing)


## Engine

🏷 This buildpack should be used with engine templates for **PredictionIO 0.11**.

🔋 Engines already optimized for Heroku are listed in the main [builpack README](README.md#user-content-engines).

📐 Starting-points may be found in the [template gallery](https://predictionio.incubator.apache.org/gallery/template-gallery/). Download the `.tar.gz` from Github and open/expand it on your local computer.

### Create the app

`cd` into the engine's directory, and ensure it is a git repo:

```bash
git init
heroku create $ENGINE_NAME
heroku buildpacks:set https://github.com/heroku/predictionio-buildpack
```

#### Provision the database

Use a higher-level paid plan for anything beyond a simple demo, e.g. `hobby-basic`.

```bash
heroku addons:create heroku-postgresql:hobby-dev
```

#### Optional persistent filesystem

👓 Heroku dynos have an [ephemeral filesystem](https://devcenter.heroku.com/articles/dynos#ephemeral-filesystem).

For engines that require filesystem persistence, this buildpack supports [HDFS](https://en.wikipedia.org/wiki/Apache_Hadoop#HDFS) on [Amazon S3](https://aws.amazon.com/s3/).

To enable, either:

* use the [S3 Add-on](https://devcenter.heroku.com/articles/bucketeer) ($5/month minimum cost)

  ```bash
  heroku addons:create bucketeer --as PIO_S3
  ```
* bring your own [s3 bucket](https://aws.amazon.com/s3/) by manually setting the [config vars](#user-content-environment-variables)
  * `PIO_S3_BUCKET_NAME`
  * `PIO_S3_AWS_ACCESS_KEY_ID`
  * `PIO_S3_AWS_SECRET_ACCESS_KEY`

⚠️ Note that with HDFS on Heroku, all filesystem path references must be absolute from `/` root, not relative or nested in User ID directory.

### Update source configs

#### `template.json`

The version of PredictionIO used for deployment is based in the value in this file:

```json
  "pio": {
    "version" : {
      "min": "0.11.0-incubating"
    }
  }
```

#### `build.sbt`

The Scala built tool config must be updated with Scala, PredictionIO, & Spark versions:

```scala
scalaVersion := "2.11.8"

organization := "org.apache.predictionio"

libraryDependencies ++= Seq(
  "org.apache.predictionio" %% "apache-predictionio-core" % "0.11.0-incubating" % "provided",
  "org.apache.spark"        %% "spark-core"               % "2.1.0" % "provided",
  "org.apache.spark"        %% "spark-mllib"              % "2.1.0" % "provided")
```

#### `engine.json`

Update so the `appName` parameter matches the value set for `PIO_EVENTSERVER_APP_NAME`.

```json
  "datasource": {
    "params" : {
      "appName": "$PIO_EVENTSERVER_APP_NAME"
    }
  }
```

⭐️  **A better alternative** is to delete the `"appName"` param from `engine.json`, and then use an environment variable value in the engine source code. See: [Migrate values from `engine.json`](#user-content-migrate-values-from-engine-json).

### Import data

🚨 **Mandatory: Data is required.** The first time an engine is deployed, it requires data for training.

⚠️  If `data/initial-events.json` already exists in the engine, then skip to [Deploy to Heroku](#user-content-deploy-to-heroku). This data will automatically be imported into the eventserver before training.

Many community-contributed engine templates provide a Python `data/import_events.py` script which may be run manually from a local machine to load data via the Eventserver's REST API. While popular for getting an example running, this method is not optimum for Heroku deployment workflow, because it requires a Python installation (nothing else in PredictionIO uses Python), it limits import performance through the Eventserver web process (extra complexity of running & scaling that process), and it is not transactional (individual REST failures will not fail the process).

#### Built-in Data Hooks

With this buildpack, initial data import and ongoing synchronization may be automated using script hooks to generate JSON data that is automatically imported before training using `pio import`, an efficient method using concurrent database connections.

To enable the data hooks, the intended `pio app`, an arbitrary name & access key used to partition data in the event store, must be configured:

```bash
heroku config:set \
  PIO_EVENTSERVER_APP_NAME=heroku-app \
  PIO_EVENTSERVER_ACCESS_KEY=$RANDOM-$RANDOM-$RANDOM-$RANDOM-$RANDOM-$RANDOM
```

🔍 See the [Data Flow docs](DATA.md) for how to leverage the built-in import & sync workflow.

### Deploy to Heroku

```bash
# Make sure the database is ready:
heroku addons:wait

# Then, commit & deploy:
git add .
git commit -m "Initial PIO engine"
git push heroku master

# Follow the logs to see start-up of the engine.
heroku logs -t --app $ENGINE_NAME
```

⚠️ **Initial deploy will probably fail due to memory constraints.** To fix, [scale up](#user-content-scale-up) and [retry the release](#user-content-retry-release).

#### Scale up

Once deployed, scale up the processes to avoid memory issues. These are paid, [professional dyno types](https://devcenter.heroku.com/articles/dyno-types#available-dyno-types):

```bash
heroku ps:scale \
  web=1:Standard-2X \
  release=0:Performance-L \
  train=0:Performance-L
```

#### Retry release

When the release (`pio train`) fails due to memory constraints or other transient error, you may use the Heroku CLI [releases:retry plugin](https://github.com/heroku/heroku-releases-retry) to rerun the release without pushing a new deployment.


## Training

### Automatic training

`pio train` will automatically run during [release-phase of the Heroku app](https://devcenter.heroku.com/articles/release-phase).

### Manual training

```bash
heroku run train

# Restart the app to pickup the new model:
heroku restart
```

## Evaluation

PredictionIO provides an [Evaluation mode for engines](https://predictionio.incubator.apache.org/evaluation/), which uses cross-validation to help select optimum engine parameters.

⚠️ Only engines that contain `src/main/scala/Evaluation.scala` support Evaluation mode.

### Changes required for evaluation

To run evaluation on Heroku, ensure `src/main/scala/Evaluation.scala` references the engine's name through the environment. Check the source file to verify that `appName` is set to `sys.env("PIO_EVENTSERVER_APP_NAME")`. For example:

```scala
DataSourceParams(appName = sys.env("PIO_EVENTSERVER_APP_NAME"), evalK = Some(5))
```

♻️ If that change was made, then commit, deploy, & re-train before proceeding.

### Perform evaluation

Next, start a console & change to the engine's directory. This uses a paid, [professional dyno type](https://devcenter.heroku.com/articles/dyno-types#available-dyno-types):

```bash
heroku run bash --size Performance-L
```

Then, start the process, specifying the evaluation & engine params classes from the `Evaluation.scala` source file. For example:

```bash
$ pio eval \
    org.template.classification.AccuracyEvaluation \
    org.template.classification.EngineParamsList  \
    -- $PIO_SPARK_OPTS
```

✏️ Memory parameters are set to fit the [dyno `--size`](https://devcenter.heroku.com/articles/dyno-types#available-dyno-types) set in the `heroku run` command.

### Re-deploy best parameters

Once `pio eval` completes, still in the Heroku console, copy the contents of `best.json`:

```bash
$ cat best.json
```

♻️ Paste into your local `engine.json`, commit, & deploy.


## Eventserver

Basic deployment to Heroku does not include PredictionIO's eventserver REST API. This should not be confused with **event storage** which is always configured for Heroku Postgres in `pio-env.sh`.

**Eventserver only needs to be deployed if the engine will ingest events from other systems via the `events.json` REST API.** The buildpack's [Data Flow](DATA.md) features do not require Eventserver.

**Whenever an eventserver is required, each engine should run its own eventserver.** It's *possible* to share event storage between engines only if they share the same storage backends and configuration, but we do not advise this practice on Heroku. *This is a change from the previous advice given here.*

### Deploy the eventserver

We'll deploy an eventserver from the same source code repo as the engine. This ensures the same dependencies and configuration are used in the eventserver:

```bash
# First, change to the engine's working directory:
cd ~/my-engine

# Capture your engine's Heroku app name, and a name for the new eventserver:
export ENGINE_NAME=my-engine
export EVENTSERVER_NAME=my-new-engine-eventserver

# Create the Heroku app:
heroku create $EVENTSERVER_NAME
heroku buildpacks:set https://github.com/heroku/predictionio-buildpack --app $EVENTSERVER_NAME
heroku config:set PIO_RUN_AS_EVENTSERVER=true --app $EVENTSERVER_NAME

# Add this new app as a second git remote in the engine's repo:
heroku git:remote --app $EVENTSERVER_NAME --remote heroku-eventserver

# Share config & add-ons between the engine & eventserver:

heroku addons:info heroku-postgresql --app $ENGINE_NAME
# Look for the add-on ID. It looks like `postgresql-shape-00000`.
# Then, attach that as `ADDON_ID`:
heroku addons:attach $ADDON_ID --app $EVENTSERVER_NAME

# If Elasticsearch is used:
heroku config:get PIO_ELASTICSEARCH_URL --app $ENGINE_NAME
# Then, set that value as `ADDON_URL` on the eventserver.
heroku config:set PIO_ELASTICSEARCH_URL=$ADDON_URL --app $EVENTSERVER_NAME

# Tell the engine how to locate the eventserver REST API.
heroku config:set PIO_EVENTSERVER_HOSTNAME=$EVENTSERVER_NAME.herokuapp.com --app $ENGINE_NAME

# Finally, deploy!
git push heroku-eventserver master
```

Note that some add-ons, such as Bonsai Elasticsearch, do not officially support attaching to multiple apps. In these cases, their config var values must be manually copied & maintained between the engine to the eventserver.

## Using pre-release features

A SNAPSHOT distribution of PredictionIO is included with this buildpack, to support a few features that are ahead of the main PredictionIO release:

* Authenticated Elasticsearch 5 client & various fixes (to support [Universal Recommender](https://github.com/heroku/predictionio-engine-ur))
* Batch predictions with the new `pio batchpredict` command

[Compare the SNAPSHOT branch](https://github.com/apache/incubator-predictionio/compare/develop...mars:esclient-auth-with-batch-predict) to see all changes.

### Switch an engine to SNAPSHOT

* **build.sbt**
  * change: `"0.11.0-incubating"` to: `"0.11.0-SNAPSHOT"`
  * append: `resolvers += "Buildpack Repository" at "file://"+baseDirectory.value+"/repo"`
* **template.json**
  * change: `"0.11.0-incubating"` to: `"0.11.0-SNAPSHOT"`

These changes will make the engine use the snapshot build included in the buildpack's `repo/`.

## Configuration

### Migrate values from `engine.json`

PredictionIO [engine templates](https://predictionio.incubator.apache.org/gallery/template-gallery/) typically have some configuration values stored alongside the source code in `engine.json`. Some of these values may vary between deployments, such as in a [pipeline](https://devcenter.heroku.com/articles/pipelines), where the same slug will be used to connect to different databases for Staging & Production. Also, the buildpack's [Data Flow hooks](DATA.md) rely on environment for configuration.

Heroku [config vars](https://devcenter.heroku.com/articles/config-vars) solve many of the problems associated with these committed configuration files. When using a template or implementing a custom engine, the developer should migrate the engine to read the [environment variables](https://github.com/heroku/predictionio-buildpack/blob/master/CUSTOM.md#user-content-environment-variables) at runtime instead of the default file-based config:

* `sys.env("PIO_EVENTSERVER_APP_NAME")` (if missing, will throw runtime error)
* `sys.env.getOrElse("PIO_UR_ELASTICSEARCH_CONCURRENCY", "4")` (if missing, will fallback to default value)

### Config files

The buildpack comes with [`config/`](config/) ERB templates that are rendered using the current [environment variables](#user-content-environment-variables) when the app is launched. Any one of these may be customized by creating a `config/` directory in your engine and copying over the template from this buildpack. Use caution when making modifications, as these configs are preset to work on Heroku. These include:

* `pio-env.sh` for PredictionIO
* `core-site.xml.erb` for Hadoop
* `spark-defaults.conf.erb` for Spark

### Environment variables

Set the variables:

* for [local development](DEV.md) in the `.env` file
* for Heroku deployment with [`heroku config:set …`](https://devcenter.heroku.com/articles/config-vars)

#### Build configuration

Changes to these require a new deployment to take effect.

* `PIO_MAVEN_REPO`
  * add a Maven repository URL to search when installing deps from engine's `build.sbt`
  * useful for testing pre-release packages
* `PIO_RUN_AS_EVENTSERVER`
  * set `PIO_RUN_AS_EVENTSERVER=true` to run `pio eventserver` as the web process
  * when `true`, the engine is built, but its release-phase training will not be performed
* `PIO_VERBOSE`
  * set `PIO_VERBOSE=true` for detailed build logs

#### Storage configuration

* `AWS_REGION`
  * when connecting to S3 in region other than US, the region name must be specified to enable signature v4.
* `DATABASE_URL` & `PIO_POSTGRES_OPTIONAL_SSL`
  * automatically set by [Heroku PostgreSQL](https://elements.heroku.com/addons/heroku-postgresql)
  * defaults to `postgres://pio:pio@locahost:5432/pio`
  * when testing locally, set `PIO_POSTGRES_OPTIONAL_SSL=true` to avoid **The server does not support SSL** errors
* `PIO_ELASTICSEARCH_URL`
  * when set, activates [Elasticsearch](https://www.elastic.co/products/elasticsearch) as the [metadata store](http://predictionio.incubator.apache.org/system/anotherdatastore/)
  * Elasticsearch version 5.x is supported
  * use an [add-on](https://elements.heroku.com/search/addons?q=elasticsearch):

    ```bash
    heroku addons:create bonsai --version 5.1 --as PIO_ELASTICSEARCH
    ```
* `PIO_S3_BUCKET_NAME`, `PIO_S3_AWS_ACCESS_KEY_ID`, & `PIO_S3_AWS_SECRET_ACCESS_KEY`
  * configures a bucket to enable filesystem access

#### Release configuration

* `PIO_EVENTSERVER_APP_NAME` & `PIO_EVENTSERVER_ACCESS_KEY`
  * used in `DataSource.scala` to access the engine's data
  * used to create the eventserver `pio app` automatically during [import of `initial-events.json`](DATA.md#user-content-initial-events-json)
  * may be manually setup by running `pio app new $PIO_APP_NAME`
* `PIO_PURGE_EVENTS_ON_SYNC`
  * set `PIO_PURGE_EVENTS_ON_SYNC=true` to delete all existing events before each data import
* `PIO_TRAIN_ON_RELEASE`
  * set `false` to disable automatic training
  * subsequent deploys may crash a deployed engine until it's retrained
  * use [manual training](#user-content-manual-training)

#### Spark configuration

* `PIO_SPARK_OPTS` & `PIO_TRAIN_SPARK_OPTS`
  * **deploy** & **training** options passed through to `spark-submit $opts`
  * see: [`spark-submit` reference](http://spark.apache.org/docs/2.1.0/submitting-applications.html)
  * example, overriding the automatic (fit-to-dyno) Spark memory settings:

    ```bash
    heroku config:set \
      PIO_SPARK_OPTS='--executor-memory 1536m --driver-memory 1g' \
      PIO_TRAIN_SPARK_OPTS='--executor-memory 10g --driver-memory 4g'
    ```
  * example, using an existing Spark cluster (deploying a cluster is outside the scope of the buildpack):

    ```bash
    heroku config:set \
      PIO_TRAIN_SPARK_OPTS='--master spark://my-master.example.com:7077' \
      PIO_SPARK_OPTS='--master spark://my-master.example.com:7077'
    ```
  * note this additional constraint of Spark pass-through args,  
    `spark.driver.extraJavaOptions` is silently ignored:

    ```bash
    # Options are silently dropped when set through `--conf`.
    # Bad example; don't use this:
    PIO_SPARK_OPTS="--conf 'spark.driver.extraJavaOptions=-Dcom.amazonaws.services.s3.enableV4'"

    # Instead, pass them using `--driver-java-options`.
    # Good example; do this:
    PIO_SPARK_OPTS="--driver-java-options '-Dcom.amazonaws.services.s3.enableV4'"
    ```
* [`config/spark-defaults.conf.erb`](config/spark-defaults.conf.erb) may be copied into the engine and customized specifically for that engine.

#### Runtime configuration
* `PIO_ENABLE_FEEDBACK`
  * set `PIO_ENABLE_FEEDBACK=true` to enable feedback loop; auto-generation of historical prediction events for analysis of engine performance
  * requires the `PIO_EVENTSERVER_*` vars to be configured
* `PIO_EVENTSERVER_HOSTNAME` & `PIO_EVENTSERVER_PORT`
  * `$EVENTSERVER_NAME.herokuapp.com` & `443` (default) for Heroku apps' HTTPS interface
* `PIO_OPTS`
  * options passed as `pio $opts`
  * see: [`pio` command reference](https://predictionio.incubator.apache.org/cli/)
  * example:

    ```bash
    heroku config:set PIO_OPTS='--variant best.json'
    ```

## Local development

▶️ setup an engine for the [local development](DEV.md) workflow

### `pio-shell`

Use the interactive Scala REPL to work with an engine locally.

```bash
pio-shell \
  --with-spark \
  --jars PredictionIO-dist/lib/pio-assembly-0.11.0-SNAPSHOT.jar,PredictionIO-dist/lib/postgresql_jdbc.jar,PredictionIO-dist/lib/spark/pio-data-elasticsearch-assembly-0.11.0-SNAPSHOT.jar,PredictionIO-dist/lib/spark/pio-data-jdbc-assembly-0.11.0-SNAPSHOT.jar
```

(This following command includes a `--jars` fix for PIO 0.11.0-incubating. If you're not using [local development](DEV.md) workflow, then those paths will be different for your own setup.)

Then, load the necessary classes to load some event data:

```scala
scala> import org.apache.predictionio.data.store.PEventStore
scala> PEventStore.aggregateProperties(appName="my-app", entityType="user")(sc).collect { case(i,p) => i }.take(5).foreach(println)
```

## Testing

### Buildpack [![Build Status](https://travis-ci.org/heroku/predictionio-buildpack.svg?branch=master)](https://travis-ci.org/heroku/predictionio-buildpack)

[Tests](test/) covering this buildpack's build and release functionality are implemented with [heroku-buildpack-testrunner](https://github.com/heroku/heroku-buildpack-testrunner). Engine test cases are staged in the [`test/fixtures/`](test/fixtures/).

Setup [testrunner with Docker](https://github.com/heroku/heroku-buildpack-testrunner#docker-usage), then run tests with:

```bash
docker-compose -p pio -f test/docker-compose.yml run testrunner
```

### Individual Apps

Engines deployed as Heroku apps may automatically run their `sbt test` suite using [Heroku CI (beta)](https://devcenter.heroku.com/articles/heroku-ci):

>Heroku CI automatically runs tests for every subsequent push to your GitHub repository. Any push to any branch triggers a test run, including a push to master. This means that all GitHub pull requests are automatically tested, along with any merges to master.
>
> Test runs are executed inside an ephemeral Heroku app that is provisioned for the test run. The app is destroyed when the run completes.
