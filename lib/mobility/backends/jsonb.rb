module Mobility
  module Backends
=begin

Stores prices as hash on Postgres jsonb column.

==Backend Options

===+prefix+ and +suffix+

Prefix and suffix to add to attribute name to generate jsonb column name.

@see Mobility::Backends::ActiveRecord::Jsonb
@see Mobility::Backends::Sequel::Jsonb
@see https://www.postgresql.org/docs/current/static/datatype-json.html PostgreSQL Documentation for JSON Types

=end
    module Jsonb
      extend Backend::OrmDelegator
    end
  end
end
