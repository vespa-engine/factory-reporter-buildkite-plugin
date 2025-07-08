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
This module uses [Buildkite Plugin Tester](https://buildkite.com/docs/pipelines/integrations/plugins/writing#step-5-add-a-test)
and [BATS](https://bats-core.readthedocs.io/en/stable/) for testing. To run the tests locally, use the following
command (from the root of the repository):
```bash
$ podman run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```
