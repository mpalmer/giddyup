`rackctl` is a couple of scripts to create and stop/start Rack applications
running in a thin application server, managed by
[daemontools](http://cr.yp.to/daemontools.html).

There are a pile of conventions used in these scripts.  Specifically:

* All services are named `rack_<username>_<appname>_<port>`
* The directory scanned by `svscan` is `/etc/service` (this is the Debian
  default, and I'm not a fan of `/service` anyway; a patch to generalise
  this wouldn't be rejected)
* The actual service directories live in `/var/lib/service`; a symlink to
  that location from `/etc/service` will be created.
* The application is deployed in a `giddyup`-compatible fashion; that is,
  inside the application's root directory, there's a symlink called
  `current` that points to the current deployment of the app.
* Probably a bunch of other assumptions I've forgotten.

To create a new appserver for a given application, you use
`setup-rack-service`, as root, like this:

    setup-rack-service fred apps/production 3456

This command line will create a new thin for the user `fred`, running the
application rooted at `~fred/apps/production` (so the app itself should be
in `~fred/apps/production/current`), and listening on `127.0.0.1:3456`.  The
name of the daemontools service will be `rack_fred_production_3456`.

Once that's done, and the appserver is up and running, you can configure
nginx or whatever to send requests to the appserver.

To start and stop your appservers, you use `rackctl`.  

# Installation

To install the `rackctl` tools, simply copy or symlink the scripts to
somewhere in your `PATH`.  You also need to add the following line to
`/etc/sudoers`, as the `rackctl` script needs to become root to be able to
manipulate daemontools:

    ALL ALL = (root) NOPASSWD: /path/to/rackctl

Questions?  Comments?  [E-mail me](mailto:theshed+giddyup@hezmatt.org).
