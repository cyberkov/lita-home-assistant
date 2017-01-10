# frozen_string_literal: true
require 'spec_helper'

describe Lita::Handlers::HomeAssistant, lita_handler: true do
  describe 'lita routes' do
    it { is_expected.to route_event(:loaded).to(:boot) }
    it { is_expected.to route_command('turn off lamp').to(:toggle) }
    it { is_expected.to route_command('state of lamp').to(:state) }
    it { is_expected.to route_command('set thermostat to 21').to(:set) }
    it { is_expected.to route_command('ha list').to(:list) }
    it { is_expected.to route_command('ha list sensor').to(:list) }
    it { is_expected.to route_command('ha info').to(:get_info) }
  end

  #  context 'listen to chat' do
  #    it { is_expected.to route_event(:unhandled_message).to(:chat) }
  #    it { is_expected.to route('turn off lamp') }
  #    it { is_expected.to route('state of lamp') }
  #    it { is_expected.to route('set lamp to on') }
  #  end

  #  context 'with auth' do
  #    it { is_expected.to route_command('turn off lamp').with_authorization_for(:admins) }
  #    it { is_expected.to route_command('state of lamp').with_authorization_for(:admins) }
  #    it { is_expected.to route_command('set lamp to on').with_authorization_for(:admins) }
  #  end

  it 'informs about the state' do
    send_command('state of lamp')
    expect(replies.last).to eq('Lamp is ON (since 2 minutes)')
  end

  it 'informs about the state with a unit' do
    send_command('state of sensor.livingroom_temperature')
    expect(replies.last).to eq("Livingroom Temperature is 19.1 \u00b0C (since 2 minutes)")
  end

  it 'does fuzzy matching on words' do
    send_command('state of bedroom lamp')
    expect(replies.last).to eq('Lamp is ON (since 2 minutes)')
  end

  it 'toggles the state of a device' do
    send_command('turn lamp on')
    expect(replies.last).to eq('Ok. Lamp has been turned on.')
  end
  it 'toggles the state of a device even if the command is in wrong order' do
    send_command('turn off lamp')
    expect(replies.last).to eq('Ok. Lamp has been turned off.')
  end

  it 'updates the state of a device' do
    send_command('set thermostat to 21')
    expect(replies.last).to eq('Ok. Thermostat has been set to 21 \u00b0C.')
  end
end
