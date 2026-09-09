# frozen_string_literal: true

require 'factbase'
require 'loog'
require_relative 'lib/fbe/regularly'
require_relative 'lib/fbe/fb'

fb = Factbase.new
pmp = fb.txn { |fbt| f = fbt.insert; f.what = 'pmp'; f.area = 'quality'; f.p_every_days = 3; f }

$judge = 'test-judge'
$loog = Loog::NULL
$fb = fb

begin
  Fbe.regularly('quality', 'p_every_days', 'p_since_days', fb: fb, judge: $judge, loog: $loog) do |f|
    f.result = 'done'
  end
  puts 'No error raised — bug NOT reproduced'
rescue NoMethodError => e
  puts "REPRODUCED: #{e.class}: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end
