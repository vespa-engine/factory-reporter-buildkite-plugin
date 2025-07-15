#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/bats-assert/load.bash"
load "$BATS_PLUGIN_PATH/bats-mock/stub.bash"
load "$BATS_PLUGIN_PATH/bats-support/load.bash"

setup_file() {
  # Echo the name of the test file, to get prettier output from github actions
  test=$(basename "$BATS_TEST_FILENAME")
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo -e "\033[36m$test\033[0m" >&3
  fi

  export BUILDKITE_BUILD_NUMBER=222
}

setup() {
  # Create mock factory-command in the PATH.
  # This is more convenient than using a stub that is called multiple times.
  local tmpdir="${BATS_TEST_TMPDIR/bin}"
  mkdir -p "$tmpdir"
  create_mock_factory_command "$tmpdir"
  export PATH="$tmpdir:$PATH"

}

@test "Skip if SKIP_BUILDKITE_PLUGINS is true" {
  export SKIP_BUILDKITE_PLUGINS=true
  export BUILDKITE_PULL_REQUEST=false

  run "$BATS_TEST_DIRNAME/../hooks/post-command"

  assert_success
  assert_output "SKIP_BUILDKITE_PLUGINS is set. Skipping factory reporter"
}

@test "Skip if pipeline is not set" {
  export BUILDKITE_PULL_REQUEST=false
  unset PIPELINE

  run "$BATS_TEST_DIRNAME/../hooks/post-command"

  assert_success
  assert_output "No pipeline ID found, skipping factory reporter"
}

@test "For PR jobs, do nothing" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=true

  run "$BATS_TEST_DIRNAME/../hooks/post-command"

  assert_success
  assert_output "This is a pull request, skipping factory reporter"
}

@test "Update factory job run for successful jobs, but don't update build status" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=false
  export BUILDKITE_BUILD_NUMBER=222

  stub buildkite-agent \
    "meta-data get start-seconds : echo 1234567890" \
    "meta-data get factory-command : echo factory-command"

  stub factory-command "echo factory-command \$@"

  run "$BATS_TEST_DIRNAME/../hooks/post-command"

  assert_success

  assert_line "Build started at 1234567890"
  assert_line "Using factory command: factory-command"
  assert_line "Build #222 succeeded, setting job run status to success"
  assert_line "factory-command update-buildkite-job-run 1234567890 123456 success"

  unstub buildkite-agent || true
  unstub factory-command || true
}

@test "For non-build jobs with non-zero exit status, fail factory job run" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=false
  export BUILDKITE_COMMAND_EXIT_STATUS=1

  stub buildkite-agent \
    "meta-data get start-seconds : echo 1234567890" \
    "meta-data get factory-command : echo factory-command"

  run "$BATS_TEST_DIRNAME/../hooks/post-command"

  assert_success

  assert_line "Build started at 1234567890"
  assert_line "Using factory command: factory-command"
  assert_line "factory-command update-buildkite-job-run 1234567890 123456 failure"

  refute_line --partial "factory-command update-build-status"

  unstub buildkite-agent || true
}

@test "For build jobs with non-zero exit status, fail factory build" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=false
  export BUILDKITE_COMMAND_EXIT_STATUS=1
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_JOB_TYPE="build"

  stub buildkite-agent \
    "meta-data get start-seconds : echo 1234567890" \
    "meta-data get factory-command : echo factory-command"

  run "$BATS_TEST_DIRNAME/../hooks/post-command"

  assert_success

  # Update job run also for build jobs
  assert_line "factory-command update-buildkite-job-run 1234567890 123456 failure"

  # Additional output for build jobs
  assert_line "factory-command update-build-status 123456 failure Build failed"

  unstub buildkite-agent || true
}

create_mock_factory_command() {
  #echo "Creating mock factory-command script in $1" >&3

  # Make sure the local factory-command script doesn't exist
  export BUILDKITE_BUILD_CHECKOUT_PATH="/tmp/nonexistent"

  local bin_dir="${1:-$BATS_TEST_TMPDIR/bin}"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/factory-command" << 'EOF'
#!/bin/sh
echo "factory-command $@"
EOF
  chmod +x "$bin_dir/factory-command"
}
