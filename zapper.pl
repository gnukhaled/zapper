#!/usr/bin/env perl
#############################################################################
# Description: A tool to debug the Data Domain Filesystem
# Parameters : See the Usage() subroutine
# Returns    : 0 on Success, 1 on Error.
# Author     : Khaled Ahmed: khaled.gnu@gmail.com 
# License    : GPL <http://www.gnu.org/licenses/gpl.html>
#############################################################################

use strict;
use Getopt::Long;
use Cwd 'abs_path';
use DateTime qw();
use File::Basename;
use File::ReadBackwards;
use Time::Piece;
use DateTime::Format::Strptime;
use POSIX;

our $VERSION 	     = 0.1;
our $absolute_path   = dirname(abs_path($0))."/";
our $bundle_path;
our $opt_help;
our $date_from = 0;
our $date_to = 0;

GetOptions(
'bundle=s' => \$bundle_path, # The --bundle /path option
'b=s'      => \$bundle_path, # -b same as --bundle
'from=s'   => \$date_from,   # --from <date>
'to=s'     => \$date_to,     # --to <date>
'help!'    => \$opt_help,    # --help
'h!'	   => \$opt_help     # -h
) or die "Incorrect Usage!\n";


sub usage() 
{

}

# Is the support bundle a valid one?
sub is_valid_bundle()
{
	if (-e "$bundle_path/ddr/var/log/debug/ddfs.info") {
		return 1;
	}else {
		return 0;
	}
}

# Return a list of ddfs.info* files from the bundle
sub get_ddfsinfo_files() 
{
	my @ddfsinfo_files;

	opendir(DEBUGDIR, "$bundle_path/ddr/var/log/debug") or die 
		"Error opening the bundle debug directory $!\n";
	my @log_files = readdir(DEBUGDIR);
	closedir(DEBUGDIR);
	foreach my $file (@log_files) {
		if ($file =~ /ddfs.info*/){
			push(@ddfsinfo_files, $file);
		}
	}

	my @sorted = map $_->[1], sort { $a->[0] <=> $b->[0] } 
		     map [/(\d+)/, $_], @ddfsinfo_files;

	undef @ddfsinfo_files;
	shift(@sorted);
	unshift(@sorted, "ddfs.info");
	return @sorted;

}

sub content_of_file($)
{
	my $file = shift;
	open(FD, "$bundle_path/ddr/var/log/debug/$file") or die
                "Error opening $file $!\n";
        my @filecontent = <FD>;
        close(FD);
	return @filecontent;
}

sub get_list_of_dates(@) 
{
	my @array = @{$_[0]};
	my @dates;
	
	foreach(@array) {
		#if ($_ =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})*/) {
		if ($_ =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2}).*\S\(*tid/) {
			push(@dates, extract_date_str($_));
		}
	}
	return @dates;
}

# Check if any of the ddfs.info file is a .gz
sub is_compressed($)
{
	my $filename = shift;
	my $ext = substr($filename, -3);
	
	if ($ext eq ".gz") {
		return 1;
	}else {
		return 0;
	}
}

sub search_date_index($ @) 
{
	my ($date, @array) = @_;
	my $sidx;
	my $eidx;
	my $cidx;
	my $index;
	my $loopcond = 1;
	my $lcmp;
	my $hcmp;

	$sidx = 0;
	$eidx = scalar(@array)-1;
	$cidx = ceil(($eidx - $sidx) / 2);	
	#$cidx = floor(($eidx - $sidx) / 2);	

	
	my $sidx_date = str_to_date($array[$sidx],0);
        my $eidx_date = str_to_date($array[$eidx],0);
        my $cidx_date = str_to_date($array[$cidx],0);
	
	print "\n\nDBG: before WHILE\n\n";
	print "sidx = $sidx, cidx = $cidx, eidx = $eidx\n";
	print "sidx_date = $sidx_date\n";
	print "cidx_date = $cidx_date\n";
	print "eidx_date = $eidx_date\n";


	if (($date == $sidx_date) || ($date == $eidx_date)){
			print "PASSED DATE --= $date\n";
			print "RETURNED DATE --= $date\n";
			$loopcond = 0;
			#return $date;
	}

	while ($loopcond){		

		print "\n\nDBG: IN WHILE\n\n";
                print "START = $sidx, CENTER = $cidx, END = $eidx\n";
                print "start_date = $sidx_date\n";
                print "center_date = $cidx_date\n";
                print "end_date = $eidx_date\n\n";

		if (($date > $sidx_date) && ($date < $cidx_date)){
			$eidx = $cidx;
			$cidx = ceil(($eidx - $sidx) / 2);
			$eidx_date = str_to_date($array[$eidx],0);
        		$cidx_date = str_to_date($array[$cidx],0);
        		$sidx_date = str_to_date($array[$sidx],0);
=pod
			if ($date <= $cidx_date){
                        	print "PASSED DATE = $date\n";
                        	print "RETURNED DATE (UPPER HALF) = $cidx_date\n";
                        	print "------> CIDX = ".$cidx."\n\n";
                        	$loopcond = 0;
                	}
=cut
		}elsif (($date > $cidx_date) && ($date < $eidx_date)){
			$sidx = $cidx;
			$cidx = ceil(($eidx - $sidx) / 2);
			$sidx_date = str_to_date($array[$sidx],0);
        		$cidx_date = str_to_date($array[$cidx],0);
        		$eidx_date = str_to_date($array[$eidx],0);
=pod
			if ($date >= $cidx_date){
                                print "PASSED DATE = $date\n";
                                print "RETURNED DATE (LOWER HALF) = $cidx_date\n";
                                print "------> CIDX = ".$cidx."\n\n";
                                $loopcond = 0;
                        }
=cut

		}
		if ($cidx_date == $date){
                        print "PASSED DATE = $date\n";
                        print "RETURNED DATE = $cidx_date\n";
                        print "------> CIDX = ".$cidx."\n";
                        $loopcond = 0;
                }
	}
}

sub get_year($ $) {
	
	my ($date, $file) = @_;
	my $yindex;

	my $latest_date = get_date_latest_in_file_str("ddfs.info");
	my ($latest_month, $lday, $lhour, $lminute, $lsecond)
                = $latest_date =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})/ or die;
	my ($passed_month, $pday, $phour, $pminute, $psecond)
                = $date =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})/ or die;
		
	if ($passed_month > $latest_month){
		$yindex = -1;
	}else {
		$yindex = 0;
	}		

	return $yindex;
}

sub extract_date_str($)
{
	my $line = shift;
	my $str = substr($line, 0, 14);
	return $str;
}

sub date_to_str($) {

	my $date = shift;
	my $str = $date->strftime("%m/%d %H:%M:%S");
	return $str;
}

sub str_to_date($ $)
{
	my ($date, $y) = @_;
	my $year;
	
	my $curr_date = DateTime->now();
	my $future_date;

	if ($y == 0) {
		$year = $curr_date->year();
	}else {
		$future_date = $curr_date->add(years => $y);
		$year = $future_date->year();
	}

	my ($month, $day, $hour, $minute, $second) 
		= $date =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})/ or die "$!\n";

	my $dt = DateTime->new(
		year      => $year,
    		month     => $month,
    		day       => $day,
    		hour      => $hour,
    		minute    => $minute,
    		second    => $second,
    		time_zone => 'local',
    	);

	return $dt;
}

sub get_date_latest_ever()
{
	my $latest_date = get_date_latest_in_file_str("ddfs.info");
	my $year_index = get_year($latest_date, "ddfs.info");
	
	return str_to_date($latest_date, $year_index);
}

sub get_date_earliest_ever()
{
	my @files = get_ddfsinfo_files();
	my $lastelem = $#files;
	my $oldestfile = $files[$lastelem];

	return str_to_date(get_date_earliest_in_file_str($oldestfile),
				 get_year(get_date_earliest_in_file_str($oldestfile), 
								  $oldestfile));
}

sub get_date_latest_in_file_str($)
{
	
	my $file = shift;
	
	my $backwards = File::ReadBackwards->new
			("$bundle_path/ddr/var/log/debug/$file");
	my $last_ddfsinfo_line;
	do {
    		$last_ddfsinfo_line = $backwards->readline;
	} until !defined $last_ddfsinfo_line 
			|| ($last_ddfsinfo_line =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})*/
		        && $last_ddfsinfo_line =~ /\S/) ;

	my $date = extract_date_str($last_ddfsinfo_line);
	return  $date;
}

sub get_date_earliest_in_file_str($)
{
	my $file = shift;

	open(FD, "$bundle_path/ddr/var/log/debug/$file") or die
		"Error opening $file $!\n";
	my $line;
	while($line = <FD>) {
		if ($line =~ /^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})*/){
			last;
		}
	}
	close(FD);
	my $date = extract_date_str($line);
	return $date;
}

sub get_date_latest_in_file($)
{
	my $file = shift;
	my $datestr = get_date_latest_in_file_str($file);
	my $yearindex = get_year($datestr, $file);
	return str_to_date($datestr, $yearindex); 
}

sub get_date_earliest_in_file($)
{
        my $file = shift;
        my $datestr = get_date_earliest_in_file_str($file);
        my $yearindex = get_year($datestr, $file);
        return str_to_date($datestr, $yearindex);
}

sub get_dateto_desired()
{
	my ($day, $month, $year, $hour, $minute, $second) = $date_to
	    =~ /^([0-9]{2})\-([0-9]{2})\-([0-9]{4})*:*([0-9]{2})*:*([0-9]{2})*:*([0-9]{2})/ 
		 or die;

	my $dt = DateTime->new(
                year      => $year,
                month     => $month,
                day       => $day,
                hour      => $hour,
                minute    => $minute,
                second    => $second,
                time_zone => 'local',
        );

	my $endfile;	
	my $desired_date;
	my $cmp;
	my $line_date_str;
	my @files = get_ddfsinfo_files();
	my @filecontent;	

	foreach my $file (@files){
		if ($dt >= get_date_earliest_in_file($file) && 
		    $dt <= get_date_latest_in_file($file)) {
			$endfile = $file;
			last;
		}
	}

	my @filecontent = content_of_file($endfile);

	foreach(@filecontent) {		

		if (/^([0-9]{2})\/([0-9]{2})\s([0-9]{2}):([0-9]{2}):([0-9]{2})*/){
			$line_date_str = extract_date_str($_);
			$desired_date = str_to_date($line_date_str, 
					get_year($line_date_str, $endfile));
			$cmp = DateTime->compare($desired_date, $dt);
			if ($cmp >=  0) {
				return $desired_date;	
			}
		}
	}
	return;
}

# Main function, Pardon me :-)
sub main()
{
	my $valid_bundle = is_valid_bundle();
	if (not $valid_bundle) {
		print("Invalid Bundle\n");
		exit(1);
	}
	

	my @aaa = content_of_file("ddfs.info.20");
	my @bbb = get_list_of_dates(\@aaa);
        # Near Beginning
	search_date_index(str_to_date("01/25 03:21:27",0), @bbb);
	
	# Near End
	#search_date_index(str_to_date("01/26 20:21:02",0), @bbb);
}

main();

__END__

