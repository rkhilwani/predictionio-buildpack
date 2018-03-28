⚠️ **This project is no longer active.** No further updates are planned.

# [Heroku buildpack](https://devcenter.heroku.com/articles/buildpacks) for PredictionIO

Enables data scientists and developers to deploy custom machine learning services created with [PredictionIO](https://predictionio.incubator.apache.org).

This buildpack is part of an exploration into utilizing the [Heroku developer experience](https://www.heroku.com/dx) to simplify data science operations. When considering this proof-of-concept technology, please note its [current limitations](#user-content-limitations). We'd love to hear from you. [Open issues on this repo](https://github.com/heroku/predictionio-buildpack/issues) with feedback and questions.

## Releases

**September 28th, 2017**: PredictionIO 0.12.0-incubating is now supported.

See [all releases](https://github.com/heroku/predictionio-buildpack/releases) with their changes.

## Engines

Create and deploy engines for PredictionIO versions:

* **0.12.0-incubating**
    * **Scala 2.11.8**, **Spark 2.1.1**, & **Hadoop 2.7.3**
    * specify these versions in the [engine template's configs](CUSTOM.md#user-content-update-source-configs)
* **0.11.0-incubating**
    * **Scala 2.11.8**, **Spark 2.1.0**, & **Hadoop 2.7.3**
    * specify these versions in the [engine template's configs](CUSTOM.md#user-content-update-source-configs)
* ~~0.10.0-incubating~~
    * no longer supported
    * see how to [upgrade or temporarily fix](https://github.com/heroku/predictionio-buildpack/pull/44)

Get started with an engine:

* [Universal Recommender engine](https://github.com/heroku/predictionio-engine-ur)
  * presented at [TrailheaDX 2017](https://www.youtube.com/watch?v=MO0Bmty9fmc)
* [Classification engine](https://github.com/heroku/predictionio-engine-classification)
  * presented at [TrailheaDX 2017](https://www.youtube.com/watch?v=MO0Bmty9fmc) & [Dreamforce 2016](https://www.salesforce.com/video/297129/)
* [Regression engine](https://github.com/heroku/predictionio-engine-regression)
  * to be presented at [Dreamforce 2017](https://www.salesforce.com/dreamforce/)  
    *Open-source at Salesforce* booth in the Developer Forest  
    3:30-6pm, Wednesday, November 8
* [Template Gallery](https://predictionio.incubator.apache.org/gallery/template-gallery/)
  * starting-points for many use-cases
  * follow [custom engine docs](CUSTOM.md) to use with this buildpack

🐸 **[How to deploy an engine](CUSTOM.md)**

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

PredictionIO requires 2GB of memory. It runs well on Heroku's [Performance dynos](https://www.heroku.com/pricing) with 2.5GB or 14GB RAM. Smaller dynos cannot run PredictionIO reliably.

This buildpack automatically trains the model during [release phase](https://devcenter.heroku.com/articles/release-phase), which executes Spark as a sub-process (i.e. [`--master local`](https://spark.apache.org/docs/2.1.0/#running-the-examples-and-shell)) within [one-off and web dynos](https://devcenter.heroku.com/articles/dynos). If the dataset and operations performed with Spark require more than 14GB memory, then it's possible to point the engine's Spark driver at an existing Spark cluster. (Running a Spark cluster is beyond the scope of this buildpack.) See: [customizing environment variables, `PIO_SPARK_OPTS` & `PIO_TRAIN_SPARK_OPTS`](CUSTOM.md#user-content-spark-configuration).

## Usage

🐸 [Deploy an Engine](CUSTOM.md) to Heroku.

🛠 Use the [Local Development](DEV.md) workflow to setup an engine on your computer.

⏩ Leverage the buildpack's [Data Flow](DATA.md) to automate import & synchronization of event data.

🤓 [Testing](CUSTOM.md#user-content-testing) this buildpack & individual engines.
