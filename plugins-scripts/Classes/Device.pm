package Classes::Device;
our @ISA = qw(Monitoring::GLPlugin::DB);
use strict;


sub classify {
  my $self = shift;
  if ($self->opts->mode =~ /cluster/) {
    bless $self, "Classes::Cluster";
    $self->classify();
  } elsif ($self->opts->method eq "dbi") {
    bless $self, "Classes::Mysql::DBI";
    if (! $self->opts->hostname ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname, username and password');
    }
    if (! eval "require DBD::mysql") {
      $self->add_critical('could not load perl module DBD::mysql');
    }
  } elsif ($self->opts->method eq "mysql") {
    bless $self, "Classes::Mysql::Mysql";
    if (! $self->opts->hostname ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname, username and password');
    }
  } elsif ($self->opts->method eq "sqlrelay") {
    bless $self, "Classes::Mysql::Sqlrelay";
    if ((! $self->opts->hostname && ! $self->opts->server) ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname or server, username and password');
    }
    if (! eval "require DBD::SQLRelay") {
      $self->add_critical('could not load perl module SQLRelay');
    }
  }
  if (! $self->check_messages()) {
    $self->check_connect();
    if (! $self->check_messages()) {
      $self->add_dbi_funcs();
      $self->check_version();
      my $class = ref($self);
      $class =~ s/::Mysql::/::Mariadb::/ if $self->get_variable("product") eq "Mariadb";
      bless $self, $class;
      $self->add_dbi_funcs();
      if ($self->opts->mode =~ /^my-/) {
        $self->load_my_extension();
      }
    }
  }
}

