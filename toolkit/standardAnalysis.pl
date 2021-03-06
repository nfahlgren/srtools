#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
use POSIX qw( ceil floor);
use DBI;
use Config::Tiny;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use CommonFunctions qw(parseListToArray);

#########################################################
# Start Variable declarations                           #
#########################################################

my (%opt, @list, $outfile, $species, $confFile, %table, $sth, %rpm);

getopts('l:o:s:c:hR', \%opt);
var_check();

# Get configuration settings
my $Conf = Config::Tiny->read($confFile);
my $conf = $Conf->{$species};
my $file = $conf->{'annotated_seqs'};

unless (-e $file) {
	print STDERR " The annotated sequences file $file does not exist!\n\n";
	exit 1;
}

# Connect to the SQLite database
my $dbh = DBI->connect("dbi:SQLite:dbname=$conf->{'db'}","","");
if ($opt{'R'}) {
	$sth = $dbh->prepare('SELECT * FROM `libraries` WHERE `library_id` = ?');
	foreach my $id (@list) {
		$sth->execute($id);
		my $row = $sth->fetchrow_hashref;
		if ($row->{'total_reads'} > 0) {
			$rpm{$id} = 1000000 / $row->{'total_reads'};
		} else {
			print STDERR " Total reads for library $id not set in $conf->{'db'}.libraries\n\n";
			exit 1;
		}
	}	
}

#########################################################
# End Variable declarations                             #
#########################################################

#########################################################
# Start Main body of Program                            #
#########################################################

print STDERR " Getting reads... \n";

$sth = $dbh->prepare('SELECT * FROM `reads` WHERE `library_id` = ?');
foreach my $library_id (@list) {
	print STDERR "      getting reads for library $library_id... ";
	$sth->execute($library_id);
	while(my $row = $sth->fetchrow_hashref){
    if ($opt{'R'}) {
      $row->{'reads'} *= $rpm{$library_id};
    }
		$table{$row->{'sid'}}->{$library_id} = $row->{'reads'};
	}
	print STDERR "done\n";
}


print STDERR " Reading sequences... ";
$sth = $dbh->prepare('SELECT * FROM `sequences` WHERE `seq` = ?');
open (OUT, ">$outfile") or die "Cannot open $outfile: $!\n\n";
print OUT "name\tseq\t".join("\t", @list)."\n";
open (IN, $file) or die " Cannot open $file: $!\n\n";
while (my $line = <IN>) {
  chomp $line;
	my ($name, $seq) = split /\t/, $line;
	print OUT $name."\t".$seq;
	$sth->execute($seq);
	my $result = $sth->fetchrow_hashref;
	if ($result) {
		foreach my $library_id (@list) {
			if (exists($table{$result->{'sid'}}->{$library_id})) {
				print OUT "\t$table{$result->{'sid'}}->{$library_id}";
			}	else {
				print OUT "\t0";
			}
		}
	} else {
		foreach my $library_id (@list) {
			print OUT "\t0";
		}
	}
	print OUT "\n";
}

close IN;
close OUT;
print STDERR "done\n";
exit;


#########################################################
# Start Subroutines                                     #
#########################################################

#########################################################
# Start of Varriable Check Subroutine "var_check"       #
#########################################################

sub var_check {
	if ($opt{'h'}) {
		var_error();
	}
	if ($opt{'l'}) {
		@list = parseListToArray($opt{'l'});
	} else {
		var_error();
	}
	if ($opt{'o'}) {
		$outfile = $opt{'o'};
	} else {
		var_error();
	}
	if ($opt{'c'}) {
		$confFile = $opt{'c'};
	} else {
		var_error();
	}
	if ($opt{'s'}) {
		$species = $opt{'s'};
	} else {
		var_error();
	}
}

#########################################################
# End of Varriable Check Subroutine "var_check"         #
#########################################################

#########################################################
# Start of Varriable error Subroutine "var_error"       #
#########################################################

sub var_error {
	print STDERR "\n  Description:\n";
	print STDERR "  This script will generate a multi-library read count table for specific sequences.\n\n";
	print STDERR "  As part of a 'standard analysis' of small RNA libraries, known simple features are quantified (e.g. miRNA).\n\n";
	print STDERR "  Usage:\n";
	print STDERR "  standardAnalysis.pl -l <library_ids> -o <output file> -c <conf_file> -s <species>\n";
	print STDERR "  -l   The library ID's to use.\n";
	print STDERR "               example: -l '1-5'\n";
	print STDERR "               example: -l '1,7,11'\n";
	print STDERR "               example: -l '1-5,7,9-11'\n";
	print STDERR "\n";
	print STDERR "  -o   The output filename.\n\n";
	print STDERR "  -c   The configuration file.\n\n";
	print STDERR "  -s   The species.\n\n";
  print STDERR "  -R   Normalize reads (Reads/Million). Default, do not normalize.\n\n";
	print STDERR "\n\n\n";
	exit 0;
}

#########################################################
# End of Varriable error Subroutine "var_error"         #
#########################################################
