--- ../../fml.pl	Mon Apr 18 18:41:59 1994
+++ fml.pl	Sun May 15 05:48:35 1994
@@ -14,7 +14,7 @@
 
 # Directory of Mailing List Server Libraries
 # format: fml.pl DIR(for config.ph) PERLLIB's
-$DIR	      = $ARGV[0] ? $ARGV[0] : '/home/axion/fukachan/work/spool/EXP';
+$DIR	      = $ARGV[0] ? $ARGV[0] : '/home/axion/fukachan/work/spool/K.Mariko';
 push(@INC, "$DIR");		# add the path for include files
 $LIBDIR = $DIR unless $ARGV[1];
 while(@ARGV, shift @ARGV) {push(@INC, $ARGV[0]); 
@@ -55,10 +55,14 @@
     }
 }
 
+require 'yumeko.pl'; 
+
 if ($CommandMode) {		# If "# (.*)" form is given, Command mode
-    require 'libfml.pl'; 
+#    require 'libfml.pl'; 
+    &YumekoCommand;		# 
 } else {			# distribution mode(Mailing List)
-    &Distribute;
+#    &Distribute;
+    &YumekoVoting;
 }
 
 (!$USE_FLOCK) ? &Unlock : &Funlock;# UnLocking 
