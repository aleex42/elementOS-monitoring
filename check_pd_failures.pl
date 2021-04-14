#!/usr/bin/perl

# nagios: -epn
# --
# check_pd_failures - Check NetApp ElementOS ProtectionDomain Failures
# Copyright (C) 2021 Alexander Krogloth, git@krogloth.de
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

my $output = connect_api("ListProtectionDomainLevels");

my $result = $output->{'result'};

my $levels = $result->{'protectionDomainLevels'};

my $resiliency_failures_blocks;
my $resiliency_failures_metadata;
my $tolerance_failures_blocks;
my $tolerance_failures_metadata;

foreach my $level (@$levels){

	my $type = $level->{'protectionDomainType'};
	
	if($type eq "custom"){
	
		$resiliency_failures_blocks = $level->{'resiliency'}->{'protectionSchemeResiliencies'}[0]->{'sustainableFailuresForBlockData'};
		$resiliency_failures_metadata = $level->{'resiliency'}->{'protectionSchemeResiliencies'}[0]->{'sustainableFailuresForMetadata'};
		
		$tolerance_failures_blocks = $level->{'tolerance'}->{'protectionSchemeTolerances'}[0]->{'sustainableFailuresForBlockData'};
		$tolerance_failures_metadata = $level->{'tolerance'}->{'protectionSchemeTolerances'}[0]->{'sustainableFailuresForMetadata'};
	}

}

if(($tolerance_failures_blocks != 1) || ($tolerance_failures_metadata != 1)){
	print "CRITICAL: cluster not failure tolerant anymore\n";
	exit 2;
} elsif(($resiliency_failures_blocks != 1) || ($resiliency_failures_metadata != 1)){
	print "WARNING: cluster not resiliant anymore\n";
	exit 1;
} else {
	print "OK: cluster failure tolerant and resiliant\n";
	exit 0;
}
