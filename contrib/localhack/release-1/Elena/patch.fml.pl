--- ../../fml.pl	Wed Nov 16 23:15:17 1994
+++ fml.pl	Sat Nov 19 00:19:03 1994
@@ -37,14 +37,18 @@
 
 (!$USE_FLOCK) ? &Lock : &Flock;	# Locking 
 
+$rcsid .= " Elena-patched";
+
 if($GUIDE_REQUEST) {
     &GuideRequest;		# Guide Request from everybady
 } elsif(($ML_MEMBER_CHECK ? &MLMemberCheck: &MLMemberNoCheckAndAdd)) { 
-    &AdditionalCommandModeCheck;# e.g. for ctl-only address
+    &AdditionalCommandModeCheck;# e.g. for ctl-only address;
+
+    require 'Elena.pl'; 
     if ($CommandMode) {		# If "# (.*)" form is given, Command mode
-	require 'libfml.pl'; 
+	&ElenaCommand;		# require 'libfml.pl'; 
     } else {			# distribution mode(Mailing List)
-	&Distribute;
+	&ElenaVoting;		# &Distribute;
     }
 }
 
@@ -206,7 +210,6 @@
         require 'libMIME.pl';
 	$Summary_Subject = &DecodeMimeStrings($Summary_Subject);
     }
-#.if
     # Crosspost extension
     $Crosspost  = $To_address;
     $Crosspost .= ", ".$Cc if $Cc;
@@ -218,7 +221,6 @@
 	require 'contrib/Crosspost/Crosspost.ph';
 	require 'contrib/Crosspost/libcrosspost.pl';
     }
-#.endif
 
     if($debug) { # debug
 	print STDERR  
@@ -260,13 +262,11 @@
 {
     $0 = "--Checking Members or not <$FML $LOCKFILE>";
     if(0 == &CheckMember($From_address, $MEMBER_LIST)) {
-#.if
 	# Crosspost extension.
 	if($USE_CROSSPOST) {
 	    &Logging("Crosspost from not member($From_address)");	    
 	    return 0;
 	}
-#.endif
 	# When not member, return the deny file.
 	&Logging("From not member: ($From_address)");
 	&Sendmail($MAINTAINER, "NOT MEMBER article from $From_address $ML_FN",
@@ -302,13 +302,11 @@
     return 0 if(1 == &LoopBackWarning($from));
 
     if(0 == &CheckMember($from, $MEMBER_LIST)) { # if not member
-#.if
 	# Crosspost extension.
 	if($USE_CROSSPOST) {
 	    &Logging("Crosspost from not member($From_address)");	    
 	    return 0;
 	}
-#.endif
 	# Special Effects use e.g. "Subject: subscribe"...
 	# Check if appropriate
 	if($REQUIRE_SUBSCRIBE) { # Keyword "subscribe" required!
@@ -391,12 +389,10 @@
       # Whether relay or not? Whether matome okuri or not?
       local($rcpt, $mx, $matome) = split(/\s+/, $_, 999);
       print STDERR "$rcpt, $mx, $matome\n" if $debug;
-#.if
       # Crosspost Extension. if matched to other ML's, no deliber
       if($USE_CROSSPOST) {
 	  next line if $NORCPT{$rcpt}; # no add to @headers
       }
-#.endif
       if($mx) {			# if MX is explicitly given,
 	  next line if($mx     =~ /^skip$/io);   # for member check mode 
 	  next line if($mx     =~ /^matome$/io); # for MatomeOkuri ver.2
@@ -457,7 +453,6 @@
 	"Posted: $Date\n" .
 	"$XMLNAME\n" .
 	"$XMLCOUNT: " . sprintf("%05d", $ID) . "\n"; # 00010 
-#.if
     # Crosspost
     if((!$USE_CROSSPOST) && -f "$DIR/tmp/crosspost") { # when not crosspost
 	$body .= "X-Crosspost-Warning:";
@@ -476,7 +471,6 @@
 	$body .= "X-Crosspost-Warning: ATTENTION! THIS IS A CROSSPOST\n";
 	open(FILE, "> $DIR/tmp/crosspost"); close(FILE);
     }
-#.endif
     $body .= "X-MLServer: $rcsid\n" if $rcsid;
     $body .= "Precedence: list\n"; # for Sendmail 8.x, for delay mail
     $body .= "Lines: $BodyLines\n\n";
