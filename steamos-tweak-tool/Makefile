# GNU Makefile for steamos-tweak-tool
# Not much here at the moment ...


# ---------------------------
# Helper functions
# ---------------------------

check_gcc = $(shell if echo | $(CC) $(1) -Werror -S -o /dev/null -xc - > /dev/null 2>&1; then echo "$(1)"; else echo "$(2)"; fi;)

# ---------------------------

HOST_OS := $(shell uname|sed -e s/_.*//|tr '[:upper:]' '[:lower:]')

DEBUG   ?= 0

# ---------------------------
# build variables
# ---------------------------

CC ?= gcc
LINKER = $(CC)

STRIP ?= strip

# ---------------------------
# targets
# ---------------------------

.PHONY:	clean debug release

DEFAULT_TARGET := release

# ---------------------------
# rules
# ---------------------------

#%.o:	%.c
#	$(CC) $(DFLAGS) -c $(CFLAGS) $(SDL_CFLAGS) -o $@ $^

# ---------------------------
# objects
# ---------------------------

MENU_OBJ:=menu.c


# ------------------------
# Linux build rules
# ------------------------

steamos-tweak-tool:
	$(LINKER) -o steamos-tweak-tool -c $(MENU_OBJ)

release:	steamos-tweak-tool


prefix ?= /usr
exec_prefix ?= $(prefix)
bindir ?= $(exec_prefix)/games
sbindir ?= $(exec_prefix)/sbin
INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL)
INSTALL_DATA ?= ${INSTALL} -m 644
install: steamos-tweak-tool
