%Procedure = (
	      # library access
	      'library',	'ProcLibrary');


sub ProcLibrary
{
    local($proc, *Fld, *e, *misc) = @_;

    # gsave
    local($org_spool_dir) = $SPOOL_DIR;
    $SPOOL_DIR   = 'library/spool';

    if ($Fld[3] =~ /^get$/) {
	&Log("$proc get ");
	@ARCHIVE_DIR = ('library/spool');
	&ProcRetrieveFileInSpool(@_);
    }
    elsif ($Fld[3] =~ /^put$/) {
	&Distribute;
    }

    # grestore
    $SPOOL_DIR = $org_spool_dir;
}

1;
