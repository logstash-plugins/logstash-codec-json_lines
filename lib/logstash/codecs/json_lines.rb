# encoding: utf-8
require "logstash/codecs/base"
require "logstash/util/charset"
require "logstash/util/buftok"
require "logstash/json"
require 'logstash/plugin_mixins/ecs_compatibility_support'
require 'logstash/plugin_mixins/ecs_compatibility_support/target_check'
require 'logstash/plugin_mixins/validator_support/field_reference_validation_adapter'
require 'logstash/plugin_mixins/event_support/event_factory_adapter'
require 'logstash/plugin_mixins/event_support/from_json_helper'

# This codec will decode streamed JSON that is newline delimited.
# Encoding will emit a single JSON string ending in a `@delimiter`
# NOTE: Do not use this codec if your source input is line-oriented JSON, for
# example, redis or file inputs. Rather, use the json codec.
# More info: This codec is expecting to receive a stream (string) of newline
# terminated lines. The file input will produce a line string without a newline.
# Therefore this codec cannot work with line oriented inputs.
class LogStash::Codecs::JSONLines < LogStash::Codecs::Base

  include LogStash::PluginMixins::ECSCompatibilitySupport
  include LogStash::PluginMixins::ECSCompatibilitySupport::TargetCheck

  extend LogStash::PluginMixins::ValidatorSupport::FieldReferenceValidationAdapter

  include LogStash::PluginMixins::EventSupport::EventFactoryAdapter
  include LogStash::PluginMixins::EventSupport::FromJsonHelper

  config_name "json_lines"

  # The character encoding used in this codec. Examples include `UTF-8` and
  # `CP1252`
  #
  # JSON requires valid `UTF-8` strings, but in some cases, software that
  # emits JSON does so in another encoding (nxlog, for example). In
  # weird cases like this, you can set the charset setting to the
  # actual encoding of the text and logstash will convert it for you.
  #
  # For nxlog users, you'll want to set this to `CP1252`
  config :charset, :validate => ::Encoding.name_list, :default => "UTF-8"

  # Change the delimiter that separates lines
  config :delimiter, :validate => :string, :default => "\n"

  # Defines a target field for placing decoded fields.
  # If this setting is omitted, data gets stored at the root (top level) of the event.
  # The target is only relevant while decoding data into a new event.
  config :target, :validate => :field_reference

  public

  def register
    @buffer = FileWatch::BufferedTokenizer.new(@delimiter)
    @converter = LogStash::Util::Charset.new(@charset)
    @converter.logger = @logger
  end

  def decode(data, &block)
    @buffer.extract(data).each do |line|
      parse_json(@converter.convert(line), &block)
    end
  end

  def encode(event)
    # Tack on a @delimiter for now because previously most of logstash's JSON
    # outputs emitted one per line, and whitespace is OK in json.
    @on_event.call(event, "#{event.to_json}#{@delimiter}")
  end

  def flush(&block)
    remainder = @buffer.flush
    if !remainder.empty?
      parse_json(@converter.convert(remainder), &block)
    end
  end

  private

  def parse_json(json)
    events_from_json(json, targeted_event_factory).each { |event| yield event }
  rescue => e
    @logger.warn("JSON parse error, original data now in message field", message: e.message, exception: e.class, data: json)
    yield parse_json_error_event(json)
  end

  def parse_json_error_event(json)
    event_factory.new_event("message" => json, "tags" => ["_jsonparsefailure"])
  end

end
