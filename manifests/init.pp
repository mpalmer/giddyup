define giddyup(
	$environment  = undef,
	$hookdir      = undef,
	$keepreleases = undef,
	$debug        = undef,
	$origin       = undef,
	$user
) {
	include giddyup::install
	include git::packages

	exec { "giddyup create ${name}":
		command => "/usr/local/lib/giddyup/giddyup ${name}",
		creates => $name,
		user => $user,
		require => [ File["/usr/local/lib/giddyup/giddyup"], User[$user] ]
	}

	giddyup::config {
		"giddyup.environment for ${name}":
			base => $name,
			user => $user,
			var => "environment",
			value => $environment;
		"giddyup.hookdir for ${name}":
			base => $name,
			user => $user,
			var => "hookdir",
			value => $hookdir;
		"giddyup.keepreleases for ${name}":
			base => $name,
			user => $user,
			var => "keepreleases",
			value => $keepreleases;
		"giddyup.debug for ${name}":
			base => $name,
			user => $user,
			var => "debug",
			value => $debug;
	}

	if $origin {
		exec { "set remote.origin.url in ${name}":
			command => "/usr/bin/git config -f '${name}/repo/config' 'remote.origin.url' '${origin}'",
			unless => "/usr/bin/test \"\$(git config -f ${name}/repo/config remote.origin.url)\" = '${origin}'",
			cwd => "/",
			user => $user,
			require => [ Noop["git/packages"], Exec["giddyup create ${name}"], User[$user] ]
		}
	}
}
