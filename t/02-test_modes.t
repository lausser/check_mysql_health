#! /usr/bin/perl --warning -I ..
#
# MySQL Database Server Tests via check_mysql_healthdb
#
#
# These are the database permissions required for this test:
#  GRANT SELECT ON $db.* TO $user@$host INDENTIFIED BY '$password';
#  GRANT SUPER, REPLICATION CLIENT ON *.* TO $user@$host;
# Check with:
#  mysql -u$user -p$password -h$host $db

use strict;
use Test::More;
use NPTest;

use vars qw($tests);

plan skip_all => "check_mysql_health not compiled" unless (-x "../plugins-scripts/check_mysql_health" || -x "plugins-scripts/check_mysql_health");

plan tests => 62;

my $mysqlserver = getTestParameter(
    "NP_MYSQL_SERVER",
    "A MySQL Server with no slaves setup",
    "localhost",
);      
my $mysql_username = getTestParameter(
    "NP_MYSQL_LOGIN_USERNAME",
    "Command line parameters to specify login access",
    "user",
);      
my $mysql_password = getTestParameter(
    "NP_MYSQL_LOGIN_PASSWORD",
    "Command line parameters to specify login access",
    "pw",
);      
my $mysql_database = getTestParameter(
    "NP_MYSQL_LOGIN_DATABASE",
    "Command line parameters to specify login access",
    "db",
);      
my $with_slave = getTestParameter(
    "NP_MYSQL_WITH_SLAVE",
    "MySQL server with slaves setup",
    undef,
);      
my $with_slave_login = getTestParameter(
    "NP_MYSQL_WITH_SLAVE_LOGIN",
    "Login details for server with slave",
    "--username user --password pw --database db",
);      

my $host_login = sprintf "--hostname %s --username %s --password '%s'",
    $mysqlserver, $mysql_username, $mysql_password;

my $result;

SKIP: {
  $result = NPTest->testCmd("check_mysql_health --hostname $mysqlserver --mode connection-time --username dummy --password dummy");
  cmp_ok($result->return_code, '==', 2, "Login failure");
  like($result->output, "/CRITICAL - .*Access denied/", "Expected login failure message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode connection-time --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success connection-time");
  like($result->output, "/OK - [\\d\\.]+ seconds to connect as .* \\| 'connection_time'=\([\\d\\.]+\);10;30;;/", "Expected connection-time message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode sql --warning 10 --critical 30 --name 'SELECT 20 FROM DUAL' --name2 test");
  cmp_ok($result->return_code, "==", 1, "Success sql");
  like($result->output, "/WARNING - test: 20 \\| 'test'=20;10;30;;/", "Expected sql message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode sql-runtime --warning 10 --critical 30 --name 'SELECT 20 FROM DUAL' --name2 test");
  cmp_ok($result->return_code, "==", 0, "Success sql-runtime");
  like($result->output, "/OK - [\\d\\.]+ seconds to execute test \\| 'sql_runtime'=[\\d\\.]+s;10;30;;/", "Expected sql-runtime message");
  diag($result->output);

  $result = NPTest->testCmd("echo 'SELECT * FROM DUAL' | check_mysql_health $host_login --mode encode --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success encode");
  like($result->output, "/SELECT%20%2A%20FROM%20DUAL/", "Expected encode message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode uptime --warning 10: --critical 30:");
  cmp_ok($result->return_code, "==", 0, "Success uptime");
  like($result->output, "/(OK|WARNING|CRITICAL) - database is up since \\d+ minutes \\| 'uptime'=\\d+;10:;30:;;/", "Expected uptime message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threads-connected --warning 11 --critical 31");
  cmp_ok($result->return_code, "==", 0, "Success threads-connected");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ client connection threads \\| 'threads_connected'=\\d+;11;31;;/", "Expected threads-connected message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threads-connected --warning 0 --critical 1");
  cmp_ok($result->return_code, ">=", 1, "Success threads-connected");
  like($result->output, "/(WARNING|CRITICAL) - \\d+ client connection threads \\| 'threads_connected'=\\d+;0;1;;/", "Expected max threads-connected message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threadcache-hitrate --warning 90: --critical 75:");
  cmp_ok($result->return_code, "<=", 2, "Success threadcache-hitrate");
  like($result->output, "/(OK|WARNING|CRITICAL) - thread cache hitrate \\d+.\\d\\d% \\| 'thread_cache_hitrate'=\[\\d\\.\]+%;;;0;100 'connections_per_sec'=\[\\d\\.\]+;;;;/", "Expected threadcache-hitrate message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threads-created --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success threads-created");
  like($result->output, "/(OK|WARNING|CRITICAL) - \[\\d\\.\]+ threads created/sec \\| 'threads_created_per_sec'=\[\\d\\.\]+;10;30;;/", "Expected threads-created message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threads-running --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success threads-running");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ running threads \\| 'threads_running'=\\d+;10;30;;/", "Expected threads-running message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threads-running --warning 0 --critical 1");
  cmp_ok($result->return_code, ">=", 0, "Success threads-running");
  like($result->output, "/(WARNING|CRITICAL) - \\d+ running threads \\| 'threads_running'=\\d+;0;1;;/", "Expected threads-running message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode threads-cached --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success threads-cached");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ cached threads \\| 'threads_cached'=\\d+;10;30;;/", "Expected threads-cached message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode connects-aborted --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success connects-aborted");
  like($result->output, "/(OK|WARNING|CRITICAL) - \[\\d\\.\]+ aborted connections\\/sec \\| 'connects_aborted_per_sec'=\[\\d\\.\]+;10;30;;/", "Expected connects-aborted message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode clients-aborted --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success clients-aborted");
  like($result->output, "/(OK|WARNING|CRITICAL) - [\\d\\.]+ aborted \\(client died\\) connections\/sec \\| 'clients_aborted_per_sec'=[\\d\\.]+;10;30;;/", "Expected clients-aborted message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode qcache-hitrate");
  cmp_ok($result->return_code, "<=", 2, "Success qcache-hitrate");
  like($result->output, "/(OK|WARNING|CRITICAL) - query cache hitrate [\\d\\.]+% \\| 'qcache_hitrate'=[\\d\\.]+%;90:;80:;0;100 'selects_per_sec'=[\\d\\.]+;;;;/", "Expected qcache-hitrate message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode qcache-lowmem-prunes --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success qcache-lowmem-prunes");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ query cache lowmem prunes in \\d+ seconds \\([\\d\\.]+\\/sec\\) \\| 'qcache_lowmem_prunes_rate'=[\\d\\.]+;10;30;;/", "Expected qcache-lowmem-prunes message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode keycache-hitrate --warning 100: --critical 99:");
  cmp_ok($result->return_code, "<=", 2, "Success keycache-hitrate");
  like($result->output, "/(OK|CRITICAL|WARNING) - myisam keycache hitrate at [\\d\\.]+% \\| 'keycache_hitrate'=[\\d\\.]+%;100:;99:;0;100/", "Expected keycache-hitrate message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode bufferpool-hitrate --warning 10: --critical 3:");
  cmp_ok($result->return_code, "==", 0, "Success bufferpool-hitrate");
  like($result->output, "/(OK|WARNING|CRITICAL) - innodb buffer pool hitrate at [\\d\\.]+% \\| 'bufferpool_hitrate'=[\\d\\.]+%;10:;3:;0;100/", "Expected bufferpool-hitrate message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode bufferpool-wait-free --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success bufferpool-wait-free");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ innodb buffer pool waits in \\d+ seconds \\([\\d\\.]+\/sec\\) \\| 'bufferpool_free_waits_rate'=[\\d\\.]+;10;30;;/", "Expected bufferpool-wait-free message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode log-waits --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success log-waits");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ innodb log waits in \\d+ seconds \\([\\d\\.]+\/sec\\) \\| 'innodb_log_waits_rate'=0;10;30;;/", "Expected log-waits message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode tablecache-hitrate --warning 93: --critical 91:");
  cmp_ok($result->return_code, "<=", 2, "Success tablecache-hitrate");
  like($result->output, "/(OK|WARNING|CRITICAL) - table cache hitrate [\\d\\.]+%, [\\d\\.]+% filled \\| 'tablecache_hitrate'=[\\d\\.]+%;93:;91:;0;100 'tablecache_fillrate'=[\\d\\.]+%;;;0;100/", "Expected tablecache-hitrate message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode table-lock-contention --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success table-lock-contention");
  like($result->output, "/(OK|WARNING|CRITICAL) - table lock contention [\\d\\.]+% \\| 'tablelock_contention'=[\\d\\.]+%;10;30;0;100/", "Expected table-lock-contention message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode index-usage --warning 100: --critical 99:");
  cmp_ok($result->return_code, "<=", 2, "Success index-usage");
  like($result->output, "/(OK|WARNING|CRITICAL) - index usage  [\\d\\.]+% \\| 'index_usage'=[\\d\\.]+%;100:;99:;0;100/", "Expected index-usage message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode tmp-disk-tables --warning 10 --critical 30");
  cmp_ok($result->return_code, "<=", 2, "Success tmp-disk-tables");
  like($result->output, "/(OK|WARNING|CRITICAL) - [\\d\\.]+% of \\d+ tables were created on disk | 'pct_tmp_table_on_disk'=[\\d\\.]+%;10;30;0;100/", "Expected tmp-disk-tables message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode table-fragmentation --warning 10 --critical 30");
  cmp_ok($result->return_code, "<=", 2, "Success table-fragmentation");
  like($result->output, "/table SESSION_VARIABLES is [\\d\\.]+% fragmented/", "Expected table-fragmentation message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode table-fragmentation --warning 10 --critical 30 --database mysql");
  cmp_ok($result->return_code, "<=", 2, "Success table-fragmentation");
  like($result->output, "/table user is [\\d\\.]+% fragmented/", "Expected table-fragmentation message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode table-fragmentation --warning 10 --critical 30 --database ''");
  cmp_ok($result->return_code, "<=", 2, "Success table-fragmentation");
  like($result->output, "/information_schema\.SESSION_VARIABLES is [\\d\\.]+% fragmented/", "Expected table-fragmentation message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode open-files --warning 10 --critical 30");
  cmp_ok($result->return_code, "<=", 2, "Success open-files");
  like($result->output, "/(OK|WARNING|CRITICAL) - [\\d\\.]+% of the open files limit reached (\\d+ of max. \\d+) | 'pct_open_files'=[\\d\\.]+%;10;30;0;100 'open_files'=\\d+;[\\d\\.]+;[\\d\\.]+;0;\\d+/", "Expected open-files message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode slow-queries --warning 10 --critical 30");
  cmp_ok($result->return_code, ">=", 0, "Success slow-queries");
  like($result->output, "/(OK|WARNING|CRITICAL) - \\d+ slow queries in \\d+ seconds \\([\\d\\.]+\\/sec\\) \\| 'slow_queries_rate'=[\\d\\.]+;10;30;;/", "Expected slow-queries message");
  diag($result->output);

  $result = NPTest->testCmd("check_mysql_health $host_login --mode long-running-procs --warning 10 --critical 30");
  cmp_ok($result->return_code, "==", 0, "Success long-running-procs");
  like($result->output, "/OK - \\d+ long running processes | 'long_running_procs'=\\d+;10;30;;/", "Expected long-running-procs message");
  diag($result->output);
}

