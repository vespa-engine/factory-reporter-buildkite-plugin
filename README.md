# Factory Reporter Buildkite Plugin
Reports a build to Vespa Factory

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: ls
    plugins:
      - ./.buildkite/plugins/factory-reporter:
          pipeline-id: 123
          first-step: true
```

## Configuration

### `pipeline-id` (Required, integer)

The id of the pipeline

### `first-step` (Required, boolean)

Set to true if this is the first step in the pipeline

### `job-type` (Optional, string)

The type of job. Defaults to `build`.

### `build-platform` (Optional, string)

The factory build platform. Defaults to `opensource_centos7`

## Run tests locally
This module uses [BATS](https://bats-core.readthedocs.io/en/stable/) for testing.

To run the tests locally with  [Buildkite Plugin Tester](https://buildkite.com/docs/pipelines/integrations/plugins/writing#step-5-add-a-test),
use the following command (from the root of the repository):
```bash
$ podman run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```
Or, even better (and much faster), install bats locally with npm:
```bash
$ brew install node
$ sudo npm install -g bats bats-assert bats-support bats-mock
```
Export the `BATS_PLUGIN_PATH` environment variable to point to the global npm modules directory, which contains the BATS plugins:
```bash
export BATS_PLUGIN_PATH="$(npm root -g)"
```
Then run all tests with:
```bash
bats -r tests
```
To run a specific test, use:
```bash
bats tests/test_name.bats
```
Tests can also be run in IntelliJ IDEA with the [BashSupport Pro](https://plugins.jetbrains.com/plugin/13841-bashsupport-pro)
plugin. Ensure the `BATS_PLUGIN_PATH` environment variable is exported before launching the IDE
to avoid setting it in each run configuration.
