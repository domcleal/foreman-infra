class utility {

  class { 'utility::repos': }

  package { "vim":
    ensure => present,
    name => $osfamily ? {
      Redhat => "vim-enhanced",
      default => "vim"
    }
  }

  package { "htop":
    ensure => present
  }

  package { "iftop":
    ensure => present
  }

  package { "screen":
    ensure => present
  }

  package { "rsync":
    ensure => present
  }

  package { "ruby-shadow":
    ensure => installed,
    name => $osfamily ? {
      Debian => "libshadow-ruby1.8",
      default => "ruby-shadow"
    }
  }

  $puppet_version = $::osfamily ? {
    Debian => '2.7.21-2puppetlabs1',
    RedHat => '2.7.21',
  }
  package { ['puppet-common','puppet']:
    ensure => $puppet_version,
    require => Class['utility::repos'],
  }
}
