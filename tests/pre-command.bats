#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
#export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  # Create a mock executable commands in the PATH
  local tmpdir="${BATS_TEST_TMPDIR/bin}"
  mkdir -p "$tmpdir"
  create_mock_factory_command "$tmpdir"
  export PATH="$tmpdir:$PATH"
}

# This is a workaround for not being able to stub the 'command' built-in
create_mock_factory_command() {
  # Make sure the local factory-command script doesn't exist
  export BUILDKITE_BUILD_CHECKOUT_PATH="/tmp/nonexistent"

  local bin_dir="${1:-$BATS_TEST_TMPDIR/bin}"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/factory-command" << 'EOF'
#!/bin/sh
if [ "$1" = "create-build" ]; then
echo '{
    "buildId":"987",
    "version":"8.9.0",
    "commits":[
      {"repo":"vespa","ref":"vespa-ref"},
      {"repo":"vespa-yahoo","ref":"vespa-yahoo-ref"},
      {"repo":"vespaai-cloud","ref":"cloud-ref"}
    ],
    "variables":{}
  }'
else
  echo "factory-command $@"
fi
EOF
  chmod +x "$bin_dir/factory-command"
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

@test "For non-build jobs, set start-seconds and factory-command" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123
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

  assert_output <<EOF
    buildkite-agent meta-data set start-seconds 1234567890
    buildkite-agent meta-data set factory-command factory-command
    Output from updating job run : factory-command update-buildkite-job-run 1234567890 123 running
    Job type is not 'build', skipping build creation
EOF

  unstub date
  unstub buildkite-agent
}

@test "For build jobs, create a build, set status, and export version and gitrefs" {
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_PIPELINE_ID=123
  export BUILDKITE_PULL_REQUEST=false
  export BUILDKITE_PLUGIN_FACTORY_REPORTER_JOB_TYPE="build"

  stub date "echo 1234567890"

  # Use bats-mock's stub to mock buildkite-agent
  stub buildkite-agent \
    "meta-data exists start-seconds : false" \
    "meta-data set start-seconds * : echo buildkite-agent \$@" \
    "meta-data set factory-command * : echo buildkite-agent \$@" \
    "meta-data set vespa-version * : echo buildkite-agent \$@" \
    "meta-data set gitref-vespa * : echo buildkite-agent \$@" \
    "meta-data set gitref-vespaai-cloud * : echo buildkite-agent \$@" \

  run "$PWD/hooks/pre-command"

  echo "version: $VESPA_VERSION"
  echo "gitref vespa: $GITREF_VESPA"

  assert_success

  # Only check the additional output for build jobs
  assert_output --partial <<EOF
    Created factory build 987 for pipeline 123
    buildkite-agent meta-data set vespa-version 8.9.0
    buildkite-agent meta-data set gitref-vespa vespa-ref
    buildkite-agent meta-data set gitref-vespaai-cloud cloud-ref
    factory-command update-build-status 123 running Building
    Set factory build 987 status to running
EOF
}
