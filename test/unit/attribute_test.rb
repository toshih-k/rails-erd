# encoding: utf-8
require File.expand_path("../test_helper", File.dirname(__FILE__))

class AttributeTest < ActiveSupport::TestCase
  def with_native_limit(type, new_limit)
    ActiveRecord::Base.connection.class_eval do
      define_method :native_database_types do
        super().tap do |types|
          types[type][:limit] = new_limit
        end
      end
    end
    yield
  ensure
    ActiveRecord::Base.connection.class_eval do
      define_method :native_database_types do
        super()
      end
    end
  end
  
  def create_attribute(model, name)
    Attribute.new(Domain.generate, model, model.arel_table[name].column)
  end
  
  # Attribute ================================================================
  test "column should return database column" do
    create_model "Foo", :my_column => :string
    assert_equal Foo.arel_table["my_column"].column,
      Attribute.from_model(Domain.new, Foo).reject(&:primary_key?).first.column
  end
  
  test "spaceship should sort attributes by name" do
    create_model "Foo", :a => :string, :b => :string, :c => :string
    a = create_attribute(Foo, "a")
    b = create_attribute(Foo, "b")
    c = create_attribute(Foo, "c")
    assert_equal [a, b, c], [c, a, b].sort
  end
  
  test "inspect should show column" do
    create_model "Foo", :my_column => :string
    assert_match %r{#<RailsERD::Attribute:.* @column="my_column" @type=:string>},
      Attribute.new(Domain.new, Foo, Foo.arel_table["my_column"].column).inspect
  end
  
  test "type should return attribute type" do
    create_model "Foo", :a => :binary
    assert_equal :binary, create_attribute(Foo, "a").type
  end
  
  # Attribute properties =====================================================
  test "mandatory should return false by default" do
    create_model "Foo", :column => :string
    assert_equal false, create_attribute(Foo, "column").mandatory?
  end

  test "mandatory should return true if attribute has a presence validator" do
    create_model "Foo", :column => :string do
      validates :column, :presence => true
    end
    assert_equal true, create_attribute(Foo, "column").mandatory?
  end

  test "mandatory should return true if attribute has a not null constraint" do
    create_model "Foo"
    add_column :foos, :column, :string, :null => false, :default => ""
    assert_equal true, create_attribute(Foo, "column").mandatory?
  end

  test "primary_key should return false by default" do
    create_model "Bar", :my_key => :integer
    assert_equal false, create_attribute(Bar, "my_key").primary_key?
  end

  test "primary_key should return true if column is used as primary key" do
    create_model "Bar", :my_key => :integer do
      set_primary_key :my_key
    end
    assert_equal true, create_attribute(Bar, "my_key").primary_key?
  end

  test "foreign_key should return false by default" do
    create_model "Foo", :bar => :references
    assert_equal false, create_attribute(Foo, "bar_id").foreign_key?
  end

  test "foreign_key should return true if it is used in an association" do
    create_model "Foo", :bar => :references do
      belongs_to :bar
    end
    create_model "Bar"
    assert_equal true, create_attribute(Foo, "bar_id").foreign_key?
  end

  test "foreign_key should return true if it is used in a remote association" do
    create_model "Foo", :bar => :references
    create_model "Bar" do
      has_many :foos
    end
    assert_equal true, create_attribute(Foo, "bar_id").foreign_key?
  end

  test "timestamp should return false by default" do
    create_model "Foo", :created => :datetime
    assert_equal false, create_attribute(Foo, "created").timestamp?
  end

  test "timestamp should return true if it is named created_at/on or updated_at/on" do
    create_model "Foo", :created_at => :string, :updated_at => :string, :created_on => :string, :updated_on => :string
    assert_equal [true] * 4, [create_attribute(Foo, "created_at"), create_attribute(Foo, "updated_at"),
      create_attribute(Foo, "created_on"), create_attribute(Foo, "updated_on")].collect(&:timestamp?)
  end
  
  # Type descriptions ========================================================
  test "type_description should return short type description" do
    create_model "Foo", :a => :binary
    assert_equal "binary", create_attribute(Foo, "a").type_description
  end

  test "type_description should return short type description without limit if standard" do
    with_native_limit :string, 456 do
      create_model "Foo"
      add_column :foos, :my_str, :string, :limit => 255
      ActiveRecord::Base.connection.native_database_types[:string]
      assert_equal "string (255)", create_attribute(Foo, "my_str").type_description
    end
  end

  test "type_description should return short type description with limit if nonstandard" do
    with_native_limit :string, 456 do
      create_model "Foo"
      add_column :foos, :my_str, :string, :limit => 456
      assert_equal "string", create_attribute(Foo, "my_str").type_description
    end
  end
  
  test "type_description should append hair space and low asterisk if field is mandatory" do
    create_model "Foo", :a => :integer do
      validates_presence_of :a
    end
    assert_equal "integer ∗", create_attribute(Foo, "a").type_description
  end
  
  test "limit should return nil if there is no limit" do
    create_model "Foo"
    add_column :foos, :my_txt, :text
    assert_equal nil, create_attribute(Foo, "my_txt").limit
  end
  
  test "limit should return nil if equal to standard database limit" do
    with_native_limit :string, 456 do
      create_model "Foo"
      add_column :foos, :my_str, :string, :limit => 456
      assert_equal nil, create_attribute(Foo, "my_str").limit
    end
  end
  
  test "limit should return limit if nonstandard" do
    with_native_limit :string, 456 do
      create_model "Foo"
      add_column :foos, :my_str, :string, :limit => 255
      assert_equal 255, create_attribute(Foo, "my_str").limit
    end
  end
end
