#!/usr/bin/perl

# nagios: -epn
# --
# check_element_drives - Check NetApp ElementOS Drives
# Copyright (C) 2019 Alexander Krogloth, git@krogloth.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;
use warnings;

use Encode qw(encode_utf8);
use HTTP::Request ();
use JSON::MaybeXS qw(encode_json decode_json);
use Data::Dumper;
use LWP::UserAgent;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

sub connect_api {

    my $method = shift;

    my $browser = LWP::UserAgent->new;
    $browser->ssl_opts(SSL_verify_mode => 0);
    $browser->ssl_opts(verify_hostname => 0);

    my $json = {
        method  => $method,
     };

    my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
    my $encoded_data = encode_utf8(encode_json($json));

    my $req = HTTP::Request->new( POST => "https://$Hostname/json-rpc/11.3/", $header, $encoded_data );
    $req->authorization_basic( $Username, $Password );

    my $page = $browser->request( $req );

    my $content = $page->decoded_content;

    my $student = decode_json $content;

    return $student;

}

my $output = connect_api("ListDrives");

my $drives = $output->{'result'}->{'drives'};

my $failed = 0;
my $active = 0;
my $avail = 0;

foreach my $drive (@$drives){

    my $status = $drive->{'status'};

    if($status eq "failed"){
        $failed++;
    }

    if($status eq "active"){
        $active++;
    }

    if($status eq "available"){
        $avail++;
    }
}

if($failed ne 0){
    print "ERROR: $failed failed drives\n";
    exit 2;
} elsif($avail ne 0){
    print "ERROR: $avail available drives\n";
    exit 2;
} else { 
    print "OK: $active drives active\n";
    exit 0;
}
