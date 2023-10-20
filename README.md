# check_scaleway_server
This is a Nagios check that uses Scaleway's REST API to get server state
https://www.scaleway.com/en/developers/api/instance/
### prerequisites

This script uses theses libs : REST::Client, Data::Dumper, Monitoring::Plugin, JSON, Readonly

to install them type :

```bash
sudo cpan REST::Client Data::Dumper  Monitoring::Plugin JSON Readonly 
```

### Use case

```bash
check_scaleway_server.pl 1.0.0

This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).

check_scaleway_server.pl is a Nagios check that uses Scaleway s REST API to get server state

Usage: check_scaleway_server.pl  -T <Token>  -z <Scaleway zone> -N <server name> | -i <id>

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html
   for usage and examples.
 -T, --Token=STRING
 Token for api authentication
 -N, --name=STRING
   instance name
 -i, --id=STRING
   instance id
 -a, --apiversion=string
  Scaleway API version
 -L, --listInstance
   Autodiscover instance
 -z, --zone=STRING
  Scaleway zone
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 30)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```


```bash
#Get servers list 
./check_scaleway_bdd.pl -T <Token> -r fr-par-1 -L
#get server state
./check_scaleway_bdd.pl -T <Token>  -z fr-par-1  -N <server_name>
./check_scaleway_bdd.pl -T <Token> -z fr-par-1  -i <uid>
```

