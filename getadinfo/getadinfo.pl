#!/usr/bin/perl -w
#T

use Text::Iconv;
use Net::LDAP;
use Encode qw(from_to);

my $converter = Text::Iconv->new('UTF-8', 'WINDOWS-1251');

my $prefix = '/var/www/lightsquid';
my $users = $prefix.'/realname.cfg';
my $groups = $prefix.'/group.cfg';
my $inject = "cat /var/www/lightsquid/ip.cfg >> /var/www/lightsquid/realname.cfg";

my $ldap = Net::LDAP->new('ldap://master.domain.ru') or die "$@";
my $result = $ldap->bind('CN=user,OU=squid,DC=domain,DC=ru', 'password' => 'pass');

if($result->code) {
    die 'Bind failed!\n';
}

$result = $ldap->search(
    'base'   => 'OU=root,DC=ptk,DC=ru',
    'filter' => '(&(objectClass=user)(!(UserAccountControl=66050)))',
    'scope'  => 'sub',
    'attrs'  => [ 'cn', 'sAMAccountName', 'company' ]
);

if($result->entries <= 0) {
    die "Found no users\n";
}

my %groups = ();

open(OUT, '>' . $users);
foreach my $entry ($result->entries) {
    my $name = $converter->convert($entry->get_value('cn'));
    my $login = $converter->convert(lc($entry->get_value('sAMAccountName')));
    my $dept = $entry->get_value('company');

    if(defined $dept) {
        $groups{$converter->convert($dept)}{$login} = 1;
    }

    print OUT $login . "\t" . $name . "\n";
}
close(OUT);

my $i = 1;
open(OUT, '>' . $groups);
foreach my $group (sort keys %groups) {
    foreach my $login (sort keys %{$groups{$group}} ) {
        my $num = sprintf("%02d", $i);
        print OUT $login . "\t" . $num . "\t" . $group . "\n";
    }
    $i++;
}
close(OUT);

@result = `$inject`;
