#!/usr/bin/perl
#
# установка модуля sudo cpan MIME::Lite::TT::HTML
#
#

use strict;
use warnings;
use MIME::Lite::TT::HTML;

my $conf_file = 'jinn.conf';
my $mail_file = 'mail.list';
my $body_conf_file = 'body.conf';
my %config = ();
my $config_line;
my %options;
my %params;
#$params{recipient} = {''};

if(!open(CONFIG, "$conf_file"))
{
    print "Error: Config file not found : $conf_file";
    exit(0);
}

while(<CONFIG>)
{
    $config_line = $_;
    chop($config_line);
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $config{$var} = $value;
}

if(defined($ARGV[0]) and  $ARGV[0] eq '-p')
{
    foreach my $conf_key(keys %config)
    {
        print "$conf_key = $config{$conf_key}\n";
    }
}

if(!open(BODYCONF,"$body_conf_file"))
{
    print "Error: Mailbase file not found: $mail_file";
    exit(0);
}
while(<BODYCONF>)
{
    chomp;
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;
    $params{$_} = "$_\.gif";
}

if(!open(MAILBASE,"$mail_file"))
{
    print "Error: Mailbase file not found: $mail_file";
    exit(0);
}

while(<MAILBASE>)
{
    chomp;
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;
    my $recipient = $_;
    $params{recipient} = $recipient;

    my $msg = MIME::Lite::TT::HTML->new(
       From        =>  'imis@ptk.ru',
       To          =>  "$params{recipient}",
       Subject     =>  'Test mail',
       Template    =>  {
                     html    =>  'body.html',
                     text    =>  'body.txt'

                   },
       Charset     => 'utf8',
       Timezone  => 'UTC',
       Type      => 'multipart/mixed',
       Encoding  => 'base64',
       TmplOptions =>  \%options,
       TmplParams  =>  \%params,
       );

    $msg->attr("content-type"  => "multipart/mixed");

    for my $key(keys %params)
    {
        print "$params{$key}\n";
        if(index($params{$key},"\@") != -1)
        {
            #print "Email adress : $params{$key}\n";
            next;
        }
        $msg->attach(  Type        =>  'image/gif',
            Path        =>  "$params{$key}",
            Filename    =>  "$params{$key}",
            Disposition =>  'attachment'
        );
    }


    $msg->send('smtp', '10.10.101.29', Timeout => 60 );;
}

exit(0);

###______________END__________________
