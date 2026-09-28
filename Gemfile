# frozen_string_literal: true

source 'https://rubygems.org'

# needed for Jekyll
gem 'jekyll'
gem 'webrick'
gem 'logger'
gem 'base64'
gem 'ostruct'

# needed for Rake tasks
gem 'rake'
gem 'csv'
gem 'fileutils'
gem 'mini_magick'
unless Gem.win_platform?
  gem 'image_optim'
  gem 'image_optim_pack'
end

# Japanese/Chinese/Korean search index, built at build time (see cjk_index in _config.yml)
group :jekyll_plugins do
  # pinned to a commit: Gemfile.lock is not committed in this repo
  gem 'cjk_index', git: 'https://github.com/nakamura196/cjk_index.git', ref: '825092c66019164596dad6cee6ad25651f493674', require: 'cjk_index/jekyll'
end
