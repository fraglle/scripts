#!/usr/bin/perl

use strict;
use warnings;
use Encode;
use MIME::Base64;
use MIME::Lite;
use Authen::SASL;
use File::Basename;

sub CreateImage($$);
sub SendEmail($$);

my $user = 'user';
my $pass = 'pass';

my $smtpserver = '10.10.101.29';
my $subj = 'Дегустация .';

my $filename = 'mail.list';
my $bk_fname = 'back.jpg';
my $name = "cupon.pdf";
my $sendlogfile = 'send.log';
my $nosendlogfile = 'nosend.log';
my $autostart = 'auto.txt';
my $file_ext = '.png';
my $email;

my $oldpath = './old/';
$subj = encode('MIME-Header', decode('utf8', $subj));
unless (-e $autostart) {die "Файл автостарта не найден.";};
if (-e $sendlogfile) { `mv $sendlogfile $sendlogfile"_old"`;};
if (-e $nosendlogfile) { `mv $nosendlogfile $nosendlogfile"_old"`;};

open(my $send_handle, '>', $sendlogfile) or die "Не могу открыть файл $sendlogfile для записи $!";
open(my $nosend_handle, '>', $nosendlogfile) or die "Не могу открыть файл $nosendlogfile для записи $!";
open(my $fh, $filename)  or die "Could not open file '$filename' $!";



my $count = 0;
my @files = glob("*.png");

while ($email = <$fh>) {
    chomp $email;

    my $image = $files[$count];

    if(!$email){ die "Список адресов пуст.\n";};

    if(defined($image))
    {
       CreateImage($image,$email);

       my @result = `mv $image $oldpath`;
       $count++;
    }
    else
    {
        print "Нет изображения для данного получателя $email \n";
        print $nosend_handle "Нет изображения для данного получателя $email \n";
    }
}
print "Отправленно $count писем\n";
close $send_handle;
close $nosend_handle;
close $fh;
#my @del = `rm auto.txt`;


#The END -------------------------------------------------------

sub CreateImage($$)
{
    my $image = $_[0];
    my $email = $_[1];

    my @result;

    my $cmdmerge = "convert $bk_fname $image -gravity north -geometry -210+190 -composite $name";
    @result = `$cmdmerge`;


   SendEmail("$name", $email);

}

sub SendEmail($$)
{
    my $image = $_[0];
    my $email = $_[1];

    #$subj = "=?UTF-8?B?".$subj."?=";
    my $msg = MIME::Lite->new(
                           From    => "$from",
                           To      => "$email",
                           Subject => "$subj",
                           Type    => 'multipart/mixed',
                   );

    my $body =  "<body>
    <img src=\"image002.gif\"/>
    <br>
    <br>
    <br>
    <img src=\"image006.gif\"/>
    </body>";

    $msg->attach( Type => 'text/html; charset=UTF-8',
                  Data => $body
              );


    $msg->attach( Type        => 'image/jpg',
                      Path        => "$image",
                      Filename    => "$image",
                      Disposition => 'attachment' );

    $msg->attach( Type        => 'image/jpg',
                      Path        => "image002.gif",
                      Filename    => "image002.gif",
                      Disposition => 'attachment' );
    $msg->attach( Type        => 'image/jpg',
                      Path        => "image004.gif",
                      Filename    => "image004.gif",
                      Disposition => 'attachment' );
    $msg->attach( Type        => 'image/jpg',
                      Path        => "image006.gif",
                      Filename    => "image006.gif",
                      Disposition => 'attachment' );

    $msg->send('smtp',
                    $smtpserver,
                    #SSL=>1,
                    #AuthUser=>"$user",
                    #AuthPass=>"$pass",
                    Debug=>0);

    print "Почта отправлена для $email с изображением : $image\n";
    print $send_handle "Почта отправлена для $email с изображением : $image\n";
