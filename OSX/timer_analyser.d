#!/bin/sh
# vim: filetype=sh

opt_pid=0; pid=0;
opt_name=0; pname=".";
opt_timeout=0; timeout=1;

function print_usage(){
	cat <<-END >&2
	USAGE: $0 [-t timeout] { -p PID | -n name } "maximum time-to-deadline"

	          -p PID          # examine this PID
	          -n name         # examine this process name
	          -t timeout      # the length of time in ms to run until exiting
	END
	exit 1
}

while getopts p:n:t:h name
do
	case $name in
	p)      opt_pid=1; pid=$OPTARG ;;
	n)      opt_name=1; pname=$OPTARG ;;
	t)      opt_timeout=1; timeout=$OPTARG ;;
	h|?)    print_usage ;;
	esac
done
shift `expr $OPTIND - 1`

if [ $# -lt 1 ]
then
	print_usage
fi

if [ $timeout -lt 1 ]
then
	echo 'timeout cannot be negative or zero'
	print_usage
fi

if [ $opt_pid -eq 1 -a $opt_name -eq 1 ]
then
	echo 'pid and name options are mutually exclusive'
	print_usage
fi

dtrace='
BEGIN
{
}
sdt:::callout-create
/
	(!'$opt_name' || execname == "'$pname'") &&
	(!'$opt_pid' || pid == '$pid')
/
{
	@deadline_distribution = quantize(((unsigned long long)arg4<<32 | arg5)>>10);
}

sdt:::callout-create
/
	((((unsigned long long)arg4 << 32) | (arg5)) < ($1*1000*1000)) &&
	arg0 != (uint64_t)(&(mach_kernel`thread_quantum_expire)) &&
	arg0 != (uint64_t)(&(mach_kernel`thread_call_delayed_timer)) &&
	(!'$opt_name' || execname == "'$pname'") &&
	(!'$opt_pid' || pid == '$pid')
/
{
	@short_deadlines[stack(), ustack(), execname, ((((unsigned long long)arg4 << 32) | (arg5))>>20)] = count();
}

sdt:::callout-cancel
/
	(!'$opt_name' || execname == "'$pname'") &&
	(!'$opt_pid' || pid == '$pid')
/
{
	@cancelled_deadline_distribution = quantize(((unsigned long long)arg4<<32 | arg5)>>10);
}

sdt:::thread_callout-create
/
	(!'$opt_name' || execname == "'$pname'") &&
	(!'$opt_pid' || pid == '$pid')
/
{
	@thread_deadline_distribution = quantize(((unsigned long long)arg2<<32 | arg3)>>10);
}

sdt:::thread_callout-create
/
	((((unsigned long long)arg2 << 32) | (arg3)) < ($1*1000*1000)) &&
	(!'$opt_name' || execname == "'$pname'") &&
	(!'$opt_pid' || pid == '$pid')
/
{
	@short_tc_deadlines[stack(), ustack(), execname, ((((unsigned long long)arg2 << 32) | (arg3))>>20)] = count();
}

sdt:::iotescallout-expire
{
	@IOTimerEventSource_timeout[sym(arg0)] = count();
}

END
{
	printf("\nTimer callout deadline distribution\n");
	printa(@deadline_distribution);
	printf("\nThread callout deadline distribution\n");
	printa(@thread_deadline_distribution);
	printf("\nCancelled timer callout deadline distribution\n");
	printa(@cancelled_deadline_distribution);
	printf("\nShort timer call deadlines\n");
	printa(@short_deadlines);
	printf("\nShort thread call deadlines\n");
	printa(@short_tc_deadlines);
	printf("\nIOTimerEventSource callouts\n");
	printa(@IOTimerEventSource_timeout);
}
'

if [ $opt_timeout -eq 1 ]
then

dtrace+='
tick-'$timeout'msec
{
	exit(0);
}
'

fi

/usr/sbin/dtrace -n "$dtrace" $1
