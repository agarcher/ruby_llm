# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class Weather < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a location'
    param :latitude, desc: 'Latitude (e.g., 52.5200)'
    param :longitude, desc: 'Longitude (e.g., 13.4050)'

    def execute(latitude:, longitude:)
      "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
    end
  end

  class BestLanguageToLearn < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets the best language to learn'

    def execute
      'Ruby'
    end
  end

  class BrokenTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather'

    def execute
      raise 'This tool is broken'
    end
  end

  class DiceRoll < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Rolls a single six-sided die and returns the result'

    def execute
      { roll: rand(1..6) }
    end
  end

  describe 'function calling' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools" do
        unless RubyLLM::Provider.providers[provider]&.local?
          model_info = RubyLLM.models.find(model)
          skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools in multi-turn conversations" do
        unless RubyLLM::Provider.providers[provider]&.local?
          model_info = RubyLLM.models.find(model)
          skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools without parameters" do
        unless RubyLLM::Provider.providers[provider]&.local?
          model_info = RubyLLM.models.find(model)
          skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(BestLanguageToLearn)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'
        response = chat.ask("What's the best language to learn?")
        expect(response.content).to include('Ruby')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools without parameters in multi-turn streaming conversations" do
        unless RubyLLM::Provider.providers[provider]&.local?
          model_info = RubyLLM.models.find(model)
          skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(BestLanguageToLearn)
                      .with_instructions('You must use tools whenever possible.')
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'
        chunks = []

        response = chat.ask("What's the best language to learn?") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('Ruby')

        response = chat.ask("Tell me again: what's the best language to learn?") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('Ruby')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools with multi-turn streaming conversations" do
        unless RubyLLM::Provider.providers[provider]&.local?
          model_info = RubyLLM.models.find(model)
          skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
        end
        if provider == :gpustack && model == 'qwen3'
          skip 'Qwen3 on GPUStack has issues with function calling in multi-turn streaming conversations'
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)
        # Disable thinking mode for qwen models
        chat = chat.with_params(enable_thinking: false) if model == 'qwen3'
        chunks = []

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can handle multiple tool calls in a single response" do
        skip 'Local providers do not reliably use tools' if RubyLLM::Provider.providers[provider]&.local?
        unless RubyLLM::Provider.providers[provider]&.local?
          model_info = RubyLLM.models.find(model)
          skip "#{model} doesn't support function calling" unless model_info&.supports_functions?
        end

        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(DiceRoll)
                      .with_instructions(
                        'You must call the dice_roll tool exactly 3 times when asked to roll dice 3 times.'
                      )

        # Track tool calls to ensure all 3 are executed
        tool_call_count = 0

        original_execute = DiceRoll.instance_method(:execute)
        DiceRoll.define_method(:execute) do |**|
          tool_call_count += 1
          # Return a fixed result for VCR consistency
          { roll: tool_call_count }
        end

        response = chat.ask('Roll the dice 3 times')

        # Restore original method
        DiceRoll.define_method(:execute, original_execute)

        # Verify all 3 tool calls were made
        expect(tool_call_count).to eq(3)

        # Verify the response contains some dice roll results
        expect(response.content).to match(/\d+/) # Contains at least one number
        expect(response.content.downcase).to match(/roll|dice|result/) # Mentions rolling or results
      end
    end
  end

  describe 'tool call callbacks' do
    it 'calls on_tool_call callback when tools are used' do
      tool_calls_received = []

      chat = RubyLLM.chat
                    .with_tool(Weather)
                    .on_tool_call { |tool_call| tool_calls_received << tool_call }

      response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")

      expect(tool_calls_received).not_to be_empty
      expect(tool_calls_received.first).to respond_to(:name)
      expect(tool_calls_received.first).to respond_to(:arguments)
      expect(tool_calls_received.first.name).to eq('weather')
      expect(response.content).to include('15')
      expect(response.content).to include('10')
    end
  end

  describe 'error handling' do
    it 'raises an error when tool execution fails' do
      chat = RubyLLM.chat.with_tool(BrokenTool)

      expect { chat.ask('What is the weather?') }.to raise_error(RuntimeError) do |error|
        expect(error.message).to include('This tool is broken')
      end
    end
  end
end
