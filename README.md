# Fop: Scraping client for Japan Airlines FOP/Mileage calculator

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fop

## Usage

```
fop = Fop::Client.new

p fop.valid_cards
p fop.valid_statuses

##

p fop.valid_intl_airports_for_earning #=> Array<Airport>
p fop.valid_intl_fares #=> Array<Fare>

p fop.intl_search(
  from: 'TYO', # or Airport object
  to: 'SFO', # or Airport object
  fare: :first, # or Fare object
  card: :global, # or CardType object
  status: :sapphire, # or Status object
)

##

p fop.valid_dom_airports #=> Array<Airport>
p fop.valid_dom_classes #=> Array<SeatClass>
p fop.valid_dom_fares #=> Array<Fare>

p fop.intl_search(
  from: 'TYO', # or Airport object
  to: 'SFO', # or Airport object
  class: 'J', # or SeatClass object
  fare: :discount_other, # or Fare object
  card: :global, # or CardType object
  status: :sapphire, # or Status object
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sorah/fop.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
