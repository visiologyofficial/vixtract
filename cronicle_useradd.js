#!/usr/bin/env node

// CLI for Storage System
// Copyright (c) 2015 Joseph Huckaby
// Released under the MIT License

var path = require('path');
var cp = require('child_process');
var os = require('os');
var fs = require('fs');
var async = require('async');
var bcrypt = require('bcrypt-node');

var Args = require('pixl-args');
var Tools = require('pixl-tools');
var StandaloneStorage = require('pixl-server-storage/standalone');

// chdir to the proper server root dir
process.chdir( path.dirname( __dirname ) );

// load app's config file
var config = require('../conf/config.json');

// shift commands off beginning of arg array
var argv = JSON.parse( JSON.stringify(process.argv.slice(2)) );
var commands = [];
while (argv.length && !argv[0].match(/^\-/)) {
	commands.push( argv.shift() );
}

// now parse rest of cmdline args, if any
var args = new Args( argv, {
	debug: false,
	verbose: false,
	quiet: false
} );
args = args.get(); // simple hash

// copy debug flag into config (for standalone)
config.Storage.debug = args.debug;

var print = function(msg) {
	// print message to console
	if (!args.quiet) process.stdout.write(msg);
};
var verbose = function(msg) {
	// print only in verbose mode
	if (args.verbose) print(msg);
};
var warn = function(msg) {
	// print to stderr unless quiet
	if (!args.quiet) process.stderr.write(msg);
};
var verbose_warn = function(msg) {
	// verbose print to stderr unless quiet
	if (args.verbose && !args.quiet) process.stderr.write(msg);
};

if (config.uid && (process.getuid() != 0)) {
	print( "ERROR: Must be root to use this script.\n" );
	process.exit(1);
}

// determine server hostname
var hostname = (process.env['HOSTNAME'] || process.env['HOST'] || os.hostname()).toLowerCase();

// find the first external IPv4 address
var ip = '';
var ifaces = os.networkInterfaces();
var addrs = [];
for (var key in ifaces) {
	if (ifaces[key] && ifaces[key].length) {
		Array.from(ifaces[key]).forEach( function(item) { addrs.push(item); } );
	}
}
var addr = Tools.findObject( addrs, { family: 'IPv4', internal: false } );
if (addr && addr.address && addr.address.match(/^\d+\.\d+\.\d+\.\d+$/)) {
	ip = addr.address;
}
else {
	print( "ERROR: Could not determine server's IP address.\n" );
	process.exit(1);
}

// util.isArray is DEPRECATED??? Nooooooooode!
var isArray = Array.isArray || util.isArray;

// prevent logging transactions to STDOUT
config.Storage.log_event_types = {};

// allow APPNAME_key env vars to override config
var env_regex = new RegExp( "^CRONICLE_(.+)$" );
for (var env_key in process.env) {
	if (env_key.match(env_regex)) {
		var env_path = RegExp.$1.trim().replace(/^_+/, '').replace(/_+$/, '').replace(/__/g, '/');
		var env_value = process.env[env_key].toString();

		// massage value into various types
		if (env_value === 'true') env_value = true;
		else if (env_value === 'false') env_value = false;
		else if (env_value.match(/^\-?\d+$/)) env_value = parseInt(env_value);
		else if (env_value.match(/^\-?\d+\.\d+$/)) env_value = parseFloat(env_value);

		Tools.setPath(config, env_path, env_value);
	}
}

// construct standalone storage server
var storage = new StandaloneStorage(config.Storage, function(err) {
	if (err) throw err;
	// storage system is ready to go

	// become correct user
	if (config.uid && (process.getuid() == 0)) {
		verbose( "Switching to user: " + config.uid + "\n" );
		process.setuid( config.uid );
	}

	// custom job data expire handler
	storage.addRecordType( 'cronicle_job', {
		'delete': function(key, value, callback) {
			storage.delete( key, function(err) {
				storage.delete( key + '/log.txt.gz', function(err) {
					callback();
				} ); // delete
			} ); // delete
		}
	} );

	// Usage: ./cronicle_useradd.js USERNAME PASSWORD [EMAIL]
	var username = commands.shift();
	var password = commands.shift();
	var email = commands.shift() || 'tester@localhost';
	if (!username || !password) {
		print( "\nUsage: bin/cronicle_useradd.js USERNAME PASSWORD [EMAIL]\n\n" );
		process.exit(1);
	}
	if (!username.match(/^[\w\-\.]+$/)) {
		print( "\nERROR: Username must contain only alphanumerics, dash and period.\n\n" );
		process.exit(1);
	}
	username = username.toLowerCase();

	var user = {
		username: username,
		password: password,
		full_name: username,
		email: email
	};

	user.active = 1;
	user.created = user.modified = Tools.timeNow(true);
	user.salt = Tools.generateUniqueID( 64, user.username );
	user.password = bcrypt.hashSync( user.password + user.salt );
	//user.privileges = { admin: 1 };
	user.privileges = { create_events: 1, edit_events: 1, delete_events: 1 };

	storage.put( 'users/' + username, user, function(err) {
		if (err) throw err;
		print( "\nUser '"+username+"' created successfully.\n" );
		print("\n");

		//storage.shutdown( function() { process.exit(0); } );
	} );

 	storage.listPush('global/users', { "username": username }, function(err) {
    if (err) throw err;
    print( "\nUser '"+username+"' added to global list successfully.\n" );
    print("\n");

    storage.shutdown( function() { process.exit(0); } );
  } );
});

function export_data(file) {
	// export data to file or stdout (except for completed jobs, logs, and sessions)
	// one record per line: KEY - JSON
	var stream = file ? fs.createWriteStream(file) : process.stdout;

	// file header (for humans)
	var file_header = "# Cronicle Data Export v1.0\n" +
		"# Hostname: " + hostname + "\n" +
		"# Date/Time: " + (new Date()).toString() + "\n" +
		"# Format: KEY - JSON\n\n";

	stream.write( file_header );
	verbose_warn( file_header );

	if (file) verbose_warn("Exporting to file: " + file + "\n\n");

	// need to handle users separately, as they're stored as a list + individual records
	storage.listEach( 'global/users',
		function(item, idx, callback) {
			var username = item.username;
			var key = 'users/' + username.toString().toLowerCase().replace(/\W+/g, '');
			verbose_warn( "Exporting user: " + username + "\n" );

			storage.get( key, function(err, user) {
				if (err) {
					// user deleted?
					warn( "\nFailed to fetch user: " + key + ": " + err + "\n\n" );
					return callback();
				}

				stream.write( key + ' - ' + JSON.stringify(user) + "\n", 'utf8', callback );
			} ); // get
		},
		function(err) {
			// ignoring errors here
			// proceed to the rest of the lists
			async.eachSeries(
				[
					'global/users',
					'global/plugins',
					'global/categories',
					'global/server_groups',
					'global/schedule',
					'global/servers',
					'global/api_keys'
				],
				function(list_key, callback) {
					// first get the list header
					verbose_warn( "Exporting list: " + list_key + "\n" );

					storage.get( list_key, function(err, list) {
						if (err) return callback( new Error("Failed to fetch list: " + list_key + ": " + err) );

						stream.write( list_key + ' - ' + JSON.stringify(list) + "\n" );

						// now iterate over all the list pages
						var page_idx = list.first_page;

						async.whilst(
							function() { return page_idx <= list.last_page; },
							function(callback) {
								// load each page
								var page_key = list_key + '/' + page_idx;
								page_idx++;

								verbose_warn( "Exporting list page: " + page_key + "\n");

								storage.get(page_key, function(err, page) {
									if (err) return callback( new Error("Failed to fetch list page: " + page_key + ": " + err) );

									// write page data
									stream.write( page_key + ' - ' + JSON.stringify(page) + "\n", 'utf8', callback );
								} ); // page get
							}, // iterator
							callback
						); // whilst

					} ); // get
				}, // iterator
				function(err) {
					if (err) {
						warn( "\nEXPORT ERROR: " + err + "\n" );
						process.exit(1);
					}

					verbose_warn( "\nExport completed at " + (new Date()).toString() + ".\nExiting.\n\n" );

					if (file) stream.end();

					storage.shutdown( function() { process.exit(0); } );
				} // done done
			); // list eachSeries
		} // done with users
	); // users listEach
};

function import_data(file) {
	// import storage data from specified file or stdin
	// one record per line: KEY - JSON
	print( "\nCronicle Data Importer v1.0\n" );
	if (file) print( "Importing from file: " + file + "\n" );
	else print( "Importing from STDIN\n" );
	print( "\n" );

	var count = 0;
	var queue = async.queue( function(line, callback) {
		// process each line
		if (line.match(/^(\w[\w\-\.\/]*)\s+\-\s+(\{.+\})\s*$/)) {
			var key = RegExp.$1;
			var json_raw = RegExp.$2;
			print( "Importing record: " + key + "\n" );

			var data = null;
			try { data = JSON.parse(json_raw); }
			catch (err) {
				warn( "Failed to parse JSON for key: " + key + ": " + err + "\n" );
				return callback();
			}

			storage.put( key, data, function(err) {
				if (err) {
					warn( "Failed to store record: " + key + ": " + err + "\n" );
					return callback();
				}
				count++;
				callback();
			} );
		}
		else callback();
	}, 1 );

	// setup readline to line-read from file or stdin
	var readline = require('readline');
	var rl = readline.createInterface({
		input: file ? fs.createReadStream(file) : process.stdin
	});

	rl.on('line', function(line) {
		// enqueue each line
		queue.push( line );
	});

	rl.on('close', function() {
		// end of input stream
		var complete = function() {
			// finally, delete state so cronicle recreates it
			storage.delete( 'global/state', function(err) {
				// ignore error here, as state may not exist yet
				print( "\nImport complete. " + count + " records imported.\nExiting.\n\n" );
				storage.shutdown( function() { process.exit(0); } );
			});
		};

		// fire complete on queue drain
		if (queue.idle()) complete();
		else queue.drain = complete;
	}); // rl close
};
