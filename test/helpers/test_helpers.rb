#encoding: utf-8

class Nanoc::HelpersTest < Nanoc::TestCase 

  include Nanoc::Helpers 

  def test_awaits_valid
    await_klass = Array
    obj         = await_klass.new 

    awaits(await_klass, obj)
  end

  def test_awaits_invalid
    await_klass = Array
    obj         = Hash.new
    opts        = { :raise => true }

    raise_class = Nanoc::Errors::GenericTrivial

    fail_msg    = "Expected #{raise_class.name} wasn't raised"

    assert_raises raise_class, fail_msg do
      awaits(await_klass, obj, opts)
    end
  end

  def test_awaits_invalid_with_opts
    await_klass = Array
    obj         = Hash.new
    opts        = { :method => __method__, :format => Integer, :raise => true }
    
    raise_class = Nanoc::Errors::GenericTrivial

    fail_msg    = "Expected #{raise_class.name} wasn't raised"

    assert_raises raise_class, fail_msg do
      awaits(await_klass, obj, opts)
    end
  end

  def test_awaits_invalid_without_raise 
    await_klass = Array
    obj         = Hash.new
    opts        = { :raise => false }
    expects     = "Waiting for Array was Hash"

    fail_msg    = "Returning of fail-string did not work"

    awaits(await_klass, obj, opts)

    assert_equal(expects, awaits(await_klass, obj, opts), fail_msg)
  end

end
