# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::Output do
  let(:stdout_capture) { StringIO.new }

  before do
    @orig_stdout = $stdout
    $stdout = stdout_capture
    described_class.silent_mode = false
    described_class.json_mode   = false
  end

  after do
    $stdout = @orig_stdout
    described_class.silent_mode = false
    described_class.json_mode   = false
  end

  describe '.success / .warning / .critical / .info / .muted / .primary' do
    it 'prints success messages to stdout' do
      described_class.success('All good')
      expect(stdout_capture.string).to include('All good')
    end

    it 'prints warning messages to stdout' do
      described_class.warning('Heads up')
      expect(stdout_capture.string).to include('Heads up')
    end

    it 'prints critical messages to stdout' do
      described_class.critical('Error!')
      expect(stdout_capture.string).to include('Error!')
    end

    it 'prints info messages to stdout' do
      described_class.info('FYI')
      expect(stdout_capture.string).to include('FYI')
    end

    it 'prints muted messages to stdout' do
      described_class.muted('quiet note')
      expect(stdout_capture.string).to include('quiet note')
    end

    it 'prints primary messages to stdout' do
      described_class.primary('headline')
      expect(stdout_capture.string).to include('headline')
    end

    it 'suppresses all output in silent_mode' do
      described_class.silent_mode = true
      described_class.success('silence')
      described_class.warning('silence')
      described_class.info('silence')
      expect(stdout_capture.string).to be_empty
    end
  end

  describe '.header' do
    it 'prints a decorative header' do
      described_class.header('Test Header')
      expect(stdout_capture.string).to include('Test Header')
    end

    it 'suppresses header in silent_mode' do
      described_class.silent_mode = true
      described_class.header('No Show')
      expect(stdout_capture.string).to be_empty
    end
  end

  describe '.divider' do
    it 'prints a divider line' do
      described_class.divider
      expect(stdout_capture.string).to include('─')
    end

    it 'suppresses divider in silent_mode' do
      described_class.silent_mode = true
      described_class.divider
      expect(stdout_capture.string).to be_empty
    end
  end

  describe '.table' do
    it 'prints a formatted table' do
      described_class.table(['Name', 'Value'], [['foo', 'bar'], ['baz', 'qux']])
      out = stdout_capture.string
      expect(out).to include('Name')
      expect(out).to include('foo')
    end

    it 'suppresses table in silent_mode' do
      described_class.silent_mode = true
      described_class.table(['A'], [['b']])
      expect(stdout_capture.string).to be_empty
    end
  end

  describe '.json_response' do
    it 'returns a hash with status, message, timestamp' do
      result = described_class.json_response(status: 'ok', message: 'done')
      expect(result[:status]).to eq('ok')
      expect(result[:message]).to eq('done')
      expect(result[:timestamp]).to match(/\d{4}-\d{2}-\d{2}/)
    end

    it 'includes optional command and data keys when provided' do
      result = described_class.json_response(
        status: 'ok', message: 'x', command: '/test', data: { k: 1 }
      )
      expect(result[:command]).to eq('/test')
      expect(result[:data]).to eq({ k: 1 })
    end

    it 'includes extra kwargs in the payload' do
      result = described_class.json_response(status: 'ok', message: 'x', version: '9.9')
      expect(result[:version]).to eq('9.9')
    end

    it 'prints valid JSON to stdout' do
      described_class.json_response(status: 'ok', message: 'hi')
      parsed = JSON.parse(stdout_capture.string)
      expect(parsed['status']).to eq('ok')
    end

    it 'omits data key when nil' do
      result = described_class.json_response(status: 'ok', message: 'x')
      expect(result).not_to have_key(:data)
    end
  end

  describe '.blank' do
    it 'prints a blank line' do
      described_class.blank
      expect(stdout_capture.string).to include("\n")
    end

    it 'suppresses blank in silent_mode' do
      described_class.silent_mode = true
      described_class.blank
      expect(stdout_capture.string).to be_empty
    end
  end
end
