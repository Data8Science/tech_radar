module TechRadar
  class Radar
    attr_reader :data
    def initialize
      @data = YAML.load_file(Rails.root + "config" + "tech-radar.yml")
    end

    def quadrants
      @data.keys.map { |quadrant_name|
        quadrant(quadrant_name)
      }
    end

    def quadrant(quadrant_name)
      quadrant = @data.fetch(quadrant_name)
      by_ring = {}
      quadrant.each do |(ring,technologies)|
        by_ring[ring] ||= []
        (technologies || {}).each do |(name,data)|
          experts = Array(data["experts"]).map { |name_or_hash|
            if name_or_hash.kind_of?(String)
              Expert.new(name: name_or_hash)
            else
              Expert.new(name: name_or_hash.fetch("name"), email: name_or_hash["email"])
            end
          }.sort_by(&:name)

          examples = Array(data["examples"]).map { |url_or_hash|
            if url_or_hash.kind_of?(String)
              Example.new(url: url_or_hash)
            else
              Example.new(url: url_or_hash.fetch("url"), title: url_or_hash["title"])
            end
          }.sort_by { |example| example.title.to_s }

          by_ring[ring] << Technology.new(name: name,
                                          ring: ring,
                                          quadrant: quadrant_name,
                                          purpose: data["purpose"],
                                          more_details_url: data["more_details_url"],
                                          more_details_summary: data["more_details_summary"],
                                          why_url: data["why_url"],
                                          tags: Array(data["tags"]).sort,
                                          experts: experts,
                                          examples: examples,
                                          why_summary: data["why_summary"])
        end
      end
      TechRadar::Quadrant.new(
        name: quadrant_name, 
        rings: by_ring.map { |ring_name,technologies| 
          TechRadar::Ring.new(name: ring_name, technologies: technologies.sort_by { |tech| tech.name.downcase }) 
        }
      )
    end

    def rings
      quadrants.map(&:rings).flatten.group_by(&:name).map { |(ring_name,rings)|
        TechRadar::Ring.new(name: ring_name,technologies: rings.map(&:technologies).flatten.sort_by { |tech| tech.name.downcase })
      }
    end

    def ring(ring_name)
      rings.detect { |ring| ring.name == ring_name }
    end

    def technologies(options = {})
      results = quadrants.
        map(&:rings).
        flatten.
        map(&:technologies).
        flatten

      if options[:tagged]
        results = results.select { |technology|
          technology.tags.include?(options[:tagged])
        }
      end
      results.sort_by { |technology| technology.name.downcase }
    end

    def technology(name)
      technologies.detect { |technology| technology.name == name }
    end

  end
end
