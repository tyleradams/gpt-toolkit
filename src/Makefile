all :

install :
	mkdir -p $(DESTDIR)$(prefix)/bin
	install gpt $(DESTDIR)$(prefix)/bin
	install gpt-to-substack $(DESTDIR)$(prefix)/bin
	install gpt-token-length $(DESTDIR)$(prefix)/bin
	install gpt-extract-code $(DESTDIR)$(prefix)/bin
	mkdir -p $(DESTDIR)$(prefix)/share/man/man1
	install -m 644 man/gpt.1 $(DESTDIR)$(prefix)/share/man/man1/gpt.1

