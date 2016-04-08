#!/usr/sbin/dtrace -Zs
/*
 * sh_flow.d - snoop Bourne shell execution showing function flow.
 *             Written for the Solaris sh DTrace provider.
 *
 * See:
 * - https://blogs.oracle.com/tpenta/entry/bin_sh_dtrace_provider
 *
 * This traces shell activity from all Bourne shells on the system that are
 * running with sh provider support.
 *
 * USAGE: sh_flow.d                     # hit Ctrl-C to end
 *
 * This watches shell function entries and returns, and indents child
 * function calls. Shell builtins are also printed.
 *
 * FIELDS:
 *              C               CPU-id
 *              TIME            Time of execution
 *              FILE            Filename that this function belongs to
 *              NAME            Shell function, builtin or command name
 *
 * If a name isn't available at the time of tracing, "<null>" is printed.
 *
 * WARNING: Watch the first column carefully, it prints the CPU-id. If it
 * changes, then it is very likely that the output has been shuffled.
 *
 * Based on the source code at:
 * - https://blogs.oracle.com/brendan/entry/dtrace_bourne_shell_sh_provider1
 *
 */

#pragma D option quiet
#pragma D option switchrate=10

dtrace:::BEGIN
{
        depth = 0;
        printf("%s %-20s  %-22s   %s %s\n", "C", "TIME", "FILE", "DELTA(us)", "NAME");
}

sh*:::function-entry
{
        depth++;
        printf("%d %-20Y  %-22s %*s-> %s\n", cpu, walltimestamp,
            basename(copyinstr(arg0)), depth*2, "", copyinstr(arg1));
}

sh*:::function-return
{
        printf("%d %-20Y  %-22s %*s<- %s\n", cpu, walltimestamp,
            basename(copyinstr(arg0)), depth*2, "", copyinstr(arg1));
        depth--;
}

sh*:::builtin-entry
{
        printf("%d %-20Y  %-22s %*s   > %s\n", cpu, walltimestamp,
            basename(copyinstr(arg0)), depth*2, "", copyinstr(arg1));
}

sh*:::command-entry
{
        printf("%d %-20Y  %-22s %*s   | %s\n", cpu, walltimestamp,
            basename(copyinstr(arg0)), depth*2, "", copyinstr(arg1));
}
