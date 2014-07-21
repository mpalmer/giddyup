define giddyup::config($base,
                       $user,
                       $var,
                       $value = undef) {
	if $value {
		exec { "set giddyup.${var} in ${base}":
			command => "/usr/bin/git config -f '${base}/repo/config' 'giddyup.${var}' '${value}'",
			unless => "/usr/bin/test \"\$(git config -f ${base}/repo/config giddyup.${var})\" = '${value}'",
			cwd => "/",
			user => $user,
			require => [ Noop["git/packages"], Exec["giddyup create ${base}"], User[$user] ]
		}
	}
}
