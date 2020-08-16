SRC_DIR:=src
BIN_DIR:=bin
SRC_FILES:=$(wildcard $(SRC_DIR)/*.asm)
TARGETS=$(patsubst $(SRC_DIR)/%.asm,$(BIN_DIR)/%.com,$(SRC_FILES))

all: $(TARGETS)

$(BIN_DIR)/%.com: $(SRC_DIR)/%.asm
	@mkdir -p $(BIN_DIR)
	zasm -uwy --z180 $< -l $(BIN_DIR)/$*.lst -o $@

clean:
	rm -f $(BIN_DIR)/*.com $(BIN_DIR)/*.lst
