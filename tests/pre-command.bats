#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
#export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  # This is a workaround for not being able to stub the 'command' built-in

  # Make sure the local factory-command script doesn't exist
  export BUILDKITE_BUILD_CHECKOUT_PATH="/tmp/nonexistent"

  # Create a mock factory-command in PATH
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  touch "$BATS_TEST_TMPDIR/bin/factory-command"
  chmod +x "$BATS_TEST_TMPDIR/bin/factory-command"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "Skip if SKIP_BUILDKITE_PLUGINS is true" {
  export SKIP_BUILDKITE_PLUGINS=true

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output "SKIP_BUILDKITE_PLUGINS is set. Skipping factory reporter"
}

@test "Skip if pipeline is not set" {
  unset PIPELINE

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output "No pipeline ID found, skipping factory reporter"
}

@test "For PR builds, just set vespa version" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=true

  stub buildkite-agent "echo buildkite-agent \$@"
  stub curl "echo '{\"version\":\"8.0.0\"}'"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output "buildkite-agent meta-data set vespa-version 8.0.0"

  unstub buildkite-agent
  unstub curl
}

@test "start-seconds and factory-command are set for non-build jobs" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123456
  export BUILDKITE_PULL_REQUEST=false

  stub date "echo 1234567890"

  # Use bats-mock's stub to mock buildkite-agent
  stub buildkite-agent \
    "meta-data exists start-seconds : false" \
    "meta-data set start-seconds * : echo buildkite-agent \$@" \
    "meta-data set factory-command * : echo buildkite-agent \$@"

  run "$PWD/hooks/pre-command"

  assert_success

  refute_output --partial "start-seconds already set, skipping"
  assert_output --partial "buildkite-agent meta-data set start-seconds 1234567890"
  assert_output --partial "buildkite-agent meta-data set factory-command factory-command"
  assert_output --partial "Job type is not 'build', skipping build creation"

  unstub date
  unstub buildkite-agent
}
