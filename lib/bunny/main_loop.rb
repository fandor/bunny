require "thread"

module Bunny
  # Network activity loop that reads and passes incoming AMQP 0.9.1 methods for
  # processing. They are dispatched further down the line in Bunny::Session and Bunny::Channel.
  # This loop uses a separate thread internally.
  #
  # This mimics the way RabbitMQ Java is designed quite closely.
  class MainLoop

    def initialize(transport, session)
      @transport = transport
      @session   = session
    end


    def start
      @thread    = Thread.new(&method(:run_loop))
    end

    def run_loop
      begin
        loop do
          frame = @transport.read_next_frame

          if frame.final?
            @session.handle_frame(frame.channel, frame.decode_payload)
          else
            header   = @transport.read_next_frame
            content  = ''

            if header.body_size > 0
              loop do
                body_frame = @transport.read_next_frame
                content << body_frame.decode_payload

                break if content.bytesize >= header.body_size
              end
            end

            @session.handle_frameset(frame.channel, [frame, header, content])
          end
        end
      rescue Exception => e
        puts e.message
        puts e.backtrace
      end
    end

    def stop
      @thread.stop
    end
  end
end
