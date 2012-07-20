module RHC
  module Commands
    class CommandHelpBindings
      def initialize(command, instance_commands, global_options)
        @command = command
        @actions = instance_commands.collect do |ic|
          m = /^#{command.name} ([^ ]+)/.match(ic[0])
          m ? {:name => m[1], :summary => ic[1].summary || ""} : nil
        end
        @actions.compact!
        @global_options = global_options
      end
    end

    def self.load
      Dir[File.join(File.dirname(__FILE__), "commands", "*.rb")].each do |file|
        require file
      end
      self
    end
    def self.add(opts)
      commands[opts[:name]] = opts
    end
    def self.global_option(*args)
      global_options << args
    end
    def self.to_commander(instance=Commander::Runner.instance)
      global_options.each{ |args| instance.global_option *args }
      commands.each_pair do |name, opts|
        instance.command name do |c|
          c.description = opts[:description]
          c.summary = opts[:summary]
          c.syntax = opts[:syntax]
          options_metadata = opts[:options_metadata]
          options_metadata.each { |o| c.option *o } unless options_metadata.nil?
          args_metadata = opts[:args_metadata] || []
          args_metadata.each do |arg_meta|
            arg_option_switches = arg_meta[:option_switches]
            arg_option_switches << arg_meta[:description]
            c.option(*arg_option_switches) unless arg_option_switches.nil?
          end

          c.when_called do |args, options|
            begin
              # handle help here
              if args.length > 0 and args[0] == 'help'
                cb = CommandHelpBindings.new(c, instance.commands, instance.options)
                help = instance.help_formatter.render_command(cb)
                say help
                next
              end

              # check to see if an arg's option was set
              raise ArgumentError.new("Invalid arguments") if args.length > args_metadata.length
              args_metadata.each_with_index do |arg_meta, i|
                o = arg_meta[:option_switches]
                raise ArgumentError.new("Missing #{arg[:name]} argument") if o.nil? and args.length <= i
                value = options.__hash__[arg_meta[:name]]
                unless value.nil?
                  raise ArgumentError.new("#{arg[:name]} specified twice on the command line and as a #{o[0]} switch") unless args.length == i
                  # add the option as an argument
                  args << value
                end
              end

              # call command
              begin
                opts[:class].new(c, args, options).send(opts[:method], *args)
              rescue Exception => e
                say e.to_s
                e.backtrace.each { |line| say line } if options.trace
                not e.respond_to?(:code) or e.code.nil? ? 128 : e.code
              end
            rescue ArgumentError => e
              cb = CommandHelpBindings.new(c, instance.commands, instance.options)
              help = instance.help_formatter.render_command(cb)
              say "Error: #{e.to_s}#{help}"
            end
          end
        end
      end
      self
    end

    protected
      def self.commands
        @commands ||= {}
      end
      def self.global_options
        @options ||= []
      end
  end
end
