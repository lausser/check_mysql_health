#! /usr/bin/perl

use strict;

eval {
  if ( ! grep /BEGIN/, keys %Monitoring::GLPlugin::) {
    require Monitoring::GLPlugin;
    require Monitoring::GLPlugin::DB;
  }
};
if ($@) {
  printf "UNKNOWN - module Monitoring::GLPlugin was not found. Either build a standalone version of this plugin or set PERL5LIB\n";
  printf "%s\n", $@;
  exit 3;
}

my $plugin = Classes::Device->new(
    shortname => '',
    usage => '%s [-v] [-t <timeout>] '.
        '--hostname=<db server hostname> [--port <port>] '.
        '--username=<username> --password=<password> '.
        '--mode=<mode> '.
        '...',
    version => '$Revision: #PACKAGE_VERSION# $',
    blurb => 'This plugin checks microsoft sql servers ',
    url => 'http://labs.consol.de/nagios/check_mss_health',
    timeout => 60,
);
$plugin->add_db_modes();
$plugin->add_mode(
    internal => 'server::uptime',
    spec => 'uptime',
    alias => undef,
    help => 'Time the server is running',
);
$plugin->add_mode(
    internal => 'server::instance::connectedthreads',
    spec => 'threads-connected',
    alias => undef,
    help => 'Number of currently open connections',
);
$plugin->add_mode(
    internal => 'server::instance::threadcachehitrate',
    spec => 'threadcache-hitrate',
    alias => undef,
    help => 'Hit rate of the thread-cache',
);
$plugin->add_mode(
    internal => 'server::instance::createdthreads',
    spec => 'threads-created',
    alias => undef,
    help => 'Number of threads created per sec',
);
$plugin->add_mode(
    internal => 'server::instance::runningthreads',
    spec => 'threads-running',
    alias => undef,
    help => 'Number of currently running threads',
);
$plugin->add_mode(
    internal => 'server::instance::cachedthreads',
    spec => 'threads-cached',
    alias => undef,
    help => 'Number of currently cached threads',
);
$plugin->add_mode(
    internal => 'server::instance::abortedconnects',
    spec => 'connects-aborted',
    alias => undef,
    help => 'Number of aborted connections per sec',
);
$plugin->add_mode(
    internal => 'server::instance::abortedclients',
    spec => 'clients-aborted',
    alias => undef,
    help => 'Number of aborted connections (because the client died) per sec',
);
$plugin->add_mode(
    internal => 'server::instance::replication::slavelag',
    spec => 'slave-lag',
    alias => ['replication-slave-lag'],
    help => 'Seconds behind master',
);
$plugin->add_mode(
    internal => 'server::instance::replication::slaveiorunning',
    spec => 'slave-io-running',
    alias => ['replication-slave-io-running'],
    help => 'Slave io running: Yes',
);
$plugin->add_mode(
    internal => 'server::instance::replication::slavesqlrunning',
    spec => 'slave-sql-running',
    alias => ['replication-slave-sql-running'],
    help => 'Slave sql running: Yes',
);
$plugin->add_mode(
    internal => 'server::instance::querycachehitrate',
    spec => 'qcache-hitrate',
    alias => ['querycache-hitrate'],
    help => 'Query cache hitrate',
);
$plugin->add_mode(
    internal => 'server::instance::querycachelowmemprunes',
    spec => 'qcache-lowmem-prunes',
    alias => ['querycache-lowmem-prunes'],
    help => 'Query cache entries pruned because of low memory',
);
$plugin->add_mode(
    internal => 'server::instance::myisam::keycache::hitrate',
    spec => 'keycache-hitrate',
    alias => ['myisam-keycache-hitrate'],
    help => 'MyISAM key cache hitrate',
);
$plugin->add_mode(
    internal => 'server::instance::innodb::bufferpool::hitrate',
    spec => 'bufferpool-hitrate',
    alias => ['innodb-bufferpool-hitrate'],
    help => 'InnoDB buffer pool hitrate',
);
$plugin->add_mode(
    internal => 'server::instance::innodb::bufferpool::waitfree',
    spec => 'bufferpool-wait-free',
    alias => ['innodb-bufferpool-wait-free'],
    help => 'InnoDB buffer pool waits for clean page available',
);
$plugin->add_mode(
    internal => 'server::instance::innodb::logwaits',
    spec => 'log-waits',
    alias => ['innodb-log-waits'],
    help => 'InnoDB log waits because of a too small log buffer',
);
$plugin->add_mode(
    internal => 'server::instance::tablecachehitrate',
    spec => 'tablecache-hitrate',
    alias => undef,
    help => 'Table cache hitrate',
);
$plugin->add_mode(
    internal => 'server::instance::tablelockcontention',
    spec => 'table-lock-contention',
    alias => undef,
    help => 'Table lock contention',
);
$plugin->add_mode(
    internal => 'server::instance::tableindexusage',
    spec => 'index-usage',
    alias => undef,
    help => 'Usage of indices',
);
$plugin->add_mode(
    internal => 'server::instance::tabletmpondisk',
    spec => 'tmp-disk-tables',
    alias => undef,
    help => 'Percent of temp tables created on disk',
);
$plugin->add_mode(
    internal => 'server::instance::needoptimize',
    spec => 'table-fragmentation',
    alias => undef,
    help => 'Show tables which should be optimized',
);
$plugin->add_mode(
    internal => 'server::instance::openfiles',
    spec => 'open-files',
    alias => undef,
    help => 'Percent of opened files',
);
$plugin->add_mode(
    internal => 'server::instance::slowqueries',
    spec => 'slow-queries',
    alias => undef,
    help => 'Slow queries',
);
$plugin->add_mode(
    internal => 'server::instance::longprocs',
    spec => 'long-running-procs',
    alias => undef,
    help => 'long running processes',
);
$plugin->add_mode(
    internal => 'cluster::ndbdrunning',
    spec => 'cluster-ndbd-running',
    alias => undef,
    help => 'ndnd nodes are up and running',
);

$plugin->add_arg(
    spec => 'hostname=s',
    help => "--hostname
   the database server",
    default => 'localhost',
    required => 0,
);
$plugin->add_arg(
    spec => 'username=s',
    help => "--username
   the mysql user",
    required => 0,
);
$plugin->add_arg(
    spec => 'replication-user=s',
    help => "--replication-user
   the database's replication user name (default: replication)",
    default => 'replication',
    required => 0,
);
$plugin->add_arg(
    spec => 'password=s',
    help => "--password
   the mssql user's password",
    required => 0,
);
$plugin->add_arg(
    spec => 'port=i',
    default => 3306,
    help => "--port
   the database server's port",
    required => 0,
);
$plugin->add_arg(
    spec => 'socket=s',
    help => "--socket
   the database server's socket",
    required => 0,
);
$plugin->add_arg(
    spec => 'database=s',
    help => "--database
   the name of a database which is used as the current database
   for the connection.",
    default => 'information_schema',
    required => 0,
);
$plugin->add_arg(
    spec => 'mycnf',
    help => "--mycnf
   a mycnf file which can be specified instead of hostname/username/password.",
    required => 0,
);
$plugin->add_arg(
    spec => 'mycnfgroup',
    help => "--mycnfgroup
   a section in a mycnf file.",
    required => 0,
);
$plugin->add_arg(
    spec => 'nooffline',
    help => "--nooffline
   skip the offline databases",
    required => 0,);

$plugin->add_db_args();
$plugin->add_default_args();

$plugin->getopts();
$plugin->classify();
$plugin->validate_args();


if (! $plugin->check_messages()) {
  $plugin->init();
  if (! $plugin->check_messages()) {
    $plugin->add_ok($plugin->get_summary())
        if $plugin->get_summary();
    $plugin->add_ok($plugin->get_extendedinfo(" "))
        if $plugin->get_extendedinfo();
  }
} else {
#  $plugin->add_critical('wrong device');
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", $plugin->get_info("\n")
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin);
$plugin->nagios_exit($code, $message);


