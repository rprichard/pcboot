build/install-pcboot.py :
	rm -f build/install-pcboot.py
	ln -s ../src/install-pcboot.py build/install-pcboot.py

FINAL_OUTPUTS := $(FINAL_OUTPUTS) \
	build/install-pcboot.py
