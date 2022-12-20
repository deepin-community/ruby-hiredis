# Compare throughput of pure-Ruby reply reader vs extension
#
# Run with
#
#   $ ruby -Ilib benchmark/reader.rb
#

require "benchmark"
require "hiredis/ruby/reader"

begin
  require "hiredis/ext/reader"
rescue LoadError
end

N = 100_000

def benchmark(b, title, klass, pipeline = 1)
  reader = klass.new

  data = "+OK\r\n"

  GC.start
  b.report("#{title}: Status reply") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end

  data = "$10\r\nxxxxxxxxxx\r\n"

  GC.start
  b.report("#{title}: Bulk reply (10 bytes)") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end

  data = "*10\r\n"
  10.times { data << "$10\r\nxxxxxxxxxx\r\n" }

  GC.start
  b.report("#{title}: Multi-bulk reply (10x 10 bytes)") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end

  data = "*1\r\n#{data}"

  GC.start
  b.report("#{title}: Nested multi-bulk reply (1x 10x 10 bytes)") do
    (N / pipeline).times do
      pipeline.times { reader.feed(data) }
      pipeline.times { reader.gets }
    end
  end
end

pipeline = (ARGV.shift || 1).to_i
puts "\n%d replies in pipelines of %d replies\n" % [N, pipeline]

Benchmark.bm(50) do |b|
  if defined?(Hiredis::Ext::Reader)
    benchmark(b, "Ext", Hiredis::Ext::Reader, pipeline)
    puts
  end

  if defined?(Hiredis::Ruby::Reader)
    benchmark(b, "Ruby", Hiredis::Ruby::Reader, pipeline)
    puts
  end
end
