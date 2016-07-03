package Classes::Mysql::DBI;
our @ISA = qw(Classes::Mysql Monitoring::GLPlugin::DB::DBI);
use strict;

sub check_connect {
  my ($self) = @_;
  my $stderrvar;
  my $dbi_options = { RaiseError => 1, AutoCommit => $self->opts->commit, PrintError => 1 };
  my $dsn = "DBI:mysql:";
  $dsn .= sprintf "database=%s", $self->opts->database;
  if ($self->opts->mycnf) {
    $dsn .= sprintf ";mysql_read_default_file=%s", $self->opts->mycnf;
    if ($self->opts->mycnfgroup) {
      $dsn .= sprintf ";mysql_read_default_group=%s", $self->opts->mycnfgroup;
    }
  } else {
    $dsn .= sprintf ";host=%s", $self->opts->hostname;
    $dsn .= sprintf ";port=%s", $self->opts->port
        unless $self->opts->socket || $self->opts->hostname eq 'localhost';
    $dsn .= sprintf ";mysql_socket=%s", $self->opts->socket 
        if $self->opts->socket;
  }
  $self->set_variable("dsn", $dsn);
  eval {
    require DBI;
    $self->set_timeout_alarm($self->opts->timeout - 1, sub {
      die "alrm";
    });
    *SAVEERR = *STDERR;
    open OUT ,'>',\$stderrvar;
    *STDERR = *OUT;
    $self->{tic} = Time::HiRes::time();
    if ($self->{handle} = DBI->connect(
        $dsn,
        $self->opts->username,
        $self->decode_password($self->opts->password),
        $dbi_options)) {
      $Monitoring::GLPlugin::DB::session = $self->{handle};
    }
    $self->{tac} = Time::HiRes::time();
    *STDERR = *SAVEERR;
  };
  if ($@) {
    if ($@ =~ /alrm/) {
      $self->add_critical(
          sprintf "connection could not be established within %s seconds",
          $self->opts->timeout);
    } else {
      $self->add_critical($@);
    }
  } elsif (! $self->{handle}) {
    $self->add_critical("no connection");
  } else {
    $self->set_timeout_alarm($self->opts->timeout - ($self->{tac} - $self->{tic}));
  }
}

sub fetchrow_array {
  my ($self, $sql, @arguments) = @_;
  my @row = ();
  my $errvar = "";
  my $stderrvar = "";
  $self->set_variable("verbosity", 2);
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments) || die DBI::errstr();
    } else {
      $sth->execute() || die DBI::errstr();
    }
    @row = $sth->fetchrow_array();
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper(\@row));
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  }
  return $row[0] unless wantarray;
  return @row;
}

sub fetchall_array {
  my ($self, $sql, @arguments) = @_;
  my $rows = undef;
  my $stderrvar = "";
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments);
    } else {
      $sth->execute();
    }
    $rows = $sth->fetchall_arrayref();
    $sth->finish();
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
    $rows = [];
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  }
  return @{$rows};
}

sub fetchrow_hashref {
  my ($self, $sql, @arguments) = @_;
  my $sth = undef;
  my $hashref = undef;
  my $stderrvar = "";
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    # helm auf! jetzt wirds dreckig.
    if ($sql =~ /^\s*SHOW/) {
      $hashref = $Monitoring::GLPlugin::DB::session->selectrow_hashref($sql);
    } else {
      my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
      if (scalar(@arguments)) {
        $sth->execute(@arguments);
      } else {
        $sth->execute();
      }
      $hashref = $sth->selectrow_hashref();
    }
  };
  $self->debug(sprintf "RESULT:\n%s\n",
      Data::Dumper::Dumper($hashref));
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
    $hashref = {};
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  }
  return $hashref;
}

sub fetchall_hashref {
  my ($self, $sql, $key, @arguments) = @_;
  my $sth = undef;
  my $hashref = undef;
  my $stderrvar = "";
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    # helm auf! jetzt wirds dreckig.
    if ($sql =~ /^\s*SHOW/) {
      $hashref = $Monitoring::GLPlugin::DB::session->selectall_hashref($sql, $key);
    } else {
      my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
      if (scalar(@arguments)) {
        $sth->execute(@arguments);
      } else {
        $sth->execute();
      }
      $hashref = $sth->selectall_hashref($key);
    }
  };
  $self->debug(sprintf "RESULT:\n%s\n",
      Data::Dumper::Dumper($hashref));
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
    $hashref = {};
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  }
  return $hashref;
}


sub execute {
  my ($self, $sql, @arguments) = @_;
  my $errvar = "";
  my $stderrvar = "";
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "EXEC\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    $sth->execute();
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  } elsif ($stderrvar || $errvar) {
    $errvar = join("\n", (split(/\n/, $errvar), $stderrvar));
    $self->debug(sprintf "stderr %s", $errvar) ;
    $self->add_warning($errvar);
  }
}


sub add_dbi_funcs {
  my $self = shift;
  $self->SUPER::add_dbi_funcs();
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::fetchall_array'} = \&{"Classes::Mysql::DBI::fetchall_array"};
    *{'Monitoring::GLPlugin::DB::fetchrow_array'} = \&{"Classes::Mysql::DBI::fetchrow_array"};
    *{'Monitoring::GLPlugin::DB::fetchrow_hashref'} = \&{"Classes::Mysql::DBI::fetchrow_hashref"};
    *{'Monitoring::GLPlugin::DB::fetchall_hashref'} = \&{"Classes::Mysql::DBI::fetchall_hashref"};
    *{'Monitoring::GLPlugin::DB::execute'} = \&{"Classes::Mysql::DBI::execute"};
  }
}

