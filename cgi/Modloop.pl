#!/usr/bin/perl -w

###############################################################
#                                                             #
# on-line loop modeling script, including parallel processing #
# with codine system                                          #
# copyright Andras Fiser, March 22, 2002,                     #
# andras@viol.compbio.ucsf.edu                                 #
# Rockefeller University, New York, NY 10021                  #
#                                                             #
###############################################################

use Cwd;
use CGI qw/:standard /;
use strict;

my $tmp="/diva2/home/andras/html/tmploop/";

################################
###some defaults
my $number_of_users=10;         #simultaneous users

################################
### get parameters from html

my $user_pdb_name = param('user_pdb2');         # uploaded file name
my $iteration     = param('iteration')||300;     # number of models
my $user_name     = param('user_name');         # root name
my $email         = param('email');             # users e-mail
my $modkey        = param('modkey');            # passwd 
my $szoveg        = param('text');              # selected loops

################################
###check and fix iteration param
if ($iteration < 1 || $iteration > 400) {
  $iteration = 400;
}


################################
###check and fix loop name 
$user_name =~ s/\s+//g;

check_modeller_key($modkey);

check_loop_selection($szoveg);

check_pdb_name($user_pdb_name);

###############################
#### extract loops
$szoveg =~ tr/a-z/A-Z/;    # capitalize
$szoveg =~ s/\s+//g;       # remove spaces

my @loop_data=split (/:/,$szoveg);

my $i=0;
my $total_res=0;
my (@start_res, @start_id, @end_res, @end_id);
while ($loop_data[$i*4] ne "")
  {
    $start_res[$i]=$loop_data[$i*4];
    $start_id[$i]=$loop_data[$i*4+1];
    $end_res[$i]=$loop_data[$i*4+2];
    $end_id[$i]=$loop_data[$i*4+3];
    $total_res=$total_res+($end_res[$i]-$start_res[$i]); #all the selected residues
    
    ################################
    # too long loops rejected
    if ((($end_res[$i]-$start_res[$i]) > 20) || ($start_id[$i] ne $end_id[$i]) || (($end_res[$i]-$start_res[$i])<0) || ($start_res[$i] eq "") || ($end_res[$i] eq ""))
      {
       print header(), start_html("MODLOOP ERROR"),
       h2({-align=>'CENTER'},font({-color=>"#AA0000"},"ERROR!")),
       hr,
       h4({-align=>'CENTER'},font({-color=>"#AA0000"},"The loop selected is too long (>20 residues) or shorter than 1 residue or not selected properly (syntax problem?)")),
       h4({-align=>'CENTER'},font({-color=>"#AA0000"},"starting position $start_res[$i]:$start_id[$i], ending position: $end_res[$i]:$end_id[$i]")),
       h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Please correct! Try again!")),
       end_html(); exit;       
     }
    ######################
    $i++; # next loop
  }


################################
# too many residues rejected
if ($total_res > 20) 
  {
         print header(), start_html("MODLOOP ERROR"),
         h2({-align=>'CENTER'},font({-color=>"#AA0000"},"ERROR!")),
       hr,
         h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Too many loop residues have been selected (selected:$total_res > limit:20) ! ")),
         h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Please correct! Try again!")),
         end_html(); exit;       
     }

#################################
### if email empty

check_email($email);

##################################
### if there are too many users

check_users($tmp, $number_of_users);

###################################
### read coordinates from file, replace if needed the pdb_user

$szoveg="";
my $user_pdb = "";

if ($user_pdb_name && ($user_pdb_name ne "")) 
   {
         while (<$user_pdb_name>) 
          {    
	      $szoveg = $szoveg.$_;
          }
    $user_pdb=$szoveg;
     }

##################################
### generate a unique memo file for each submission

srand;
my $bemenet = time()."_AF_".int(rand(1)*100000);

$user_name =~ s/[\/ ;\[\]\<\>&\t]/_/g;

my $runname = "do_modloop_" . $bemenet;
my @utasitas=sprintf ("touch $tmp/modloop_$bemenet;chmod uog+rwx $tmp/modloop_$bemenet; echo $email $user_name $runname $bemenet $iteration > $tmp/modloop_$bemenet");
system(@utasitas);

@utasitas=sprintf ("chmod uog+rwx $tmp/modloop_$bemenet");
system(@utasitas);

##################################
### send a mail each time someone is using it

open(OUTMAIL,">$tmp/mail.txt");
print OUTMAIL "This is the  LOOP SERVER speaking!!\n\n";
print OUTMAIL "who is attempting to use modloop? (e-mail):>",$email,"<\n";
print OUTMAIL "protein code: >",$user_name,"<\n";
print OUTMAIL "loops: >",@loop_data,"<\n";
print OUTMAIL "job id: >",$bemenet,"<\n";
print OUTMAIL "\n\n...adios...\n";
close (OUTMAIL);
@utasitas=sprintf ("/bin/mail andras\@fiserlab.org < $tmp/mail.txt\n");
system(@utasitas);
@utasitas=sprintf ("/bin/mail eashwar\@salilab.org < $tmp/mail.txt\n");
system(@utasitas);
unlink("/$tmp/mail.txt");

####################################
### create a run directory

system("mkdir -p $tmp/$runname");

@utasitas=sprintf ("chmod uog+rwx $tmp/$runname/");
system(@utasitas);

###################################
### write pdb output

open(OUT,">$tmp/$runname/pdb-$bemenet.pdb");
print OUT $user_pdb;
close(OUT);

@utasitas=sprintf ("chmod uog+rwx $tmp/$runname/pdb-$bemenet.pdb");
system(@utasitas);

#################################
### generate top file 

  my $oldconfig="looptmp.top";
  my $newconf = "$tmp/$runname/loop-$bemenet.top";
  open(NEWCONF,">$newconf");
  open(OLDCONF,$oldconfig);
  while(my $line =  <OLDCONF> ) {
    $line =~ s/USR_NAME/$user_name/g;
    $line =~ s/USER_PDB/pdb-$bemenet.pdb/g;

  for (my $j=0;$j<$i;$j++)
    {
      if ($line =~ /\#$j\#/)
	{
        $line =~ s/START_RES/$start_res[$j]/g;
        $line =~ s/START_ID/$start_id[$j]/g;
        $line =~ s/END_RES/$end_res[$j]/g;
        $line =~ s/END_ID/$end_id[$j]/g; 
        $line =~ s/\#$j\#//g; 
        } 
    } 
    print NEWCONF $line;
    }
  close(OLDCONF);
  close(NEWCONF);

#################################
# generate  codine script
  my $oldcodine="codinetmp.sh";
  my $newcodine = "codine-$bemenet.sh";
  open(NEWCONF,">$tmp/$runname/$newcodine");
  open(OLDCONF,$oldcodine);
  while(my $line =  <OLDCONF> ) 
    {
     $line =~ s/iteration/$iteration/g;
     print NEWCONF $line;
    }
  close(OLDCONF);
  close(NEWCONF);

#################################
# generate  pdb header
  my $loopout;
  my $oldtext="toptext.tex";
  open(NEWCONF,">$tmp/$runname/toptext.tex");
  open(OLDCONF,$oldtext);
  while(my $line =  <OLDCONF> ) 
    {
    $line =~ s/USR_NAME/$user_name/g;
    $line =~ s/USER_PDB/pdb-$bemenet.pdb/g;
    
$loopout="";
for (my $j=0;$j<$i;$j++)
    {
     $loopout = $loopout.$start_res[$j].":".$start_id[$j]."-".$end_res[$j].":".$end_id[$j]." "; 
   }

     $line =~ s/LOOP_LIST/$loopout/g;
     $line =~ s/iteration/$iteration/g;
     print NEWCONF $line;
    }
  close(OLDCONF);
  close(NEWCONF);

####################################
### copy/generate  pdb/top/sh files in $tmp directory
#system("cp  $tmp/pdb-$bemenet.pdb $cwd/$runname/");
# already there

my $topfile="";
for ($i=1;$i<=$iteration;$i++)
{
    #get a random number here
    srand;
    my $random_seed=int(rand(1)*48000);$random_seed=$random_seed-49000;

    system("sed \"s;CODINE_RND;$random_seed;\" $tmp/$runname/loop-$bemenet.top > $tmp/$runname/ide; mv $tmp/$runname/ide $tmp/$runname/$i.top");
    $topfile=$topfile." $i.top";  # collect names for codine
    system("sed \"s;item;$i;\" $tmp/$runname/$i.top >  $tmp/$runname/ide; mv $tmp/$runname/ide $tmp/$runname/$i.top");
}

###fix codine with job inputs
system("sed \"s;TOPFILES;$topfile;\"  $tmp/$runname/codine-$bemenet.sh > $tmp/$runname/ide; mv $tmp/$runname/ide  $tmp/$runname/codine-$bemenet.sh");
system("sed \"s;DIR;$runname;\"  $tmp/$runname/codine-$bemenet.sh > $tmp/$runname/ide; mv $tmp/$runname/ide  $tmp/$runname/codine-$bemenet.sh");

###############################################
## write subject details into a file and pop up an exit page

### good bye

print header(), start_html("MODLOOP SUBMITTED"),
         h2({-align=>'CENTER'},font({-color=>"#AA0000"},"Dear User")),
       hr,
         h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Your job has been submitted to the server! Your process ID is $bemenet")),
         h4({-align=>'LEFT'},font({-color=>"#AA0000"},"The following loop segment(s) will be optimized: $loopout in protein: >$user_name< ")),
         h4({-align=>'LEFT'},font({-color=>"#AA0000"},"using the method of Fiser et al. (Prot. Sci. (2000) 9,1753-1773")),
         h4({-align=>'LEFT'},font({-color=>"#AA0000"},"You will receive the protein coordinate file with the optimized loop region by e-mail, to the adress: $email")),
        h4({-align=>'LEFT'},font({-color=>"#AA0000"},"The estimated execution time is ~90 min, depending on the load..")),
        h4({-align=>'LEFT'},font({-color=>"#AA0000"},"If you experience a problem or you do not receive the results for more than  12 hours, please contact afiser\@aecom.yu.edu")),
h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Thank you for using our server and good luck in your research!")),
    h4({-align=>'RIGHT'},font({-color=>"#AA0000"},"Andras Fiser")),
	hr,
         end_html(); exit;  




sub end_modloop {

	my @message=@_;
	my $errortable;
	print header,start_html("MODLOOP ERROR");

	$errortable=table({-border=>0, -width=>"70%", -bgcolor=>"white", -align=>"center"},
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"redtxt", -align=>"left"},b("MODLOOP Error"))),
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"redtxt", -align=>"left"},b("An error occured during your request:"))),
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"smallindented", -align=>"left"},br,b(join(br,@message)),br,br)),
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"redtxt",-align=>"left"},
			b("Please click on your browser's \"BACK\" button, and correct the problem.",br))));

	print $errortable;
	print end_html;
	exit;

}

# Quit with an error message
sub quit_with_error {
  my ($err) = @_;
  print header(), start_html("MODLOOP ERROR"),
        h2({-align=>'CENTER'},font({-color=>"#AA0000"},"ERROR!")), hr,
        h4({-align=>'CENTER'},font({-color=>"#AA0000"}, $err)),
        h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Try again!")),
        end_html();
  exit;
}

# Check Modeller license key
sub check_modeller_key {
  my ($key) = @_;
  if ($key ne "***REMOVED***") {
    quit_with_error("You have entered an invalid MODELLER KEY!");
  }
}

# Check for loop selection
sub check_loop_selection {
  my ($loop) = @_;
  if ($loop eq "") {
    quit_with_error("No loop segments were specified!");
  }
}

# Check if a PDB name was specified
sub check_pdb_name {
  my ($pdb_name) = @_;
  if ($pdb_name eq "") {
    quit_with_error("No coordinate file has been submitted!");
  }
}

# Check for valid email address
sub check_email {
  my ($email) = @_;

  if (!$email || $email eq "") {
    end_modloop("Please provide an e-mail address, because results will " .
                "be sent by email!");
  }

  unless ($email =~ /^[\w.+-]+\@[\w.+-]+$/) {
    end_modloop("Your email address contains special characters. " .
                "Please enter a regular email address! ");
  }
}

# Check for user limit
sub check_users {
  my ($tmp, $number_of_users) = @_;

  my $pid=`ls -1  $tmp/modloop_* |wc | awk '{print \$2}'`;

  if ($pid > $number_of_users ) {
    end_modloop("The server queue has reached its maximum number of " .
                "$number_of_users  simultaneous users. Please try later on!",
                "Sorry!");
  }
}
