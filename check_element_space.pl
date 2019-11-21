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

my $output = connect_api("GetClusterCapacity");

my $stats = $output->{'result'}->{'clusterCapacity'};

my $total_space = $stats->{'maxUsedSpace'};
my $used_space = $stats->{'usedSpace'};
my $used_metadata = $stats->{'usedMetadataSpace'};
my $total_metadata = $stats->{'maxUsedMetadataSpace'};

my $full_output = connect_api("GetClusterFullThreshold");
my $full_stats = $full_output->{'result'};

my $warning_full = $full_stats->{'stage3BlockThresholdBytes'};

my $percent_space = $used_space/$warning_full*100;
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

#                        'clusterCapacity' => {
#                                               'peakIOPS' => 369,
#                                               'zeroBlocks' => 2372212520,
#                                               'maxProvisionedSpace' => '221231914467328',
#                                               'averageIOPS' => 7,
#                                               'usedMetadataSpace' => 3970572288,
#                                               'peakActiveSessions' => 38,
#                                               'maxIOPS' => 400000,
#                                               'usedSpace' => '50081558926',
#                                               'timestamp' => '2019-11-21T15:21:27Z',
#                                               'uniqueBlocks' => 17906302,
#                                               'maxUsedSpace' => '19204159242240',
#                                               'clusterRecentIOSize' => 5179,
#                                               'provisionedSpace' => '5359393570816',
#                                               'nonZeroBlocks' => 244678872,
#                                               'activeBlockSpace' => '94071187536',
#                                               'maxUsedMetadataSpace' => '1728374331800',
#                                               'totalOps' => 5767886433,
#                                               'maxOverProvisionableSpace' => '1106159572336640',
#                                               'uniqueBlocksUsedSpace' => '50065102307',
#                                               'activeSessions' => 38,
#                                               'snapshotNonZeroBlocks' => 0,
#                                               'currentIOPS' => 4,
#                                               'usedMetadataSpaceInSnapshots' => 3970572288
#                                             }

#GetClusterFullThreshold

#          'result' => {
#                        'stage4CriticalThreshold' => 1,
#                        'sumUsedMetadataClusterBytes' => 3970572288,
#                        'stage2AwareThreshold' => 3,
#                        'sumUsedClusterBytes' => '50080693091',
#                        'stage4BlockThresholdBytes' => '16225287536640',
#                        'sumTotalMetadataClusterBytes' => '1728374331800',
#                        'sliceReserveUsedThresholdPct' => 5,
#                        'stage3BlockThresholdBytes' => '15649241825280',
#                        'stage3BlockThresholdPercent' => 3,
#                        'maxMetadataOverProvisionFactor' => 5,
#                        'stage3LowThreshold' => 2,
#                        'metadataFullness' => 'stage1Happy',
#                        'blockFullness' => 'stage1Happy',
#                        'stage2BlockThresholdBytes' => '11424906608640',
#                        'fullness' => 'stage1Happy',
#                        'sumTotalClusterBytes' => '19201523712000',
#                        'stage5BlockThresholdBytes' => '19201523712000'
#                      },
