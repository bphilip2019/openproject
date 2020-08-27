#-- encoding: UTF-8
#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

module API
  module Utilities
    class ResourceLinkParser
      class << self
        def parse(resource_link)
          # string objects have a quite different format from the usual resources (query-parameter)
          # we therefore have a specific regex to deal with them and a generic one for all others
          link = Addressable::URI.parse(resource_link)
          parse_string_object(link) || parse_resource(link)
        end

        def parse_id(resource_link,
                     property:,
                     expected_version: nil,
                     expected_namespace: nil)
          raise ArgumentError unless resource_link

          resource = parse(resource_link)

          if resource
            version_valid = matches_expectation?(expected_version, resource[:version])
            namespace_valid = matches_expectation?(expected_namespace, resource[:namespace])
          end

          unless resource && version_valid && namespace_valid
            expected_link = make_expected_link(expected_version, expected_namespace)
            fail ::API::Errors::InvalidResourceLink.new(property, expected_link, resource_link)
          end

          resource[:id]
        end

        private

        def parse_resource(resource_link)
          match = resource_matcher.extract(resource_link)

          return nil unless match

          parsed = {
            version: match['version'],
            namespace: match['namespace'],
            id: match['id']
          }

          parsed.values.any?(&:nil?) || parsed[:id].end_with?('/') ? nil : parsed
        end

        def parse_string_object(resource_link)
          match = string_object_matcher.extract(resource_link)

          return nil unless match

          {
            version: match['version'],
            namespace: 'string_objects',
            id: (match['value'] || '').match(/\w*/)[0]
          }
        end

        def resource_matcher
          @resource_matcher ||= Addressable::Template.new("/api/v{version}/{namespace}/{+id}")
        end

        def string_object_matcher
          @string_object_matcher ||= Addressable::Template.new("/api/v{version}/string_objects?value={+value}")
        end

        # returns whether expectation and actual are identical
        # will always be true if there is no expectation (nil)
        def matches_expectation?(expected, actual)
          expected.nil? || Array(expected).any? { |e| e.to_s == actual }
        end

        def make_expected_link(version, namespaces)
          version = "v#{version}" || ':apiVersion'
          namespaces = Array(namespaces || ':resource')

          namespaces.map { |namespace| "/api/#{version}/#{namespace}/:id" }
        end
      end
    end
  end
end
