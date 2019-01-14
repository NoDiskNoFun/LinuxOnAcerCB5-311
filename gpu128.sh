while [ "1" = "1" ]
do
speed=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq)
if [ "$speed" = "2524500" ]; then
    echo 0f > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "2422500" ]; then
    echo 0e > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "2320500" ]; then
    echo 0d > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "2218500" ]; then
    echo 0d > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "2116500" ]; then
    echo 0c > /sys/kernel/debug/dri/129/pstate
fi
if [ "$speed" = "2014500" ]; then
    echo 0c > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1938000" ]; then
    echo 0b > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1734000" ]; then
    echo 0a > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1632000" ]; then
    echo 0a > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1530000" ]; then
    echo 09 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1428000" ]; then
    echo 09 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1326000" ]; then
    echo 08 > /sys/kernel/debug/dri/129/pstate
fi
if [ "$speed" = "1224000" ]; then
    echo 08 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1122000" ]; then
    echo 08 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "1020000" ]; then
    echo 07 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "918000" ]; then
    echo 07 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "816000" ]; then
    echo 06 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "714000" ]; then
    echo 06 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "612000" ]; then
    echo 05 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "510000" ]; then
    echo 05 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "408000" ]; then
    echo 04 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "306000" ]; then
    echo 04 > /sys/kernel/debug/dri/128/pstate
fi
if [ "$speed" = "204000" ]; then
    echo 03 > /sys/kernel/debug/dri/128/pstate
fi
sleep 1
done
