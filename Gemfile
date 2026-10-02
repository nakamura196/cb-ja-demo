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
  # Gemfile.lock is not committed in this repo, so allow patch releases only
  gem 'cjk_index', '~> 0.1.0', require: 'cjk_index/jekyll'
  # static IIIF: info.json at build time and the iiif_image filter used by _layouts/item/manifest.json
  gem 'static_iiif', git: 'https://github.com/nakamura196/static_iiif.git', ref: '8b097d906a0fada6bbcc17cbbd70188d6d47ec6a', require: 'static_iiif/jekyll'
end
