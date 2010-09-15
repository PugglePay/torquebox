require 'yaml'

module TorqueBox
  module Messaging
    module MetaData
      class Builder
        attr_reader :processors
        def initialize(&block)
          @processors = []
          block.call( self ) if block
        end
        
        def evaluate_file(file)
          evaluate( File.read( file ) ) 
        end
        
        def evaluate(config)
          yaml = YAML.load(config)
          return unless yaml
          raise "Invalid configuration" unless yaml.is_a? Hash
          parse yaml
        end

        def parse(map)
          destinations = map.keys
          destinations.each do |destination|
            case map[destination]
            when Hash
              map[destination].keys.each do |handler|
                subscribe handler, destination, map[destination][handler]
              end
            when Array
              map[destination].each do |handler|
                if handler.is_a? String
                  subscribe handler, destination
                else # it's a Hash
                  subscribe handler.keys.first, destination, handler.values.first
                end
              end
            else # it's a String
              subscribe map[destination], destination
            end
          end
        end

        def self.evaluate_file(file)
          builder = Builder.new()
          builder.evaluate_file( file )
          builder.processors
        end

        def subscribe(processor, destination_name, opts=nil)
          opts ||= {}
          metadata = Java::org.torquebox.messaging.metadata::MessageProcessorMetaData.new()
          case ( processor )
            when Class
              metadata.ruby_class_name = processor.name
            when String, Symbol
              processor_str = processor.to_s
              metadata.ruby_class_name   = Java::org.torquebox.common.util::StringUtils.camelize( processor_str )
              metadata.ruby_require_path = Java::org.torquebox.common.util::StringUtils.underscore( processor_str )
            else
              throw "Unable to configure message processor #{processor}"
          end 
          metadata.destination_name = destination_name
          metadata.message_selector = opts['filter']
          config = opts['config'] || {}
          processor_config = Marshal.dump( config )
          config_bytes = processor_config.to_java_bytes
          metadata.ruby_config = config_bytes
          @processors << metadata
        end
      end
    end
  end
end

