JTFRAME_PATCHES = jtframe-cfgstr-options.patch jtframe-cfgstr-credits.patch jtframe-no-dirty.patch jtframe-no-git-hooks.patch
JT49_PATCHES = jt49-custom-exp.patch

nemesis:
	$(eval CORE := nemesis)

salamander:
	$(eval CORE := salamander)

compile: colmix
	jtcore -mr $(CORE)

docker_compile:
	docker run -it --rm \
		-e TZ=Europe/Zurich \
		-v $$(pwd):/build \
		jtframe:17.1-2023 \
		bash -ic '. setprj.sh && make $(CORE) compile'
	
copy: ## copy .rbf to MiSTer
	#scp rom/Nemesis\ \(ROM\ version\).mra root@192.168.1.118:/media/fat/
	scp mister/output_1/jtnemesis.rbf root@192.168.1.118:/media/fat/

colmix:
	make -C cpp colmix

warnings:
	grep -v -F -f nolog.txt log/mister/jtnemesis.log | less +/warn

patch-jtframe:
	@for patch in $(JTFRAME_PATCHES); do \
		patch -p1 --forward --dir modules/jtframe --reject-file=/tmp/rej < patches/$$patch ; \
	done

patch-jt49:
	@for patch in $(JT49_PATCHES); do \
		patch -p1 --forward --dir modules/jt49 --reject-file=/tmp/rej < patches/$$patch ; \
	done

clean:
	make -C rom clean

.PHONY: compile prog rom clean copy
