package Classes::Mysql::Component::MyIsamSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /server::instance::myisam::keycache::hitrate/) {

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

