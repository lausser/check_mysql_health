package Classes::Mysql::Component::TableSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item Classes::Mysql);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /server::instance::table::cachehitrate/) {
    $self->{open_tables} = $self->get_status_var('Open_tables');
    $self->{opened_tables} = $self->get_status_var('Opened_tables');
    if ($self->version_is_minimum("5.1.3")) {
      $self->{table_cache} = $self->get_system_var('table_open_cache');
    } else {
      $self->{table_cache} = $self->get_system_var('table_cache');
    }
    $self->{table_cache} ||= 0;
    #$self->valdiff(\%params, qw(open_tables opened_tables table_cache));
    # _now ist hier sinnlos, da opened_tables waechst, aber open_tables wieder
    # schrumpfen kann weil tabellen geschlossen werden.
    if ($self->{opened_tables} != 0 && $self->{table_cache} != 0) {
      $self->{tablecache_hitrate} =
          100 * $self->{open_tables} / $self->{opened_tables};
      $self->{tablecache_fillrate} =
          100 * $self->{open_tables} / $self->{table_cache};
    } elsif ($self->{opened_tables} == 0 && $self->{table_cache} != 0) {
      $self->{tablecache_hitrate} = 100;
      $self->{tablecache_fillrate} =
          100 * $self->{open_tables} / $self->{table_cache};
    } else {
      $self->{tablecache_hitrate} = 0;
      $self->{tablecache_fillrate} = 0;
      $self->add_critical("no table cache");
    }
    $self->add_info(sprintf "table cache hitrate %.2f%%, %.2f%% filled",
        $self->{tablecache_hitrate}, $self->{tablecache_fillrate});
    if (! $self->check_messages()) {
      $self->set_thresholds(metric => 'tablecache_hitrate',
          warning => "99:", critical => "95:");
      if ($self->{tablecache_fillrate} < 95) {
        $self->add_ok();
      } else {
        $self->add_message($self->check_thresholds(
            metric => 'tablecache_hitrate',
            value => $self->{tablecache_hitrate}),
            sprintf "table cache hitrate %.2f%%", $self->{tablecache_hitrate});
      }
      $self->add_perfdata(
          label => 'tablecache_hitrate',
          value => $self->{tablecache_hitrate},
          uom => '%',
      );
      $self->add_perfdata(
          label => 'tablecache_fillrate',
          value => $self->{tablecache_fillrate},
          uom => '%',
      );
    }
  } elsif ($self->mode =~ /server::instance::table::lockcontention/) {
    $self->{table_locks_waited} = $self->get_status_var('Table_locks_waited');
    $self->{table_locks_immediate} = $self->get_status_var('Table_locks_immediate');
    $self->valdiff({ name => 'table_locks_waited' },
        qw(table_locks_waited table_locks_immediate));
    eval {
      $self->{tablelock_contention} =
          100 * $self->{table_locks_waited} /
          ($self->{table_locks_waited} + $self->{table_locks_immediate});
    };
    $self->{tablelock_contention} = 0 if $@ =~ /division/;
    if ($self->get_variable('uptime') > 10800) { # MySQL Bug #30599
      $self->check_var('tablelock_contention', 1, 2,
          'table lock contention %.2f%%', '%');
    } else {
      $self->set_thresholds(metric => 'tablelock_contention',
          warning => 1, critical => 2);
      $self->add_ok(sprintf 'table lock contention %.2f%% (uptime < 10800)',
          $self->{tablelock_contention});
    }
  } elsif ($self->mode =~ /server::instance::innodb::logwaits/) {
    $self->get_check_status_var_rate('innodb_log_waits',
        'Innodb_log_waits', 1, 10,
        '%ld innodb log waits in %ld seconds (%.2f/sec)'
    );
  } elsif ($self->mode =~ /server::instance::table::indexusage/) {
    # http://johnjacobm.wordpress.com/2007/06/
    # formula for calculating the percentage of full table scans
    foreach (['handler_read_first', 'Handler_read_first'],
        ['handler_read_key', 'Handler_read_key'],
        ['handler_read_next', 'Handler_read_next'],
        ['handler_read_prev', 'Handler_read_prev'],
        ['handler_read_rnd', 'Handler_read_rnd'],
        ['handler_read_rnd_next', 'Handler_read_rnd_next']) {
      $self->{$_->[0]} = $self->get_status_var($_->[1]);
    }
    $self->valdiff({ name => 'tableindexusage' },
        qw(handler_read_first handler_read_key handler_read_next
        handler_read_prev handler_read_rnd handler_read_rnd_next));
    my $delta_reads = $self->{delta_handler_read_first} +
        $self->{delta_handler_read_key} +
        $self->{delta_handler_read_next} +
        $self->{delta_handler_read_prev} +
        $self->{delta_handler_read_rnd} +
        $self->{delta_handler_read_rnd_next};
    my $reads = $self->{handler_read_first} +
        $self->{handler_read_key} +
        $self->{handler_read_next} +
        $self->{handler_read_prev} +
        $self->{handler_read_rnd} +
        $self->{handler_read_rnd_next};
    eval {
        $self->{index_usage} = 100 - (100 *
            ($self->{delta_handler_read_rnd} + $self->{delta_handler_read_rnd_next}) /
        $delta_reads);
    };
    $self->{index_usage} = 0 if $@ =~ /division/;
    $self->check_var('index_usage', '90:', '80:', 'index usage  %.2f%%', '%');
  } elsif ($self->mode =~ /server::instance::table::tmpondisk/) {
    $self->{created_tmp_tables} = $self->get_status_var('Created_tmp_tables');
    $self->{created_tmp_disk_tables} = $self->get_status_var('Created_tmp_disk_tables');
    $self->valdiff({ name => 'pct_tmp_table_on_disk' }, qw(created_tmp_tables created_tmp_disk_tables));
    eval {
      $self->{pct_tmp_table_on_disk} = 100 * $self->{delta_created_tmp_disk_tables} /
          $self->{delta_created_tmp_tables};
    };
    $self->{pct_tmp_table_on_disk} = 0 if $@ =~ /division/;
    $self->check_var('pct_tmp_table_on_disk', 25, 50, ['%.2f%% of %d tables were created on disk', 'delta_created_tmp_tables'], '%');
  } elsif ($self->mode =~ /server::instance::table::needoptimize/) {
    #http://www.electrictoolbox.com/optimize-tables-mysql-php/
    my $sql = q{
        -- SHOW TABLE STATUS
        SELECT
            table_schema, table_name, engine, data_length, index_length, data_free
        FROM
            information_schema.tables
    };
    my $columns = ['table_schema', 'table_name', 'engine', 'data_length', 'index_length', 'data_free', ];
    my $filter = sub {
      my $o = shift;
      $self->filter_name($o->{table_name}) &&
          ($self->filter_namex($self->opts->database, $o->{table_schema} ||
          defined $self->opts->database && $self->opts->database eq ''));
    };
    $self->get_db_tables([
      ['tables', $sql, 'Classes::Mysql::Component::TableSubsystem::Table', $filter, $columns ],
    ]);
    $self->add_unknown('no tables found') if ! scalar(@{$self->{tables}});
  }
}

package Classes::Mysql::Component::TableSubsystem::Table;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  eval {
    $self->{fragmentation} = 100 *
        $self->{data_free} / ($self->{data_free} + $self->{data_length} + $self->{index_length});
  };
  $self->{fragmentation} = 0 if $@ =~ /division/;
  $self->{full_name} = ($self->opts->database eq '') ?
      $self->{table_schema}.'.'.$self->{table_name} :
      $self->{table_name};
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf 'table %s is %.2f%% fragmented',
      $self->{full_name}, $self->{fragmentation});
  $self->set_thresholds(metric => $self->{full_name}.'_frag',
      warning => 10, critical => 25);
  $self->add_message($self->check_thresholds(
      metric => $self->{full_name}.'_frag',
      value => $self->{fragmentation},
  ));
  if ($self->opts->name) {
    $self->add_perfdata(
        label => $self->{full_name}.'_frag',
        value => $self->{fragmentation},
        uom => '%',
    );
  }
}

