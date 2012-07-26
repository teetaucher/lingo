# encoding: utf-8

#--
###############################################################################
#                                                                             #
# Lingo -- A full-featured automatic indexing system                          #
#                                                                             #
# Copyright (C) 2005-2007 John Vorhauer                                       #
# Copyright (C) 2007-2012 John Vorhauer, Jens Wille                           #
#                                                                             #
# Lingo is free software; you can redistribute it and/or modify it under the  #
# terms of the GNU Affero General Public License as published by the Free     #
# Software Foundation; either version 3 of the License, or (at your option)   #
# any later version.                                                          #
#                                                                             #
# Lingo is distributed in the hope that it will be useful, but WITHOUT ANY    #
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS   #
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for     #
# more details.                                                               #
#                                                                             #
# You should have received a copy of the GNU Affero General Public License    #
# along with Lingo. If not, see <http://www.gnu.org/licenses/>.               #
#                                                                             #
###############################################################################
#++

class Lingo

  class Attendee

    # Der Tokenizer zerlegt eine Textzeile in einzelne Token. Dies ist notwendig,
    # damit nachfolgende Attendees die Textdatei häppchenweise verarbeiten können.
    #
    # === Mögliche Verlinkung
    # Erwartet:: Daten des Typs *String* (Textzeilen) z.B. von TextReader
    # Erzeugt:: Daten des Typs *Token* z.B. für Abbreviator, Wordsearcher
    #
    # === Parameter
    # Kursiv dargestellte Parameter sind optional (ggf. mit Angabe der Voreinstellung).
    # Alle anderen Parameter müssen zwingend angegeben werden.
    # <b>in</b>:: siehe allgemeine Beschreibung des Attendee.
    # <b>out</b>:: siehe allgemeine Beschreibung des Attendee
    #
    # === Konfiguration
    # Der Tokenizer benötigt zur Identifikation einzelner Token Regeln, nach denen er
    # arbeiten soll. Die benötigten Regeln werden aufgrund des Umfangs nicht als Parameter,
    # sondern in der Sprachkonfiguration hinterlegt, die sich standardmäßig in der Datei
    # <tt>de.lang</tt> befindet (YAML-Format).
    #   language:
    #     attendees:
    #       tokenizer:
    #         regulars:
    #           - _CHR_: '\wÄÖÜÁÂÀÉÊÈÍÎÌÓÔÒÚÛÙÝäöüáâàéêèíîìóôòúûùý'
    #           - NUMS:  '[+-]?(\d{4,}|\d{1,3}(\.\d{3,3})*)(\.|(,\d+)?%?)'
    #           - URLS:  '((mailto:|(news|http|https|ftp|ftps)://)\S+|^(www(\.\S+)+)|\S+([\._]\S+)+@\S+(\.\S+)+)'
    #           - ABRV:  '(([_CHR_]+\.)+)[_CHR_]+'
    #           - ABRS:  '(([_CHR_]{1,1}\.)+)(?!\.\.)'
    #           - WORD:  '[_CHR_\d]+'
    #           - PUNC:  '[!,\.:;?]'
    #           - OTHR:  '[!\"#$%&()*\+,\-\./:;<=>?@\[\\\]^_`{|}~´]'
    #           - HELP:  '.*'
    # Die Regeln werden in der angegebenen Reihenfolge abgearbeitet, solange bis ein Token
    # erkannt wurde. Sollte keine Regel zutreffen, so greift die letzt Regel +HELP+ in jedem
    # Fall.
    # Regeln, deren Name in Unterstriche eingefasst sind, werden als Makro interpretiert.
    # Makros werden genutzt, um lange oder sich wiederholende Bestandteile von Regeln
    # einmalig zu definieren und in den Regeln über den Makronamen eine Auflösung zu forcieren.
    # Makros werden selber nicht für die Erkennung von Token eingesetzt.
    #
    # === Generierte Kommandos
    # Damit der nachfolgende Datenstrom einwandfrei verarbeitet werden kann, generiert der Tokenizer
    # Kommandos, die mit in den Datenstrom eingefügt werden.
    # <b>*EOL(<dateiname>)</b>:: Kennzeichnet das Ende einer Textzeile, da die Information ansonsten
    # für nachfolgende Attendees verloren wäre.
    #
    # === Beispiele
    # Bei der Verarbeitung einer normalen Textdatei mit der Ablaufkonfiguration <tt>t1.cfg</tt>
    #   meeting:
    #     attendees:
    #       - text_reader: { out: lines, files: '$(files)' }
    #       - tokenizer:   { in: lines, out: token }
    #       - debugger:    { in: token, prompt: 'out>' }
    # ergibt die Ausgabe über den Debugger: <tt>lingo -c t1 test.txt</tt>
    #   out> *FILE('test.txt')
    #   out> :Dies/WORD:
    #   out> :ist/WORD:
    #   out> :eine/WORD:
    #   out> :Zeile/WORD:
    #   out> :./PUNC:
    #   out> *EOL('test.txt')
    #   out> :Dies/WORD:
    #   out> :ist/WORD:
    #   out> :noch/WORD:
    #   out> :eine/WORD:
    #   out> :./PUNC:
    #   out> *EOL('test.txt')
    #   out> *EOF('test.txt')

    class Tokenizer < self

      protected

      def init
        @space = get_key('space', false)
        @tags  = get_key('tags',  true)
        @wiki  = get_key('wiki',  true)

        # default rules
        @rules = [['SPAC', /^\s+/]]
        @rules << ['HTML', /^<[^>]+>/]       unless @tags
        @rules << ['WIKI', /^\[\[.+?\]\]/]   unless @wiki
        @rules.unshift(['WIKI', /^=+.+=+$/]) unless @wiki

        get_key('regulars', []).each_with_object({}) { |rule, macros|
          name, expr = rule.dup.shift

          expr = expr.gsub(/_(\w+?)_/) {
            macros[$&] || Char[$1] || warn("Macro not found: #{$1}")
          }

          if name =~ /^_\w+_$/
            macros[name] = expr
          else
            @rules << [name, /^#{expr}/]
          end
        }

        @filename = @cont = nil
      end

      def control(cmd, param)
        case cmd
          when STR_CMD_FILE then @filename = param
          when STR_CMD_LIR  then @filename = nil
          when STR_CMD_EOF  then @cont     = nil
        end
      end

      def process(obj)
        if obj.is_a?(String)
          inc('Anzahl Zeilen')

          tokenize(obj) { |form, attr|
            inc("Anzahl Muster #{attr}")
            inc('Anzahl Token')

            forward(Token.new(form, attr))
          }

          forward(STR_CMD_EOL, @filename) if @filename
        else
          forward(obj)
        end
      end

      private

      # tokenize("Eine Zeile.")  ->  [:Eine/WORD:, :Zeile/WORD:, :./PUNC:]
      def tokenize(line)
        case @cont
          when 'HTML'
            if line =~ /^[^<>]*>/
              yield $&, @cont
              line, @cont = $', nil
            else
              yield line, @cont
              return
            end
          when 'WIKI'
            if line =~ /^[^\[\]]*\]\]/
              yield $&, @cont
              line, @cont = $', nil
            else
              yield line, @cont
              return
            end
          when nil
            if !@tags && line =~ /<[^<>]*$/
              yield $&, @cont = 'HTML'
              line = $`
            end

            if !@wiki && line =~ /\[\[[^\[\]]*$/
              yield $&, @cont = 'WIKI'
              line = $`
            end
        end

        while (l = line.length) > 0 && @rules.find { |name, expr|
          if line =~ expr
            yield $&, name if name != 'SPAC' || @space
            l == $'.length ? break : line = $'
          end
        }
        end
      end

    end

  end

end
