package Classes::Mysql::Component::InstanceSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /server::instance::slowqueries/) {
  } elsif ($self->mode =~ /^server::instance::openfiles/) {
    $self->{open_files_limit} = $self->get_system_var('open_files_limit');
    $self->{open_files} = $self->get_status_var('Open_files');
    $self->{pct_open_files} = 100 * $self->{open_files} / $self->{open_files_limit};
    $self->set_thresholds(netric => 'pct_open_files',
        warning => 80, critical => 95);
    $self->info(
        sprintf "%.2f%% of the open files limit reached (%d of max. %d)",
        $self->{pct_open_files},
        $self->{open_files}, $self->{open_files_limit});

    $self->add_message($self->check_thresholds($self->{pct_open_files}));
    $self->add_perfdata(
        label => "pct_open_files",
        value => $self->{pct_open_files},
    );
    $self->add_perfdata(
      label => 'open_files',
      value => $self->{open_files},
      warning => ($self->get_thresholds())[0] * $self->{open_files_limit} / 100,
      critical => ($self->get_thresholds())[1] * $self->{open_files_limit} / 100,
    );
  } elsif ($self->mode =~ /server::instance::slowqueries/) {

    $self->{key_reads} = $self->get_status_var('Key_reads');
    $self->{key_read_requests} = $self->get_status_var('Key_read_requests');
    $self->valdiff({ name => 'keycache_reads' },
        qw(key_reads key_read_requests));
    eval {
      $self->{keycache_hitrate} = 100 -
          100 * $self->{delta_key_reads} /
          $self->{delta_key_read_requests};
    };
    $self->{keycache_hitrate} = 0 if $@ =~ /division/;

    $self->set_thresholds(metric => 'keycache_hitrate',
        warning => '99:', critical => '95:');
    $self->add_message($self->check_thresholds(
        metric => 'keycache_hitrate',
        value => $self->{keycache_hitrate}),
        sprintf "myisam keycache hitrate at %.2f%%", $self->{keycache_hitrate});
    $self->add_perfdata(
        label => 'keycache_hitrate',
        value => $self->{keycache_hitrate},
        uom => '%',
    );
  }
}

