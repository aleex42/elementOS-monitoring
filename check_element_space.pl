#!/usr/bin/perl

# nagios: -epn
# --
# check_element_cluster_space - Check NetApp ElementOS Space usage
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

#my $output = connect_api("GetClusterCapacity");

my $output = connect_api("GetClusterFullThreshold");

my $stats = $output->{'result'}->{'clusterCapacity'};

print Dumper($output);

die;

my $total_space = $stats->{'maxUsedSpace'};
my $used_space = $stats->{'usedSpace'};
my $used_metadata = $stats->{'usedMetadataSpace'};
my $total_metadata = $stats->{'maxUsedMetadataSpace'};

my $percent_space = $used_space/$total_space*100;
$percent_space = sprintf("%.2f", $percent_space);

my $percent_metadata = $used_metadata/$total_metadata*100;
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

#$VAR1 = {
#          'maxIOPS' => 300000,
#          'maxOverProvisionableSpace' => '829619679252480',
#          'snapshotNonZeroBlocks' => 0,
#          'usedMetadataSpace' => 4024844288,
#          'usedMetadataSpaceInSnapshots' => 4024844288,
#          'usedSpace' => '49911346023',
#          'totalOps' => 5767293737,
#          'maxUsedSpace' => '14403119431680',
#          'zeroBlocks' => 2368649842,
#          'peakIOPS' => 52,
#          'peakActiveSessions' => 22,
#          'timestamp' => '2019-11-20T15:38:38Z',
#          'maxProvisionedSpace' => '165923935850496',
#          'activeSessions' => 22,
#          'currentIOPS' => 3,
#          'clusterRecentIOSize' => 0,
#          'averageIOPS' => 4,
#          'uniqueBlocks' => 18232112,
#          'activeBlockSpace' => '83870836944',
#          'maxUsedMetadataSpace' => '1296280748850',
#          'provisionedSpace' => '5359393570816',
#          'uniqueBlocksUsedSpace' => '49887316910',
#          'nonZeroBlocks' => 248241550
#        };


#GetClusterFullThreshold
#
#                        'maxMetadataOverProvisionFactor' => 5,
#                        'sliceReserveUsedThresholdPct' => 5,
#                        'stage3LowThreshold' => 2,
#                        'metadataFullness' => 'stage1Happy',
#                        'stage5BlockThresholdBytes' => '14401142784000',
#                        'stage4CriticalThreshold' => 1,
#                        'stage2BlockThresholdBytes' => '6768537108480',
#                        'blockFullness' => 'stage1Happy',
#                        'sumUsedMetadataClusterBytes' => 4024852480,
#                        'sumTotalMetadataClusterBytes' => '1296280748850',
#                        'stage3BlockThresholdPercent' => 3,
#                        'stage2AwareThreshold' => 3,
#                        'sumUsedClusterBytes' => '49913482661',
#                        'stage3BlockThresholdBytes' => '11136883752960',
#                        'fullness' => 'stage1Happy',
#                        'stage4BlockThresholdBytes' => '11568918036480',
#                        'sumTotalClusterBytes' => '14401142784000'
#
