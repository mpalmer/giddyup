class giddyup::install {
	file {
		"/usr/local/lib/giddyup":
			ensure => directory,
			mode => 0755;
		"/usr/local/lib/giddyup/giddyup":
			source => "puppet:///modules/giddyup/giddyup",
			mode => 0555,
			require => [ File["/usr/local/lib/giddyup/update-hook"],
			             File["/usr/local/lib/giddyup/functions.sh"]
			           ];
		"/usr/local/lib/giddyup/update-hook":
			source => "puppet:///modules/giddyup/update-hook",
			mode => 0555;
		"/usr/local/lib/giddyup/functions.sh":
			source => "puppet:///modules/giddyup/functions.sh",
			mode => 0444;
	}
}
