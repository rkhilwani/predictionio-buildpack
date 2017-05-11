#!/bin/sh
. ${BUILDPACK_HOME}/test/helper.sh

appBinDir=""
loadDataSpy=""
trainSpy=""

# Create spy scripts where executables are expected
# to assert how they are called.
afterSetUp() {
  PATH=./:$PATH
  appBinDir="$BUILD_DIR/bin"
  loadDataSpy="${appBinDir}/heroku-buildpack-pio-load-data"
  trainSpy="${appBinDir}/heroku-buildpack-pio-train"
  mkdir -p "${appBinDir}"

  cat > $loadDataSpy <<'HEREDOC'
#!/bin/sh
exit
HEREDOC
  chmod +x $loadDataSpy

  cat > $trainSpy <<'HEREDOC'
#!/bin/sh
set -e
echo "train-was-called"
HEREDOC
  chmod +x $trainSpy

  cd $BUILD_DIR
  unset PIO_TRAIN_ON_RELEASE
}

beforeTearDown() {
  cd $BUILDPACK_HOME
  rm $loadDataSpy $trainSpy
}

test_release_calls_load_data_and_train()
{
  capture ${BUILDPACK_HOME}/bin/engine/heroku-buildpack-pio-release
  assertEquals 0 ${rtrn}
  assertContains "train-was-called" "$(cat ${STD_OUT})"
  assertEquals "" "$(cat ${STD_ERR})"
}

test_release_train_may_be_disabled()
{
  export PIO_TRAIN_ON_RELEASE=false

  capture ${BUILDPACK_HOME}/bin/engine/heroku-buildpack-pio-release
  assertEquals 0 ${rtrn}
  assertEquals "Skipping train on release." "$(cat ${STD_OUT})"
  assertEquals "" "$(cat ${STD_ERR})"
}

test_release_handles_transient_load_data_error()
{
  cat > $loadDataSpy <<'HEREDOC'
#!/bin/sh
exit 3
HEREDOC

  capture ${BUILDPACK_HOME}/bin/engine/heroku-buildpack-pio-release
  assertEquals 0 ${rtrn}
  assertEquals "" "$(cat ${STD_OUT})"
  assertContains "Transient error loading data" "$(cat ${STD_ERR})"
}

test_release_handles_critical_load_data_error()
{
  cat > $loadDataSpy <<'HEREDOC'
#!/bin/sh
exit 138
HEREDOC

  capture ${BUILDPACK_HOME}/bin/engine/heroku-buildpack-pio-release
  assertEquals 138 ${rtrn}
  assertEquals "" "$(cat ${STD_OUT})"
  assertContains "Error loading data" "$(cat ${STD_ERR})"
}
