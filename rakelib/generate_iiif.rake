###############################################################################
# TASK: generate_iiif
#
# create static IIIF Image API level 0 files (fixed sizes, tiles for large
# images) for images in the 'objects' folder, into objects/iiif/3/<name>/,
# and the same files for Image API 2 in objects/iiif/2/<name>/ (links into the
# version 3 folder, used by the Presentation 2 manifests at /iiif/2/).
# Provided by the static_iiif gem (https://github.com/nakamura196/static_iiif);
# needs the libvips command-line tools (e.g. `brew install vips`).
#
# Usage:  rake generate_iiif
#         rake "generate_iiif[objects,objects/iiif/3,256;1024,4000,512,false,objects/iiif/2]"
#         (input_dir, output_dir, sizes, tile_threshold (0 = never), tile_size, force, v2_output_dir)
###############################################################################

require 'static_iiif/rake_task'

StaticIIIF::RakeTask.new(:generate_iiif) do |t|
  t.v2_output_dir = 'objects/iiif/2'
end
