## 3.2.3
  - Update behaviour of `decode_size_limit_bytes` to do not apply any limitation to the length of a line, eventually tagging the event if it's set. [#45](https://github.com/logstash-plugins/logstash-codec-json_lines/pull/45)

## 3.2.2
  - Fix: updated the way to check if the `decode_size_limit_bytes` has been explicitly customised. [#47](https://github.com/logstash-plugins/logstash-codec-json_lines/pull/47)

## 3.2.1
  - Raise the default value of `decode_size_limit_bytes` up to 512 MB. [#46](https://github.com/logstash-plugins/logstash-codec-json_lines/pull/46)

## 3.2.0
  - Add decode_size_limit_bytes option to limit the maximum size of each JSON line that can be parsed.[#43](https://github.com/logstash-plugins/logstash-codec-json_lines/pull/43)

## 3.1.0
  - Feat: event `target => namespace` support (ECS) [#41](https://github.com/logstash-plugins/logstash-codec-json_lines/pull/41)
  - Refactor: dropped support for old Logstash versions (< 6.0)

## 3.0.6
  - Support flush method, see https://github.com/logstash-plugins/logstash-codec-json_lines/pull/35

## 3.0.5
  - Update gemspec summary

## 3.0.4
  - Fix some documentation issues

## 3.0.2
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 3.0.1
  - Republish all the gems under jruby.
## 3.0.0
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141
# 2.1.3
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.1.2
  - New dependency requirements for logstash-core for the 5.0 release
## 2.1.0
 - Backward compatible support for `Event#from_json` method https://github.com/logstash-plugins/logstash-codec-json_lines/pull/19

## 2.0.5
 - Directly use buftok to avoid indirection through the line codec https://github.com/logstash-plugins/logstash-codec-json_lines/pull/18

## 2.0.4
 - Support for customizable delimiter

## 2.0.3
 - Fixed Timestamp check in specs

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

## 1.0.1
 - Improve documentation to warn about using this codec with a line oriented input.
 - light refactor of decode method
