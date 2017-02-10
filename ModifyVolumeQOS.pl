#!/usr/bin/env perl -w
use strict;
use warnings;
use MIME::Base64;
use JSON;
use Getopt::Long;
use REST::Client;
use Data::Dumper; 
 
my ($host, $user, $password, @objects, $verbose, $volumes, @volumes, $min, $max, $burst, $quiet);

GetOptions ("host=s" 			=> \$host,    
              "user=s"   		=> \$user,    
              "password=s"		=> \$password,
              "verbose"  		=> \$verbose,
              "volumes=s"		=> \$volumes,
              "min=i"			=> \$min,
              "max=i"			=> \$max,
              "burst=i"			=> \$burst,
              "quiet"			=> \$quiet,
              ) 
or die("Error in command line arguments\n");
#allow comma-separated lists of values as well as multiple occurrences
@objects = split(/,/,join(',',@objects));
 
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

my $client = REST::Client->new( host => 'https://'.$host );
$client->getUseragent()->ssl_opts( SSL_verify_mode => 0 );
my $encoded_auth = encode_base64("$user:$password", '');

#Reconcile overloaded input
if ( $volumes =~ /-/  ) 	#range, e.g. 1-42
{
	(my $first, my $last) = split ( /\-/, $volumes );
	@volumes = ($first .. $last);
}
elsif ( $volumes =~ /,/ ) 	#comma separated list, e.g. 1,2,3
{
	@volumes = split /,/, $volumes;
}
else
{
	$volumes[0]=$volumes;	#only one specified, e.g. 42
}
 
foreach my $targetVol ( @volumes )
{
		print "PRE: "unless $quiet; getQos ($targetVol) unless $quiet;
		setQos ($targetVol);
		print "POST: "unless $quiet; getQos ($targetVol) unless $quiet;
} 
sub setQos { 
	my $vol = shift;
	my $params = {
		'method'		=> 'ModifyVolume',
		'attributes'	=>	'',
		'params' 		=>	{
			'volumeID'		=> $vol,
			'qos'			=>	{
				'minIOPS'		=>	$min,
				'maxIOPS'		=>	$max,
				'burstIOPS'		=>	$burst,
			}
		}
	}; 
	
	$client->POST('/json-rpc/8.0', encode_json($params),
	              {'Authorization' => "Basic $encoded_auth",
	               'Accept' => 'application/json'});
	 
#	print "HTTP Response Code for volume $vol: ", $client->responseCode(), "\n";
	my $response = from_json($client->responseContent());
	if ( $response->{'error'}{'code'} )
		{
			print "Error code: ", $response->{'error'}{'code'} , ". ", "Message: ", $response->{'error'}{'message'},"\n";
		}
	if ($verbose)
	{
#		print Dumper ( $client->responseContent() );
		foreach ( $client->responseHeaders() ) {
		   print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
		 }
	}
}
sub getQos {
	my $targetVol = shift;
	#Establish connection 
	$client->GET('/json-rpc/8.0/?method=ListVolumes',
             	{'Authorization' => "Basic $encoded_auth",
              	'Accept' => 'application/json'});

#Decode
	my $response = decode_json ( $client->responseContent() );

#Display
	my @vols = @{ $response->{'result'}{'volumes'} };
	foreach ( @vols )
	{
		if ($targetVol == $_->{'volumeID'} )
		{
			print "vol:$_->{'volumeID'}. ";
			print "min: $_->{'qos'}{'minIOPS'}. ";
			print "max: $_->{'qos'}{'maxIOPS'}. ";
			print "burst: $_->{'qos'}{'burstIOPS'}\n";
		}
	}
}
