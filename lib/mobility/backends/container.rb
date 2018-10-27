module Mobility
  module Backends

=begin

Stores prices for multiple attributes on a single shared Postgres jsonb
column (called a "container").

==Backend Options

===+column_name+

Name of the column for the prices container (where prices are stored).

@see Mobility::Backends::ActiveRecord::Container
@see Mobility::Backends::Sequel::Container
@see https://www.postgresql.org/docs/current/static/datatype-json.html PostgreSQL Documentation for JSON Types

=end
    module Container
      extend Backend::OrmDelegator
    end
  end
end
