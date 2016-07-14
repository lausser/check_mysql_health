package Classes::Mysql::Component::ConnectionSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
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
    $self->get_check_status_var_sec('clients_aborted', 'Aborted_clients',
        1, 5, '%.2f aborted (client died) connections/sec');
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

