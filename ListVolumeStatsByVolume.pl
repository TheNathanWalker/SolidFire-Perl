#!/usr/bin/env perl -w
use strict;
use warnings;
use MIME::Base64;
use JSON;
use Data::Dumper;
use Getopt::Long;
#use diagnostics -verbose; 
use REST::Client;
 
my ($host, $user, $password, @objects, $verbose, @volumes, $iterations, $wait);

GetOptions ("host=s" 			=> \$host,    
              "user=s"   		=> \$user,    
              "password=s"		=> \$password,
              "verbose"  		=> \$verbose,
              "volumes"			=> \@volumes,
              "objects=s"		=> \@objects,
              "iterations=i"	=> \$iterations,
              "wait=i"			=> \$wait,
              ) 
or die("Error in command line arguments\n");
#allow comma-separated lists of values as well as multiple occurrences
@objects = split(/,/,join(',',@objects));
#print join(", ", @objects), "\n";
 
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

my $client = REST::Client->new( host => 'https://'.$host );
$client->getUseragent()->ssl_opts( SSL_verify_mode => 0 );
my $encoded_auth = encode_base64("$user:$password", '');

#Establish connection 
$client->GET('/json-rpc/8.0/?method=ListVolumeStatsByVolume',
             {'Authorization' => "Basic $encoded_auth",
              'Accept' => 'application/json'});

#Decode 
my $response = decode_json ( $client->responseContent() );

#Display
my @vols = @{ $response->{'result'}{'volumeStats'} };
foreach my $volume ( @vols )
{
	print "Volume:$volume->{'volumeID'}";
#Enumerate all given -object target inputs, e.g. writeOps,actualIOPS,volumeSize,volumeUtilization,timestamp
	foreach my $obj (  @objects )
	{
		print  ", $obj:", $volume->{"$obj"};
	}	
	print "\n";
}

print 'HTTP Response Code: ' . $client->responseCode() . "\n";
if ($verbose)
{
	print 'Response: ' . $client->responseContent() . "\n";
	foreach ( $client->responseHeaders() ) {
	   print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
	 }
}

