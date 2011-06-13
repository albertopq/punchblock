          # Records a sound file with the given name. If no filename is specified a file named by Asterisk
          # will be created and returned. Else the given filename will be returned. If a relative path is
          # given, the file will be saved in the default Asterisk sound directory, /var/lib/spool/asterisk
          # by default.
          #
          # Silence and maxduration is specified in seconds.
          #
          # @example Asterisk generated filename
          #   filename = record
          # @example Specified filename
          #   record '/path/to/my-file.gsm'
          # @example All options specified
          #   record 'my-file.gsm', :silence => 5, :maxduration => 120
          #
          def record(*args)
            options = args.last.kind_of?(Hash) ? args.pop : {}
            filename = args.shift || "/tmp/recording_%d"

            if filename.index("%d")
              if @call.variables.has_key?(:recording_counter)
                @call.variables[:recording_counter] += 1
              else
                @call.variables[:recording_counter]  = 0
              end
              filename = filename % @call.variables[:recording_counter]
            end

            if (!options.has_key?(:format))
              format = filename.slice!(/\.[^\.]+$/)
              if (format.nil?)
                ahn_log.agi.warn "Format not specified and not detected.  Defaulting to \"gsm\""
                format = "gsm"
              end
              format.sub!(/^\./, "")
            else
              format = options.delete(:format)
            end

            # maxduration must be in milliseconds when using RECORD FILE
            maxduration = options.delete(:maxduration) || -1
            maxduration = maxduration * 1000 if maxduration > 0

            escapedigits = options.delete(:escapedigits) || "#"
            silence     = options.delete(:silence) || 0

            if (silence > 0)
              response("RECORD FILE", filename, format, escapedigits, maxduration, 0, "BEEP", "s=#{silence}")
            else
              response("RECORD FILE", filename, format, escapedigits, maxduration, 0, "BEEP")
            end

            # If the user hangs up before the recording is entered, -1 is returned and RECORDED_FILE
            # will not contain the name of the file, even though it IS in fact recorded.
            filename + "." + format
          end