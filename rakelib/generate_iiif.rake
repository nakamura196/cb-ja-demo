###############################################################################
# TASK: generate_iiif
#
# create static IIIF Image API level 0 files for images in the 'objects' folder,
# so they can be served from any static host (no image server)
###############################################################################
#
# For each image, writes objects/iiif/3/<name>/ (Image API 3) with:
#   full/max/0/default.jpg        the full image
#   full/<w>,<h>/0/default.jpg    a few fixed sizes (the `sizes` argument)
#   <region>/<w>,<h>/0/default.jpg  tiles, only for images whose long side
#                                   exceeds `tile_threshold` (0 = never tile)
#   _level0.json                  what was made; Jekyll reads it to write info.json
#
# <name> is the lowercased file name without extension, as in generate_derivatives.
# Requires libvips (https://www.libvips.org/install.html), e.g. `brew install vips`.
#
# Usage:  rake generate_iiif
#         rake generate_iiif[objects,"256,1024",4000,512,false]

require 'fileutils'
require 'json'
require 'open3'
require 'pathname'
require 'tmpdir'

def iiif_vips(*cmd)
  out, status = Open3.capture2e(*cmd)
  raise "#{cmd.join(' ')} failed:\n#{out}" unless status.success?

  out
end

# relative symlink from dest to target, or a copy where symlinks are unavailable (Windows)
def iiif_link(target, dest)
  rel = Pathname.new(File.expand_path(target)).relative_path_from(Pathname.new(File.expand_path(File.dirname(dest))))
  File.symlink(rel.to_s, dest)
rescue NotImplementedError, SystemCallError
  FileUtils.cp(target, dest)
end

desc 'Generate static IIIF Image API level 0 files from collection objects'
task :generate_iiif, [:input_dir, :sizes, :tile_threshold, :tile_size, :missing] do |_t, args|
  args.with_defaults(
    input_dir: 'objects',
    sizes: '256,1024',
    tile_threshold: '4000',
    tile_size: '512',
    missing: 'true'
  )
  begin
    iiif_vips('vips', '--version')
  rescue StandardError
    abort 'generate_iiif needs libvips (the `vips` command). Install it first, e.g. `brew install vips`.'
  end

  widths = args.sizes.split(',').map(&:to_i).reject(&:zero?).sort
  threshold = args.tile_threshold.to_i
  tile_size = args.tile_size.to_i
  out_root = File.join(args.input_dir, 'iiif', '3') # Image API 3

  images = Dir.glob(File.join(args.input_dir, '*')).select { |f| File.file?(f) && f =~ /\.(jpe?g|png|tiff?)$/i }
  puts "generate_iiif: #{images.size} images in #{args.input_dir}"

  images.sort.each do |src|
    name = File.basename(src, '.*').downcase
    dest = File.join(out_root, name)
    meta_file = File.join(dest, '_level0.json')
    if args.missing == 'true' && File.exist?(meta_file) && File.mtime(meta_file) >= File.mtime(src)
      puts "Skipping: #{dest} is up to date"
      next
    end
    puts "Creating: #{dest}"
    FileUtils.rm_rf(dest)

    width = iiif_vips('vipsheader', '-f', 'width', src).to_i
    height = iiif_vips('vipsheader', '-f', 'height', src).to_i

    # The full image is requested both as full/max and as full/<width>,<height>.
    # JPEGs are linked, not copied, so the repository does not hold them twice
    # (Jekyll writes the real file into _site); other formats are converted once.
    max_file = File.join(dest, 'full', 'max', '0', 'default.jpg')
    full_file = File.join(dest, 'full', "#{width},#{height}", '0', 'default.jpg')
    FileUtils.mkdir_p([File.dirname(max_file), File.dirname(full_file)])
    if src =~ /\.jpe?g$/i
      iiif_link(src, max_file)
    else
      iiif_vips('vips', 'copy', src, max_file + '[Q=90]')
    end
    iiif_link(max_file, full_file)

    # fixed sizes smaller than the original
    sizes = []
    widths.select { |w| w < width }.each do |w|
      h = (height * w / width.to_f).round
      dir = File.join(dest, 'full', "#{w},#{h}", '0')
      FileUtils.mkdir_p(dir)
      iiif_vips('vips', 'thumbnail', src, File.join(dir, 'default.jpg[Q=85,strip]'), w.to_s,
                '--height', h.to_s, '--size', 'force')
      sizes << { 'width' => w, 'height' => h }
    end
    sizes << { 'width' => width, 'height' => height }

    # tiles for large images only
    tiles = nil
    if threshold.positive? && [width, height].max > threshold
      Dir.mktmpdir do |tmp|
        iiif_vips('vips', 'dzsave', src, File.join(tmp, 'out'), '--layout', 'iiif3',
                  '--tile-size', tile_size.to_s, '--overlap', '0', '--suffix', '.jpg[Q=85,strip]')
        info = JSON.parse(File.read(File.join(tmp, 'out', 'info.json')))
        tiles = info['tiles']
        # keep the tile folders; info.json is written by Jekyll instead.
        # full/ holds the top tile level (the whole image at the smallest scale),
        # which viewers request as a tile, so merge it in beside our sizes.
        Dir.children(File.join(tmp, 'out')).each do |entry|
          next if entry == 'info.json'

          if entry == 'full'
            Dir.children(File.join(tmp, 'out', 'full')).each do |size|
              target = File.join(dest, 'full', size)
              FileUtils.mv(File.join(tmp, 'out', 'full', size), target) unless File.exist?(target)
            end
          else
            FileUtils.mv(File.join(tmp, 'out', entry), File.join(dest, entry))
          end
        end
      end
    end

    meta = { 'width' => width, 'height' => height, 'sizes' => sizes }
    meta['tiles'] = tiles if tiles
    File.write(meta_file, JSON.pretty_generate(meta) + "\n")
    count = Dir.glob(File.join(dest, '**', '*.jpg')).size
    puts "  #{width}x#{height}, #{sizes.size} sizes#{tiles ? ", tiled (#{count} files)" : ''}"
  end
end
