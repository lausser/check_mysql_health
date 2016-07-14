package Classes::Mysql;
our @ISA = qw(Classes::Device);

use strict;
use Time::HiRes;
use IO::File;
use File::Copy 'cp';
use Data::Dumper;
our $AUTOLOAD;

sub init {
  my $self = shift;
  if ($self->mode =~ /^server::uptime/) {
    $self->add_info(sprintf "database is up since %d minutes", 
        $self->get_variable('uptime'));
    $self->set_thresholds(warning => '10:', critical => '5:');
    $self->add_message($self->check_thresholds($self->get_variable('uptime')));
    $self->add_perfdata(
      label => 'uptime',
      value => $self->get_variable('uptime'),
    );
  } elsif ($self->mode =~ /^server::instance::(thread|(.*threads$)|(.*connects$)|(.*clients$))/) {
    $self->analyze_and_check_connection_subsystem("Classes::Mysql::Component::ConnectionSubsystem");
    $self->reduce_messages_short();
  } elsif ($self->mode =~ /^server::instance::querycache/) {
    $self->analyze_and_check_qcache_subsystem("Classes::Mysql::Component::QueryCacheSubsystem");
    $self->reduce_messages_short();
  } elsif ($self->mode =~ /^server::instance::innodb/) {
    $self->analyze_and_check_innodb_subsystem("Classes::Mysql::Component::InnoDBSubsystem");
    $self->reduce_messages_short();
  } elsif ($self->mode =~ /^server::instance::replication/) {
    $self->analyze_and_check_replication_subsystem("Classes::Mysql::Component::ReplicationSubsystem");
    $self->reduce_messages_short();
  } else {
    $self->no_such_mode();
  }
}

sub check_version {
  my $self = shift;
  my $version = $self->get_system_var("version");
  $self->set_variable("product", ($version =~ /mariadb/i ? 'mariadb' : 'mysql'));
  $version =~ s/([\d\.]+)/$1/g;
  my $uptime = $self->get_status_var("uptime");
  my $os = $self->get_status_var("version_compile_os");
  $self->set_variable("version", $version);
  $self->set_variable("uptime", int($uptime / 60));
  $self->set_variable("os", $os);
}

sub create_statefile {
  my $self = shift;
  my %params = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  if ($self->opts->can('hostname') && $self->opts->hostname) {
    $extension .= '_'.$self->opts->hostname;
    $extension .= '_'.$self->opts->port;
  }
  if ($self->opts->can('socket') && $self->opts->socket) {
    $extension .= '_'.$self->opts->socket;
  }
  if ($self->opts->can('mycnf') && $self->opts->mycnf) {
    $extension .= '_'.$self->opts->mycnf;
  }
  if ($self->opts->can('mycnfgroup') && $self->opts->mycnfgroup) {
    $extension .= '_'.$self->opts->mycnfgroup;
  }
  if ($self->opts->mode eq 'sql' && $self->opts->username) {
    $extension .= '_'.$self->opts->username;
  }
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  return sprintf "%s/%s%s", $self->statefilesdir(),
      $self->opts->mode, lc $extension;
}

sub get_system_var {
  my ($self, $var) = @_;
  my ($dummy, $value) = $self->fetchrow_array(
      sprintf("SHOW VARIABLES LIKE '%s'", $var)
  );
  return $value;
}

sub get_status_var {
  my ($self, $var) = @_;
  my ($dummy, $value) = $self->fetchrow_array(
      sprintf("SHOW /*!50000 global */ STATUS LIKE '%s'", $var)
  );
  return $value;
}

sub get_check_status_var {
  my ($self, $var, $varname, $warn, $crit, $text) = @_;
  $self->{$var} = $self->get_status_var($varname);
  $self->set_thresholds(metric => $var, warning => $warn, critical => $crit);
  $self->add_message($self->check_thresholds(
      metric => $var, value => $self->{$var}),
      sprintf $text, $self->{$var});
  $self->add_perfdata(
      label => $var,
      value => $self->{$var},
  );
}

sub get_check_status_var_sec {
  my ($self, $var, $varname, $warn, $crit, $text) = @_;
  $self->{$var} = $self->get_status_var($varname);
  $self->valdiff({ name => $var }, ($var));
  $self->set_thresholds(metric => $var.'_per_sec', warning => $warn, critical => $crit);
  $self->add_message($self->check_thresholds(
      metric => $var.'_per_sec', value => $self->{$var.'_per_sec'}),
      sprintf $text, $self->{$var.'_per_sec'});
  $self->add_perfdata(
      label => $var.'_per_sec',
      value => $self->{$var.'_per_sec'},
  );
}

sub add_dbi_funcs {
  my $self = shift;
  $self->SUPER::add_dbi_funcs() if $self->SUPER::can('add_dbi_funcs');
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::CSF::create_statefile'} = \&{"Classes::Mysql::create_statefile"};
    *{'Monitoring::GLPlugin::DB::get_status_var'} = \&{"Classes::Mysql::get_status_var"};
    *{'Monitoring::GLPlugin::DB::get_check_status_var'} = \&{"Classes::Mysql::get_check_status_var"};
    *{'Monitoring::GLPlugin::DB::get_check_status_var_sec'} = \&{"Classes::Mysql::get_check_status_var_sec"};
  }
}

sub compatibility_class {
  my $self = shift;
  # old extension packages inherit from DBD::Mysql::Server
  # let DBD::Mysql::Server inherit myself, so we can reach compatibility_methods
  {
    no strict 'refs';
    *{'DBD::Mysql::Server::new'} = sub {};
    push(@DBD::Mysql::Server::ISA, ref($self));
  }
}

sub compatibility_methods {
  my $self = shift;
  if ($self->isa("DBD::Mysql::Server")) {
    # a old-style extension was loaded
    $self->SUPER::compatibility_methods() if $self->SUPER::can('compatibility_methods');
  }
}


