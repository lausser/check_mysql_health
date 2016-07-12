package Classes::Mysql::Component::ConnectionSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::instance::connectedthreads/) {
    $self->get_check_status_var('threads_connected', 'Threads_connected',
        10, 20, '%d client connection threads');
  } elsif ($self->mode =~ /server::instance::createdthreads/) {
    $self->get_check_status_var_sec('threads_created', 'Threads_created',
        10, 20, '%.2f threads created/sec');
  } elsif ($self->mode =~ /server::instance::runningthreads/) {
    $self->get_check_status_var('threads_running', 'Threads_running',
        10, 20, '%d running threads');
  } elsif ($self->mode =~ /server::instance::cachedthreads/) {
    $self->get_check_status_var('threads_cached', 'Threads_cached',
        10, 20, '%d cached threads');
  } elsif ($self->mode =~ /server::instance::abortedconnects/) {
    $self->get_check_status_var_sec('connects_aborted', 'Aborted_connects',
        1, 5, '%.2f aborted connections/sec');
  } elsif ($self->mode =~ /server::instance::abortedclients/) {
    $self->get_check_status_var_sec('connects_aborted', 'Aborted_clients',
        1, 5, '%.2f aborted clients/sec');
  } elsif ($self->mode =~ /server::instance::threadcachehitrate/) {
    $self->{threads_created} = $self->get_status_var('Threads_created');
    $self->{connections} = $self->get_status_var('Connections');
    $self->valdiff({ name => 'threads_created_connections' },
        qw(threads_created connections));
    if ($self->{delta_connections} > 0) {
      $self->{threadcache_hitrate} =
          100 - ($self->{delta_threads_created} * 100.0 /
          $self->{delta_connections});
    } else {
      $self->{threadcache_hitrate} = 100;
    }
    $self->set_thresholds(metric => 'threadcache_hitrate',
        warning => '90:', critical => '80:');
    $self->add_message($self->check_thresholds(
        metric => 'threadcache_hitrate',
        value => $self->{threadcache_hitrate}),
        sprintf "thread cache hitrate %.2f%%", $self->{threadcache_hitrate});
    $self->add_perfdata(
        label => 'thread_cache_hitrate',
        value => $self->{threadcache_hitrate},
        uom => '%',
    );
    $self->add_perfdata(
        label => 'connections_per_sec',
        value => $self->{connections_per_sec},
    );
  }
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
  $self->set_thresholds(metric => $var, warning => $warn, critical => $crit);
  $self->add_message($self->check_thresholds(
      metric => $var, value => $self->{$var.'_per_sec'}),
      sprintf $text, $self->{$var.'_per_sec'});
  $self->add_perfdata(
      label => $var.'_per_sec',
      value => $self->{$var.'_per_sec'},
  );
}

