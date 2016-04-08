#!/usr/sbin/dtrace -n
/*
 *  iosnoop - A program to print disk I/O events as they happen, with useful
 *            details such as UID, PID, filename, command, etc. 
 *            Written using DTrace (Solaris 10 3/05).
 * 
 *  This is measuring disk events that have made it past system caches.
 * 
 *   eg,
 *         iosnoop -v    # human readable timestamps
 *         iosnoop -N    # print major and minor numbers
 *         iosnoop -m /    # snoop events on the root filesystem only
 *      
 *  FIELDS:
 *         UID        user ID
 *         PID        process ID
 *         PPID        parennt process ID
 *         COMM        command name for the process
 *         ARGS        argument listing for the process
 *         SIZE        size of operation, bytes
 *         BLOCK        disk block for the operation (location)
 *         STIME         timestamp for the disk request, us
 *         TIME        timestamp for the disk completion, us
 *         DELTA        elapsed time from request to completion, us
 *         DTIME        time for disk to complete request, us
 *         STRTIME        timestamp for the disk completion, string
 *         DEVICE      device name
 *         INS         device instance number
 *         D        direction, Read or Write
 *         MOUNT        mount point
 *         FILE        filename (basename) for io operation
 *  
 *  NOTE:
 *  - There are two different delta times reported. -D prints the
 *    elapsed time from the disk request (strategy) to the disk completion
 *    (iodone); -o prints the time for the disk to complete that event 
 *    since it's last event (time between iodones), or, the time to the 
 *    strategy if the disk had been idle. 
 *  - When filtering on PID or process name, be aware that poor disk event
 *    times may be due to events that have been filtered away, for example
 *    another process that may be seeking the disk heads elsewhere.
 * 
 *  SEE ALSO: BigAdmin: DTrace, http://www.sun.com/bigadmin/content/dtrace
 *         Solaris Dynamic Tracing Guide, http://docs.sun.com
 *         DTrace Tools, http://www.brendangregg.com/dtrace.html
 * 
 *  COPYRIGHT: Copyright (c) 2005 Brendan Gregg.
 * 
 *  CDDL HEADER START
 * 
 *   The contents of this file are subject to the terms of the
 *   Common Development and Distribution License, Version 1.0 only
 *   (the "License").  You may not use this file except in compliance
 *   with the License.
 * 
 *   You can obtain a copy of the license at Docs/cddl1.txt
 *   or http://www.opensolaris.org/os/licensing.
 *   See the License for the specific language governing permissions
 *   and limitations under the License.
 * 
 *  CDDL HEADER END
 * 
 *  Author: Brendan Gregg  [Sydney, Australia]
 * 
 *  12-Mar-2004    Brendan Gregg    Created this, build 51.
 *  23-May-2004       "      "    Fixed mntpt bug.
 *  10-Oct-2004       "      "    Rewritten to use the io provider, build 63.
 *  04-Jan-2005       "      "    Wrapped in sh to provide options.
 *  08-May-2005       "      "    Rewritten for perfromance.
 *  15-Jul-2005       "      "    Improved DTIME calculation.
 *  25-Jul-2005       "      "    Added -p, -n. Improved code.
 *  17-Sep-2005       "      "    Increased switchrate.
 * 
 */

/*
 * Command line arguments
 */
inline int OPT_dump    = '0'; /* dump all data, space delimited */
inline int OPT_device  = '0'; /* enable filtering on specific device */
inline int OPT_delta   = '0'; /* print time delta, us (elapsed) */
inline int OPT_devname = '0'; /* print device name */
inline int OPT_file    = '0'; /* enable filtering on file */
inline int OPT_args    = '0'; /* print command arguments */
inline int OPT_ins     = '0'; /* print device instance */
inline int OPT_nums    = '0'; /* print major and minor numbers */
inline int OPT_dtime   = '0'; /* print disk delta time, us  */
inline int OPT_mount   = '0'; /* enable filtering on FS only */
inline int OPT_start   = '0'; /* print start time, us */
inline int OPT_pid     = '0'; /* enable filtering on PID */
inline int OPT_name    = '0'; /* enable filtering on process name */
inline int OPT_end     = '0'; /* print completion time, us */
inline int OPT_endstr  = '0'; /* print completion time, string */
inline int FILTER      = '0'; /* enable filtering, otherwise trace */
inline int PID         = '0'; /* this PID only */
inline string DEVICE   = "."; /* instance name to snoop (eg, dad0) */
inline string FILENAME = "."; /* when full pathname of file is specified, snoop this file only */
inline string MOUNT    = "."; /* this FS only (will skip raw events) */
inline string NAME     = "."; /* this process name only */


#pragma D option quiet
#pragma D option switchrate=10hz

/*
* Print header
*/
dtrace:::BEGIN 
{
last_event[""] = 0;

/* print optional headers */
OPT_start   ? printf("%-14s ","STIME")   : 1;
OPT_end     ? printf("%-14s ","TIME")    : 1;
OPT_endstr  ? printf("%-20s ","STRTIME") : 1;
OPT_devname ? printf("%-7s ","DEVICE")   : 1;
OPT_ins     ? printf("%-3s ","INS")      : 1;
OPT_nums    ? printf("%-3s %-3s ","MAJ","MIN") : 1;
OPT_delta   ? printf("%-10s ","DELTA")   : 1;
OPT_dtime   ? printf("%-10s ","DTIME")   : 1;

/* print main headers */
OPT_dump ? 
    printf("%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s\n",
    "TIME", "STIME", "DELTA", "DEVICE", "INS", "MAJ", "MIN", "UID",
    "PID", "PPID", "D", "BLOCK", "SIZE", "MOUNT", "FILE", "PATH",
    "COMM","ARGS") :
    printf("%5s %5s %1s %8s %6s ", "UID", "PID", "D", "BLOCK", "SIZE");
OPT_args == 0 ? printf("%10s %s\n", "COMM", "PATHNAME") : 1;
OPT_args == 1 ? printf("%28s %s\n", "PATHNAME", "ARGS") : 1;
}

/*
 * Check event is being traced
 */
io:::start
{ 
/* default is to trace unless filtering, */
self->ok = FILTER ? 0 : 1;

/* check each filter, */
(OPT_device == 1 && DEVICE == args[1]->dev_statname)? self->ok = 1 : 1;
(OPT_file == 1 && FILENAME == args[2]->fi_pathname) ? self->ok = 1 : 1;
(OPT_mount == 1 && MOUNT == args[2]->fi_mount) ? self->ok = 1 : 1;
(OPT_name == 1 && NAME == strstr(NAME, execname)) ? self->ok = 1 : 1;
(OPT_name == 1 && execname == strstr(execname, NAME)) ? self->ok = 1 : 1;
(OPT_pid == 1 && PID == pid) ? self->ok = 1 : 1;
}

/*
* Reset last_event for disk idle -> start
* this prevents idle time being counted as disk time.
*/
io:::start
/! pending[args[1]->dev_statname]/
{
  /* save last disk event */
  last_event[args[1]->dev_statname] = timestamp;
}

/*
* Store entry details
*/
io:::start
/self->ok/
{
/* these are used as a unique disk event key, */
this->dev = args[0]->b_edev;
this->blk = args[0]->b_blkno;

/* save disk event details, */
start_uid[this->dev, this->blk] = (int)uid;
start_pid[this->dev, this->blk] = pid;
start_ppid[this->dev, this->blk] = ppid;
start_args[this->dev, this->blk] = (char *)curpsinfo->pr_psargs;
start_comm[this->dev, this->blk] = execname;
start_time[this->dev, this->blk] = timestamp;

/* increase disk event pending count */
pending[args[1]->dev_statname]++;

self->ok = 0;
}

/*
* Process and Print completion
*/
io:::done
/start_time[args[0]->b_edev, args[0]->b_blkno]/
{
/* decrease disk event pending count */
pending[args[1]->dev_statname]--;

/*
  * Process details
  */

/* fetch entry values */
this->dev = args[0]->b_edev;
this->blk = args[0]->b_blkno;
this->suid = start_uid[this->dev, this->blk];
this->spid = start_pid[this->dev, this->blk];
this->sppid = start_ppid[this->dev, this->blk];
self->sargs = (int)start_args[this->dev, this->blk] == 0 ? 
    "" : start_args[this->dev, this->blk];
self->scomm = start_comm[this->dev, this->blk];
this->stime = start_time[this->dev, this->blk];
this->etime = timestamp; /* endtime */
this->delta = this->etime - this->stime;
this->dtime = last_event[args[1]->dev_statname] == 0 ? 0 :
    timestamp - last_event[args[1]->dev_statname];

/* memory cleanup */
start_uid[this->dev, this->blk]  = 0;
start_pid[this->dev, this->blk]  = 0;
start_ppid[this->dev, this->blk] = 0;
start_args[this->dev, this->blk] = 0;
start_time[this->dev, this->blk] = 0;
start_comm[this->dev, this->blk] = 0;
start_rw[this->dev, this->blk]   = 0;

/*
 * Print details
 */

/* print optional fields */
OPT_start   ? printf("%-14d ", this->stime/1000) : 1;
OPT_end     ? printf("%-14d ", this->etime/1000) : 1;
OPT_endstr  ? printf("%-20Y ", walltimestamp) : 1;
OPT_devname ? printf("%-7s ", args[1]->dev_statname) : 1;
OPT_ins     ? printf("%3d ", args[1]->dev_instance) : 1;
OPT_nums    ? printf("%3d %3d ",
    args[1]->dev_major, args[1]->dev_minor) : 1;
OPT_delta   ? printf("%-10d ", this->delta/1000) : 1;
OPT_dtime   ? printf("%-10d ", this->dtime/1000) : 1;

/* print main fields */
OPT_dump ? 
    printf("%d %d %d %s %d %d %d %d %d %d %s %d %d %s %s %s %s %S\n",
    this->etime/1000, this->stime/1000, this->delta/1000,
    args[1]->dev_statname, args[1]->dev_instance, args[1]->dev_major,
    args[1]->dev_minor, this->suid, this->spid, this->sppid, 
    args[0]->b_flags & B_READ ? "R" : "W", 
    args[0]->b_blkno, args[0]->b_bcount, args[2]->fi_mount,
    args[2]->fi_name, args[2]->fi_pathname, self->scomm, self->sargs) :
    printf("%5d %5d %1s %8d %6d ",
    this->suid, this->spid, args[0]->b_flags & B_READ ? "R" : "W",
    args[0]->b_blkno, args[0]->b_bcount);
OPT_args == 0 ? printf("%10s %s\n", self->scomm, args[2]->fi_pathname)
    : 1;
OPT_args == 1 ? printf("%28s %S\n",
    args[2]->fi_pathname, self->sargs) : 1;

/* save last disk event */
last_event[args[1]->dev_statname] = timestamp;

/* cleanup */
self->scomm = 0;
self->sargs = 0;
}

/*
* Prevent pending from underflowing
* this can happen if this program is started during disk events.
*/
io:::done
/pending[args[1]->dev_statname] < 0/
{
pending[args[1]->dev_statname] = 0;
}
