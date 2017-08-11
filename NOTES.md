# Notes

## Adding packages to local Maven repo

```bash
# Clear out previously generated Maven packages from the buildpack
rm -rf repo/org/apache/predictionio/apache-predictionio-*

# For PredictionIO dist made for Scala 2.11
./make-distribution.sh     -Dscala.version=2.11.8     -Dspark.version=2.1.0     -Dhadoop.version=2.7.3     -Delasticsearch.version=5.1.1

for NAME in core_2.11 common_2.11 data_2.11 e2_2.11 parent_2.11 data-elasticsearch_2.11 data-hbase_2.11 data-hdfs_2.11 data-jdbc_2.11 data-localfs_2.11
do
  mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/.ivy2/local/org.apache.predictionio/apache-predictionio-${NAME}/0.12.0-SNAPSHOT/jars/apache-predictionio-${NAME}.jar -DpomFile=/Users/mars.hall/.ivy2/local/org.apache.predictionio/apache-predictionio-${NAME}/0.12.0-SNAPSHOT/poms/apache-predictionio-${NAME}.pom -DuniqueVersion=false
done

# For Mahout dist made for Scala 2.11
mvn clean install -DskipTests -Phadoop2 -Dspark.version=2.1.0 -Dscala.version=2.11.8 -Dscala.compat.version=2.11

mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/Projects/mahout/h2o/target/mahout-h2o_2.11-0.13.0.jar -DgroupId=org.apache.mahout -DartifactId=mahout-h2o_2.11 -Dversion=0.13.0
mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/Projects/mahout/hdfs/target/mahout-hdfs-0.13.0.jar -DgroupId=org.apache.mahout -DartifactId=mahout-hdfs -Dversion=0.13.0
mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/Projects/mahout/math/target/mahout-math-0.13.0.jar -DgroupId=org.apache.mahout -DartifactId=mahout-math -Dversion=0.13.0
mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/Projects/mahout/math-scala/target/mahout-math-scala_2.11-0.13.0.jar -DgroupId=org.apache.mahout -DartifactId=mahout-math-scala_2.11 -Dversion=0.13.0
mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/Projects/mahout/mr/target/mahout-mr-0.13.0.jar -DgroupId=org.apache.mahout -DartifactId=mahout-mr -Dversion=0.13.0
mvn deploy:deploy-file -Durl=file://$(pwd)/repo/ -Dfile=/Users/mars.hall/Projects/mahout/spark/target/mahout-spark_2.11-0.13.0.jar -DgroupId=org.apache.mahout -DartifactId=mahout-spark_2.11 -Dversion=0.13.0
```
