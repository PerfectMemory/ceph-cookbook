#
# Author:: Kyle Bader <kyle.bader@dreamhost.com>
# Cookbook Name:: ceph
# Recipe:: mds
#
# Copyright 2011, DreamHost Web Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe 'ceph'
include_recipe 'ceph::mds_install'

cluster = 'ceph'

if node['ceph']['version'] >= 'giant'
  # doesn't work on non-mon nodes, will need to be moved to lwrp
  node['ceph']['mds']['fs'].keys.each do |fs|
    metadata_pool = node['ceph']['mds']['fs'][fs]['metadata_pool']
    data_pool = node['ceph']['mds']['fs'][fs]['data_pool']

    [metadata_pool, data_pool].each do |pool_name|
      execute "ensure ceph pool #{pool_name} exists" do
        command "ceph osd pool create #{pool_name} 32"
        user node['ceph']['user']
        group node['ceph']['group']
        not_if "rados lspools | grep '^#{Regexp.quote(pool_name)}$'"
      end
    end

    execute "ensure cephfs #{fs} exists" do
      command "ceph fs new #{fs} #{metadata_pool} #{data_pool}"
      user node['ceph']['user']
      group node['ceph']['group']
      not_if "ceph fs ls | grep '^#{Regexp.quote(fs)}$'"
    end
  end
end

directory "/var/lib/ceph/mds/#{cluster}-#{node['hostname']}" do
  owner node['ceph']['user']
  group node['ceph']['group']
  mode 00755
  recursive true
  action :create
end

ceph_client 'mds' do
  caps('osd' => 'allow *', 'mon' => 'allow rwx')
  keyname "mds.#{node['hostname']}"
  filename "/var/lib/ceph/mds/#{cluster}-#{node['hostname']}/keyring"
  owner node['ceph']['user']
  group node['ceph']['group']
end

file "/var/lib/ceph/mds/#{cluster}-#{node['hostname']}/done" do
  owner 'root'
  group 'root'
  mode 00644
end

service_type = node['ceph']['osd']['init_style']

case service_type
when 'upstart'
  filename = 'upstart'
else
  filename = 'sysvinit'
end
file "/var/lib/ceph/mds/#{cluster}-#{node['hostname']}/#{filename}" do
  owner 'root'
  group 'root'
  mode 00644
end

service 'ceph_mds' do
  case service_type
  when 'upstart'
    service_name 'ceph-mds-all-starter'
    provider Chef::Provider::Service::Upstart
  else
    service_name 'ceph'
  end
  action [:enable, :start]
  supports :restart => true
end
