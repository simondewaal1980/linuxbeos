#!/usr/bin/env bash
# Maakt, start en beheert de geïsoleerde Debian Sid build-VM.
#
# De VM draait met directe QEMU/KVM (geen libvirt) en user-mode networking.
# SSH is bereikbaar op 127.0.0.1:$BUILD_VM_SSH_PORT en wordt gebruikt om de
# projectmap te synchroniseren en de ISO te bouwen.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

ACTION=create
REFRESH_BASE=0
NO_WAIT=0
TIMEOUT=1800

usage() {
  cat <<EOF
Gebruik: $0 [opties]

Zonder opties: maak de build-VM aan als die nog niet bestaat, of start hem.
Opties:
  --recreate       Verwijder de VM-schijf en maak een schone VM (basisimage blijft)
  --refresh-base   Download het Debian Sid cloud-image opnieuw
  --stop           Sluit de build-VM netjes af
  --delete         Verwijder de build-VM inclusief schijf, seed en SSH-sleutel
  --status         Toon status van de build-VM
  --log            Toon de laatste regels van de seriële console
  --no-wait        Start de VM zonder te wachten op SSH/cloud-init
  --timeout N      Timeout in seconden voor SSH/cloud-init (standaard 1800)
  -h, --help       Deze uitleg
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --recreate) ACTION=recreate ;;
    --refresh-base) REFRESH_BASE=1 ;;
    --stop) ACTION=stop ;;
    --delete) ACTION=delete ;;
    --status) ACTION=status ;;
    --log) ACTION=log ;;
    --no-wait) NO_WAIT=1 ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout vereist een waarde"
      TIMEOUT="$2"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

require_cmd curl qemu-img ssh ssh-keygen rsync xorriso sha256sum
[[ -n "$QEMU_BIN" ]] || die "qemu-system-x86_64 niet gevonden"
kvm_available || die "/dev/kvm is niet toegankelijk; de build-VM vereist KVM"

mkdir -p "$CACHE_DIR" "$VM_DIR"

download_base() {
  step "Debian Sid cloud-image"
  if [[ -f "$VM_BASE_IMAGE" && $REFRESH_BASE -eq 0 ]]; then
    ok "basisimage aanwezig: $VM_BASE_IMAGE"
    return 0
  fi
  rm -f "$VM_BASE_IMAGE" "$VM_BASE_IMAGE.part"
  log "downloaden: $BUILD_VM_BASE_URL"
  curl -fL --retry 3 --retry-delay 5 --connect-timeout 20 \
    -o "$VM_BASE_IMAGE.part" "$BUILD_VM_BASE_URL"
  "$QEMU_IMG" info "$VM_BASE_IMAGE.part" >/dev/null \
    || die "gedownloade image is geen geldig qcow2-bestand"
  mv "$VM_BASE_IMAGE.part" "$VM_BASE_IMAGE"
  ok "basisimage opgeslagen: $VM_BASE_IMAGE"
}

ensure_ssh_key() {
  if [[ ! -f "$VM_SSH_KEY" ]]; then
    log "SSH-sleutel genereren: $VM_SSH_KEY"
    mkdir -p "$(dirname "$VM_SSH_KEY")"
    ssh-keygen -q -t ed25519 -N "" -C "${BUILD_VM_NAME}" -f "$VM_SSH_KEY"
  fi
  chmod 600 "$VM_SSH_KEY"
  chmod 644 "$VM_SSH_KEY.pub"
  [[ -f "$VM_KNOWN_HOSTS" ]] || : > "$VM_KNOWN_HOSTS"
  chmod 600 "$VM_KNOWN_HOSTS" 2>/dev/null || true
}

write_cloud_init() {
  local pubkey packages
  pubkey="$(cat "$VM_SSH_KEY.pub")"

  cat > "$VM_USER_DATA" <<EOF
#cloud-config
hostname: ${BUILD_VM_NAME}
manage_etc_hosts: true
timezone: Etc/UTC
locale: en_US.UTF-8

growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true

users:
  - name: ${BUILD_VM_SSH_USER}
    gecos: LinuxBeOS build user
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    plain_text_passwd: ${BUILD_VM_SSH_PASSWORD}
    ssh_authorized_keys:
      - ${pubkey}

ssh_pwauth: false
package_update: true
package_upgrade: false

packages:
  - live-build
  - debootstrap
  - fakeroot
  - squashfs-tools
  - xorriso
  - mtools
  - dosfstools
  - isolinux
  - syslinux-common
  - syslinux-efi
  - grub-pc-bin
  - grub-efi-amd64-bin
  - rsync
  - ca-certificates
  - curl
  - file
  - git

runcmd:
  - [ bash, -c, "touch /home/${BUILD_VM_SSH_USER}/cloud-init-ready && chown ${BUILD_VM_SSH_USER}:${BUILD_VM_SSH_USER} /home/${BUILD_VM_SSH_USER}/cloud-init-ready" ]

final_message: "LinuxBeOS build-VM is klaar na \$UPTIME seconden."
EOF

  cat > "$VM_META_DATA" <<EOF
instance-id: ${BUILD_VM_NAME}-001
local-hostname: ${BUILD_VM_NAME}
EOF

  local seed_dir="$VM_DIR/seed"
  rm -rf "$seed_dir"
  mkdir -p "$seed_dir"
  cp "$VM_USER_DATA" "$VM_META_DATA" "$seed_dir/"
  rm -f "$VM_SEED_ISO"
  xorriso -as mkisofs -quiet -output "$VM_SEED_ISO" \
    -volid cidata -joliet -rock "$seed_dir"
  rm -rf "$seed_dir"
  ok "cloud-init seed-ISO gemaakt: $VM_SEED_ISO"
}

create_disk() {
  step "Build-VM-schijf"
  [[ -f "$VM_BASE_IMAGE" ]] || die "basisimage ontbreekt: $VM_BASE_IMAGE"
  rm -f "$VM_OVERLAY"
  "$QEMU_IMG" create -q -f qcow2 -F qcow2 -b "$VM_BASE_IMAGE" \
    "$VM_OVERLAY" "${BUILD_VM_DISK_GB}G"
  ok "overlay-schijf gemaakt (${BUILD_VM_DISK_GB} GiB, backing: basisimage)"
}

port_in_use() {
  have_cmd ss && ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${BUILD_VM_SSH_PORT}$"
}

start_vm() {
  step "Build-VM starten"
  if vm_is_running; then
    ok "build-VM draait al (pid $(vm_pid))"
    return 0
  fi
  rm -f "$VM_PIDFILE"
  if port_in_use; then
    die "TCP-poort $BUILD_VM_SSH_PORT is al in gebruik; kies een andere BUILD_VM_SSH_PORT in config/project.conf"
  fi
  if [[ ! -f "$VM_OVERLAY" ]]; then
    die "VM-schijf ontbreekt; voer $0 uit zonder --stop/--status of gebruik --recreate"
  fi
  if [[ ! -f "$VM_SEED_ISO" ]]; then
    die "cloud-init seed-ISO ontbreekt; gebruik --recreate"
  fi

  if [[ -f "$VM_SERIAL_LOG" ]]; then
    mv -f "$VM_SERIAL_LOG" "$VM_SERIAL_LOG.prev"
  fi

  "$QEMU_BIN" \
    -name "$BUILD_VM_NAME" \
    -machine q35,accel=kvm \
    -cpu host \
    -smp "$BUILD_VM_CPUS" \
    -m "$BUILD_VM_MEMORY_MB" \
    -drive "file=$VM_OVERLAY,if=virtio,format=qcow2,cache=writeback" \
    -drive "file=$VM_SEED_ISO,media=cdrom,readonly=on,format=raw" \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${BUILD_VM_SSH_PORT}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -rtc base=utc \
    -display none \
    -serial "file:$VM_SERIAL_LOG" \
    -monitor none \
    -no-reboot \
    -daemonize \
    -pidfile "$VM_PIDFILE"

  ok "QEMU gestart (pid $(vm_pid)); serieel log: $VM_SERIAL_LOG"
}

wait_boot() {
  step "Wachten op build-VM"
  if ! wait_for_vm_ssh "$TIMEOUT"; then
    die "build-VM kwam niet binnen ${TIMEOUT}s online; zie $VM_SERIAL_LOG"
  fi
  ok "SSH bereikbaar op 127.0.0.1:$BUILD_VM_SSH_PORT"
  if ! wait_for_cloud_init "$TIMEOUT"; then
    die "cloud-init in de build-VM is niet klaar; zie $VM_SERIAL_LOG en /var/log/cloud-init-output.log"
  fi
  ok "cloud-init klaar (build-gereedschap geïnstalleerd)"

  local lb_version
  if lb_version="$(vm_ssh 'lb --version 2>/dev/null' 2>/dev/null)"; then
    ok "live-build in VM: $lb_version"
  else
    warn "kon live-build in de VM niet uitvoeren"
  fi
}

show_status() {
  printf 'Build-VM: %s\n' "$BUILD_VM_NAME"
  if vm_is_running; then
    printf '  status:   running (pid %s)\n' "$(vm_pid)"
    if vm_ssh_ready; then
      printf '  SSH:      bereikbaar op 127.0.0.1:%s\n' "$BUILD_VM_SSH_PORT"
      printf '  cloud:    %s\n' "$(vm_ssh 'cloud-init status 2>/dev/null || true' 2>/dev/null | head -1)"
    else
      printf '  SSH:      nog niet bereikbaar\n'
    fi
  else
    printf '  status:   gestopt\n'
  fi
  printf '  schijf:   %s\n' "$VM_OVERLAY"
  printf '  log:      %s\n' "$VM_SERIAL_LOG"
}

case "$ACTION" in
  status)
    show_status
    exit 0
    ;;
  log)
    [[ -f "$VM_SERIAL_LOG" ]] || die "nog geen serieel log: $VM_SERIAL_LOG"
    exec tail -n 80 -f "$VM_SERIAL_LOG"
    ;;
  stop)
    stop_build_vm
    ok "build-VM gestopt"
    exit 0
    ;;
  delete)
    stop_build_vm
    rm -rf "$VM_DIR"
    ok "build-VM verwijderd (basisimage in $CACHE_DIR blijft bewaard)"
    exit 0
    ;;
esac

download_base
ensure_ssh_key

if [[ "$ACTION" == "recreate" ]]; then
  stop_build_vm
  rm -f "$VM_OVERLAY" "$VM_SEED_ISO" "$VM_USER_DATA" "$VM_META_DATA"
fi

if [[ ! -f "$VM_USER_DATA" || ! -f "$VM_SEED_ISO" ]]; then
  write_cloud_init
fi
if [[ ! -f "$VM_OVERLAY" ]]; then
  create_disk
fi

start_vm

if (( NO_WAIT )); then
  show_status
  exit 0
fi

wait_boot
show_status
