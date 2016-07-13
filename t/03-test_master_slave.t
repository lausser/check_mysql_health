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

plan tests => 51;

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
  $result = NPTest->testCmd("check_mysql_health $host_login --mode slave-lag --warning 10 --critical 30");
  cmp_ok( $result->return_code, "==", 0, "Success slave-lag");
  like( $result->output, "/xxx/", "Expected slave-lag message");

  $result = NPTest->testCmd("check_mysql_health $host_login --mode slave-io-running --warning 10 --critical 30");
  cmp_ok( $result->return_code, "==", 0, "Success slave-io-running");
  like( $result->output, "/xxx/", "Expected slave-io-running message");

  $result = NPTest->testCmd("check_mysql_health $host_login --mode slave-sql-running --warning 10 --critical 30");
  cmp_ok( $result->return_code, "==", 0, "Success slave-sql-running");
  like( $result->output, "/xxx/", "Expected slave-sql-running message");
}

