#!/usr/bin/ruby

require 'mcollective'

include MCollective::RPC

mc = rpcclient("inventory")
