#! /bin/bash
	
  prefer=/tmp/file
			cat <<- EOF >> ${prefer}
			Package: *
			Pin: release l=Debian
			Pin-Priority: 110
			EOF
