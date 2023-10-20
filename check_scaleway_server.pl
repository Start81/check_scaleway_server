#!/usr/bin/perl -w
#=============================================================================== 
# Script Name   : check_scaleway_server.pl
# Usage Syntax  : check_scaleway_server.pl -T <Token>  -z <Scaleway zone> -N <server name> | -i <id> 
# Version       : 1.0.0
# Last Modified : 30/06/2023
# Modified By   : J DESMAREST (Start81)
# Description   : This is a Nagios check that uses Scaleway s REST API to get server state
# Depends On    :  Monitoring::Plugin Data::Dumper JSON REST::Client Readonly File::Basename
# 
# Changelog: 
#    Legend: 
#       [*] Informational, [!] Bugfix, [+] Added, [-] Removed 
#  - 30/06/2023| 1.0.0 | [*] First release
#===============================================================================

use strict;
use warnings;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use Monitoring::Plugin;
use Data::Dumper;
use REST::Client;
use JSON;
use utf8; 
#use LWP::UserAgent;
use Readonly;
use File::Basename;
Readonly our $VERSION => "1.0.0";
my %state  =("running"=>0, 
"stopped"=>2,
"stopped in place"=>2, 
"starting"=>0, 
"stopping"=>2, 
"locked"=>2 
);
my %volume_state =("available"=>0,
"snapshotting"=>0,
"error"=>2,
"resizing"=>0,
"saving"=>0,
"hotsyncing"=>0
);
my $me = basename($0);
my $o_verb;
sub verb { my $t=shift; print $t,"\n" if ($o_verb) ; return 0}
my $np = Monitoring::Plugin->new(
    usage => "Usage: %s  -T <Token>  -z <Scaleway zone> -N <server name> | -i <id> \n",
    plugin => $me,
    shortname => " ",
    blurb => "$me is a Nagios check that uses Scaleway s REST API to get server state ",
    version => $VERSION,
    timeout => 30
);
$np->add_arg(
    spec => 'Token|T=s',
    help => "-T, --Token=STRING\n"
          . ' Token for api authentication',
    required => 1
);
$np->add_arg(
    spec => 'name|N=s',
    help => "-N, --name=STRING\n"
          . '   instance name',
    required => 0
);
$np->add_arg(
    spec => 'id|i=s',
    help => "-i, --id=STRING\n"
          . '   instance id',
    required => 0
);
$np->add_arg(
    spec => 'apiversion|a=s',
    help => "-a, --apiversion=string\n"
          . '  Scaleway API version',
    required => 1,
    default => 'v1'
);
$np->add_arg(
    spec => 'listInstance|L',
    help => "-L, --listInstance\n"  
          . '   Autodiscover instance',
);
$np->add_arg(
    spec => 'zone|z=s',
    help => "-z, --zone=STRING\n"
          . '  Scaleway zone',
    required => 1
);

my @criticals = ();
my @warnings = ();
my @ok = ();
$np->getopts;
my $o_token = $np->opts->Token;
my $o_apiversion = $np->opts->apiversion;
my $o_list_servers = $np->opts->listInstance;
my $o_id = $np->opts->id;
$o_verb = $np->opts->verbose;
my $o_zone = $np->opts->zone;
my $o_timeout = $np->opts->timeout;
my $o_name = $np->opts->name;
#Check parameters
if ((!$o_list_servers) && (!$o_name) && (!$o_id)) {
    $np->plugin_die("instance name or id missing");
}
if (!$o_zone)
{
    $np->plugin_die("region missing");
}
if ($o_timeout > 60){
    $np->plugin_die("Invalid time-out");
}

#Rest client Init
my $client = REST::Client->new();
$client->setTimeout($o_timeout);
my $url ;
#Header
$client->addHeader('Content-Type', 'application/json;charset=utf8');
$client->addHeader('Accept', 'application/json');
$client->addHeader('Accept-Encoding',"gzip, deflate, br");
#Add authentication
$client->addHeader('X-Auth-Token',$o_token);
my $id; #id servers
my $i; 
my $max_connexions = 0;
my $msg = "";
my $pages =1;
if ((!$o_id)){
    #https://api.scaleway.com/instance/v1/zones/fr-par-1/servers?page=$pages
    $url = "https://api.scaleway.com/instance/v1/zones/$o_zone/servers?page=$pages";
    my %servers;
    my $instance;
    my $servers_list_json;
    do {
        verb($url);
        $client->GET($url);
        if($client->responseCode() ne '200'){
            $np->plugin_exit('UNKNOWN', " response code : " . $client->responseCode() . " Message : Error when getting servers list ". $client->{_res}->decoded_content );
        }
        my $rep = $client->{_res}->decoded_content;
        $servers_list_json = from_json($rep);
        verb(Dumper($servers_list_json));
        $i = 0;
        while (exists ($servers_list_json->{'servers'}->[$i])){
            $instance = q{};
            $id = q{};
            $instance = $servers_list_json->{'servers'}->[$i]->{'name'};
            $id = $servers_list_json->{'servers'}->[$i]->{'id'}; 
            $servers{$instance}=$id;
            $i++;
        }
        $pages++;
    } while (exists ($servers_list_json->{'servers'}->[49])); #50 items par page par defaut
    my @keys = keys %servers;
    my $size;
    $size = @keys;
    verb ("hash size : $size\n");
    if (!$o_list_servers){
        #If instance name not found
        if (!defined($servers{$o_name})) {
            my $list="";
            my $key ="";
            #format a instance list
            foreach my $key (@keys) {
                $list = "$list $key" 
            }
            $np->plugin_exit('UNKNOWN',"instance $o_name not found the servers list is $list"  );
        }
    } else {
        #Format autodiscover Xml for centreon
        my $xml='<?xml version="1.0" encoding="utf-8"?><data>'."\n";
        foreach my $key (@keys) {
            $xml = $xml . '<label name="' . $key . '"id="'. $servers{$key} . '"/>' . "\n"; 
        }
        $xml = $xml . "</data>\n";
        print $xml;
        exit 0;
    }
    # inject id in api url
    verb ("Found id : $servers{$o_name}\n");
    $id = $servers{$o_name};
};

$id = $o_id if (!$id);
verb ("id = $id\n") if (!$id);

#https://api.scaleway.com/rdb/v1/regions/{region}/servers/{instance_id}
#Getting instance info
my $a_server_url = "https://api.scaleway.com/instance/$o_apiversion/zones/$o_zone/servers/$id";
my $server_json;
my $rep_server ;
verb($a_server_url);
$client->GET($a_server_url);
if($client->responseCode() ne '200'){
    $np->plugin_exit(UNKNOWN, " response code : " . $client->responseCode() . " Message : Error when getting server ". $client->{_res}->decoded_content );
}
$rep_server = $client->{_res}->decoded_content;
$server_json = from_json($rep_server);
verb(Dumper($server_json));
my $status = $server_json->{'server'}->{'state'};
my $name =  $server_json->{'server'}->{'name'};
$i=0;
my $cpt_storage=0;
while(exists $server_json->{'server'}->{'volumes'}->{"$i"}){
    my $storage_name= $server_json->{'server'}->{'volumes'}->{"$i"}->{'name'};
    my $storage_id= $server_json->{'server'}->{'volumes'}->{"$i"}->{'id'};
    my $storage_status= $server_json->{'server'}->{'volumes'}->{"$i"}->{'state'};
    $msg = " volume $storage_name id : $storage_id state is $status ";
    if (!exists $volume_state{$storage_status} ){
        push( @criticals," State $storage_status is UNKNOWN for volume $storage_name id : $storage_id"); 
    } else {
        push( @criticals,$msg) if ($volume_state{$storage_status}== 2);
    }
    push( @criticals,$msg) if ($volume_state{$storage_status}== 2);
    $cpt_storage++ if ($volume_state{$storage_status} == 0);
    $i++;
}

$msg ="server status $status name $name id = $id  $cpt_storage volume(s) ok ";
#If state in not defined in %state then return critical
if (!exists $state{$status} ){
    push( @criticals," State $status is UNKNOWN for server $name"); 
} else {
    push( @criticals,$msg) if ($state{$status}== 2);
}
push( @criticals,$msg) if ($state{$status}== 2);


$np->plugin_exit('CRITICAL', join(', ', @criticals)) if (scalar @criticals > 0);
$np->plugin_exit('WARNING', join(', ', @warnings)) if (scalar @warnings > 0);
$np->plugin_exit('OK', $msg );
