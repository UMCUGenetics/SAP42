#!/usr/bin/perl -w

use lib pop(@ARGV);

print join("\n", @INC) . "\n";

use postmap_clus_pdf;