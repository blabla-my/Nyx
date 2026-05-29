chmod +x hget

if [ ! -x ./hget ]; then
	echo "[fuzz.sh] hget missing" > /tmp/hget_missing.log
	exit 1
fi

./hget hcat hcat
chmod +x hcat

log_step() {
	echo "[fuzz.sh] $1" | ./hcat
}

log_step "hget downloaded by loader OK"

./hget hypertrash.iso hypertrash.iso
log_step "downloaded hypertrash.iso"

./hget hypertrash_crash_detector hypertrash_crash_detector
log_step "downloaded hypertrash_crash_detector"

./hget hypertrash_crash_detector_asan hypertrash_crash_detector_asan
log_step "downloaded hypertrash_crash_detector_asan"

./hget set_kvm_ip_range set_kvm_ip_range
log_step "downloaded set_kvm_ip_range"

./hget set_ip_range set_ip_range
log_step "downloaded set_ip_range"

chmod +x hypertrash_crash_detector
log_step "chmod +x hypertrash_crash_detector"

chmod +x hypertrash_crash_detector_asan
log_step "chmod +x hypertrash_crash_detector_asan"

chmod +x set_kvm_ip_range
log_step "chmod +x set_kvm_ip_range"

chmod +x set_ip_range
log_step "chmod +x set_ip_range"

#./set_kvm_ip_range
#./set_ip_range 0x1000 0x7ffffffff000 1

# disable ASLR
echo 0 > /proc/sys/kernel/randomize_va_space
log_step "disabled ASLR"

./set_ip_range 0x1000 0x6ffffffff000 0
log_step "configured IP range"

echo 0 > /proc/sys/kernel/printk
log_step "disabled kernel printk"

clear
log_step "cleared terminal"

QEMU_BIN=""
for candidate in \
    /home/user/qemu-10.0.8/build/qemu-system-x86_64 \
    /home/user/qemu-4.2.0/x86_64-softmmu/qemu-system-x86_64 \
    /usr/bin/qemu-system-x86_64 \
    $(command -v qemu-system-x86_64 2>/dev/null)
do
    if [ -x "$candidate" ]; then
        QEMU_BIN="$candidate"
        break
    fi
done

if [ -z "$QEMU_BIN" ]; then
	echo "qemu-system-x86_64 not found" > /tmp/data.log
	log_step "qemu-system-x86_64 not found"
	exit 1
fi
log_step "selected QEMU binary: $QEMU_BIN"

PRELOAD="./hypertrash_crash_detector"
for asan in /usr/lib/x86_64-linux-gnu/libasan.so.8 /usr/lib/x86_64-linux-gnu/libasan.so.6 /usr/lib/x86_64-linux-gnu/libasan.so.5 /usr/lib/x86_64-linux-gnu/libasan.so.4
do
	if [ -e "$asan" ]; then
		PRELOAD="$asan:$PRELOAD"
		log_step "selected ASAN runtime: $asan"
		break
	fi
done

log_step "starting nested QEMU"
rm -f /tmp/qemu_status
{
	LD_PRELOAD="$PRELOAD" ASAN_OPTIONS=abort_on_error=true:detect_leaks=false "$QEMU_BIN" \
		-cdrom hypertrash.iso \
		-enable-kvm \
		-net none \
		-display none \
		-serial stdio \
		-monitor none \
		-device nec-usb-xhci 2>&1
	echo "$?" > /tmp/qemu_status
} | tee /tmp/data.log | while IFS= read -r line
do
	printf '%s\n' "$line" | ./hcat
done

QEMU_STATUS="$(cat /tmp/qemu_status 2>/dev/null)"
log_step "nested QEMU exited with status $QEMU_STATUS"
