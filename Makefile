CC = gcc
CFLAGS = -O2 -fPIC -shared
LIBS = -lgmp -llua

# OS Detect
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    EXT = dylib
else
    EXT = so
endif

BUILD_DIR = build
SRC_C = src_c

TARGETS = $(BUILD_DIR)/gmporacle.$(EXT) $(BUILD_DIR)/gmpdec.$(EXT)

all: build_c test

# Compile c libs
build_c: $(TARGETS)

$(BUILD_DIR)/gmporacle.$(EXT): $(SRC_C)/gmp_bigint_oracle.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

$(BUILD_DIR)/gmpdec.$(EXT): $(SRC_C)/gmp_decimal_oracle.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

# Run all tests
test:
	lua run_tests.lua

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all build_c test clean
