install:
	cp pw-apply            /usr/bin/pw-apply
	cp pw-check            /usr/bin/pw-check
	cp pw-request-pull     /usr/bin/pw-request-pull
	cp pw-backport         /usr/bin/pw-backport

uninstall:
	$(RM) /usr/bin/pw-apply /usr/bin/pw-request-pull /usr/bin/pw-check /usr/bin/pw-backport
