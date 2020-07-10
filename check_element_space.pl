#!/usr/bin/perl

# nagios: -epn
# --
# check_element_cluster_space - Check NetApp ElementOS Space usage
# 
# error threshold is used. warning/critical with percent of the error threshold
#
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
    'warning=i' => \my $Warning,
    'critical=i' => \my $Critical,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option --warning needed!') unless $Warning;
Error('Option --critical needed!') unless $Critical;

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

my $output = connect_api("GetClusterFullThreshold");

my $full = $output->{'result'};

my $block_error = $full->{'stage4BlockThresholdBytes'};
my $block_used = $full->{'sumUsedClusterBytes'};
my $meta_used = $full->{'sumUsedMetadataClusterBytes'};
my $meta_total = $full->{'sumTotalMetadataClusterBytes'};

my $percent_space = $block_used/$block_error*100;
$percent_space = sprintf("%.2f", $percent_space);

my $percent_metadata = $meta_used/$meta_total*100;
$percent_metadata = sprintf("%.2f", $percent_metadata);

if(($percent_space > $Critical ) || ($percent_metadata > $Critical)){
    print "CRITICAL: cluster space usage (Block: $percent_space % / Meta: $percent_metadata %)\n";
    exit 2;
} elsif(($percent_space > $Warning ) || ($percent_metadata > $Warning)){
    print "WARNING: cluster space usage (Block: $percent_space % / Meta: $percent_metadata %)\n";
    exit 1;
} else { 
    print "OK: cluster space usage (Block: $percent_space % / Meta: $percent_metadata %)\n";
    exit 0;
}
