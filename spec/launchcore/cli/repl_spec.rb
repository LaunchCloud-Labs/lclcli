# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LaunchCore::CLI::REPL do
  include DatabaseHelper

  # Stub out Reline per-test so no terminal interaction is needed.
  # setup_reline sets .completion_proc= and .completion_append_character=,
  # and load_history_into_reline calls Reline::HISTORY.push — all safe to stub.
  before(:each) do
    stub_const('Reline', Module.new do
      HISTORY = []
      def self.completion_proc=(_); end
      def self.completion_append_character=(_); end
      def self.readline(_prompt, _history = false)
        nil
      end
    end)
  end

  before(:each) do
    truncate_tables!
    LaunchCore::Output.silent_mode = true
  end

  after(:each) do
    LaunchCore::Output.silent_mode = false
  end

  let(:repl) { described_class.new }

  describe '#initialize' do
    it 'creates a REPL instance without raising' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '#build_prompt (private)' do
    context 'when unauthenticated' do
      it 'returns a guest prompt string' do
        prompt = repl.send(:build_prompt)
        expect(prompt).to be_a(String)
        expect(prompt).to include('guest')
      end
    end

    context 'when authenticated' do
      let(:user) { create_test_user }

      before do
        token, = LaunchCore::Auth::JWTManager.encode(
          user_id:    user[:id],
          email:      user[:email],
          user_class: user[:user_class],
          auth_level: user[:auth_level]
        )
        repl.instance_variable_get(:@session).store!(token)
      end

      it 'returns an authenticated prompt with email' do
        prompt = repl.send(:build_prompt)
        expect(prompt).to be_a(String)
        expect(prompt).to include(user[:email])
      end
    end
  end

  describe '#level_color_for (private)' do
    it 'returns a color for each auth level' do
      [1, 2, 3, 4].each do |level|
        color = repl.send(:level_color_for, level)
        expect(color).to be_a(String)
        expect(color).not_to be_empty
      end
    end
  end

  describe '#tab_complete (private)' do
    it 'returns commands starting with given prefix' do
      result = repl.send(:tab_complete, '/auth')
      expect(result).to be_an(Array)
      expect(result).to all(start_with('/auth'))
    end

    it 'returns empty array for unmatched prefix' do
      result = repl.send(:tab_complete, '/zzz_no_match')
      expect(result).to be_empty
    end

    it 'returns all commands for empty string' do
      result = repl.send(:tab_complete, '')
      expect(result.length).to be > 10
    end
  end

  describe '#save_history and #persist_history (private)' do
    it 'accumulates history without duplicates' do
      repl.send(:save_history, '/help')
      repl.send(:save_history, '/status')
      repl.send(:save_history, '/status') # duplicate — should not be added
      buf = repl.instance_variable_get(:@history_buffer)
      expect(buf).to eq(['/help', '/status'])
    end

    it 'persist_history writes to the history file without raising' do
      repl.send(:save_history, '/help')
      expect { repl.send(:persist_history) }.not_to raise_error
      expect(File.exist?(LaunchCore::Config::HISTORY_FILE)).to be true
    end
  end

  describe '#run' do
    let(:capture) { StringIO.new }

    it 'starts up and exits immediately when readline returns nil (EOF)' do
      $stdout = capture
      expect { repl.run }.not_to raise_error
      $stdout = STDOUT
    end

    it 'processes a slash command when readline returns one line then EOF' do
      call_count = 0
      allow(Reline).to receive(:readline) do
        call_count += 1
        call_count == 1 ? '/help' : nil
      end
      $stdout = capture
      expect { repl.run }.not_to raise_error
      $stdout = STDOUT
    end

    it 'handles an Interrupt from readline gracefully' do
      allow(Reline).to receive(:readline).and_raise(Interrupt)
      $stdout = capture
      expect { repl.run }.not_to raise_error
      $stdout = STDOUT
    end

    it 'treats exit/quit input as logout + exit' do
      call_count = 0
      allow(Reline).to receive(:readline) do
        call_count += 1
        call_count == 1 ? 'quit' : nil
      end
      # Stub exit so the test doesn't actually exit
      allow(repl).to receive(:exit)
      $stdout = capture
      expect { repl.run }.not_to raise_error
      $stdout = STDOUT
    end
  end

  describe '#process (private)' do
    let(:dispatcher) { repl.instance_variable_get(:@dispatcher) }

    it 'dispatches slash commands' do
      LaunchCore::Output.json_mode = true
      expect(dispatcher).to receive(:dispatch).with('/help')
      repl.send(:process, '/help')
      LaunchCore::Output.json_mode = false
    end

    it 'prints a warning for non-slash input' do
      LaunchCore::Output.silent_mode = false
      out = StringIO.new
      $stdout = out
      repl.send(:process, 'some random text')
      $stdout = STDOUT
      expect(out.string).to include('Unknown input')
    end

    it 'does not raise for an AuthError in process' do
      allow(dispatcher).to receive(:dispatch).and_raise(LaunchCore::Auth::AuthError, 'test error')
      LaunchCore::Output.silent_mode = false
      out = StringIO.new
      $stdout = out
      expect { repl.send(:process, '/help') }.not_to raise_error
      $stdout = STDOUT
    end
  end
end
