# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/codecs/json_lines"
require "logstash/event"
require "logstash/json"
require "insist"

describe LogStash::Codecs::JSONLines do

  let(:codec_options) { {} }

  shared_examples :codec do

  context "#decode" do
    it "should return an event from json data" do
      data = {"foo" => "bar", "baz" => {"bah" => ["a","b","c"]}}
      subject.decode(LogStash::Json.dump(data) + "\n") do |event|
        insist { event.is_a? LogStash::Event }
        insist { event.get("foo") } == data["foo"]
        insist { event.get("baz") } == data["baz"]
        insist { event.get("bah") } == data["bah"]
      end
    end

    it "should return an event from json data when a newline is recieved" do
      data = {"foo" => "bar", "baz" => {"bah" => ["a","b","c"]}}
      subject.decode(LogStash::Json.dump(data)) do |event|
        insist {false}
      end
      subject.decode("\n") do |event|
        insist { event.is_a? LogStash::Event }
        insist { event.get("foo") } == data["foo"]
        insist { event.get("baz") } == data["baz"]
        insist { event.get("bah") } == data["bah"]
      end
    end

    context "when using custom delimiter" do
      let(:delimiter) { "|" }
      let(:line) { "{\"hey\":1}|{\"hey\":2}|{\"hey\":3}|" }
      let(:codec_options) { { "delimiter" => delimiter } }

      it "should decode multiple lines separated by the delimiter" do
        result = []
        subject.decode(line) { |event| result << event }
        expect(result.size).to eq(3)
        expect(result[0].get("hey")).to eq(1)
        expect(result[1].get("hey")).to eq(2)
        expect(result[2].get("hey")).to eq(3)
      end
    end

    context "processing plain text" do
      it "falls back to plain text" do
        decoded = false
        subject.decode("something that isn't json\n") do |event|
          decoded = true
          insist { event.is_a?(LogStash::Event) }
          insist { event.get("message") } == "something that isn't json"
          insist { event.get("tags") }.include?("_jsonparsefailure")
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
          insist { event.get("message").encoding.to_s } == "UTF-8"
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
          expect(event.get('tags')).to be_a Array
        end
      end

      it "add a json parser failure tag" do
        subject.decode(message) do |event|
          expect(event.get('tags')).to include "_jsonparsefailure"
        end
      end
    end

    context "blank lines" do
      let(:collector) { Array.new }

      it "should ignore bare blanks" do
        subject.decode("\n\n") do |event|
          collector.push(event)
        end
        expect(collector.size).to eq(0)
      end

      it "should ignore in between blank lines" do
        subject.decode("\n{\"a\":1}\n\n{\"b\":2}\n\n") do |event|
          collector.push(event)
        end
        expect(collector.size).to eq(2)
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
      let(:codec_options) { { "delimiter" => delimiter } }

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
      expect(collector.first.get('field')).to eq('value1')
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
      expect(collector.first.get('field')).to eq('value1')
      expect(collector.last.get('field')).to eq('value2')
    end
  end

  end

  context "forcing legacy parsing" do
    it_behaves_like :codec do
      subject do
        # register method is called in the constructor
        LogStash::Codecs::JSONLines.new(codec_options)
      end

      before(:each) do
        # stub codec parse method to force use of the legacy parser.
        # this is very implementation specific but I am not sure how
        # this can be tested otherwise.
        allow(subject).to receive(:parse) do |line, &block|
          subject.send(:legacy_parse, line, &block)
        end
      end
    end
  end

  context "default parser choice" do
    # here we cannot force the use of the Event#from_json since if this test is run in the
    # legacy context (no Java Event) it will fail but if in the new context, it will be picked up.
    it_behaves_like :codec do
      subject do
        # register method is called in the constructor
        LogStash::Codecs::JSONLines.new(codec_options)
      end
    end

    context "flush" do
      subject do
        LogStash::Codecs::JSONLines.new(codec_options)
      end

      let(:input) { "{\"foo\":\"bar\"}" }

      it "should flush buffered data'" do
        result = []
        subject.decode(input) { |e| result << e }
        expect(result.size).to eq(0)

        subject.flush { |e| result << e }
        expect(result.size).to eq(1)

        expect(result[0].get("foo")).to eq("bar")
      end
    end
  end
end
