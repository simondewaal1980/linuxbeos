.PHONY: all check vm iso release release-full matrix test static assets test-uefi test-bios test-install-uefi test-install-bios clean distclean help

help:
	@printf '%s\n' \
	  'LinuxBeOS build targets:' \
	  '  make check              Hostafhankelijkheden controleren' \
	  '  make vm                 Build-VM aanmaken/starten' \
	  '  make iso                ISO bouwen in de build-VM' \
	  '  make release            Check + ISO + statische controle + UEFI/BIOS-rooktest' \
	  '  make release-full       Als release, plus de volledige releasematrix (Btrfs/rollback)' \
	  '  make matrix             Volledige releasematrix op de bestaande dist-ISO' \
	  '  make static             Statische projectcontrole' \
	  '  make assets             Thema-assets opnieuw genereren' \
	  '  make test-uefi          UEFI-rooktest (live-sessie)' \
	  '  make test-bios          BIOS-rooktest (live-sessie)' \
	  '  make test-install-uefi  UEFI-installatietest + Btrfs snapshot/rollback' \
	  '  make test-install-bios  BIOS-installatietest + Btrfs snapshot/rollback' \
	  '  make test               Statische controle + beide rooktesten' \
	  '  make test-install       Beide installatietests' \
	  '  make clean              Build- en testartefacten verwijderen' \
	  '  make distclean          Ook de build-VM en cache verwijderen'

all: iso

check:
	scripts/00-check-host.sh

vm:
	scripts/01-create-build-vm.sh

iso:
	scripts/10-build-iso.sh

release:
	scripts/20-build-release.sh

release-full:
	scripts/20-build-release.sh --full

matrix:
	tests/release-matrix.sh

static:
	tests/static/check-config.sh

assets:
	python3 desktop/tools/generate-assets.py

test-uefi:
	tests/test-uefi.sh

test-bios:
	tests/test-bios.sh

test-install-uefi:
	tests/test-install-uefi.sh

test-install-bios:
	tests/test-install-bios.sh

test: static test-uefi test-bios

test-install: test-install-uefi test-install-bios

clean:
	rm -rf dist tests/vm/*.qcow2 tests/vm/*/*.qcow2 tests/vm/*/*.log
	rm -rf .build/iso .build/lb-build.out

distclean: clean
	scripts/01-create-build-vm.sh --delete || true
	rm -rf .build
