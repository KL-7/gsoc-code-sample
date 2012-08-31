# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

ActiveRecord::Migration.create_table :users do |t|
  t.string :first_name
  t.string :middle_name
  t.string :last_name
  t.string :middle_name_nfc
  t.string :last_name_nfc
  t.string :role
end

class User < ActiveRecord::Base
  include TwitterCldr::ActiveRecord::Normalize

  normalize_unicode :first_name
  normalize_unicode :middle_name, :last_name
  normalize_unicode :middle_name_nfc, :last_name_nfc, :using => :NFC
end

class Admin < User
  # rewrite normalization options for :first_name and add new normalization options for :role
  normalize_unicode :first_name, :role, :using => :NFC
end

describe TwitterCldr::ActiveRecord::Normalize do

  describe '.normalize_unicode' do
    it 'gathers all options if called multiple times' do
      User.unicode_normalization_options.should == {
          :first_name      => {},
          :middle_name     => {},
          :last_name       => {},
          :middle_name_nfc => { :using => :NFC },
          :last_name_nfc   => { :using => :NFC }
      }
    end

    it 'inherits and rewrites parent options' do
      Admin.unicode_normalization_options.should == {
          :first_name      => { :using => :NFC },
          :middle_name     => {},
          :last_name       => {},
          :middle_name_nfc => { :using => :NFC },
          :last_name_nfc   => { :using => :NFC },
          :role            => { :using => :NFC }
      }
    end
  end

  describe 'normalization' do
    let(:denormalized) { 'Español' }

    let(:normalized_nfd) { TwitterCldr::Normalization::NFD.normalize(denormalized) }
    let(:normalized_nfc) { TwitterCldr::Normalization::NFC.normalize(denormalized) }

    it 'normalizes to NFD by default' do
      validate_normalization(User,
          :first_name  => { :from => denormalized, :to => normalized_nfd },
          :middle_name => { :from => denormalized, :to => normalized_nfd },
          :last_name   => { :from => denormalized, :to => normalized_nfd }
      )
    end

    it "normalizes to the form specified by :using option if it's provided" do
      validate_normalization(User,
          :middle_name_nfc => { :from => normalized_nfd, :to => normalized_nfc },
          :last_name_nfc   => { :from => normalized_nfd, :to => normalized_nfc }
      )
    end

    it "doesn't fail when attribute is nil" do
      User.create!(:first_name => nil)
    end

    it 'inherits normalization options from base class' do
      validate_normalization(Admin,
          :first_name => { :from => normalized_nfd, :to => normalized_nfc },
          :role       => { :from => normalized_nfd, :to => normalized_nfc }
      )
    end

    def validate_normalization(model_class, normalization_map)
      model = model_class.new(
          normalization_map.inject({}) { |memo, (attr, normalization)| memo.merge!(attr => normalization[:from]) }
      )

      normalization_map.each do |attr, normalization|
        model[attr].should_not(eq(normalization[:to]), "#{model_class.name.downcase}.#{attr} is already normalized")
      end

      model.save!

      normalization_map.each do |attr, normalization|
        model[attr].should(eq(normalization[:to]), "failed to normalize #{model_class.name.downcase}.#{attr}")
      end
    end
  end

end