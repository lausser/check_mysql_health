package Classes::Cluster::NDB;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  $self->{nodes} = [];
  if ($self->mode =~ /cluster::ndbdrunning/) {
    my $ndb_mgm = sprintf "%s --ndb-connectstring=%s%s",
        $self->{extcmd}, $self->opts->hostname,
        ($self->opts->port != 3306 ? ':'.$self->opts->port : '');
    my $output = `$ndb_mgm -e show 2>&1`;
    if ($output !~ /Cluster Configuration/) {
      $self->add_critical("got no cluster configuration");
    }
    if (! $self->check_messages()) {
      my $type = undef;
      foreach (split /\n/, $output) {
        if (/\[(\w+)\((\w+)\)\]\s+(\d+) node/) {
          $type = uc $2;
        } elsif (/id=(\d+)(.*)/) {
          push(@{$self->{nodes}}, Classes::Cluster::NDB::Node->new(
              type => $type,
              id => $1,
              status => $2,
          ));
        }
      }
    }
    $self->add_perfdata(
      label => 'ndbd_nodes',
      value => scalar(grep { $_->{type} eq "NDB" && $_->{status} eq "running" } @{$self->{nodes}}),
    );
    $self->add_perfdata(
      label => 'ndb_mgmd_nodes',
      value => scalar(grep { $_->{type} eq "MGM" && $_->{status} eq "running" } @{$self->{nodes}}),
    );
    $self->add_perfdata(
      label => 'mysqld_nodes',
      value => scalar(grep { $_->{type} eq "API" && $_->{status} eq "running" } @{$self->{nodes}}),
    );
  }
  $self->SUPER::check();
}

sub check_connect {
  my $self = shift;
  if (! $self->find_extcmd('ndb_mgm')) {
    $self->add_unknown('could not find ndb_mgm');
  } else {
    my $ndb_mgm = sprintf "%s --ndb-connectstring=%s%s",
        $self->{extcmd}, $self->opts->hostname,
        ($self->opts->port != 3306 ? ':'.$self->opts->port : '');
    my $output = `$ndb_mgm -e help 2>&1`;
    if ($? == -1) {
      $self->add_critical("ndb_mgm failed to execute $!");
    } elsif ($? & 127) {
      $self->add_critical("ndb_mgm failed to execute $!");
    } elsif ($? >> 8 != 0) {
      $self->add_critical("ndb_mgm unable to connect");
    }
  }
}

sub check_version {
  my $self = shift;
}

sub add_dbi_funcs {
  my $self = shift;
}

package Classes::Cluster::NDB::Node;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my $self = shift;
  if ($self->{status} =~ /@(\d+\.\d+\.\d+\.\d+)\s/) {
    $self->{addr} = $1;
    $self->{connected} = 1;
  } elsif ($self->{status} =~ /accepting connect from (\d+\.\d+\.\d+\.\d+)/) {
    $self->{addr} = $1;
    $self->{connected} = 0;
  }
  if ($self->{status} =~ /starting,/) {
    $self->{status} = "starting";
  } elsif ($self->{status} =~ /shutting,/) {
    $self->{status} = "shutting";
  } else {
    $self->{status} = $self->{connected} ? "running" : "dead";
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /cluster::ndbdrunning/) {
    $self->add_info(sprintf "%s node %d is %s", lc $self->{type},
        $self->{id}, $self->{status});
    if ($self->{status} ne "running") {
      $self->add_critical();
    } else {
      $self->add_ok();
    }
  }
}

