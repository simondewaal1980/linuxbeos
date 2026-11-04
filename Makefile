.PHONY: all check vm iso test static test-uefi test-bios clean distclean help

help:
	@printf '%s\n' \
	  'LinuxBeOS build targets:' \
	  '  make check       Hostafhankelijkheden controleren' \
	  '  make vm          Build-VM aanmaken/starten' \
	  '  make iso         ISO bouwen in de build-VM' \
	  '  make static      Statische projectcontrole' \
	  '  make test-uefi   UEFI-rooktest' \
	  '  make test-bios   BIOS-rooktest' \
	  '  make test        Statische controle + beide rooktesten' \
	  '  make clean       Build- en testartefacten verwijderen' \
	  '  make distclean   Ook de build-VM en cache verwijderen'

all: iso

check:
	scripts/00-check-host.sh

vm:
	scripts/01-create-build-vm.sh

iso:
	scripts/10-build-iso.sh

static:
	tests/static/check-config.sh

test-uefi:
	tests/test-uefi.sh

test-bios:
	tests/test-bios.sh

test: static test-uefi test-bios

clean:
	rm -rf dist tests/vm/*.qcow2 tests/vm/*/*.qcow2 tests/vm/*/*.log
	rm -rf .build/iso .build/lb-build.out

distclean: clean
	scripts/01-create-build-vm.sh --delete || true
	rm -rf .build
