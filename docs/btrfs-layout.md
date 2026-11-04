# Btrfs-layout (fase 2)

Dit document wordt in fase 2 uitgewerkt. De voorlopige indeling staat al in
`config/project.conf` (`BTRFS_SUBVOLUMES`) zodat de namen consistent zijn.

| Subvolume | Mountpoint | Bijzonderheden |
|---|---|---|
| `@` | `/` | root, `compress=zstd`, `noatime` |
| `@home` | `/home` | gebruikersdata, blijft behouden bij rollback van `/` |
| `@snapshots` | `/.snapshots` | Snapper-snapshots |
| `@var_log` | `/var/log` | apart subvolume |
| `@var_cache` | `/var/cache` | apart subvolume |
| `@swap` | `/swap` | swapfile zonder CoW (`chattr +C`) of zram |

Uitgangspunten:

- `compress=zstd` op de root-subvolumes, `noatime`
- Snapper-configuratie `root` met timeline-snapshots en apt-hooks
- `grub-btrfs` zodat snapshots in het GRUB-menu verschijnen
- Rollback van `/` laat `/home` intact
- Geen snapshots van `@var_cache` en `@swap`

De exacte keuzes (swapfile versus zram, snapshotretentie, rollbackprocedure)
worden in fase 2 vastgelegd en getest in de VM.
