package Classes::Mysql::Component::InstanceSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /^server::instance::openfiles/) {
    $self->{open_files_limit} = $self->get_system_var('open_files_limit');
    $self->{open_files} = $self->get_status_var('Open_files');
    $self->{pct_open_files} = 100 * $self->{open_files} / $self->{open_files_limit};
    $self->set_thresholds(netric => 'pct_open_files',
        warning => 80, critical => 95);
    $self->add_info(
        sprintf "%.2f%% of the open files limit reached (%d of max. %d)",
        $self->{pct_open_files},
        $self->{open_files}, $self->{open_files_limit});

    $self->add_message($self->check_thresholds($self->{pct_open_files}));
    $self->add_perfdata(
        label => "pct_open_files",
        value => $self->{pct_open_files},
        uom => '%',
    );
    $self->add_perfdata(
      label => 'open_files',
      value => $self->{open_files},
      warning => ($self->get_thresholds())[0] * $self->{open_files_limit} / 100,
      critical => ($self->get_thresholds())[1] * $self->{open_files_limit} / 100,
      min => 0, max => $self->{open_files_limit},
    );
  } elsif ($self->mode =~ /server::instance::slowqueries/) {
    $self->get_check_status_var_rate('slow_queries',
        'Slow_queries', 1, 10,
        '%d slow queries in %d seconds (%.2f/sec)'
    );
  } elsif ($self->mode =~ /server::instance::longprocs/) {
    if ($self->version_is_minimum("5.1")) {
      $self->{long_running_procs} = $self->fetchrow_array(q(
          SELECT
              COUNT(*)
          FROM
              information_schema.processlist
          WHERE id <> CONNECTION_ID()
          AND time > 60
          AND command <> 'Sleep'
      ));
    } else {
      $self->{long_running_procs} = 0;
      my @processes = $self->fetchall_array(q{
          SHOW FULL PROCESSLIST
      });
      map {
        $self->{longrunners}++;
      } grep {
        # $id, $user, $host, $db, $command, $tme, $state, $info
        $_->[4] ne 'Sleep' && $_->[5] > 60;
      } @processes;
    }
    $self->set_thresholds(metric => 'long_running_procs',
        warning => 10, critical => 20);
    $self->add_info(sprintf "%d long running processes",
        $self->{long_running_procs});
    $self->add_message($self->check_thresholds(
        metric => 'long_running_procs', value => $self->{long_running_procs}));
    $self->add_perfdata(
        label => 'long_running_procs',
        value => $self->{long_running_procs},
    );
  }
}

