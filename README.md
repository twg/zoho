# Zoho
[![Coverage Status](https://coveralls.io/repos/twg/zoho/badge.svg?branch=dexter)](https://coveralls.io/r/twg/zoho?branch=master)
[![Build Status](https://travis-ci.org/twg/zoho.svg?branch=master)](https://travis-ci.org/twg/zoho)

A thin wrapper around the Zoho CRM API.

## Installation

Add this line to your application's Gemfile:

    gem 'zoho'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install zoho

## Usage

This gem exposes a thin Ruby interface over a subset of the Zoho CRM API.

The following methods are currently implemented:

* getUsers
* searchRecords
* insertRecords
* updateRecords
* deleteRecords
* convertLead

Look at the [Zoho API Documentation](https://www.zoho.com/crm/help/api/) for
more information.

## Contributing

1. Fork it ( https://github.com/twg/zoho/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
