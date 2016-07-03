package Classes::Mysql::Mysql;
our @ISA = qw(Classes::Mysql Monitoring::GLPlugin::DB);
use strict;

sub create_cmd_line {
  my $self = shift;
  my @args = ();
  push (@args, '--batch --raw --skip-column-names');
  push (@args, sprintf "--database=%s", $self->opts->database);
  push (@args, sprintf "--host=%s", $self->opts->hostname)
      unless $self->opts->socket;
  push (@args, sprintf "--port=%s", $self->opts->port)
      unless ($self->opts->socket || $self->opts->hostname eq 'localhost');
  push (@args, sprintf "--socket '%s'", $self->opts->socket) 
      if $self->opts->socket;
  push (@args, sprintf "--user '%s'", $self->opts->username);
  $ENV{MYSQL_PWD} = $self->decode_password($self->opts->password);
  #push (@args, sprintf "--password='%s'",
  #    $self->decode_password($self->opts->password));
  push (@args, sprintf "< '%s'",
      $Monitoring::GLPlugin::DB::sql_commandfile);
  push (@args, sprintf "> '%s'",
      $Monitoring::GLPlugin::DB::sql_resultfile);
  $Monitoring::GLPlugin::DB::session =
      sprintf '"%s" %s', $self->{extcmd}, join(" ", @args);
}

sub check_connect {
  my $self = shift;
  my $stderrvar;
  if (! $self->find_extcmd("mysql")) {
    $self->add_unknown("mysql command was not found");
    return;
  }
  $self->create_extcmd_files();
  $self->create_cmd_line();
  eval {
    $self->set_timeout_alarm($self->opts->timeout - 1, sub {
      die "alrm";
    });
    *SAVEERR = *STDERR;
    open OUT ,'>',\$stderrvar;
    *STDERR = *OUT;
    $self->{tic} = Time::HiRes::time();
    my $answer = $self->fetchrow_array(q{
        SELECT 'schnorch'
    });
    die unless defined $answer and $answer eq 'schnorch';
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
  } else {
    $self->set_timeout_alarm($self->opts->timeout - ($self->{tac} - $self->{tic}));
  }
}

sub write_extcmd_file {
  my $self = shift;
  my $sql = shift;
  open CMDCMD, "> $Monitoring::GLPlugin::DB::sql_commandfile";
  printf CMDCMD "%s\n", $sql;
  close CMDCMD;
}

sub fetchrow_hashref {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my $hashref = undef;
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $sql =~ s/^\s*SHOW/SHOW/g;
  if ($sql =~ /^\s*SHOW/) {
    $sql =~ s/\s*$//gm;
    chomp $sql;
    $sql .= '\G'; # http://dev.mysql.com/doc/refman/5.1/de/show-slave-status.html
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "SQL (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  my $hashsession = $Monitoring::GLPlugin::DB::session;
  $hashsession =~ s/--skip-column-names//g;
  $self->debug($hashsession);
  my $exit_output = `$hashsession`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    if ($sql =~ /^\s*SHOW/) {
      map {
        if (/^\s*([\w_]+):\s*(.*)/) {
          $hashref->{$1} = $2;
        }
      } split(/\n/, $output);
    } else {
      # i dont mess around here and you shouldn't either
    }
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($hashref));
  }
  return $hashref;
}

sub fetchall_hashref {
  my $self = shift;
  my $sql = shift;
  my $key = shift;
  my @arguments = @_;
  my $hashref = undef;
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $sql =~ s/^\s*SHOW/SHOW/g;
  if ($sql =~ /^\s*SHOW/) {
    $sql =~ s/\s*$//gm;
    chomp $sql;
    $sql .= '\G'; # http://dev.mysql.com/doc/refman/5.1/de/show-slave-status.html
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "SQL (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  my $hashsession = $Monitoring::GLPlugin::DB::session;
  $hashsession =~ s/--skip-column-names//g;
  $self->debug($hashsession);
  my $exit_output = `$hashsession`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    if ($sql =~ /^\s*SHOW/) {
      my $tmphashref = {};
      foreach my $line (split(/\n/, $output)) {
        if ($line =~ /^\*\*\*\*/) {
          $tmphashref = {};
        } elsif ( $line =~ /^\s*([^:]+):\s*(.*)$/) {
          $tmphashref->{$1} = $2;
          if ($1 eq $key) {
            $hashref->{$tmphashref->{$key}} = $tmphashref;
          }
        }
      }
    } else {
      # i dont mess around here and you shouldn't either
    }
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($hashref));
  }
  return $hashref;
}

sub fetchrow_array {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my @row = ();
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "SQL (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  $self->debug($Monitoring::GLPlugin::DB::session);
  my $exit_output = `$Monitoring::GLPlugin::DB::session`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    @row = map { convert($_) }
        map { s/^\s+([\.\d]+)$/$1/g; $_ }         # strip leading space from numbers
        map { s/\s+$//g; $_ }                     # strip trailing space
        split(/\t/, (split(/\n/, $output))[0]);
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper(\@row));
  }
  return $row[0] unless wantarray;
  return @row;
}

sub fetchall_array {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my $rows = [];
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "SQL (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  $self->debug($Monitoring::GLPlugin::DB::session);
  my $exit_output = `$Monitoring::GLPlugin::DB::session`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    my @rows = map { [
        map { $self->convert_scientific_numbers($_) }
        map { s/^\s+([\.\d]+)$/$1/g; $_ }
        map { s/\s+$//g; $_ }
        split /\|/
    ] } grep { ! /^\d+ rows selected/ }
        grep { ! /^\d+ [Zz]eilen ausgew / }
        grep { ! /^Elapsed: / }
        grep { ! /^\s*$/ } map { s/^\|//; $_; } split(/\n/, $output);
    $rows = \@rows;
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
  }
  return @{$rows};
}



sub execute {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my $rows = [];
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "EXEC (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  $self->debug($Monitoring::GLPlugin::DB::session);
  my $exit_output = `$Monitoring::GLPlugin::DB::session`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    my @rows = map { [
        map { $self->convert_scientific_numbers($_) }
        map { s/^\s+([\.\d]+)$/$1/g; $_ }
        map { s/\s+$//g; $_ }
        split /\|/
    ] } grep { ! /^\d+ rows selected/ }
        grep { ! /^\d+ [Zz]eilen ausgew / }
        grep { ! /^Elapsed: / }
        grep { ! /^\s*$/ } map { s/^\|//; $_; } split(/\n/, $output);
    $rows = \@rows;
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
  }
  return @{$rows};
}

sub convert {
  my $n = shift;
  # mostly used to convert numbers in scientific notation
  if ($n =~ /^\s*\d+\s*$/) {
    return $n;
  } elsif ($n =~ /^\s*([-+]?)(\d*[\.,]*\d*)[eE]{1}([-+]?)(\d+)\s*$/) {
    my ($vor, $num, $sign, $exp) = ($1, $2, $3, $4);
    $n =~ s/E/e/g;
    $n =~ s/,/\./g;
    $num =~ s/,/\./g;
    my $sig = $sign eq '-' ? "." . ($exp - 1 + length $num) : '';
    my $dec = sprintf "%${sig}f", $n;
    $dec =~ s/\.[0]+$//g;
    return $dec;
  } elsif ($n =~ /^\s*([-+]?)(\d+)[\.,]*(\d*)\s*$/) {
    return $1.$2.".".$3;
  } elsif ($n =~ /^\s*(.*?)\s*$/) {
    return $1;
  } else {
    return $n;
  }
}

sub add_dbi_funcs {
  my $self = shift;
  $self->SUPER::add_dbi_funcs();
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::create_cmd_line'} = \&{"Classes::Mysql::Mysql::create_cmd_line"};
    *{'Monitoring::GLPlugin::DB::write_extcmd_file'} = \&{"Classes::Mysql::Mysql::write_extcmd_file"};
#    *{'Monitoring::GLPlugin::DB::decode_password'} = \&{"Classes::Mysql::Mysql::decode_password"};
    *{'Monitoring::GLPlugin::DB::fetchrow_hashref'} = \&{"Classes::Mysql::Mysql::fetchrow_hashref"};
    *{'Monitoring::GLPlugin::DB::fetchall_hashref'} = \&{"Classes::Mysql::Mysql::fetchall_hashref"};
    *{'Monitoring::GLPlugin::DB::fetchall_array'} = \&{"Classes::Mysql::Mysql::fetchall_array"};
    *{'Monitoring::GLPlugin::DB::fetchrow_array'} = \&{"Classes::Mysql::Mysql::fetchrow_array"};
    *{'Monitoring::GLPlugin::DB::execute'} = \&{"Classes::Mysql::Mysql::execute"};
  }
}

