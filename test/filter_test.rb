require File.dirname(__FILE__) + '/test_helper'

context "Add filters" do
  setup do
    Exceptionist.filter.clear
  end

  test 'should be able to add filter' do
    Exceptionist.filter.add(:nonbot) { |occurrence| occurrence.nil? }

    assert_equal 1, Exceptionist.filter.all.size
    assert_equal [:nonbot], Exceptionist.filter.all.map(&:first)

    Exceptionist.filter.add(:human) { |occurrence| !occurrence.nil? }

    assert_equal 2, Exceptionist.filter.all.size
    assert_equal [:nonbot, :human], Exceptionist.filter.all.map(&:first)
  end

  test 'should be able to apply a filter' do
    Exceptionist.filter.add :nonbot do |occurrence|
      occurrence.nil?
    end

    filter = Exceptionist.filter.all.first
    assert filter.last.is_a?(Proc)
    assert_equal true,  filter.last.call(nil)
    assert_equal false, filter.last.call(42)
  end
end
