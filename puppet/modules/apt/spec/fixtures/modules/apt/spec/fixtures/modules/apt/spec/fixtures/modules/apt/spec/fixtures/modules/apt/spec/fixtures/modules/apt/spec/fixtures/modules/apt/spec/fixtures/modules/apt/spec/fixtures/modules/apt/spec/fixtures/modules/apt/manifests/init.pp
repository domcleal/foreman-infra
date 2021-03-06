# Class: apt
#
# This module manages the initial configuration of apt.
#
# Parameters:
#   The parameters listed here are not required in general and were
#     added for use cases related to development environments.
#   disable_keys - disables the requirement for all packages to be signed
#   always_apt_update - rather apt should be updated on every run (intended
#     for development environments where package updates are frequent
#   purge_sources_list - Accepts true or false. Defaults to false If set to
#     true, Puppet will purge all unmanaged entries from sources.list"
#   purge_sources_list_d - Accepts true or false. Defaults to false. If set
#     to false, Puppet will purge all unmanaged entries from sources.list.d
#
# Actions:
#
# Requires:
#
# Sample Usage:
#  class { 'apt': }
class apt(
  $always_apt_update = false,
  $disable_keys = undef,
  $proxy_host = false,
  $proxy_port = '8080',
  $purge_sources_list = false,
  $purge_sources_list_d = false
) {

  include apt::params
  include apt::update

  validate_bool($purge_sources_list, $purge_sources_list_d)

  $sources_list_content = $purge_sources_list ? {
    false => undef,
    true  => "# Repos managed by puppet.\n",
  }

  if $always_apt_update == true {
    Exec <| title=='apt_update' |> {
      refreshonly => false,
    }
  }

  $root           = $apt::params::root
  $apt_conf_d     = $apt::params::apt_conf_d
  $sources_list_d = $apt::params::sources_list_d
  $provider       = $apt::params::provider

  file { 'sources.list':
    ensure  => present,
    path    => "${root}/sources.list",
    owner   => root,
    group   => root,
    mode    => '0644',
    content => $sources_list_content,
    notify  => Exec['apt_update'],
  }

  file { 'sources.list.d':
    ensure  => directory,
    path    => $sources_list_d,
    owner   => root,
    group   => root,
    purge   => $purge_sources_list_d,
    recurse => $purge_sources_list_d,
    notify  => Exec['apt_update'],
  }

  case $disable_keys {
    true: {
      file { '99unauth':
        ensure  => present,
        content => "APT::Get::AllowUnauthenticated 1;\n",
        path    => "${apt_conf_d}/99unauth",
      }
    }
    false: {
      file { '99unauth':
        ensure => absent,
        path   => "${apt_conf_d}/99unauth",
      }
    }
    undef:   { } # do nothing
    default: { fail('Valid values for disable_keys are true or false') }
  }

  if ($proxy_host) {
    file { 'configure-apt-proxy':
      path    => "${apt_conf_d}/proxy",
      content => "Acquire::http::Proxy \"http://${proxy_host}:${proxy_port}\";",
      notify  => Exec['apt_update'],
    }
  }
}
