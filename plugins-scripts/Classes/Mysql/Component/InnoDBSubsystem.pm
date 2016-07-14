package Classes::Mysql::Component::InnoDBSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  
  my $has_innodb = $self->get_system_var('have_innodb');
  if ($has_innodb eq "NO") {
    $self->add_critical("the innodb engine has a problem (have_innodb=no)");
    return;
  } elsif ($has_innodb eq "DISABLED") {
    $self->add_critical("the innodb engine has been disabled");
    return;
  }
  if ($self->mode =~ /server::instance::innodb::bufferpool::hitrate/) {
    $self->{bufferpool_reads} = $self->get_status_var('Innodb_buffer_pool_reads');
    $self->{bufferpool_read_requests} = $self->get_status_var('Innodb_buffer_pool_read_requests');
    $self->valdiff({ name => 'bufferpool_reads' },
        qw(bufferpool_reads bufferpool_read_requests connections));
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
  } elsif ($self->mode =~ /server::instance::threadcachehitrate/) {
  }
}

