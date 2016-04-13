# Dtrace scripts.

DTrace scripts to trace executables that support DTrace Dynamic Tracing.

## Top One-Liners

DTrace is a dynamic troubleshooting and analysis tool first introduced in the Solaris 10 and OpenSolaris operating systems.

The following are the top 10 one-liners to try out.

### Processes

New processes with arguments:

    dtrace -n 'proc:::exec-success { trace(curpsinfo->pr_psargs); }'

### Files

Files opened by process name:

    dtrace -n 'syscall::open*:entry { printf("%s %s",execname,copyinstr(arg0)); }'

Files created using creat() by process name:

    dtrace -n 'syscall::creat*:entry { printf("%s %s",execname,copyinstr(arg0)); }'

### Syscalls

Syscall count by process name:

    dtrace -n 'syscall:::entry { @num[execname] = count(); }'

Syscall count by syscall:

    dtrace -n 'syscall:::entry { @num[probefunc] = count(); }'

Syscall count by process ID:

    dtrace -n 'syscall:::entry { @num[pid,execname] = count(); }'

Read bytes by process name:

    dtrace -n 'sysinfo:::readch { @bytes[execname] = sum(arg0); }'

### I/O

Write bytes by process name:

    dtrace -n 'sysinfo:::writech { @bytes[execname] = sum(arg0); }'

Read size distribution by process name:

    dtrace -n 'sysinfo:::readch { @dist[execname] = quantize(arg0); }'

Write size distribution by process name:

    dtrace -n 'sysinfo:::writech { @dist[execname] = quantize(arg0); }'

### Physical I/O

Disk size by process ID:

    dtrace -n 'io:::start { printf("%d %s %d",pid,execname,args[0]->b_bcount); }'

Disk size aggregation:

    dtrace -n 'io:::start { @size[execname] = quantize(args[0]->b_bcount); }'

Pages paged in by process name:

    dtrace -n 'vminfo:::pgpgin { @pg[execname] = sum(arg0); }'

### Memory

Minor faults by process name:

    dtrace -n 'vminfo:::as_fault { @mem[execname] = sum(arg0); }'

### User-land

Sample user stack trace of specified process ID at 1001 Hertz:

    dtrace -n 'profile-1001 /pid == $target/ { @num[ustack()] = count(); }' -p PID

Trace why threads are context switching off the CPU, from the user-land perspective:

    dtrace -n 'sched:::off-cpu { @[execname, ustack()] = count(); }'

User stack size for processes:

    dtrace -n 'sched:::on-cpu { @[execname] = max(curthread->t_procp->p_stksize);}'

### Kernel

Sample kernel stack trace at 1001 Hertz:

    dtrace -n 'profile-1001 /!pid/ { @num[stack()] = count(); }'

Interrupts by CPU:

    dtrace -n 'sdt:::interrupt-start { @num[cpu] = count(); }'

CPU cross calls by process name:

    dtrace -n 'sysinfo:::xcalls { @num[execname] = count(); }'

Trace why threads are context switching off the CPU, from the kernel perspective:

    dtrace -n 'sched:::off-cpu { @[execname, stack()] = count(); }'

Kernel funtion calls by module:

    dtrace -n 'fbt:::entry { @calls[probemod] = count(); }'

### Locks

Trace user-level lock statistics for 10 seconds, with 8 line stack traces (uses DTrace):

    plockstat -s8 -e10 -p PID

Trace kernel lock statistics for 10 seconds, with 8 line stack traces (uses DTrace):

    lockstat -s8 sleep 10

Lock time by process name:

    dtrace -n 'lockstat:::adaptive-block { @time[execname] = sum(arg1); }'

Lock distribution by process name:

    dtrace -n 'lockstat:::adaptive-block { @time[execname] = quantize(arg1); }'

### Zones

Syscalls by zonename:

    dtrace -n 'syscall:::entry { @num[zonename] = count(); }'

### DTrace Longer One Liners

New processes with arguments and time:

    dtrace -qn 'syscall::exec*:return { printf("%Y %s\n",walltimestamp,curpsinfo->pr_psargs); }'

Successful signal details:

    dtrace -n 'proc:::signal-send /pid/ { printf("%s -%d %d",execname,args[2],args[1]->pr_pid); }'

Trace PHP functions:

    sudo dtrace -qn 'php*:::function-entry { printf("%Y: PHP function-entry:\t%s%s%s() in %s:%d\n", walltimestamp, copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2); }'


### References

Most of these onliners are in the [DTraceToolkit](http://www.solarisinternals.com/wiki/index.php/DTraceToolkit) as docs/oneliners.txt, and as Appendix B in Solaris Performance and Tools.
