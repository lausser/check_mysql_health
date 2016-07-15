package Classes::Mysql::Component::QueryCacheSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::instance::querycachehitrate/) {
    $self->{have_query_cache} = $self->get_system_var('have_query_cache');
    $self->{qcache_inserts} = $self->get_status_var('Qcache_inserts');
    $self->{qcache_not_cached} = $self->get_status_var('Qcache_not_cached');
    $self->{com_select} = $self->get_status_var('Com_select');
    $self->{qcache_hits} = $self->get_status_var('Qcache_hits');
    $self->{query_cache_size} = $self->get_system_var('query_cache_size');
    $self->valdiff({ name => 'querycachehitrate' },
        qw(qcache_inserts qcache_not_cached com_select qcache_hits));

    # MySQL Enterprise Monitor
    eval {
      $self->{querycache_hitrate_mem} = 
          100 * $self->{delta_qcache_hits} /
          ($self->{delta_qcache_hits} + $self->{delta_qcache_inserts});
    }; 
    $self->{querycache_hitrate_mem} = 0 if $@ =~ /division/;
    # Workbench
    # das war das ehem. querycache_hitrate (ohne delta_)
    eval {
      $self->{querycache_hitrate_wb} = 
          100 * $self->{delta_qcache_hits} /
          ($self->{delta_qcache_hits} + $self->{delta_qcache_inserts} + $self->{delta_qcache_not_cached});
    };
    $self->{querycache_hitrate_wb} = 0 if $@ =~ /division/;
    # High Performance MySQL v3 page 321
    # mit delta_ war das das ehem. querycache_hitrate_now
    eval {
      $self->{querycache_hitrate_hpm} = 
          100 * $self->{delta_qcache_hits} /
          ($self->{delta_qcache_hits} + $self->{delta_com_select});
    };
    $self->{querycache_hitrate_hpm} = 0 if $@ =~ /division/;
    $self->{querycache_hitrate} = $self->{querycache_hitrate_wb};
    $self->set_thresholds(metric => 'qcache_hitrate',
        warning => '90:', critical => '80:');
    if (lc $self->{have_query_cache} eq 'yes' && $self->{query_cache_size}) {
      $self->add_message($self->check_thresholds(
          metric => 'qcache_hitrate',
          value => $self->{querycache_hitrate}),
          sprintf "query cache hitrate %.2f%%", $self->{querycache_hitrate});
    } else {
      $self->add_ok(sprintf "query cache hitrate %.2f%% (because it's turned off)",
          $self->{querycache_hitrate});
    }
    $self->add_perfdata(
        label => 'qcache_hitrate',
        value => $self->{querycache_hitrate},
        uom => '%',
    );
    $self->add_perfdata(
        label => 'selects_per_sec',
        value => $self->{com_select_per_sec},
    );
  } elsif ($self->mode =~ /server::instance::querycachelowmemprunes/) {
    $self->get_check_status_var_rate('qcache_lowmem_prunes',
        'Qcache_lowmem_prunes', 1, 10,
        '%d query cache lowmem prunes in %d seconds (%.2f/sec)'
    );
  }
}


