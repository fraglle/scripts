#!/usr/bin/perl
#


use strict;
use warnings;
use MIME::Lite;
use Data::Dumper;
use XML::Simple;
use Encode;


my $conf_file = 'jinn.xml';
my $mail_list = 'mail.list';
my $mail_xml = 'mail.xml';


unless (-e $conf_file) { die "Error open config file : $conf_file $!";}
unless (-e $mail_list) { die "Error open config file : $mail_list $!";}
unless (-e $mail_xml) { die "Error open config file : $mail_xml $!";}

my $config = XMLin("$conf_file");
my $email = XMLin("$mail_xml");
open (MAILBASE, $mail_list) or die "Can't open file $mail_list $!";

#print Dumper $config;
print Dumper $email;

Encode::_utf8_off($email->{subject});

while (<MAILBASE>)
{
    my $msg = MIME::Lite->new(
        From    => "$email->{from}",
        To      => "$_",
        Subject => "$email->{subject}",
        Type    => 'multipart/mixed',
    );

    $msg->attach( Type => 'text/html; charset=UTF-8',
                  Data => "$email->{emailbody}"
    );

    if(!ref($email->{emailattachments}))
    {
        print "Scalar\n";
        $msg->attach( Type        => 'image/jpg',
                      Path        => "$email->{emailattachments}",
                      Filename    => "$email->{emailattachments}",
                      Disposition => 'attachment' );
    }
    else
    {
        print "Hash\n";
        for my $key (keys $email->{emailattachments} )
        {
            $msg->attach( Type        => 'image/jpg',
                          Path        => "$email->{emailattachments}[$key]",
                          Filename    => "$email->{emailattachments}[$key]",
                          Disposition => 'attachment' );
        }
    }

    $msg->send('smtp',
        $config->{server_smtp},
        #SSL=>1,
        #AuthUser=>"$user",
        #AuthPass=>"$pass",
        Debug=>0);
}
close(MAILBASE);

exit(0);

###______________END__________________
