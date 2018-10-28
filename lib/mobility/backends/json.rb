module Mobility
  module Backends
=begin

Stores prices as hash on Postgres json column.

==Backend Options

===+column_prefix+ and +column_suffix+

Prefix and suffix to add to attribute name to generate json column name.

@see Mobility::Backends::ActiveRecord::Json
@see Mobility::Backends::Sequel::Json
@see https://www.postgresql.org/docs/current/static/datatype-json.html PostgreSQL Documentation for JSON Types

=end
    module Json
      extend Backend::OrmDelegator
    end
  end
end
