# frozen_string_literal: true

# CollectionBuilder static IIIF helpers
#
# 1. Liquid filter `iiif_image`: given an image path from the metadata
#    (object_location), returns what a IIIF manifest needs to paint it:
#      { "id" => absolute image URL, "width", "height", "format",
#        "service" => absolute Image API base URL (only if level 0 files exist) }
#    Width and height are read from the file header, so no extra metadata
#    columns are needed. Returns nil for external URLs and missing files.
#
# 2. Generator: for every objects/iiif/3/<name>/_level0.json made by
#    `rake generate_iiif`, writes objects/iiif/3/<name>/info.json with this
#    site's URL, so the same files work in development and production.

require 'json'

module CollectionBuilderIIIF
  # Image API version in the path, so a v2 service could sit beside it (objects/iiif/2/...)
  IIIF_DIR = 'objects/iiif/3'

  # Pixel size from a JPEG or PNG header, without image libraries.
  def self.image_size(file)
    File.open(file, 'rb') do |f|
      head = f.read(24)
      return nil if head.nil? || head.bytesize < 24
      return head[16, 8].unpack('NN') if head.start_with?("\x89PNG".b)
      return nil unless head.start_with?("\xFF\xD8".b)

      f.seek(2)
      loop do
        marker = f.read(2)
        return nil if marker.nil? || marker.getbyte(0) != 0xFF

        code = marker.getbyte(1)
        length = f.read(2).unpack1('n')
        # SOF0-SOF15 carry the frame size (C4, C8, CC are other markers)
        if (0xC0..0xCF).cover?(code) && ![0xC4, 0xC8, 0xCC].include?(code)
          height, width = f.read(5).unpack('xnn')
          return [width, height]
        end
        f.seek(length - 2, IO::SEEK_CUR)
      end
    end
  rescue StandardError
    nil
  end

  def self.site_base(site)
    site.config['url'].to_s + site.config['baseurl'].to_s
  end

  def self.level0_meta(site, name)
    file = File.join(site.source, IIIF_DIR, name, '_level0.json')
    File.exist?(file) ? JSON.parse(File.read(file)) : nil
  end

  module Filters
    def iiif_image(path)
      return nil if path.nil? || path.to_s.strip.empty? || path.to_s =~ %r{\A[a-z]+://}i

      site = @context.registers[:site]
      @iiif_cache ||= {}
      @iiif_cache[path] ||= begin
        rel = path.to_s.sub(%r{\A/}, '')
        base = CollectionBuilderIIIF.site_base(site)
        name = File.basename(rel, '.*').downcase
        meta = CollectionBuilderIIIF.level0_meta(site, name)
        if meta
          service = "#{base}/#{IIIF_DIR}/#{name}"
          { 'id' => "#{service}/full/max/0/default.jpg", 'width' => meta['width'], 'height' => meta['height'],
            'format' => 'image/jpeg', 'service' => service }
        else
          file = File.join(site.source, rel)
          size = File.exist?(file) && CollectionBuilderIIIF.image_size(file)
          if size
            format = rel =~ /\.png\z/i ? 'image/png' : 'image/jpeg'
            { 'id' => "#{base}/#{rel}", 'width' => size[0], 'height' => size[1], 'format' => format }
          end
        end
      end
    end
  end

  class InfoJsonGenerator < Jekyll::Generator
    safe true

    def generate(site)
      Dir.glob(File.join(site.source, IIIF_DIR, '*', '_level0.json')).sort.each do |file|
        name = File.basename(File.dirname(file))
        meta = JSON.parse(File.read(file))
        info = {
          '@context' => 'http://iiif.io/api/image/3/context.json',
          'id' => "#{CollectionBuilderIIIF.site_base(site)}/#{IIIF_DIR}/#{name}",
          'type' => 'ImageService3',
          'protocol' => 'http://iiif.io/api/image',
          'profile' => 'level0',
          'width' => meta['width'],
          'height' => meta['height'],
          'sizes' => meta['sizes']
        }
        info['tiles'] = meta['tiles'] if meta['tiles']
        page = Jekyll::PageWithoutAFile.new(site, site.source, "#{IIIF_DIR}/#{name}", 'info.json')
        page.content = JSON.pretty_generate(info) + "\n"
        page.data['layout'] = nil
        page.data['sitemap'] = false
        site.pages << page
      end
    end
  end
end

Liquid::Template.register_filter(CollectionBuilderIIIF::Filters)
