# [Heroku buildpack](https://devcenter.heroku.com/articles/buildpacks) for PredictionIO

Enables data scientists and developers to deploy custom machine learning services created with [PredictionIO](https://predictionio.incubator.apache.org).

This buildpack is part of an exploration into utilizing the [Heroku developer experience](https://www.heroku.com/dx) to simplify data science operations. When considering this proof-of-concept technology, please note its [current limitations](#user-content-limitations). We'd love to hear from you. [Open issues on this repo](https://github.com/heroku/predictionio-buildpack/issues) with feedback and questions.

## Engines

Supports engines created for PredictionIO version:

  * **0.11.0-incubating**
    * with Scala 2.11, Spark 2.1, & Hadoop 2.7
  * **0.10.0-incubating**
    * with Scala 2.10, Spark 1.6, & Hadoop 2.6

Getting started with an engine:

* [Universal Recommender engine](https://github.com/heroku/predictionio-engine-ur)
* [Classification engine](https://github.com/heroku/predictionio-engine-classification) presented at [Dreamforce 2016 "Exploring Machine Learning On Heroku"](https://www.salesforce.com/video/297129/)
* [Template Gallery](https://predictionio.incubator.apache.org/gallery/template-gallery/) offers starting-points for many use-cases.

🐸 [How to deploy an engine](CUSTOM.md)

## Architecture

This buildpack transforms the [Scala](http://www.scala-lang.org) source-code of a PredictionIO engine into a [Heroku app](https://devcenter.heroku.com/articles/how-heroku-works).

![Diagram of Deployment to Heroku Common Runtime](http://marsikai.s3.amazonaws.com/predictionio-buildpack-arch-04.png)

The events data can be stored in:

* **PredictionIO event storage** backed by Heroku PostgreSQL
  * compatible with this buildpack's [built-in Data Flow features](DATA.md) providing initial data load & sync automation
  * compatible with most engine templates; required by some (e.g. [UR](https://github.com/heroku/predictionio-engine-ur))
  * supports RESTful ingestion & querying via PredictionIO's built-in [Eventserver](CUSTOM.md#user-content-eventserver)
* **custom data store** such as Heroku Connect with PostgreSQL or RDD/DataFrames stored in HDFS
  * requires a highly technical, custom implementation of `DataSource.scala`

## Limitations

### Memory

This buildpack automatically trains the predictive model during [release phase](https://devcenter.heroku.com/articles/release-phase), which runs in a [one-off dyno](https://devcenter.heroku.com/articles/dynos). That dyno's memory capacity is a limiting factor at this time. Only [Performance dynos](https://www.heroku.com/pricing) with 2.5GB or 14GB RAM provide reasonable utility.

This limitation can be worked-around by pointing the engine at an existing Spark cluster. See: [customizing environment variables, `PIO_SPARK_OPTS` & `PIO_TRAIN_SPARK_OPTS`](CUSTOM.md#user-content-spark-configuration).

### Private Network

This is not a limitation for PredictionIO itself, but for the underlying Spark service. [Spark clusters](https://spark.apache.org/docs/1.6.3/spark-standalone.html) require a private network, so they cannot be deployed in the [Common Runtime](https://devcenter.heroku.com/articles/dyno-runtime).

To operate in the Common Runtime this buildpack executes Spark as a sub-process (i.e. [`--master local`](https://spark.apache.org/docs/1.6.3/#running-the-examples-and-shell)) within [one-off and web dynos](https://devcenter.heroku.com/articles/dynos).

This buildpack also supports executing jobs on an existing Spark cluster. See: [customizing environment variables, `PIO_SPARK_OPTS` & `PIO_TRAIN_SPARK_OPTS`](CUSTOM.md#user-content-spark-configuration).

### Additional Service Dependencies

Engines may require [Elasticsearch](https://predictionio.incubator.apache.org/system/) [ES] which is not currently supported with PredictionIO 0.10.0-incubating on Heroku (see [this pull request](https://github.com/heroku/predictionio-buildpack/pull/16)).

[Heroku Postgres](https://www.heroku.com/postgres) is the default storage repository, so this does not effect most engines.

✅ Fixed: **PredictionIO 0.11.0-incubating** supports ElasticSearch 5.x. An additional patch to [enable basic HTTP authentication](https://github.com/apache/incubator-predictionio/compare/develop...mars:esclient-auth) is included with buildpack deployments and will be included in an upcoming PredictionIO release.

### Stateless Builds

PredictionIO 0.10.0-incubating requires a database connection during the build phase. While this works fine in the [Common Runtime](https://devcenter.heroku.com/articles/dyno-runtime), it is not compatible with [Private Databases](https://devcenter.heroku.com/articles/heroku-postgres-and-private-spaces).

✅ Fixed: **PredictionIO 0.11.0-incubating** supports stateless build, so deployment to both Common Runtime and Private Spaces is possible.

### Config Files

PredictionIO [engine templates](https://predictionio.incubator.apache.org/gallery/template-gallery/) typically have some configuration values stored alongside the source code in `engine.json`. Some of these values may vary between deployments, such as in a [pipeline](https://devcenter.heroku.com/articles/pipelines), where the same slug will be used to connect to different databases for Review Apps, Staging, & Production.

Heroku [config vars](https://devcenter.heroku.com/articles/config-vars) solve many of the problems associated with these committed configuration files. When using a template or implementing a custom engine, the developer may migrate the engine to read the [environment variables](https://github.com/heroku/predictionio-buildpack/blob/master/CUSTOM.md#user-content-environment-variables) instead of the default file-based config, e.g. `sys.env("PIO_EVENTSERVER_APP_NAME")`.

## Development & Testing

🛠 Follow the [local development](DEV.md) workflow to setup an engine on your computer.

🔍 See the [Data Flow docs](DATA.md) for how to leverage the built-in import & sync workflow.

🤓 Info for [testing](CUSTOM.md#user-content-testing) this buildpack & individual engines.
