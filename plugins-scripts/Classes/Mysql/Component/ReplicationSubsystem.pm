package Classes::Mysql::Component::ReplicationSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  $self->{channels} = [];
  my $channels = $self->fetchrow_hashref(q{
    SHOW SLAVE STATUS
  });
  if (! exists $channels->{Channel_Name}) {
    $channels = {
      'default' => $channels,
    };
    $channels->{default}->{Channel_Name} = 'default';
  } else {
    $channels = $self->fetchall_hashref(q{
      SHOW SLAVE STATUS
    }, 'Channel_Name');
  }
  foreach my $channel (keys %{$channels}) {
    next if ! $self->filter_name($channel);
    push(@{$self->{channels}},
      Classes::Mysql::Component::ReplicationSubsystem::Channel->new(
        %{$channels->{$channel}}
      )
    );
  }
}

sub check {
  my $self = shift;
  if (scalar(@{$self->{channels}}) == 0) {
    $self->add_unknown('unable to get replication status');
  } else {
    $self->SUPER::check();
  }
}

package Classes::Mysql::Component::ReplicationSubsystem::Channel;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{name} = $self->{Channel_Name};
  if ($self->{Channel_Name} eq 'default') {
    bless $self, 'Classes::Mysql::Component::ReplicationSubsystem::DefChannel';
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /server::instance::replication::slavelag/) {
    $self->add_info(sprintf "Slave channel %s is %d seconds behind master",
        $self->{name},
        $self->{Seconds_Behind_Master});
    $self->set_thresholds(metric => 'slave_lag_'.$self->{name}, 
        warning => 10, critical => 20);
    $self->add_message($self->check_thresholds(
        metric => 'slave_lag_'.$self->{name},
        value => $self->{Seconds_Behind_Master}));
    $self->add_perfdata(
        label => 'slave_lag_'.$self->{name},
        value => $self->{Seconds_Behind_Master},
    );
  } elsif ($self->mode =~ /server::instance::replication::slaveiorunning/) {
    $self->add_info(sprintf 'Slave io is %srunning for channel %s',
        (lc $self->{Slave_IO_Running} eq 'yes' ? '' : 'not '), $self->{name});
    if (lc $self->{Slave_IO_Running} eq 'yes') {
      $self->add_ok();
    } else {
      $self->add_critical();
    }
  } elsif ($self->mode =~ /server::instance::replication::slavesqlrunning/) {
    $self->add_info(sprintf 'Slave sql is %srunning for channel %s',
        (lc $self->{Slave_SQL_Running} eq 'yes' ? '' : 'not '), $self->{name});
    if (lc $self->{Slave_SQL_Running} eq 'yes') {
      $self->add_ok();
    } else {
      $self->add_critical();
    }
  }
}

package Classes::Mysql::Component::ReplicationSubsystem::DefChannel;
our @ISA = qw(Classes::Mysql::Component::ReplicationSubsystem::Channel);
use strict;

sub check {
  my $self = shift;
  if ($self->mode =~ /server::instance::replication::slavelag/) {
    $self->add_info(sprintf "Slave is %d seconds behind master",
        $self->{Seconds_Behind_Master});
    $self->set_thresholds(metric => 'slave_lag',
        warning => 10, critical => 20);
    $self->add_message($self->check_thresholds(
        metric => 'slave_lag',
        value => $self->{Seconds_Behind_Master}));
    $self->add_perfdata(
        label => 'slave_lag',
        value => $self->{Seconds_Behind_Master},
    );
  } elsif ($self->mode =~ /server::instance::replication::slaveiorunning/) {
    $self->add_info(sprintf 'Slave io is %srunning',
        (lc $self->{Slave_IO_Running} eq 'yes' ? '' : 'not '));
    if (lc $self->{Slave_IO_Running} eq 'yes') {
      $self->add_ok();
    } else {
      $self->add_critical();
    }
  } elsif ($self->mode =~ /server::instance::replication::slavesqlrunning/) {
    $self->add_info(sprintf 'Slave sql is %srunning',
        (lc $self->{Slave_SQL_Running} eq 'yes' ? '' : 'not '));
    if (lc $self->{Slave_SQL_Running} eq 'yes') {
      $self->add_ok();
    } else {
      $self->add_critical();
    }
  }
}


