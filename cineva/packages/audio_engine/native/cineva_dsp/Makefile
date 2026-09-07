# Cineva DSP — build sans dépendance (gcc/clang).
#   make            → lib statique + lib partagée + tests + benchmark
#   make test       → compile et lance les tests
#   make bench      → compile et lance le benchmark
#   make goldens DIR=../../test/goldens → régénère les golden files

CC      ?= cc
CFLAGS  ?= -O2 -std=c99 -Wall -Wextra -Wno-unused-parameter -fPIC -pedantic
LDFLAGS ?=

SRC_DIR := src
TEST_DIR := test
BUILD   := build

SRCS := $(SRC_DIR)/biquad.c $(SRC_DIR)/loudness.c $(SRC_DIR)/param_eq.c \
        $(SRC_DIR)/drc.c $(SRC_DIR)/dialogue.c $(SRC_DIR)/bass.c \
        $(SRC_DIR)/spatial.c $(SRC_DIR)/room.c $(SRC_DIR)/limiter.c \
        $(SRC_DIR)/channel_mapper.c $(SRC_DIR)/cineva_dsp.c
OBJS := $(patsubst $(SRC_DIR)/%.c,$(BUILD)/%.o,$(SRCS))

TEST_BIN := $(BUILD)/cineva_dsp_test
BENCH_BIN := $(BUILD)/cineva_dsp_benchmark

.PHONY: all test bench goldens clean

all: $(BUILD)/libcineva_dsp.a $(BUILD)/libcineva_dsp.so $(TEST_BIN) $(BENCH_BIN)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: $(SRC_DIR)/%.c | $(BUILD)
	$(CC) $(CFLAGS) -Iinclude -I$(SRC_DIR) -c $< -o $@

$(BUILD)/libcineva_dsp.a: $(OBJS)
	ar rcs $@ $^

$(BUILD)/libcineva_dsp.so: $(OBJS)
	$(CC) -shared -o $@ $^ $(LDFLAGS)

$(TEST_BIN): $(TEST_DIR)/test_main.c $(OBJS)
	$(CC) $(CFLAGS) -Iinclude -I$(SRC_DIR) $< $(OBJS) -lm -o $@

$(BENCH_BIN): $(TEST_DIR)/benchmark.c $(OBJS)
	$(CC) $(CFLAGS) -Iinclude -I$(SRC_DIR) $< $(OBJS) -lm -o $@

test: $(TEST_BIN)
	./$(TEST_BIN)

bench: $(BENCH_BIN)
	./$(BENCH_BIN)

goldens: $(TEST_BIN)
	./$(TEST_BIN) $(if $(DIR),$(DIR),.)

clean:
	rm -rf $(BUILD)
