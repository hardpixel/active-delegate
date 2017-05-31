# ActiveDelegate

Stores and retrieves delegatable data through attributes on a ActiveRecord class, with support for translatable attributes.

[![Gem Version](https://badge.fury.io/rb/active_delegate.svg)](https://badge.fury.io/rb/active_delegate)
[![Code Climate](https://codeclimate.com/github/hardpixel/active-delegate/badges/gpa.png)](https://codeclimate.com/github/hardpixel/active-delegate)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_delegate'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_delegate

## Usage

```ruby
class Address < ActiveRecord::Base
  # columns: :city, :district
end

class Person < ActiveRecord::Base
  # columns: :name, email, :phone, :address_id

  include ActiveDelegate

  belongs_to :address
  has_one    :user
  has_many   :books

  delegate_attributes to: :address, prefix: true
end

person = Person.new(name: "John", email: 'john@mail.com', address_city: 'Athens', address_district: 'Attiki')

person.name             # 'John'
person.address_city     # 'Athens'
person.address.city     # 'Athens'
person.address_district # 'Attiki'
person.address.district # 'Attiki'

class User < ActiveRecord::Base
  # columns: :login, :password, :person_id

  include ActiveDelegate

  belongs_to :person, autosave: true

  delegate_associations to: :person
  delegate_attributes   to: :person
end

user = User.new(login: 'jonian', password: 'passwd', name: "John", email: 'john@mail.com')

user.name           # 'John'
user.login          # 'jonian'
user.user           # @user
user.books          # []

user.email          # 'john@mail.com'
user.email?         # true
user.email_changed? # true
user.email_was      # nil
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hardpixel/active-delegate.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
