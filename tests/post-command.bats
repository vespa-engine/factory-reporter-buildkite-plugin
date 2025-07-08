#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/bats-assert/load.bash"
load "$BATS_PLUGIN_PATH/bats-mock/stub.bash"
load "$BATS_PLUGIN_PATH/bats-support/load.bash"

@test "Skip if SKIP_BUILDKITE_PLUGINS is true" {
  export SKIP_BUILDKITE_PLUGINS=true
  export BUILDKITE_PULL_REQUEST=false

  run "$PWD/hooks/post-command"

  assert_success
  assert_output "SKIP_BUILDKITE_PLUGINS is set. Skipping factory reporter"
}

@test "Skip if pipeline is not set" {
  export BUILDKITE_PULL_REQUEST=false
  unset PIPELINE

  run "$PWD/hooks/post-command"

  assert_success
  assert_output "No pipeline ID found, skipping factory reporter"
}

@test "For PR builds, do nothing" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=true

  run "$PWD/hooks/post-command"

  assert_success
  assert_output "This is a pull request, skipping factory reporter"
}

@test "Update job run for non-PR builds" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=false

  stub buildkite-agent \
    "meta-data get start-seconds : echo 1234567890" \
    "meta-data get factory-command : echo factory-command"

  stub factory-command "echo factory-command \$@"

  run "$PWD/hooks/post-command"

  assert_success

  assert_line "Build started at 1234567890"
  assert_line "Using factory command: factory-command"
  assert_line "Output from updating job run : factory-command update-buildkite-job-run 1234567890 123456 success"

  unstub buildkite-agent
  unstub factory-command
}
