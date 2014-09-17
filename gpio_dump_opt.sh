#! /bin/bash
# Sourced from linux-rockchip.info, which referred to this thread
# http://www.freaktab.com/showthread.php?7021-GPIO-module-to-check-gpios-in-wifi-and-bt-Lets-make-the-wifi-and-BT-work-in-more-devices&p=124430&viewfull=1#post124430
# License therefore completely unknown, but presumably copyright "raxy, gormar, leolas"

# Not all machines have useful tools, or the busybox symlinks installed
# attempt to set a prefix for busybox to get less common tools
b=""
[ -f /system/bin/sed ] || b="busybox"
GPIO_BINARY=/data/karl/gpio
b_has_dc=`$b dc 1 1 + p 2>/dev/null`
b_has_expr=`$b expr 1 + 1 2>/dev/null`
OUT=GPIO-DUMP-


# TODO - make better tests for this
#$b modprobe user-gpio-drv
module_gpio=`$b lsmod | $b grep -e user_gpio_drv`

if [ "$module_gpio" = "" ]
then
    $b echo "ERROR: Can't load kernel module: \"user-gpio-drv.ko\""
    $b echo "Probably you haven't got super user privileges"
    $b echo "or depmod -a has not been run or module is missing"
    exit 1
fi

echo "User GPIO module loaded!"
echo


for conf in $($b seq 1 7)
do
for on in 0 1
do

gpio_nr=159
end=287

OUTF="${OUT}conf$conf-$([ "$on" == "1" ] && echo freqon || echo alloff).RF"
for n in $($b seq 0 2)
do
  switch=/sys/class/rfkill/rfkill$n
  OUTF="${OUTF}$(echo $(( ($conf >> $n) & $on )) | $b tee $switch/state)"
done

OUTF="$OUTF.log"
for n in $($b seq 0 2)
do
  switch=/sys/class/rfkill/rfkill$n
  echo "*** $switch ***" >> $OUTF
  cat $switch/uevent >> $OUTF
done

sleep 6 # wait for RF to settle
echo
echo "NEW GPIO DUMP"

while [ $gpio_nr -lt $end ]
do
    let gpio_nr+=1
    gpio_num=$gpio_nr

    if [ $b_has_expr ]
    then
         gpio_off=`$b expr $gpio_num  - 160`
         gpio_bank=`$b expr $gpio_off / 32`
         gpio_goff=`$b expr $gpio_off % 32`
         gpio_goff=`$b expr $gpio_goff / 8`
         gpio_off=`$b expr $gpio_off % 32`
         gpio_off=`$b expr $gpio_off % 8`
    else
         $b echo "expr command is unsupported! Make it available or us another shell."
    fi
  
    gpio_goff=`$b echo -n $gpio_goff | $b sed -e 's/0/A/' -e 's/1/B/' -e 's/2/C/' -e 's/3/D/'`
        $b echo -n "$gpio_num: RK30_PIN$gpio_bank"_"P$gpio_goff$gpio_off = " >> $OUTF
        $GPIO_BINARY get $gpio_num >> $OUTF
done
echo $OUTF written

done
done

for i in $($b seq 1 7)
do
    $b diff -u *conf$i*log > ${OUT}conf$i-unified.diff
done
