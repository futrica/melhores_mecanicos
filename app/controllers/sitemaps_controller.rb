class SitemapsController < ApplicationController
  def index
    filepath = SitemapGenerator.index_path

    if File.exist?(filepath)
      render xml: File.read(filepath), content_type: "application/xml"
    else
      head :not_found
    end
  end

  def show
    filename = File.basename(params[:filename])
    filepath = SitemapGenerator.sitemap_dir.join(filename)

    if File.exist?(filepath)
      render xml: File.read(filepath), content_type: "application/xml"
    else
      head :not_found
    end
  end
end
