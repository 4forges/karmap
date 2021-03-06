[![Build Status](https://secure.travis-ci.org/4forges/karmap.png)](http://travis-ci.org/4forges/karmap)

# Karmap

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/karmap`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'karmap'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install karmap

## Usage

To prevent Karma services from being killed on SSH session disconnect, run this command:

    $ sudo loginctl enable-linger ubuntu

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/karmap.

## Testing

```bash
brew cask install virtualbox

```

Copy `nassa/downloads/VirtualBox VMs` to your user root folder, then

```bash
vboxmanage startvm KarmaP --type headless
(wait 10 sec)
ssh -p 2222 extendi@localhost
(password: extendi1)
cd /media/sf_shared

(after running tests)
vboxmanage controlvm KarmaP poweroff 
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


## Systemd

Enabled services 

    $ systemctl --user list-unit-files | grep enabled
    
Log

    $ journalctl -f
    
Manual start
    
    $ systemctl --user start managed-sources-facebookfetcher@33000.service

Avoid service kill on SSH disconnect

    $ sudo loginctl enable-linger ubuntu

