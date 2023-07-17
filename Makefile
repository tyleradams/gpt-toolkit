args = $(foreach a,$($(subst -,_,$1)_args),$(if $(value $a),$a="$($a)"))

# Only install if apt is on system, otherwise do nothing
# Using oneliner to avoid messing around with makefile if statements

dependencies :  python-dependencies
all :  python-dependencies

python-dependencies : requirements.txt
	python3 -m pip install -r requirements.txt

clean:
	rm -rf target
install :
	prefix=/usr/local
	export prefix
	(cd src; prefix=/usr/local make install)
package:
	mkdir -p target/bin
	(cd src; make)
	tar czf target/gpt-toolkit_${version}.orig.tar.gz src --transform "s#src#gpt-toolkit-${version}#"
	(cd target; tar xf gpt-toolkit_${version}.orig.tar.gz;)
	cp -r debian target/gpt-toolkit-${version}/debian
	(cd target/gpt-toolkit-${version}; debuild -S -us -uc;)

publish:
	debsign -k 5DB475563E94EEAC666956FD31CA7EECE167B1C8 ./target/gpt-toolkit_${version}_source.changes
	dput -f code-faster ./target/gpt-toolkit_${version}_source.changes
