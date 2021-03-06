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

  class Database

    module HashStore

      # Never close, because we can't restore.
      def close
        self
      end

      private

      # Never up-to-date.
      def uptodate?
        false
      end

      # Nothing to do.
      def uptodate!
        nil
      end

      def _clear
        @db.clear if @db
      end

      def _open
        {}
      end

      # Never closed.
      def _closed?
        false
      end

      # Dup key, because we're reusing everything.
      def _each
       @db.each { |key, val| yield key.dup, val }
     end

    end

  end

end
