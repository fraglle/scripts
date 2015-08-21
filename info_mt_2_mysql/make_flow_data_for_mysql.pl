#!/usr/bin/perl
#
#
use POSIX qw(strftime);
use DBI;
use Net::OpenSSH;
use Encode;
use Switch;

my $path = "/home/flow/10.10.20.50";                              # путь куда складывает информацию сервис flow-capture
my $filtername = "all_192.168.0.0";                               # имя фильтра (должно быть прописанно в файле в настройках flow-tools
my $database = "netflow";                                         # база данных куда складывать информацию
my $table = "flows";                                            # таблица
my $mysql_user = "netflow";                                       # username for connect
my $mysql_pass = "netflow";                                       # password for connect

my $sshhost = "10.10.20.50";                                      # адрес микротика для подключения по ssh
my $sshuser = "root";                                             # имя пользователя под которым цепляться к микротику
my $mtcmd = "/ip dhcp-server lease print detail where !dynamic";  # комманда микротика для получения информации с dhcp сервера

my @result;
#######################################################################################
#  Get DHCP information from mikrotik
#######################################################################################
$ssh = Net::OpenSSH->new($sshuser.'@'.$sshhost);
$ssh->error and
    die "Couldn't establish SSH connection: ". $ssh->error;
my (@result, $err) = $ssh->capture($mtcmd);
$ssh->error and
    die "remote command failed: " . $ssh->error;
my @dhcpinfo;
my %dhcpinfo;
foreach $str(@result){
        if ($str =~ m/;{3}\s+/){
            $name = $';
            $name =~ s/\s+$//g;
#        print $name;

        };

        if($str =~ m/\d{1,3}(\.\d{1,3}){3}/){
            $ip = $&;
#            print $ip,"\n";
        };

        if( $str =~ m/(((?:(\d{1,2}|[a-fA-F]{1,2}){2})(?::|-*)){6})/){
            $str =~ m/^.+
                    ( # Start back reference capture for MAC Address
                    ((?:(\d{1,2}|[a-fA-F]{1,2}){2})(?::|-*)){6}
                    ) # End back reference
                   $/xms;
            $mac = $1;
        };

        if (defined $name and defined $ip and defined $mac){
            $name = Encode::decode("cp1251", $name);
            Encode::_utf8_off($name);
#            print "NAME = $name, IP = $ip, MAC = $mac\n";
            push (@dhcpinfo, "$name\t$ip\t$mac");
            %dhcpinfo = ( %dhcpinfo, $ip, $name);

            ($ip,$name,$mac) = undef;
        };
};

#######################################################################################
#  Get information from flow-stat
#######################################################################################
#my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
my $date = strftime "%Y-%m-%d", localtime;
($year,$mon,$day) = split /\-/, $date;
my $statcmd = "flow-cat $path/$year/$year-$mon/$year-$mon-$day |flow-nfilter -F $filtername | flow-stat -f8 -S3";
#my $tday = "03";
#$date = "2015-04-$tday";
#my $statcmd = "flow-cat $path/$year/$year-$mon/$year-$mon-$tday |flow-nfilter -F $filtername | flow-stat -f8 -S3";

my @stat;
my %stat;
@result = `$statcmd`;

foreach $str(@result){
    $str =~ s/(^\#.*\s$)//g;
    ($ip,$flows,$octets,$packets) = split /\s+/, $str;
    if( defined $ip and defined $flows and defined $octets and defined $packets){
#       print "IP = $ip, FLOWS = $flows, OCTETS = $octets, PACKETS = $packets\n";
       push (@stat, "$ip\t$flows\t$octets\t$packets");                       # добавляем элемент в массив

    };
};

#######################################################################################
#  Push in database
#######################################################################################
if ( !$mysqlhost ) {
        $mysqlhost = 'localhost';
        print STDERR "Database host not specified. Using $mysqlhost.";
}

if ( !$database ) {
        $database = 'netflow';
        print STDERR "Database name not specified. Using $database.";
}

if ( !$table ) {
        $table = 'users';
        print STDERR "Table parameter not specified. Using $table.";
}

if ( !$mysql_user ) {
        $mysql_user = 'netflow';
        print STDERR "User parameter not specified. Using $mysql_user.";
}

if ( !$mysql_pass ) {
        print STDERR "No password specified. Connecting with NO password.";
}

my $dsn = "DBI:mysql:database=$database" . ($mysqlhost ne "localhost" ? ":$mysqlhost" : "");
eval {
    warn "Connecting... dsn='$dsn', username='$mysql_user', password='...'";
    $dbh = DBI->connect($dsn, $mysql_user, $mysql_pass, { AutoCommit => 1, RaiseError => 1, PrintError => 1 });
    $dbh->do( "set names utf8" );
    warn "Initializing database table: $table";
    my $q = "SELECT `date`, `name`, `ip`, `octets`, `flows`, `packets` FROM $table LIMIT 1";
    my $sth = $dbh->prepare($q);
    $sth->execute;
};

my $update_count = 0;
my $insert_count = 0;
foreach $str1(@stat){
    ($ip,$flows,$octets,$packets) = split /\t/, $str1;
#       $name = ( defined $dhcpinfo{$ip} ? $dhcpinfo{$ip} : "" );
       $name = $dhcpinfo{$ip};
       if (!defined $name){
            switch($ip){
                case /^192\.168\.1\./    {$name = "КомбиСервис"}
                case /^192\.168\.7\./    {$name = "Проект"}
                case /^192\.168\.101\./  {$name = "Времянная сеть для wifi"}
                case /^192\.168\.102\./  {$name = "ОФ wifi"}
                case /^192\.168\.103\./  {$name = "ЗАО  wifi"}
                case /^192\.168\.104\./  {$name = "Сервис wifi"}
                case /^192\.168\.105\./  {$name = "Терминал wifi"}
                case /^192\.168\.106\./  {$name = "Гостевой wifi"}
            }
       }

       my $q = qq{SELECT COUNT(1) FROM $table WHERE date='$date' and `ip`='$ip'};
#       warn "Query: $q";
       $sth = $dbh->prepare($q);
       $sth->execute;
       if($sth->fetch->[0]){
            my $q = qq{UPDATE $table SET `name`='$name', `octets`=$octets, `flows`=$flows, `packets`=$packets WHERE date='$date', ip='$ip'};
#            warn "Query: $q";
            $sth = $dbh->prepare($q);
            $update_count++;
       }
       else{
            my $q = "INSERT INTO $table (`date`, `name`, `ip`, `octets`, `flows`, `packets`) VALUES ('$date','$name','$ip','$octets','$flows','$packets')";
#            warn "Query: $q";
            $sth = $dbh->prepare($q);
            $sth->execute() or die $sth->errstr;
            $insert_count++;
        }
#        print "$name : $ip : $mac : $octets : $flows : $packets\n";
};
print "Update records: $update_count \n Insert records: $insert_count\n";

$dbh->disconnect or warn "Failed to disconnect: ", $dbh->errstr(), "\n";
exit;
