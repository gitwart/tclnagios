# Package to assist in creating Nagios plugins written in Tcl
package require cmdline
package provide nagios 1.3

namespace eval nagios {
    set options [list \
	[list V "Print version information"] \
	[list h "Print detailed help screen"] \
	[list v "Show details for command-line debugging (Nagios may truncate output)"] \
	[list nagioshost.arg {} "The name of the nagios server for sending passive service check results"] \
	[list host.arg {} "The name of this host as it is registered with Nagios"] \
	[list service.arg {} "The name of this host as it is registered with Nagios"] \
    ]

    variable returnCode
    array set returnCode {
	OK 0
	WARNING 1
	CRITICAL 2
	UNKNOWN 3
    }

    variable serviceName SERVICE

    # The service type can be either 'active' or 'passive'.  Active service
    # checks print out the result on stdout and exit with the appropriate
    # exit code.  Passive service checks invoke 'send_nsca' to send the
    #  
    variable activeService 1

    # The name of the nagios host for sending passive results
    variable server ""
}

proc nagios::process_options {full_options options_var} {
    variable activeService
    variable serviceName
    variable server
    variable host
    variable options

    upvar $options_var local_argv

    if {[catch {
	foreach {var val} [::cmdline::getKnownOptions local_argv $options] {
	    set option($var) $val
	}
    } msg]} {
	puts stderr $msg:$::errorInfo 
	exit 1
    }

    if {$option(h)} {
	puts stderr [cmdline::usage $full_options]
	exit 1
    }

    if {$option(nagioshost) != ""} {
	set activeService 0
	set server $option(nagioshost) 
    }
    if {$option(host) == ""} {
	set host [info hostname]
    } else {
	set host $option(host)
    }
    if {$option(service) != ""} {
	set serviceName $option(service)
    }
}

proc nagios::exit_ok {msg} {
    _exit OK $msg
}

proc nagios::exit_warning {msg} {
    _exit WARNING $msg
}

proc nagios::exit_critical {msg} {
    _exit CRITICAL $msg
}

proc nagios::exit_unknown {msg} {
    _exit UNKNOWN $msg
}

proc nagios::_exit {status msg} {
    variable returnCode
    variable serviceName
    variable activeService
    variable server
    variable host

    puts "$serviceName $status: $msg"
    if {! $activeService} {
	set chanId [open "|/usr/sbin/send_nsca -H $server" w]
	puts $chanId "$host\t$serviceName\t$returnCode($status)\t$msg"
	close $chanId
    }
    exit $returnCode($status)
}

proc nagios::compareToRange {value range} {
    set inRange 0

    if {[string is double $range]} {
        set minval 0
        set maxval $range
        set invert {}
    } elseif {[regexp {^(@?)(-?\d+\.?\d*):?(-?\d+\.?\d*)?$} $range null invert minval maxval]} {
        if {$maxval == ""} {
            set maxval Inf
        }
    }

    if {$value > $minval && $value < $maxval} {
        set inRange 1
    } else {
        set inRange 0
    }

    if {$invert == ""} {
        return $inRange
    } else {
        return [expr 1-$inRange]
    }
}


