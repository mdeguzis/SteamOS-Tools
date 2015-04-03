#! /bin/bash

main()
{
  prefer=/tmp/file
			cat <<- EOF >> ${prefer}
			Package: *
			Pin: release l=Debian
			Pin-Priority: 110
			EOF
			
# test based on my code

	# Install/Uninstall process
	
		# Create and add required text to preferences file
		cat <<-EOF >> ${prefer}
		Package: *
		Pin: release l=Debian
		Pin-Priority: 110
		EOF

}
main
