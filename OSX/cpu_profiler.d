#!/bin/sh
# vim: filetype=sh

opt_pid=0; pid=0;
opt_name=0; pname=".";
opt_timeout=0; timeout=1;
opt_count=0; count=0;

function print_usage(){
	cat <<-END >&2
		USAGE: $0 [-t timeout] [-c N] { -p PID | -n name }

		          -p PID          # examine this PID
		          -n name         # examine this process name
		          -t timeout      # the length of time in ms to run until exiting
		          -c N            # show the top N stacks only
	END
	exit 1
}

while getopts p:n:t:c:h name
do
	case $name in
	p)      opt_pid=1; pid=$OPTARG ;;
	n)      opt_name=1; pname=$OPTARG ;;
	t)      opt_timeout=1; timeout=$OPTARG ;;
	c)      opt_count=1; count=$OPTARG ;;
	h|?)    print_usage
	esac
done

if [ $timeout -lt 1 ]
then
	echo 'timeout cannot be negative or zero'
	print_usage
fi

if [ $count -lt 0 ]
then
	echo 'top N stack count cannot be negative'
	print_usage
fi

if [ $opt_pid -eq 1 -a $opt_name -eq 1 ]
then
	echo 'pid and name options are mutually exclusive'
	print_usage
fi

dtrace='
profile-1000
/
	!(curthread->state & 0x80) &&
	(!'$opt_name' || execname == "'$pname'") &&
	(!'$opt_pid' || pid == '$pid')
/
{
	@stacks[stack(), ustack(), execname] = count();
}
'

if [ $opt_count -eq 1 ]
then
	dtrace+='
	END
	{
		trunc(@stacks, '$count');
		printa(@stacks);
	}
	'
fi

if [ $opt_timeout -eq 1 ]
then
	dtrace+='
	tick-'$timeout'msec
	{
		exit(0);
	}
	'
fi

/usr/sbin/dtrace -n "$dtrace"
