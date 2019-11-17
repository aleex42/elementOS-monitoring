#!/usr/bin/perl

# nagios: -epn
# --
# check_element_cluster_performance - Check ElementOS Cluster Performance
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
    'latency=f' => \my $Latency,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option --latency needed!') unless $Latency;

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

my $output = connect_api("ListVolumeStatsByVolume");

my $volumes = $output->{'result'}->{'volumeStats'};

my $slow = 0;

my $latency_us = $Latency*1000;

foreach my $volume (@$volumes){

    my $latency = $volume->{'latencyUSec'};
    

    if($latency > $latency_us){
        $slow++;
    }
}

if($slow ne 0){
    print "WARNING: volumes with high latency over $Latency ms\n";
    exit 2;
} else { 
    print "OK: no latency over $Latency ms\n";
    exit 0;
}
