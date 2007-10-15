require 'test/unit'
require File.join(File.dirname(__FILE__), '../lib/permalink_fu')

class MockModel
  include PermalinkFu
  attr_accessor :id
  attr_accessor :title
  attr_accessor :permalink
  
  def self.count(whatever, options = {})
    if options[:conditions][1] == 'foo' || options[:conditions][1] == 'bar' || 
      (options[:conditions][1] == 'bar-2' && options[:conditions][2] != 2)
      1
    else
      0
    end
  end
  
  def self.before_validation(method)
    @@validation = method
  end
  
  def validate
    send @@validation
    permalink
  end

  def new_record?
    @id.nil?
  end

  has_permalink :title
end

class MockModelExtra
  include PermalinkFu
  attr_accessor :id
  attr_accessor :title
  attr_accessor :extra
  attr_accessor :permalink

  def self.count(*args)
    0
  end

  def self.before_validation(method)
    @@validation = method
  end

  def validate
    send @@validation
    permalink
  end
  
  def new_record?
    !@id.nil?
  end

  has_permalink [:title, :extra]
end

class PermalinkFuTest < Test::Unit::TestCase
  @@samples = {
    'This IS a Tripped out title!!.!1  (well/ not really)' => 'this-is-a-tripped-out-title-1-well-not-really',
    '////// meph1sto r0x ! \\\\\\' => 'meph1sto-r0x',
    'āčēģīķļņū' => 'acegiklnu'
  }

  @@extra = { 'some-)()()-ExtRa!/// .data==?>    to \/\/test' => 'some-extra-data-to-test' }

  def test_should_escape_permalinks
    @@samples.each do |from, to|
      assert_equal to, PermalinkFu.escape(from)
    end
  end
  
  def test_should_escape_activerecord_model
    @m = MockModel.new
    @@samples.each do |from, to|
      @m.title = from; @m.permalink = nil
      assert_equal to, @m.validate
    end
  end

  def test_multiple_attribute_permalink
    @m = MockModelExtra.new
    @@samples.each do |from, to|
      @@extra.each do |from_extra, to_extra|
        @m.title = from; @m.extra = from_extra; @m.permalink = nil
        assert_equal "#{to}-#{to_extra}", @m.validate
      end
    end
  end
  
  def test_should_create_unique_permalink
    @m = MockModel.new
    @m.permalink = 'foo'
    @m.validate
    assert_equal 'foo-2', @m.permalink
    
    @m.permalink = 'bar'
    @m.validate
    assert_equal 'bar-3', @m.permalink
  end
  
  def test_should_not_check_itself_for_unique_permalink
    @m = MockModel.new
    @m.id = 2
    @m.permalink = 'bar-2'
    @m.validate
    assert_equal 'bar-2', @m.permalink
  end
end
