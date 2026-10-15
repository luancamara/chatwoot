require 'rails_helper'

RSpec.describe SalesRouting::Classifier do
  describe '.origin_store' do
    it 'reads the pinned origin, including an explicit "no store" origin' do
      expect(described_class.origin_store('store' => 'tat', 'origin_store' => 'psd', 'rule' => 'manual-team')).to eq('psd')
      expect(described_class.origin_store('store' => 'tat', 'origin_store' => nil, 'rule' => 'manual-team')).to be_nil
    end

    it 'trusts the routed store of older routes only while they were never re-routed by hand' do
      expect(described_class.origin_store('store' => 'psd', 'rule' => 'codigo')).to eq('psd')
      expect(described_class.origin_store('store' => 'tat', 'rule' => 'manual-team')).to be_nil
      expect(described_class.origin_store(nil)).to be_nil
    end
  end

  describe '.with_origin_store' do
    it 'pins a provable origin before a manual re-route and never invents an unknown one' do
      expect(described_class.with_origin_store('store' => 'psd', 'rule' => 'codigo')).to include('origin_store' => 'psd')
      expect(described_class.with_origin_store('store' => 'tat', 'rule' => 'manual-team')).not_to have_key('origin_store')
      expect(described_class.with_origin_store('store' => 'tat', 'origin_store' => nil, 'rule' => 'codigo')).to include('origin_store' => nil)
    end
  end
end
