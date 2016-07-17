package Classes::Mysql::Component::InnoDBSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  if ($self->version_is_minimum("5.6")) {
    ($self->{has_innodb}) = $self->fetchrow_array(q{
        SELECT
          ENGINE, SUPPORT
        FROM
          INFORMATION_SCHEMA.ENGINES
        WHERE
          ENGINE='InnoDB'
    });
  } else {
    $self->{has_innodb} = $self->get_system_var('have_innodb');
  }
  if ($self->{has_innodb} eq "NO") {
    $self->add_critical("the innodb engine has a problem (have_innodb=no)");
    return;
  } elsif ($self->{has_innodb} eq "DISABLED") {
    $self->add_critical("the innodb engine has been disabled");
    return;
  }
  if ($self->mode =~ /server::instance::innodb::bufferpool::hitrate/) {
    $self->{bufferpool_reads} = $self->get_status_var('Innodb_buffer_pool_reads');
    $self->{bufferpool_read_requests} = $self->get_status_var('Innodb_buffer_pool_read_requests');
    $self->valdiff({ name => 'bufferpool_reads' },
        qw(bufferpool_reads bufferpool_read_requests));
    eval {
      $self->{bufferpool_hitrate} = 100 -
          100 * $self->{bufferpool_reads} /
          $self->{bufferpool_read_requests};
    };
    $self->{bufferpool_hitrate} = 0 if $@ =~ /division/;

    $self->set_thresholds(metric => 'bufferpool_hitrate',
        warning => '99:', critical => '95:');
    $self->add_message($self->check_thresholds(
        metric => 'bufferpool_hitrate',
        value => $self->{bufferpool_hitrate}),
        sprintf "innodb buffer pool hitrate at %.2f%%", $self->{bufferpool_hitrate});
    $self->add_perfdata(
        label => 'bufferpool_hitrate',
        value => $self->{bufferpool_hitrate},
        uom => '%',
    );
  } elsif ($self->mode =~ /server::instance::innodb::bufferpool::waitfree/) {
    $self->get_check_status_var_rate('bufferpool_free_waits',
        'Innodb_buffer_pool_wait_free', 1, 10,
        '%ld innodb buffer pool waits in %ld seconds (%.2f/sec)'
    );
  } elsif ($self->mode =~ /server::instance::innodb::logwaits/) {
    $self->get_check_status_var_rate('innodb_log_waits',
        'Innodb_log_waits', 1, 10,
        '%ld innodb log waits in %ld seconds (%.2f/sec)'
    );
  } elsif ($self->mode =~ /server::instance::innodb::needoptimize/) {
  }
}

