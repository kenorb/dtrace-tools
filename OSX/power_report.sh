#!/bin/bash

if [ $UID -ne 0 ]
then
	echo "Requires root privileges. Please re-run using sudo."
	exit 1
fi

if [ $# -lt 1 ]
then
	echo "Usage: $0 file"
	exit 1
fi

echo "Writing power report to $1..."

echo "Running powermetrics..."
echo "*** Powermetrics ***" >> $1
date >> $1
powermetrics -p -d -i 2000 >> $1 &
sleep 11
killall powermetrics
echo "Done"

wait %1

echo "Running timer analysis..."
echo "*** Timer analysis ***" >> $1
date >> $1
timer_analyser.d 100 >> $1 &
sleep 12
killall dtrace
echo "Done"

wait %1

echo "Running cpu profiler..."
echo "*** CPU profile (non-idle) ***" >> $1
date >> $1
cpu_profiler.d >> $1 &
sleep 12
killall dtrace
echo "Done"

wait %1

echo "Running IO report..."
echo "*** IO report ***" >> $1
date >> $1
iosnoop >> $1 &
sleep 12
killall dtrace
echo "Done"

wait %1

echo "Running exec report..."
date >> $1
echo "*** Exec report ***" >> $1
execsnoop >> $1 &
sleep 12
killall dtrace
echo "Done"

wait %1
exit 0
