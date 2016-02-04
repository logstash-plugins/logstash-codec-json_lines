# encoding: utf-8

require "logstash/codecs/json_lines"
require "logstash/event"
require "logstash/json"
require "insist"

describe LogStash::Codecs::JSONLines do
  subject do
    next LogStash::Codecs::JSONLines.new
  end

  context "#decode" do
    it "should return an event from json data" do
      data = {"foo" => "bar", "baz" => {"bah" => ["a","b","c"]}}
      subject.decode(LogStash::Json.dump(data) + "\n") do |event|
        insist { event.is_a? LogStash::Event }
        insist { event["foo"] } == data["foo"]
        insist { event["baz"] } == data["baz"]
        insist { event["bah"] } == data["bah"]
      end
    end

    it "should return an event from json data when a newline is recieved" do
      data = {"foo" => "bar", "baz" => {"bah" => ["a","b","c"]}}
      subject.decode(LogStash::Json.dump(data)) do |event|
        insist {false}
      end
      subject.decode("\n") do |event|
        insist { event.is_a? LogStash::Event }
        insist { event["foo"] } == data["foo"]
        insist { event["baz"] } == data["baz"]
        insist { event["bah"] } == data["bah"]
      end
    end

    context "when using custom delimiter" do
      let(:delimiter) { "|" }
      let(:line) { "{\"hey\":1}|{\"hey\":2}|{\"hey\":3}|" }
      subject do
        next LogStash::Codecs::JSONLines.new("delimiter" => delimiter)
      end

      it "should decode multiple lines separated by the delimiter" do
        result = []
        subject.decode(line) { |event| result << event }
        expect(result.size).to eq(3)
        expect(result[0]["hey"]).to eq(1)
        expect(result[1]["hey"]).to eq(2)
        expect(result[2]["hey"]).to eq(3)
      end
    end

    context "processing plain text" do
      it "falls back to plain text" do
        decoded = false
        subject.decode("something that isn't json\n") do |event|
          decoded = true
          insist { event.is_a?(LogStash::Event) }
          insist { event["message"] } == "something that isn't json"
          insist { event["tags"] }.include?("_jsonparsefailure")
        end
        insist { decoded } == true
      end
    end

    context "processing weird binary blobs" do
      it "falls back to plain text and doesn't crash (LOGSTASH-1595)" do
        decoded = false
        blob = (128..255).to_a.pack("C*").force_encoding("ASCII-8BIT")
        subject.decode(blob)
        subject.decode("\n") do |event|
          decoded = true
          insist { event.is_a?(LogStash::Event) }
          insist { event["message"].encoding.to_s } == "UTF-8"
        end
        insist { decoded } == true
      end
    end

    context "when json could not be parsed" do

      let(:message)    { "random_message\n" }

      it "add the failure tag" do
        subject.decode(message) do |event|
          expect(event).to include "tags"
        end
      end

      it "uses an array to store the tags" do
        subject.decode(message) do |event|
          expect(event['tags']).to be_a Array
        end
      end

      it "add a json parser failure tag" do
        subject.decode(message) do |event|
          expect(event['tags']).to include "_jsonparsefailure"
        end
      end

    end
  end

  context "#encode" do
    let(:data) { { LogStash::Event::TIMESTAMP => "2015-12-07T11:37:00.000Z", "foo" => "bar", "baz" => {"bah" => ["a","b","c"]}} }
    let(:event) { LogStash::Event.new(data) }

    it "should return json data" do
      got_event = false
      subject.on_event do |e, d|
        insist { d } == "#{LogStash::Event.new(data).to_json}\n"
        insist { LogStash::Json.load(d)["foo"] } == data["foo"]
        insist { LogStash::Json.load(d)["baz"] } == data["baz"]
        insist { LogStash::Json.load(d)["bah"] } == data["bah"]
        got_event = true
      end
      subject.encode(event)
      insist { got_event }
    end

    context "when using custom delimiter" do
      let(:delimiter) { "|" }
      subject do
        next LogStash::Codecs::JSONLines.new("delimiter" => delimiter)
      end

      it "should decode multiple lines separated by the delimiter" do
        subject.on_event do |e, d|
          insist { d } == "#{LogStash::Event.new(data).to_json}#{delimiter}"
        end
        subject.encode(event)
      end
    end
  end

  context 'reading from a simulated multiline json file without last newline' do
    let(:input) do
      %{{"field": "value1"}
{"field": "value2"}}
    end

    let(:collector) { Array.new }

    it 'should generate one event' do
      subject.decode(input) do |event|
        collector.push(event)
      end
      expect(collector.size).to eq(1)
      expect(collector.first['field']).to eq('value1')
    end
  end

  context 'reading from a simulated multiline json file with last newline' do
    let(:input) do
      %{{"field": "value1"}
{"field": "value2"}
}
    end

    let(:collector) { Array.new }

    it 'should generate two events' do
      subject.decode(input) do |event|
        collector.push(event)
      end
      expect(collector.size).to eq(2)
      expect(collector.first['field']).to eq('value1')
      expect(collector.last['field']).to eq('value2')
    end
  end
end
