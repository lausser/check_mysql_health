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

plan tests => 35;

my $bad_login_output = '/Access denied for user /';
my $mysqlserver = getTestParameter(
		"NP_MYSQL_SERVER",
		"A MySQL Server with no slaves setup",
                "localhost",
		);
my $mysql_username = getTestParameter(
		"NP_MYSQL_LOGIN_USERNAME",
		"Command line parameters to specify login access",
		"--username user",
		);
my $mysql_password = getTestParameter(
		"NP_MYSQL_LOGIN_PASSWORD",
		"Command line parameters to specify login access",
		"--password pw",
		);
my $mysql_database = getTestParameter(
		"NP_MYSQL_LOGIN_DATABASE",
		"Command line parameters to specify login access",
		"--database db",
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

my $host_login = sprintf "--username %s --password '%s'",
    $mysql_username, $mysql_password;

my $result;
SKIP: {
	$result = NPTest->testCmd("check_mysql_health -V");
	cmp_ok( $result->return_code, '==', 0, "expected result");
	like( $result->output, "/check_mysql_health \\\$Revision: \\d+\\.\\d+/", "Expected message");

	$result = NPTest->testCmd("check_mysql_health --help");
	cmp_ok( $result->return_code, '==', 0, "expected result");
        like( $result->output, "/bufferpool-hitrate/", "Expected message");
        like( $result->output, "/bufferpool-wait-free/", "Expected message");
        like( $result->output, "/clients-aborted/", "Expected message");
        like( $result->output, "/cluster-ndbd-running/", "Expected message");
        like( $result->output, "/connection-time/", "Expected message");
        like( $result->output, "/connects-aborted/", "Expected message");
        like( $result->output, "/encode/", "Expected message");
        like( $result->output, "/index-usage/", "Expected message");
        like( $result->output, "/keycache-hitrate/", "Expected message");
        like( $result->output, "/log-waits/", "Expected message");
        like( $result->output, "/long-running-procs/", "Expected message");
        like( $result->output, "/open-files/", "Expected message");
        like( $result->output, "/qcache-hitrate/", "Expected message");
        like( $result->output, "/qcache-lowmem-prunes/", "Expected message");
        like( $result->output, "/slave-io-running/", "Expected message");
        like( $result->output, "/slave-lag/", "Expected message");
        like( $result->output, "/slave-sql-running/", "Expected message");
        like( $result->output, "/slow-queries/", "Expected message");
        like( $result->output, "/sql/", "Expected message");
        like( $result->output, "/sql-runtime/", "Expected message");
        like( $result->output, "/tablecache-hitrate/", "Expected message");
        like( $result->output, "/table-fragmentation/", "Expected message");
        like( $result->output, "/table-lock-contention/", "Expected message");
        like( $result->output, "/threadcache-hitrate/", "Expected message");
        like( $result->output, "/threads-cached/", "Expected message");
        like( $result->output, "/threads-connected/", "Expected message");
        like( $result->output, "/threads-created/", "Expected message");
        like( $result->output, "/threads-running/", "Expected message");
        like( $result->output, "/tmp-disk-tables/", "Expected message");
        like( $result->output, "/uptime/", "Expected message");
}

SKIP: {
	$result = NPTest->testCmd("check_mysql_health");
	cmp_ok( $result->return_code, "==", 3, "No mode defined" );
	like( $result->output, "/hostname.*username.*password/", "Correct error message");
}
