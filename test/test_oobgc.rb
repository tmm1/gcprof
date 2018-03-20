require 'minitest/autorun'
require 'gctools/oobgc'
require 'json'

class TestOOBGC < Minitest::Test
  HEAP_SWEPT_SLOTS_KEY = RUBY_VERSION >= "2.2" ? :heap_swept_slots : :heap_swept_slot

  def setup
    GC::OOB.setup
    GC::OOB.clear
  end

  def test_oob_sweep
    GC.start(immediate_sweep: false)
    assert_equal false, GC.latest_gc_info(:immediate_sweep)

    # GC.latest_gc_info(:state) added in version 2.2.
    if RUBY_VERSION < '2.2'
      # GC.stat(:heap_swept_slots) removed in version 2.4.
      before = GC.stat(HEAP_SWEPT_SLOTS_KEY)
      assert_equal true, GC::OOB.run
      assert_operator GC.stat(HEAP_SWEPT_SLOTS_KEY), :>, before
    else
      assert_equal :sweeping, GC.latest_gc_info(:state)
      assert_equal true, GC::OOB.run
      assert_equal :none, GC.latest_gc_info(:state)
    end
  end

  def test_oob_mark
    oob = 0
    before = GC.count
    minor, major = GC.stat(:minor_gc_count), GC.stat(:major_gc_count)

    20.times do
      (10_000 + rand(25_000)).times{ Object.new }
      oob += 1 if GC::OOB.run
    end

    assert_equal 0, GC.count - before - oob
    assert_equal 0, GC.stat(:minor_gc_count) - minor - oob
    assert_equal major, GC.stat(:major_gc_count)
  end

  def test_oob_major_mark
    oob = 0
    before = GC.count
    minor, major = GC.stat(:minor_gc_count), GC.stat(:major_gc_count)
    list = []

    20.times do
      2_000.times do
        list << JSON.parse('{"hello":"world", "foo":["bar","bar"], "zap":{"zap":"zap"}}')
        list.shift if list.size > 2_000
      end
      oob += 1 if GC::OOB.run
    end

    assert_equal oob, GC::OOB.stat(:count)
    assert_equal 1, GC.count - before -
      GC::OOB.stat(:major_count) - GC::OOB.stat(:minor_count) - GC::OOB.stat(:sweep_count)
  end
end
